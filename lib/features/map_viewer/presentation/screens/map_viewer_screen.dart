import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/file_picker_service.dart';
import '../../data/repositories/wad_repository.dart';
import '../../domain/models/doom_map.dart';
import '../widgets/doom_map_painter.dart';
import '../widgets/doom_map_viewer.dart';
import '../widgets/hologram_map_viewer.dart';
import '../widgets/hologram_painter.dart';
import '../widgets/map_geometry.dart';
import '../widgets/map_strip.dart';

/// Opens a WAD and browses its maps, either as a flat plan or as the
/// holographic projection.
class MapViewerScreen extends StatefulWidget {
  const MapViewerScreen({super.key});

  @override
  State<MapViewerScreen> createState() => _MapViewerScreenState();
}

class _MapViewerScreenState extends State<MapViewerScreen> {
  final _repository = WadRepository();
  final _filePicker = FilePickerService();
  final _hologramKey = GlobalKey<HologramMapViewerState>();

  List<DoomMap>? _maps;
  DoomMap? _current;
  MapSelection? _selection;
  MapViewerLayers _layers = const MapViewerLayers(showGrid: true);
  MapViewMode _mode = MapViewMode.hologram;
  String? _error;
  bool _loading = false;
  String? _sourceName;

  Future<void> _openWad() async {
    String? picked;
    try {
      // The picker itself can fail — on Linux it shells out to zenity or
      // kdialog, and neither is guaranteed to be installed. Left unhandled
      // that makes the button look dead.
      picked = await _filePicker.pickFile(
        allowedExtensions: ['wad', 'pk3', 'pk4', 'zip'],
        dialogTitle: 'Select a WAD or PK3 file',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the file picker: $e');
      return;
    }
    if (picked == null) return;
    final path = picked;

    setState(() {
      _error = null;
      _selection = null;
      _loading = true;
    });

    try {
      final maps = await _repository.loadMaps(path);
      if (!mounted) return;
      setState(() {
        _maps = maps;
        _current = maps.isNotEmpty ? maps.first : null;
        _sourceName = path.split(RegExp(r'[/\\]')).last;
        _loading = false;
        if (maps.isEmpty) _error = 'No maps found in this file.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to parse WAD: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            sourceName: _sourceName,
            loading: _loading,
            mode: _mode,
            hasMap: _current != null,
            onOpen: _openWad,
            onModeChanged: (mode) => setState(() => _mode = mode),
            onReset: () => _hologramKey.currentState?.resetView(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (_maps != null && _maps!.length > 1) ...[
            const SizedBox(height: 12),
            MapStrip(
              maps: _maps!,
              current: _current,
              onSelected: (map) => setState(() {
                _current = map;
                _selection = null;
              }),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _current == null ? const _EmptyState() : _buildViewer(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewer() {
    final map = _current!;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: switch (_mode) {
                MapViewMode.hologram => HologramMapViewer(
                    key: _hologramKey,
                    map: map,
                    layers: _layers,
                    selection: _selection,
                    onSelectionChanged: (selection) =>
                        setState(() => _selection = selection),
                  ),
                MapViewMode.plan => DoomMapViewer(
                    map: map,
                    layers: _layers,
                    selection: _selection,
                    onSelectionChanged: (selection) =>
                        setState(() => _selection = selection),
                  ),
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 268,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MapStats(map: map),
              const SizedBox(height: 10),
              _LayerToggles(
                layers: _layers,
                onChanged: (layers) => setState(() => _layers = layers),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _Inspector(map: map, selection: _selection),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String? sourceName;
  final bool loading;
  final MapViewMode mode;
  final bool hasMap;
  final VoidCallback onOpen;
  final ValueChanged<MapViewMode> onModeChanged;
  final VoidCallback onReset;

  const _Header({
    required this.sourceName,
    required this.loading,
    required this.mode,
    required this.hasMap,
    required this.onOpen,
    required this.onModeChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withAlpha(140);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Map Viewer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              sourceName ?? 'No file loaded',
              style: TextStyle(fontSize: 12, color: dim),
            ),
          ],
        ),
        const Spacer(),
        if (hasMap) ...[
          _ModeSwitch(mode: mode, onChanged: onModeChanged),
          const SizedBox(width: 8),
          if (mode == MapViewMode.hologram)
            IconButton(
              tooltip: 'Reset view',
              onPressed: onReset,
              icon: const Icon(Icons.center_focus_strong_outlined, size: 18),
            ),
          const SizedBox(width: 4),
        ],
        OutlinedButton.icon(
          onPressed: loading ? null : onOpen,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open, size: 18),
          label: Text(loading ? 'Loading...' : 'Open WAD'),
        ),
      ],
    );
  }
}

/// Segmented plan / hologram switch.
class _ModeSwitch extends StatelessWidget {
  final MapViewMode mode;
  final ValueChanged<MapViewMode> onChanged;

  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget segment(MapViewMode value, IconData icon, String label) {
      final selected = value == mode;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface.withAlpha(140),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(MapViewMode.hologram, Icons.view_in_ar_outlined, '3D'),
          segment(MapViewMode.plan, Icons.grid_on_outlined, 'Plan'),
        ],
      ),
    );
  }
}

/// Counts for the loaded map, so the size of what is on screen is legible.
class _MapStats extends StatelessWidget {
  final DoomMap map;

  const _MapStats({required this.map});

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withAlpha(140);

    Widget stat(String label, int value) {
      return Expanded(
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: dim)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                map.name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Text(map.format.name, style: TextStyle(fontSize: 11, color: dim)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              stat('verts', map.vertices.length),
              stat('lines', map.linedefs.length),
              stat('sectors', map.sectors.length),
              stat('things', map.things.length),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, 0.3),
          radius: 1.0,
          colors: [Color(0xFF241013), Color(0xFF150E0F)],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar_outlined,
              size: 46,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text(
              'Open a WAD to project its levels.',
              style: TextStyle(
                color: AppColors.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Drag to orbit  ·  scroll to zoom  ·  click to inspect',
              style: TextStyle(
                color: AppColors.onBackground.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerToggles extends StatelessWidget {
  final MapViewerLayers layers;
  final ValueChanged<MapViewerLayers> onChanged;

  const _LayerToggles({required this.layers, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, IconData icon, Color tint, bool value,
        void Function(bool) set) {
      return InkWell(
        onTap: () => set(!value),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: value ? tint.withValues(alpha: 0.16) : Colors.transparent,
            border: Border.all(
              color: value
                  ? tint.withValues(alpha: 0.55)
                  : Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: value
                    ? tint
                    : Theme.of(context).colorScheme.onSurface.withAlpha(110),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: value
                      ? tint
                      : Theme.of(context).colorScheme.onSurface.withAlpha(110),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          chip('Sectors', Icons.layers_outlined, HologramPalette.primary,
              layers.showSectors,
              (v) => onChanged(layers.copyWith(showSectors: v))),
          chip('Walls', Icons.square_foot, HologramPalette.secondary,
              layers.showLinedefs,
              (v) => onChanged(layers.copyWith(showLinedefs: v))),
          chip('Things', Icons.place_outlined, HologramPalette.player,
              layers.showThings,
              (v) => onChanged(layers.copyWith(showThings: v))),
          chip('Grid', Icons.grid_4x4, HologramPalette.grid, layers.showGrid,
              (v) => onChanged(layers.copyWith(showGrid: v))),
        ],
      ),
    );
  }
}

class _Inspector extends StatelessWidget {
  final DoomMap map;
  final MapSelection? selection;

  const _Inspector({required this.map, required this.selection});

  @override
  Widget build(BuildContext context) {
    final rows = selection == null
        ? const <(String, String)>[]
        : _rowsFor(selection!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: rows.isEmpty
          ? Center(
              child: Text(
                'Click the map to inspect\nan element.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                ),
              ),
            )
          : ListView(
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(140),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  List<(String, String)> _rowsFor(MapSelection selection) {
    switch (selection) {
      case LinedefSelection(:final linedefIndex):
        final line = map.linedefAt(linedefIndex);
        if (line == null) return const [];
        return [
          ('Kind', 'Linedef'),
          ('Index', '#$linedefIndex'),
          ('Vertices', '${line.startVertexIndex} -> ${line.endVertexIndex}'),
          ('Flags', '0x${line.flags.toRadixString(16).padLeft(4, '0')}'),
          ('Special', '${line.special}'),
          ('Tag', '${line.tag}'),
          ('Sidedefs', '${line.frontSidedefIndex} / ${line.backSidedefIndex}'),
          ('Two-sided', line.isTwoSided ? 'yes' : 'no'),
          ('Args', line.args.isEmpty ? '-' : line.args.join(', ')),
        ];
      case ThingSelection(:final thingIndex):
        final thing = map.things[thingIndex];
        return [
          ('Kind', 'Thing'),
          ('Index', '#$thingIndex'),
          ('Type', thing.typeName ?? '${thing.type}'),
          ('Position', '(${thing.x}, ${thing.y}, ${thing.z})'),
          ('Angle', '${thing.angle}'),
          ('Flags', '0x${thing.flags.toRadixString(16).padLeft(4, '0')}'),
          ('TID', '${thing.tid}'),
          ('Special', '${thing.special}'),
        ];
      case SectorSelection(:final sectorIndex):
        final sector = map.sectorAt(sectorIndex);
        if (sector == null) return const [];
        return [
          ('Kind', 'Sector'),
          ('Index', '#$sectorIndex'),
          ('Floor', '${sector.floorHeight}'),
          ('Ceiling', '${sector.ceilingHeight}'),
          ('Height', '${sector.ceilingHeight - sector.floorHeight}'),
          ('Light', '${sector.lightLevel}'),
          ('Floor Tex', sector.floorTexture.isEmpty ? '-' : sector.floorTexture),
          ('Ceil Tex',
              sector.ceilingTexture.isEmpty ? '-' : sector.ceilingTexture),
          ('Special', '${sector.special}'),
          ('Tag', '${sector.tag}'),
        ];
    }
  }
}
