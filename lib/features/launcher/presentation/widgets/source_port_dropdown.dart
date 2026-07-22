import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/file_picker_service.dart';
import '../../../../domain/entities/source_port.dart';
import '../providers/launch_provider.dart';

class SourcePortSelector extends ConsumerWidget {
  const SourcePortSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(launchNotifierProvider.select((s) => s.sourcePort));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Source Port', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select source port executable...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  suffixIcon: port != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => ref
                              .read(launchNotifierProvider.notifier)
                              .clearSourcePort(),
                        )
                      : null,
                ),
                controller: TextEditingController(
                  text: port != null
                      ? '${port.name} (${port.executablePath})'
                      : '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                final path = await FilePickerService().pickFile(
                  allowedExtensions: ['exe', 'AppImage', ''],
                  dialogTitle: 'Select Source Port Executable',
                );
                if (path != null) {
                  ref.read(launchNotifierProvider.notifier).setSourcePort(
                    SourcePort(
                      id: const Uuid().v4(),
                      name: path.split('\\').last.split('/').last,
                      executablePath: path,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse'),
            ),
          ],
        ),
      ],
    );
  }
}
