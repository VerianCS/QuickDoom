import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/hive_service.dart';
import '../../../../data/repositories/iwad_repository_impl.dart';
import '../../../../domain/entities/iwad.dart';
import '../../../../domain/interfaces/i_iwad_repository.dart';

part 'iwad_provider.g.dart';

IIwadRepository _repo() => IwadRepositoryImpl(HiveService());

@riverpod
class IwadList extends _$IwadList {
  @override
  Future<List<Iwad>> build() async {
    return _repo().getIwads();
  }

  Future<void> save(Iwad iwad) async {
    await _repo().saveIwad(iwad);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _repo().deleteIwad(id);
    ref.invalidateSelf();
  }
}
