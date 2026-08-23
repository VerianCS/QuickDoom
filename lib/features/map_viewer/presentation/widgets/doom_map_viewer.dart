import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/models/doom_map.dart';
import 'doom_map_painter.dart';
import 'map_geometry.dart';
import 'map_viewport.dart';

/// Interactive 2D map viewer: pan with the mouse (left/middle/right drag), zoom
/// with the wheel (centered on the cursor) or a two-finger pinch, and click to
/// pick an element which is reported through [onSelectionChanged].
///
/// Panning and pinch are handled directly via [Listener] pointer events so that
/// any mouse button drags the view and touch pinch-zoom keeps working.
class DoomMapViewer extends StatefulWidget {
  final DoomMap map;
  final MapViewerLayers layers;
  final MapSelection? selection;
  final ValueChanged<MapSelection?> onSelectionChanged;

  const DoomMapViewer({
    super.key,
    required this.map,
    required this.layers,
    required this.onSelectionChanged,
    this.selection,
  });

  @override
  State<DoomMapViewer> createState() => _DoomMapViewerState();
}

class _DoomMapViewerState extends State<DoomMapViewer> {
  final _viewport = MapViewport();
  late List<SectorLoop> _loops;
  bool _fitted = false;

  final Map<int, Offset> _activePointers = {};
  Offset? _panLast;
  Offset? _panStart;
  bool _panMoved = false;
  double _prevPinchDist = 0;
  Offset _prevPinchFocal = Offset.zero;

  bool get _isPanning => _activePointers.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loops = MapGeometry.buildSectorLoops(widget.map);
  }

  @override
  void didUpdateWidget(covariant DoomMapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.map != widget.map) {
      _loops = MapGeometry.buildSectorLoops(widget.map);
      _fitted = false;
    }
  }

  void _fit(Size size) {
    _viewport.fit(widget.map.bounds, size);
    _fitted = true;
  }

  double _twoPointerDistance() {
    final points = _activePointers.values.toList();
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  Offset _centroid() {
    final points = _activePointers.values;
    var x = 0.0;
    var y = 0.0;
    for (final p in points) {
      x += p.dx;
      y += p.dy;
    }
    final count = points.length.toDouble();
    return Offset(x / count, y / count);
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 1) {
      _panLast = event.localPosition;
      _panStart = event.localPosition;
      _panMoved = false;
    } else if (_activePointers.length == 2) {
      _prevPinchDist = _twoPointerDistance();
      _prevPinchFocal = _centroid();
    }
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;

    if (_activePointers.length == 1) {
      final last = _panLast;
      if (last == null) return;
      final delta = event.localPosition - last;
      if (delta.distance > 3) _panMoved = true;
      setState(() {
        _viewport.pan(delta.dx, delta.dy);
        _panLast = event.localPosition;
      });
    } else if (_activePointers.length >= 2) {
      final dist = _twoPointerDistance();
      final focal = _centroid();
      if (_prevPinchDist > 0) {
        final factor = dist / _prevPinchDist;
        setState(() {
          _viewport.zoomAt(focal, factor);
          _viewport.pan(focal.dx - _prevPinchFocal.dx,
              focal.dy - _prevPinchFocal.dy);
        });
      }
      _prevPinchDist = dist;
      _prevPinchFocal = focal;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _onPointerEnd(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _onPointerEnd(event.pointer);
  }

  void _onPointerEnd(int pointer) {
    final wasPanning = _isPanning;
    _activePointers.remove(pointer);

    if (_activePointers.length < 2) _prevPinchDist = 0;

    if (_activePointers.isEmpty) {
      if (wasPanning && !_panMoved && _panStart != null) {
        _selectAt(_panStart!);
      }
      _panLast = null;
      _panStart = null;
      _panMoved = false;
    } else if (_activePointers.length == 1) {
      // Lifted from a pinch: keep the remaining pointer as the pan anchor and
      // suppress the tap that would otherwise fire on release.
      _panLast = _activePointers.values.first;
      _panMoved = true;
    }

    setState(() {});
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy < 0 ? 1.2 : 1 / 1.2;
      setState(() {
        _viewport.zoomAt(event.localPosition, factor);
      });
    }
  }

  void _selectAt(Offset localPosition) {
    final world = _viewport.screenToWorld(localPosition);
    final pixels = _viewport.scale.clamp(1.0, 8.0);
    final selection = pickElement(
      widget.map,
      Offset(world.$1, world.$2),
      linedefMaxDistance: 12 / pixels,
      thingMaxDistance: 20 / pixels,
      loops: _loops,
    );
    widget.onSelectionChanged(selection);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_fitted && size.width > 0 && size.height > 0) {
          _fit(size);
        }

        return MouseRegion(
          key: const Key('mapViewportMouseRegion'),
          cursor: _isPanning
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            onPointerSignal: _onPointerSignal,
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: DoomMapPainter(
                  map: widget.map,
                  viewport: _viewport,
                  layers: widget.layers,
                  selection: widget.selection,
                  sectorLoops: _loops,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
