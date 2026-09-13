/// One mod inside a pack: a reference into the library plus its load state.
///
/// Load order is the position of the entry in [ModPack.entries].
class ModPackEntry {
  /// Matches `InstalledMod.id`.
  final String modId;
  final bool isEnabled;

  const ModPackEntry({required this.modId, this.isEnabled = true});

  ModPackEntry copyWith({String? modId, bool? isEnabled}) {
    return ModPackEntry(
      modId: modId ?? this.modId,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// A reusable combination of engine, IWAD and ordered mods.
class ModPack {
  final String id;
  final String name;
  final String description;
  final List<ModPackEntry> entries;

  /// `Iwad.id` this pack plays against.
  final String? iwadId;

  /// `SourcePort.id` this pack launches with.
  final String? engineId;

  const ModPack({
    required this.id,
    required this.name,
    this.description = '',
    this.entries = const [],
    this.iwadId,
    this.engineId,
  });

  int get enabledCount => entries.where((e) => e.isEnabled).length;

  bool contains(String modId) => entries.any((e) => e.modId == modId);

  ModPack copyWith({
    String? id,
    String? name,
    String? description,
    List<ModPackEntry>? entries,
    String? iwadId,
    String? engineId,
    bool clearIwad = false,
    bool clearEngine = false,
  }) {
    return ModPack(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      entries: entries ?? this.entries,
      iwadId: clearIwad ? null : iwadId ?? this.iwadId,
      engineId: clearEngine ? null : engineId ?? this.engineId,
    );
  }
}
