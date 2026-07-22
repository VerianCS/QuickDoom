import 'package:hive/hive.dart';

import '../../domain/entities/source_port.dart';

part 'source_port_model.g.dart';

@HiveType(typeId: 0)
class SourcePortModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String executablePath;
  @HiveField(3)
  final String defaultArgs;

  SourcePortModel({
    required this.id,
    required this.name,
    required this.executablePath,
    this.defaultArgs = '',
  });

  factory SourcePortModel.fromDomain(SourcePort entity) {
    return SourcePortModel(
      id: entity.id,
      name: entity.name,
      executablePath: entity.executablePath,
      defaultArgs: entity.defaultArgs,
    );
  }

  SourcePort toDomain() {
    return SourcePort(
      id: id,
      name: name,
      executablePath: executablePath,
      defaultArgs: defaultArgs,
    );
  }
}
