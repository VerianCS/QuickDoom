import '../entities/iwad.dart';

abstract class IIwadRepository {
  Future<List<Iwad>> getIwads();
  Future<void> saveIwad(Iwad iwad);
  Future<void> deleteIwad(String id);
}
