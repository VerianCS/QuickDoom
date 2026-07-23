import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mod_pack.dart';
import '../providers/mod_pack_provider.dart';

class ModPackEditorScreen extends ConsumerStatefulWidget {
  final ModPack pack;

  const ModPackEditorScreen({super.key, required this.pack});

  @override
  ConsumerState<ModPackEditorScreen> createState() => _ModPackEditorScreenState();
}

class _ModPackEditorScreenState extends ConsumerState<ModPackEditorScreen> {
  late TextEditingController _nameController;
  int _nextModId = 1;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pack.name);
    if (widget.pack.modIds.isNotEmpty) {
      _nextModId = widget.pack.modIds.reduce(max) + 1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    ref.read(modPackListProvider.notifier).save(
      widget.pack.copyWith(name: name),
    );
  }

  void _addMod() {
    final id = _nextModId++;
    ref.read(modPackListProvider.notifier).save(
      widget.pack.copyWith(modIds: [...widget.pack.modIds, id]),
    );
  }

  void _removeMod(int modId) {
    ref.read(modPackListProvider.notifier).save(
      widget.pack.copyWith(
        modIds: widget.pack.modIds.where((id) => id != modId).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(modPackListProvider);
    final pack = packsAsync.whenOrNull(data: (packs) => packs.firstWhere(
      (p) => p.id == widget.pack.id,
      orElse: () => widget.pack,
    )) ?? widget.pack;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameController,
          onSubmitted: (_) => _saveName(),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 20),
            onPressed: _saveName,
            tooltip: 'Rename',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton.tonalIcon(
              onPressed: _addMod,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Mod Entry'),
            ),
          ),
          Expanded(
            child: pack.modIds.isEmpty
                ? Center(
                    child: Text(
                      'No mods in this pack yet.\nTap "Add Mod Entry" to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pack.modIds.length,
                    itemBuilder: (context, index) {
                      final modId = pack.modIds[index];
                      return ListTile(
                        title: Text('Mod #$modId', style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                          onPressed: () => _removeMod(modId),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
