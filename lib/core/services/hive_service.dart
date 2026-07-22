import 'package:hive/hive.dart';

class HiveService {
  static const String profilesBoxName = 'profiles';
  static const String portsBoxName = 'ports';
  static const String iwadsBoxName = 'iwads';

  Future<Box<T>> openBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  Future<List<T>> getAll<T>(String boxName) async {
    final box = await openBox<T>(boxName);
    return box.values.toList();
  }

  Future<T?> getById<T>(String boxName, String key) async {
    final box = await openBox<T>(boxName);
    return box.get(key);
  }

  Future<void> save<T>(String boxName, String key, T value) async {
    final box = await openBox<T>(boxName);
    await box.put(key, value);
  }

  Future<void> delete<T>(String boxName, String key) async {
    final box = await openBox<T>(boxName);
    await box.delete(key);
  }

  Future<void> clear(String boxName) async {
    final box = await openBox(boxName);
    await box.clear();
  }
}
