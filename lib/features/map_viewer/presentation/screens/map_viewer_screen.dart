import 'package:flutter/material.dart';

import '../../../../core/services/file_picker_service.dart';
import '../../data/repositories/wad_repository.dart';
import '../../domain/models/doom_map.dart';
import '../widgets/doom_map_painter.dart';
import '../widgets/doom_map_viewer.dart';
import '../widgets/map_geometry.dart';

/// Opens a WAD file and lets the user browse its maps in the 2D viewer with
/// layer toggles and an inspector panel.
class MapViewerScreen extends StatefulWidget {
  const MapViewerScreen({super.key});

  @override
  State<MapViewerScreen> createState() => _MapViewerScreenState();
}

class _MapViewerScreenState extends State<MapViewerScreen> {
  final _repository = WadRepository();
  final _filePicker = FilePickerService();

  List<DoomMap>? _maps;
  DoomMap? _current;
  MapSelection? _selection;
  MapViewerLayers _layers = const MapViewerLayers(showGrid: true);
  String? _error;

  Future<void> _openWad() async {
    final path = await _filePicker.pickFile(
      allowedExtensions: ['wad'],
      dialogTitle: 'Select a WAD file',
    );
    if (path == null) return;

    setState(() {
      _error = null;
      _selection = null;
    });
    try {
      final maps = await _repository.loadMaps(path);
      if (!mounted) return;
      setState(() {
        _maps = maps;
        _current = maps.isNotEmpty ? maps.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to parse WAD: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Map Viewer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _openWad,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Open WAD'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_maps != null && _maps!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final map in _maps!)
                  ChoiceChip(
                    label: Text('${map.name} (${map.format.name})'),
                    selected: identical(map, _current),
                    onSelected: (_) => setState(() {
                      _current = map;
                      _selection = null;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_current == null)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurface.withAlpha(80),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Open a WAD file to inspect its maps.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(80),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: DoomMapViewer(
                          map: _current!,
                          layers: _layers,
                          selection: _selection,
                          onSelectionChanged: (selection) =>
                              setState(() => _selection = selection),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LayerToggles(
                          layers: _layers,
                          onChanged: (layers) =>
                              setState(() => _layers = layers),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _Inspector(
                            map: _current!,
                            selection: _selection,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
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
    Widget toggle(String label, bool value, void Function(bool) set) {
      return CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: (v) => set(v ?? false),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          toggle('Sectors', layers.showSectors,
              (v) => onChanged(layers.copyWith(showSectors: v))),
          toggle('Linedefs', layers.showLinedefs,
              (v) => onChanged(layers.copyWith(showLinedefs: v))),
          toggle('Things', layers.showThings,
              (v) => onChanged(layers.copyWith(showThings: v))),
          toggle('Grid', layers.showGrid,
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
                'Tap the map to inspect\nan element.',
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
                          width: 90,
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
