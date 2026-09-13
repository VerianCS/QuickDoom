import 'dart:math' as math;
import 'dart:ui';

/// A point in map space: [x] and [y] are Doom's floor plane, [z] is height.
///
/// Doom stores geometry as a 2D plan plus per-sector floor and ceiling
/// heights, so the third axis is reconstructed rather than read.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get length => math.sqrt(x * x + y * y + z * z);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, '
      '${z.toStringAsFixed(2)})';
}

/// The result of projecting a world point: where it lands on screen, how far
/// it was from the camera, and whether it sits in front of the near plane.
class Projected {
  final Offset screen;
  final double depth;
  final bool visible;

  const Projected({
    required this.screen,
    required this.depth,
    required this.visible,
  });

  static const Projected behind =
      Projected(screen: Offset.zero, depth: double.infinity, visible: false);
}

/// Orbit camera over a map.
///
/// The camera always looks at [target] from a point on a sphere of radius
/// [distance], positioned by [yaw] and [pitch]. That keeps navigation
/// predictable — every drag maps to an angle, and the map cannot be lost off
/// screen the way a free-flying camera allows.
class HologramCamera {
  /// Rotation around the vertical axis, in radians.
  double yaw;

  /// Elevation above the floor plane, in radians. Clamped so the camera stays
  /// above the map and never flips through the poles.
  double pitch;

  /// Distance from [target], in map units.
  double distance;

  /// Point the camera orbits, in map space.
  Vec3 target;

  /// Vertical field of view, in radians.
  double fov;

  /// Extra screen-space offset, so the user can shift the map within the
  /// frame without moving the orbit centre.
  Offset panOffset;

  HologramCamera({
    this.yaw = -math.pi / 4,
    this.pitch = 0.62,
    this.distance = 3000,
    this.target = Vec3.zero,
    this.fov = 0.9,
    this.panOffset = Offset.zero,
  });

  static const double minPitch = 0.06;
  static const double maxPitch = 1.52;
  static const double minDistance = 64;
  static const double maxDistance = 60000;

  /// Height scale applied to map z, exaggerating relief so short steps read.
  static const double heightScale = 1.0;

  /// Anything closer than this is clipped; it would project to absurd
  /// coordinates or invert behind the lens.
  static const double _nearPlane = 1.0;

  Vec3 get position {
    final cosPitch = math.cos(pitch);
    return Vec3(
      target.x + distance * cosPitch * math.cos(yaw),
      target.y + distance * cosPitch * math.sin(yaw),
      target.z + distance * math.sin(pitch),
    );
  }

  void orbit(double deltaYaw, double deltaPitch) {
    yaw += deltaYaw;
    pitch = (pitch + deltaPitch).clamp(minPitch, maxPitch);
  }

  void dolly(double factor) {
    distance = (distance * factor).clamp(minDistance, maxDistance);
  }

  void pan(Offset delta) => panOffset += delta;

  /// Frames a box of [width] x [depth] x [height] map units on [centre].
  ///
  /// A closed-form distance is not enough: the footprint is rotated by [yaw],
  /// foreshortened by [pitch], then magnified unevenly by perspective, so at
  /// shallow angles the near edge grows far more than an extent measured at
  /// the target plane predicts.
  ///
  /// Pulling back always shrinks what the camera sees, so "does the box fit"
  /// is monotonic in distance and can simply be searched: expand until the
  /// box fits, then bisect for the closest distance that still holds. Scaling
  /// the distance by the overflow ratio instead looks like the obvious fix
  /// and is not — the relationship is nonlinear enough near the map that it
  /// overshoots and oscillates without settling.
  void frame({
    required Vec3 centre,
    required double width,
    required double depth,
    double height = 0,
    double aspect = 16 / 9,
    double margin = 1.06,
  }) {
    target = centre;
    panOffset = Offset.zero;

    final halfWidth = math.max(width, 1.0) / 2;
    final halfDepth = math.max(depth, 1.0) / 2;
    final halfHeight = math.max(height, 0.0) / 2;

    final corners = <Vec3>[
      for (final dx in [-halfWidth, halfWidth])
        for (final dy in [-halfDepth, halfDepth])
          for (final dz in [-halfHeight, halfHeight])
            Vec3(centre.x + dx, centre.y + dy, centre.z + dz),
    ];

    // Normalised viewport: height 1, width `aspect`, so the test is in plain
    // ratios and the answer holds at any pixel size.
    final viewport = Size(aspect, 1);
    final centreX = aspect / 2;

    bool fitsAt(double candidate) {
      distance = candidate;
      for (final corner in corners) {
        final projected = project(corner, viewport);
        if (!projected.visible) return false;
        if ((projected.screen.dx - centreX).abs() > centreX) return false;
        if ((projected.screen.dy - 0.5).abs() > 0.5) return false;
      }
      return true;
    }

    // First guess from the linear extents: roughly right, and a good place to
    // start expanding from.
    final sinYaw = math.sin(yaw).abs();
    final cosYaw = math.cos(yaw).abs();
    final horizontal = math.max(width * sinYaw + depth * cosYaw, 1.0);
    final vertical = math.max(
      math.sin(pitch) * (width * cosYaw + depth * sinYaw) +
          math.cos(pitch) * height,
      1.0,
    );
    final horizontalFov = 2 * math.atan(math.tan(fov / 2) * aspect);

    var far = math.max(
      vertical / (2 * math.tan(fov / 2)),
      horizontal / (2 * math.tan(horizontalFov / 2)),
    ).clamp(minDistance, maxDistance);

    var near = minDistance;
    var bounded = false;
    for (var expand = 0; expand < 48; expand++) {
      if (fitsAt(far)) {
        bounded = true;
        break;
      }
      near = far;
      if (far >= maxDistance) break;
      far = math.min(far * 1.6, maxDistance);
    }

    if (bounded) {
      for (var step = 0; step < 32; step++) {
        final mid = (near + far) / 2;
        if (fitsAt(mid)) {
          far = mid;
        } else {
          near = mid;
        }
      }
    }

    distance = (far * margin).clamp(minDistance, maxDistance);
  }

  /// Projects a world point to screen space for a viewport of [size].
  Projected project(Vec3 world, Size size) {
    // Camera basis: forward points at the target, right is horizontal, up
    // completes the frame.
    final eye = position;
    final forward = _normalize(target - eye);
    final right = _normalize(_cross(forward, const Vec3(0, 0, 1)));
    final up = _cross(right, forward);

    final relative = world - eye;
    final depth = _dot(relative, forward);
    if (depth <= _nearPlane) return Projected.behind;

    final focal = (size.height / 2) / math.tan(fov / 2);
    final screenX = _dot(relative, right) / depth * focal;
    final screenY = _dot(relative, up) / depth * focal;

    return Projected(
      // Screen y grows downward, so the up component is negated.
      screen: Offset(
        size.width / 2 + screenX + panOffset.dx,
        size.height / 2 - screenY + panOffset.dy,
      ),
      depth: depth,
      visible: true,
    );
  }

  HologramCamera copy() {
    return HologramCamera(
      yaw: yaw,
      pitch: pitch,
      distance: distance,
      target: target,
      fov: fov,
      panOffset: panOffset,
    );
  }

  static Vec3 _cross(Vec3 a, Vec3 b) => Vec3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
      );

  static double _dot(Vec3 a, Vec3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

  static Vec3 _normalize(Vec3 v) {
    final length = v.length;
    if (length == 0) return Vec3.zero;
    return Vec3(v.x / length, v.y / length, v.z / length);
  }
}
