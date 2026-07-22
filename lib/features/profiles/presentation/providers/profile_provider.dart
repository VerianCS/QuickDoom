import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/hive_service.dart';
import '../../../../data/repositories/profile_repository_impl.dart';
import '../../../../domain/entities/launch_profile.dart';
import '../../../../domain/interfaces/i_profile_repository.dart';

part 'profile_provider.g.dart';

IProfileRepository _repo() => ProfileRepositoryImpl(HiveService());

@riverpod
class ProfileList extends _$ProfileList {
  @override
  Future<List<LaunchProfile>> build() async {
    return _repo().getProfiles();
  }

  Future<void> create(String name) async {
    final profile = LaunchProfile(
      id: const Uuid().v4(),
      name: name,
      sourcePortId: '',
      iwadId: '',
    );
    await _repo().saveProfile(profile);
    ref.invalidateSelf();
  }

  Future<void> save(LaunchProfile profile) async {
    await _repo().saveProfile(profile);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _repo().deleteProfile(id);
    ref.invalidateSelf();
  }
}

@riverpod
class CurrentProfileId extends _$CurrentProfileId {
  @override
  String? build() => null;

  void select(String id) => state = id;
  void clear() => state = null;
}
