import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/file_extensions.dart';
import '../../../../domain/entities/pwad.dart';
import '../../../launcher/presentation/providers/launch_provider.dart';

class WadDropZone extends ConsumerWidget {
  final Widget child;

  const WadDropZone({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropTarget(
      onDragEntered: (_) {},
      onDragExited: (_) {},
      onDragDone: (details) {
        final pwads = <Pwad>[];
        for (final file in details.files) {
          final path = file.path;
          if (FileExtensions.pwadExtensions.any((ext) => path.toLowerCase().endsWith(ext))) {
            pwads.add(Pwad(
              id: const Uuid().v4(),
              path: path,
            ));
          }
        }
        if (pwads.isNotEmpty) {
          ref.read(launchNotifierProvider.notifier).addPwads(pwads);
        }
      },
      child: child,
    );
  }
}
