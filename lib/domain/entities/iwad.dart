enum GameFamily { doom, doom2, heretic, hexen, strife, unknown }

class Iwad {
  final String id;
  final String name;
  final String path;
  final GameFamily gameFamily;

  const Iwad({
    required this.id,
    required this.name,
    required this.path,
    this.gameFamily = GameFamily.unknown,
  });

  Iwad copyWith({
    String? id,
    String? name,
    String? path,
    GameFamily? gameFamily,
  }) {
    return Iwad(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      gameFamily: gameFamily ?? this.gameFamily,
    );
  }
}
