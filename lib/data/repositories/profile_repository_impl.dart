import '../../core/services/hive_service.dart';
import '../../domain/entities/launch_profile.dart';
import '../../domain/interfaces/i_profile_repository.dart';
import '../models/launch_profile_model.dart';

class ProfileRepositoryImpl implements IProfileRepository {
  final HiveService _hive;

  ProfileRepositoryImpl(this._hive);

  @override
  Future<List<LaunchProfile>> getProfiles() async {
    final models = await _hive.getAll<LaunchProfileModel>(HiveService.profilesBoxName);
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<LaunchProfile?> getProfile(String id) async {
    final model = await _hive.getById<LaunchProfileModel>(HiveService.profilesBoxName, id);
    return model?.toDomain();
  }

  @override
  Future<void> saveProfile(LaunchProfile profile) async {
    final model = LaunchProfileModel.fromDomain(profile);
    await _hive.save(HiveService.profilesBoxName, profile.id, model);
  }

  @override
  Future<void> deleteProfile(String id) async {
    await _hive.delete<LaunchProfileModel>(HiveService.profilesBoxName, id);
  }
}
