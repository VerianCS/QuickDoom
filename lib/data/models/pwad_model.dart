import 'package:hive/hive.dart';

import '../../domain/entities/pwad.dart';

part 'pwad_model.g.dart';

@HiveType(typeId: 2)
class PwadModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String path;
  @HiveField(2)
  final bool isEnabled;
  @HiveField(3)
  final int loadOrder;

  PwadModel({
    required this.id,
    required this.path,
    this.isEnabled = true,
    this.loadOrder = 0,
  });

  factory PwadModel.fromDomain(Pwad entity) {
    return PwadModel(
      id: entity.id,
      path: entity.path,
      isEnabled: entity.isEnabled,
      loadOrder: entity.loadOrder,
    );
  }

  Pwad toDomain() {
    return Pwad(
      id: id,
      path: path,
      isEnabled: isEnabled,
      loadOrder: loadOrder,
    );
  }
}
