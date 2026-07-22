import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/file_picker_service.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../data/repositories/iwad_repository_impl.dart';
import '../../../../data/repositories/profile_repository_impl.dart';
import '../../../../data/repositories/source_port_repository_impl.dart';
import '../../../../domain/entities/iwad.dart';
import '../../../../domain/entities/pwad.dart';
import '../../../profiles/presentation/providers/profile_provider.dart';
import '../../../profiles/presentation/widgets/profile_list_sidebar.dart';
import '../../../wads/presentation/widgets/wad_drop_zone.dart';
import '../providers/launch_provider.dart';
import '../widgets/launch_button.dart';
import '../widgets/source_port_dropdown.dart';

class LauncherScreen extends ConsumerWidget {
  const LauncherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launchNotifierProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickDoom'),
        centerTitle: false,
        actions: [
          if (currentProfileId != null)
            TextButton.icon(
              onPressed: () => _saveToProfile(ref),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
            ),
        ],
      ),
      body: Row(
        children: [
          const ProfileListSidebar(),
          Expanded(
            child: WadDropZone(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          const SourcePortSelector(),
                          const SizedBox(height: 24),
                          _IwadSelector(),
                          const SizedBox(height: 24),
                          _PwadSection(),
                          if (state.error != null) ...[
                            const SizedBox(height: 16),
                            _ErrorBanner(message: state.error!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const LaunchButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToProfile(WidgetRef ref) async {
    final state = ref.read(launchNotifierProvider);
    final currentId = ref.read(currentProfileIdProvider);
    if (currentId == null) return;

    final profileRepo = ProfileRepositoryImpl(HiveService());
    final existing = await profileRepo.getProfile(currentId);
    if (existing == null) return;

    if (state.sourcePort != null) {
      final portRepo = SourcePortRepositoryImpl(HiveService());
      await portRepo.savePort(state.sourcePort!);
    }
    if (state.iwad != null) {
      final iwadRepo = IwadRepositoryImpl(HiveService());
      await iwadRepo.saveIwad(state.iwad!);
    }

    final updated = existing.copyWith(
      sourcePortId: state.sourcePort?.id ?? existing.sourcePortId,
      iwadId: state.iwad?.id ?? existing.iwadId,
      pwadList: state.pwads,
    );
    await profileRepo.saveProfile(updated);

    ref.invalidate(profileListProvider);
  }
}

class _IwadSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iwad = ref.watch(launchNotifierProvider.select((s) => s.iwad));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('IWAD', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select IWAD file (.wad)...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  suffixIcon: iwad != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => ref
                              .read(launchNotifierProvider.notifier)
                              .clearIwad(),
                        )
                      : null,
                ),
                controller: TextEditingController(
                  text: iwad != null
                      ? '${iwad.name} (${iwad.path})'
                      : '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                final path = await _pickIwadFile();
                if (path != null) {
                  final name = path.split('\\').last.split('/').last;
                  ref.read(launchNotifierProvider.notifier).setIwad(
                    Iwad(
                      id: const Uuid().v4(),
                      name: name,
                      path: path,
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

class _PwadSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pwads = ref.watch(launchNotifierProvider.select((s) => s.pwads));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('PWADs / Mods',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '${pwads.length} loaded',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(128),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pwads.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No mods loaded. Click "+" or drag-and-drop WAD/PK3 files.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(128),
                ),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pwads.length,
            onReorder: (oldIndex, newIndex) =>
                ref.read(launchNotifierProvider.notifier).reorderPwad(
                      oldIndex,
                      newIndex,
                    ),
            proxyDecorator: (child, index, animation) =>
                Material(elevation: 4, child: child),
            itemBuilder: (context, index) {
              final pwad = pwads[index];
              final fileName = pwad.path.split('\\').last.split('/').last;
              return ListTile(
                key: ValueKey(pwad.id),
                leading: InkWell(
                  onTap: () =>
                      ref.read(launchNotifierProvider.notifier).togglePwad(
                            pwad.id,
                          ),
                  child: Icon(
                    pwad.isEnabled
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: pwad.isEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(80),
                    size: 20,
                  ),
                ),
                title: Text(
                  fileName,
                  style: TextStyle(
                    color: pwad.isEnabled
                        ? null
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(80),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      ref.read(launchNotifierProvider.notifier).removePwad(
                            pwad.id,
                          ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final paths = await _pickPwadFiles();
                if (paths.isNotEmpty) {
                  final newPwads = paths
                      .map((path) => Pwad(
                            id: const Uuid().v4(),
                            path: path,
                          ))
                      .toList();
                  ref
                      .read(launchNotifierProvider.notifier)
                      .addPwads(newPwads);
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add WAD Files'),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.cloud_download_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
            const SizedBox(width: 4),
            Text(
              'Drop files anywhere',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withAlpha(25),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withAlpha(76),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _pickIwadFile() async {
  final service = FilePickerService();
  return service.pickFile(
    allowedExtensions: ['wad'],
    dialogTitle: 'Select IWAD File',
  );
}

Future<List<String>> _pickPwadFiles() async {
  final service = FilePickerService();
  return service.pickMultipleFiles(
    allowedExtensions: ['wad', 'pk3', 'pk7', 'ipk3', 'ipk7', 'deh', 'bex'],
    dialogTitle: 'Select Mod Files',
  );
}
