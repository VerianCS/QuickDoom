import '../../core/services/hive_service.dart';
import '../../domain/entities/iwad.dart';
import '../../domain/interfaces/i_iwad_repository.dart';
import '../models/iwad_model.dart';

class IwadRepositoryImpl implements IIwadRepository {
  final HiveService _hive;

  IwadRepositoryImpl(this._hive);

  @override
  Future<List<Iwad>> getIwads() async {
    final models = await _hive.getAll<IwadModel>(HiveService.iwadsBoxName);
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<void> saveIwad(Iwad iwad) async {
    final model = IwadModel.fromDomain(iwad);
    await _hive.save(HiveService.iwadsBoxName, iwad.id, model);
  }

  @override
  Future<void> deleteIwad(String id) async {
    await _hive.delete<IwadModel>(HiveService.iwadsBoxName, id);
  }
}
