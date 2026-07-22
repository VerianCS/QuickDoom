import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/hive_service.dart';
import '../../../../data/repositories/source_port_repository_impl.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../../domain/interfaces/i_source_port_repository.dart';

part 'source_port_provider.g.dart';

ISourcePortRepository _repo() => SourcePortRepositoryImpl(HiveService());

@riverpod
class SourcePortList extends _$SourcePortList {
  @override
  Future<List<SourcePort>> build() async {
    return _repo().getPorts();
  }

  Future<void> save(SourcePort port) async {
    await _repo().savePort(port);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _repo().deletePort(id);
    ref.invalidateSelf();
  }
}
