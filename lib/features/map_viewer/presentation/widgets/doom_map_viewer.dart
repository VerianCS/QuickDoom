import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../domain/models/doom_map.dart';
import 'doom_map_painter.dart';
import 'map_geometry.dart';
import 'map_viewport.dart';

/// Interactive 2D map viewer: pan/zoom with mouse wheel, drag and pinch, and
/// tap-to-pick which reports a [MapSelection] through [onSelectionChanged].
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

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy < 0 ? 1.2 : 1 / 1.2;
      setState(() {
        _viewport.zoomAt(event.localPosition, factor);
      });
    }
  }

  void _handleTap(TapUpDetails details) {
    final world = _viewport.screenToWorld(details.localPosition);
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

  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = 1;
    _lastFocal = details.localFocalPoint;
  }

  double _lastScale = 1;
  Offset _lastFocal = Offset.zero;

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final factor = details.scale / _lastScale;
    final focal = details.localFocalPoint;
    setState(() {
      _viewport.zoomAt(_lastFocal, factor);
      _viewport.pan(focal.dx - _lastFocal.dx, focal.dy - _lastFocal.dy);
      _lastScale = details.scale;
      _lastFocal = focal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_fitted && size.width > 0 && size.height > 0) {
          _fit(size);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTap,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          child: Listener(
            onPointerSignal: _handlePointerSignal,
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
