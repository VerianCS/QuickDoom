class ModPack {
  final String id;
  final String name;
  final String description;
  final List<int> modIds;
  final String? iwadId;
  final String? engineId;

  const ModPack({
    required this.id,
    required this.name,
    this.description = '',
    this.modIds = const [],
    this.iwadId,
    this.engineId,
  });

  ModPack copyWith({
    String? id,
    String? name,
    String? description,
    List<int>? modIds,
    String? iwadId,
    String? engineId,
    bool clearIwad = false,
    bool clearEngine = false,
  }) {
    return ModPack(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      modIds: modIds ?? this.modIds,
      iwadId: clearIwad ? null : iwadId ?? this.iwadId,
      engineId: clearEngine ? null : engineId ?? this.engineId,
    );
  }
}
