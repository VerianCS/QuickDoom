import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/widgets/notched_panel.dart';
import 'loadout_slot.dart';

/// One candidate for a slot.
class SlotEntry<T> {
  final T value;
  final String label;
  final String? detail;
  final bool selected;

  const SlotEntry({
    required this.value,
    required this.label,
    this.detail,
    this.selected = false,
  });
}

/// What came back from the picker: either a chosen entry or a request to go
/// looking on disk.
class SlotChoice<T> {
  final T? value;
  final bool browse;

  const SlotChoice.picked(this.value) : browse = false;
  const SlotChoice.browse()
      : value = null,
        browse = true;
}

/// Opens the list of things that can be seated in a slot.
///
/// This replaces a dropdown whose Browse row was built with `enabled: false`,
/// so it rendered in the accent colour and could never be clicked. Here the
/// browse row is a real, reachable option.
Future<SlotChoice<T>?> showSlotPicker<T>({
  required BuildContext context,
  required String title,
  required List<SlotEntry<T>> entries,
  required String emptyLabel,
  required String browseLabel,
}) {
  return showDialog<SlotChoice<T>>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 460),
        child: NotchedPanel(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(width: 3, height: 13, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppFonts.doomText,
                        fontSize: 13,
                        letterSpacing: 1.6,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              Flexible(
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          emptyLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.onSurfaceFaint,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: entries.length,
                        itemBuilder: (_, i) => _EntryRow<T>(entry: entries[i]),
                      ),
              ),
              const Divider(height: 1),
              InkWell(
                // SlotChoice<T>, not const SlotChoice.browse(): a const call
                // here infers SlotChoice<dynamic>, and popping that into a
                // DialogRoute<SlotChoice<T>> trips Navigator's result-type
                // assertion, which swallows the pop and leaves Browse dead.
                onTap: () => Navigator.of(ctx).pop(SlotChoice<T>.browse()),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open,
                          size: 17, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        browseLabel,
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EntryRow<T> extends StatelessWidget {
  final SlotEntry<T> entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(SlotChoice<T>.picked(entry.value)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        color: entry.selected
            ? AppColors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 3,
              height: 26,
              color: entry.selected ? AppColors.primary : Colors.transparent,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: entry.selected
                          ? AppColors.primary
                          : AppColors.onSurface,
                    ),
                  ),
                  if (entry.detail != null)
                    Text(
                      LoadoutSlot.shortenPath(entry.detail!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: AppColors.onSurfaceFaint,
                      ),
                    ),
                ],
              ),
            ),
            if (entry.selected)
              const Icon(Icons.check, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
