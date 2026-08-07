import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/doom_map.dart';

/// Transforms between Doom map space (x right, y up) and canvas/screen space
/// (x right, y down). All math is pure so it can be unit tested without a
/// widget tree.
class MapViewport {
  /// Pixels per world unit.
  double scale;

  /// Screen position of the world origin (0, 0).
  double offsetX;
  double offsetY;

  static const double minScale = 0.01;
  static const double maxScale = 500;

  MapViewport({this.scale = 1, this.offsetX = 0, this.offsetY = 0});

  /// Fits [bounds] centered inside [size] with [padding], flipping the Y axis
  /// so that the map's "up" becomes the screen's "down".
  void fit(MapBounds bounds, Size size, {double padding = 32}) {
    if (size.width <= 0 || size.height <= 0) return;
    if (bounds.width <= 0 || bounds.height <= 0) {
      scale = 1;
      offsetX = size.width / 2;
      offsetY = size.height / 2;
      return;
    }
    final availableWidth = math.max(1.0, size.width - padding * 2);
    final availableHeight = math.max(1.0, size.height - padding * 2);
    scale = math.min(
      availableWidth / bounds.width,
      availableHeight / bounds.height,
    );
    scale = scale.clamp(minScale, maxScale);

    final viewWidth = bounds.width * scale;
    final viewHeight = bounds.height * scale;
    offsetX = (size.width - viewWidth) / 2 - bounds.minX * scale;
    offsetY = (size.height - viewHeight) / 2 + bounds.maxY * scale;
  }

  /// Doom map coords (y up) -> screen coords (y down).
  Offset worldToScreen(double x, double y) =>
      Offset(x * scale + offsetX, -y * scale + offsetY);

  /// Screen coords -> Doom map coords.
  (double, double) screenToWorld(Offset point) => (
        (point.dx - offsetX) / scale,
        (offsetY - point.dy) / scale,
      );

  /// Moves the view by a screen-space delta.
  void pan(double dx, double dy) {
    offsetX += dx;
    offsetY += dy;
  }

  /// Zooms around the given screen point, keeping the world position under it
  /// fixed. Returns the applied scale factor.
  double zoomAt(Offset focalPoint, double factor) {
    final (worldX, worldY) = screenToWorld(focalPoint);
    final oldScale = scale;
    scale = (scale * factor).clamp(minScale, maxScale);
    final applied = scale / oldScale;
    if (applied != 1) {
      offsetX = focalPoint.dx - worldX * scale;
      offsetY = focalPoint.dy + worldY * scale;
    }
    return applied;
  }
}
