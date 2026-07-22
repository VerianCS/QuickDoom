import '../../core/services/hive_service.dart';
import '../../domain/entities/source_port.dart';
import '../../domain/interfaces/i_source_port_repository.dart';
import '../models/source_port_model.dart';

class SourcePortRepositoryImpl implements ISourcePortRepository {
  final HiveService _hive;

  SourcePortRepositoryImpl(this._hive);

  @override
  Future<List<SourcePort>> getPorts() async {
    final models = await _hive.getAll<SourcePortModel>(HiveService.portsBoxName);
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<void> savePort(SourcePort port) async {
    final model = SourcePortModel.fromDomain(port);
    await _hive.save(HiveService.portsBoxName, port.id, model);
  }

  @override
  Future<void> deletePort(String id) async {
    await _hive.delete<SourcePortModel>(HiveService.portsBoxName, id);
  }
}
