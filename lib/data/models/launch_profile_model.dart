import 'package:hive/hive.dart';

import '../../domain/entities/launch_profile.dart';
import 'pwad_model.dart';

part 'launch_profile_model.g.dart';

@HiveType(typeId: 3)
class LaunchProfileModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String sourcePortId;
  @HiveField(3)
  final String iwadId;
  @HiveField(4)
  final List<PwadModel> pwadModels;
  @HiveField(5)
  final String customArgs;

  LaunchProfileModel({
    required this.id,
    required this.name,
    required this.sourcePortId,
    required this.iwadId,
    this.pwadModels = const [],
    this.customArgs = '',
  });

  factory LaunchProfileModel.fromDomain(LaunchProfile entity) {
    return LaunchProfileModel(
      id: entity.id,
      name: entity.name,
      sourcePortId: entity.sourcePortId,
      iwadId: entity.iwadId,
      pwadModels: entity.pwadList.map((p) => PwadModel.fromDomain(p)).toList(),
      customArgs: entity.customArgs,
    );
  }

  LaunchProfile toDomain() {
    return LaunchProfile(
      id: id,
      name: name,
      sourcePortId: sourcePortId,
      iwadId: iwadId,
      pwadList: pwadModels.map((p) => p.toDomain()).toList(),
      customArgs: customArgs,
    );
  }
}
