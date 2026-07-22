import 'package:hive/hive.dart';

import '../../domain/entities/iwad.dart';

part 'iwad_model.g.dart';

@HiveType(typeId: 1)
class IwadModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String path;
  @HiveField(3)
  final int gameFamilyIndex;

  GameFamily get gameFamily => GameFamily.values[gameFamilyIndex];

  IwadModel({
    required this.id,
    required this.name,
    required this.path,
    this.gameFamilyIndex = 5,
  });

  factory IwadModel.fromDomain(Iwad entity) {
    return IwadModel(
      id: entity.id,
      name: entity.name,
      path: entity.path,
      gameFamilyIndex: entity.gameFamily.index,
    );
  }

  Iwad toDomain() {
    return Iwad(
      id: id,
      name: name,
      path: path,
      gameFamily: gameFamily,
    );
  }
}
