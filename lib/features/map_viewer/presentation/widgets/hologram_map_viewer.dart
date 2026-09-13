import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/doom_map.dart';
import '../../domain/projection/hologram_camera.dart';
import '../../domain/projection/map_mesh.dart';
import 'doom_map_painter.dart';
import 'hologram_painter.dart';
import 'map_geometry.dart';

/// Interactive holographic view of a map.
///
/// Left drag orbits, right/middle drag (or shift-drag) pans, the wheel dollies
/// and two fingers pinch. A click that did not turn into a drag picks whatever
/// is under the cursor.
class HologramMapViewer extends StatefulWidget {
  final DoomMap map;
  final MapViewerLayers layers;
  final MapSelection? selection;
  final ValueChanged<MapSelection?> onSelectionChanged;

  /// Disables the scan sweep animation; tests pump frames by hand and a
  /// repeating ticker would never settle.
  final bool animate;

  const HologramMapViewer({
    super.key,
    required this.map,
    required this.layers,
    required this.onSelectionChanged,
    this.selection,
    this.animate = true,
  });

  @override
  State<HologramMapViewer> createState() => HologramMapViewerState();
}

class HologramMapViewerState extends State<HologramMapViewer>
    with SingleTickerProviderStateMixin {
  final HologramCamera camera = HologramCamera();

  late MapMesh _mesh;
  late List<SectorLoop> _loops;
  bool _framed = false;
  Size _lastSize = Size.zero;

  AnimationController? _sweepController;

  final Map<int, Offset> _pointers = {};
  Offset? _dragLast;
  Offset? _dragStart;
  bool _dragMoved = false;
  bool _panning = false;
  double _prevPinchDistance = 0;

  @override
  void initState() {
    super.initState();
    _rebuildMesh();
    if (widget.animate) {
      _sweepController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant HologramMapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.map != widget.map) {
      _rebuildMesh();
      _framed = false;
    }
  }

  @override
  void dispose() {
    _sweepController?.dispose();
    super.dispose();
  }

  void _rebuildMesh() {
    _loops = MapGeometry.buildSectorLoops(widget.map);
    _mesh = MapMesh.build(
      widget.map,
      sectorLoops: [
        for (final loop in _loops)
          (sectorIndex: loop.sectorIndex, vertexIndices: loop.vertexIndices),
      ],
    );
  }

  /// Points the camera at the map and backs off far enough to see all of it.
  void frameMap() {
    final bounds = widget.map.bounds;
    camera.frame(
      centre: Vec3(bounds.centerX, bounds.centerY, (_mesh.minZ + _mesh.maxZ) / 2),
      width: bounds.width,
      depth: bounds.height,
      height: _mesh.maxZ - _mesh.minZ,
      aspect: _lastSize.isEmpty || _lastSize.height == 0
          ? 16 / 9
          : _lastSize.width / _lastSize.height,
    );
    _framed = true;
  }

  void resetView() {
    setState(() {
      camera
        ..yaw = -math.pi / 4
        ..pitch = 0.62;
      frameMap();
    });
  }

  bool get _panModifier {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1) {
      _dragLast = event.localPosition;
      _dragStart = event.localPosition;
      _dragMoved = false;
      // Secondary and tertiary buttons pan, matching most 3D tools.
      _panning = _panModifier ||
          event.buttons & kSecondaryButton != 0 ||
          event.buttons & kTertiaryButton != 0;
    } else if (_pointers.length == 2) {
      _prevPinchDistance = _pinchDistance();
    }
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length == 1) {
      final last = _dragLast;
      if (last == null) return;
      final delta = event.localPosition - last;
      if (delta.distance > 3) _dragMoved = true;

      setState(() {
        if (_panning) {
          camera.pan(delta);
        } else {
          // Drag right spins the map right: a full screen width is about a
          // half turn, which keeps the control predictable at any zoom.
          camera.orbit(-delta.dx * 0.008, delta.dy * 0.006);
        }
        _dragLast = event.localPosition;
      });
    } else if (_pointers.length >= 2) {
      final distance = _pinchDistance();
      if (_prevPinchDistance > 0 && distance > 0) {
        setState(() => camera.dolly(_prevPinchDistance / distance));
      }
      _prevPinchDistance = distance;
      _dragMoved = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) => _endPointer(event.pointer);

  void _onPointerCancel(PointerCancelEvent event) => _endPointer(event.pointer);

  void _endPointer(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2) _prevPinchDistance = 0;

    if (_pointers.isEmpty) {
      if (!_dragMoved && !_panning && _dragStart != null) {
        _pickAt(_dragStart!);
      }
      _dragLast = null;
      _dragStart = null;
      _dragMoved = false;
      _panning = false;
    } else {
      _dragLast = _pointers.values.first;
      _dragMoved = true;
    }
    setState(() {});
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    setState(() {
      camera.dolly(event.scrollDelta.dy > 0 ? 1.12 : 1 / 1.12);
    });
  }

  double _pinchDistance() {
    final points = _pointers.values.toList();
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  /// Picks in screen space: every candidate is projected and compared against
  /// the cursor, so what the user clicks is what they see, whatever the angle.
  void _pickAt(Offset position) {
    final size = _lastSize;
    if (size.isEmpty) return;

    const thingRadius = 12.0;
    var bestThing = -1;
    var bestThingDistance = thingRadius;
    var bestThingDepth = double.infinity;

    for (final thing in _mesh.things) {
      final projected = camera.project(thing.position, size);
      if (!projected.visible) continue;
      final distance = (projected.screen - position).distance;
      if (distance <= bestThingDistance ||
          (distance <= thingRadius && projected.depth < bestThingDepth)) {
        bestThingDistance = distance;
        bestThingDepth = projected.depth;
        bestThing = thing.thingIndex;
      }
    }
    if (bestThing >= 0) {
      widget.onSelectionChanged(ThingSelection(bestThing));
      return;
    }

    const wallTolerance = 8.0;
    var bestWall = -1;
    var bestWallDepth = double.infinity;

    for (final wall in _mesh.walls) {
      final a = camera.project(wall.a, size);
      final b = camera.project(wall.b, size);
      final c = camera.project(wall.c, size);
      final d = camera.project(wall.d, size);
      if (!a.visible || !b.visible || !c.visible || !d.visible) continue;

      final corners = [a.screen, b.screen, c.screen, d.screen];
      final inside = _pointInPolygon(corners, position);
      final distance = inside
          ? 0.0
          : [
              MapGeometry.distanceToSegment(position, a.screen, b.screen),
              MapGeometry.distanceToSegment(position, b.screen, c.screen),
              MapGeometry.distanceToSegment(position, c.screen, d.screen),
              MapGeometry.distanceToSegment(position, d.screen, a.screen),
            ].reduce(math.min);

      if (distance > wallTolerance) continue;
      // Nearest surface wins, so clicking a wall does not select the one
      // behind it.
      if (a.depth < bestWallDepth) {
        bestWallDepth = a.depth;
        bestWall = wall.linedefIndex;
      }
    }
    if (bestWall >= 0) {
      widget.onSelectionChanged(LinedefSelection(bestWall));
      return;
    }

    var bestSector = -1;
    var bestSectorDepth = double.infinity;
    for (final floor in _mesh.floors) {
      final points = <Offset>[];
      var depth = 0.0;
      var ok = true;
      for (final point in floor.points) {
        final projected = camera.project(point, size);
        if (!projected.visible) {
          ok = false;
          break;
        }
        points.add(projected.screen);
        depth += projected.depth;
      }
      if (!ok || points.length < 3) continue;
      if (!_pointInPolygon(points, position)) continue;

      depth /= points.length;
      if (depth < bestSectorDepth) {
        bestSectorDepth = depth;
        bestSector = floor.sectorIndex;
      }
    }

    widget.onSelectionChanged(
      bestSector >= 0 ? SectorSelection(bestSector) : null,
    );
  }

  static bool _pointInPolygon(List<Offset> polygon, Offset point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      if ((pi.dy > point.dy) != (pj.dy > point.dy) &&
          point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _lastSize = size;
        if (!_framed && !size.isEmpty) frameMap();

        return MouseRegion(
          key: const Key('hologramMouseRegion'),
          cursor: _pointers.isEmpty
              ? SystemMouseCursors.grab
              : SystemMouseCursors.grabbing,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            onPointerSignal: _onPointerSignal,
            child: RepaintBoundary(
              child: _sweepController == null
                  ? _canvas(size, 0.35)
                  : AnimatedBuilder(
                      animation: _sweepController!,
                      builder: (context, _) =>
                          _canvas(size, _sweepController!.value),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _canvas(Size size, double sweep) {
    return CustomPaint(
      size: size,
      painter: HologramPainter(
        map: widget.map,
        mesh: _mesh,
        camera: camera,
        layers: widget.layers,
        selection: widget.selection,
        sweep: sweep,
      ),
    );
  }
}
