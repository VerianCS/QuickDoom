import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/models/doom_map.dart';

/// The list of maps in the loaded file.
///
/// This wraps onto as many rows as it needs and scrolls vertically past a few
/// of them. A single horizontal row looks tidier but strands maps off the end:
/// a mouse wheel scrolls a horizontal list on no desktop platform, and Flutter
/// does not drag-scroll with a mouse pointer, so anything past the right edge
/// of the panel simply could not be reached.
class MapStrip extends StatefulWidget {
  final List<DoomMap> maps;
  final DoomMap? current;
  final ValueChanged<DoomMap> onSelected;

  const MapStrip({
    super.key,
    required this.maps,
    required this.current,
    required this.onSelected,
  });

  @override
  State<MapStrip> createState() => _MapStripState();
}

class _MapStripState extends State<MapStrip> {
  final _controller = ScrollController();

  static const double _rowHeight = 28;
  static const double _runSpacing = 6;

  /// Rows shown before the list starts scrolling. Three covers a 32-level
  /// megawad at a typical window width without crowding out the viewer.
  static const int _visibleRows = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = _rowHeight * _visibleRows + _runSpacing * (_visibleRows - 1);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          // Room for the scrollbar so it never sits on top of a chip.
          padding: const EdgeInsets.only(right: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: _runSpacing,
            children: [
              for (final map in widget.maps)
                _MapChip(
                  map: map,
                  selected: identical(map, widget.current),
                  height: _rowHeight,
                  onTap: () => widget.onSelected(map),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final DoomMap map;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  const _MapChip({
    required this.map,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.6)
                : Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        // widthFactor pins the chip to its label. Container.alignment would
        // centre the text but also expand the chip to the full width the Wrap
        // offers, putting one map on every row.
        child: Center(
          widthFactor: 1,
          child: Text(
            map.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.primary : null,
            ),
          ),
        ),
      ),
    );
  }
}
