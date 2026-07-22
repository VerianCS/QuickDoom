import '../entities/launch_profile.dart';

abstract class IProfileRepository {
  Future<List<LaunchProfile>> getProfiles();
  Future<LaunchProfile?> getProfile(String id);
  Future<void> saveProfile(LaunchProfile profile);
  Future<void> deleteProfile(String id);
}
