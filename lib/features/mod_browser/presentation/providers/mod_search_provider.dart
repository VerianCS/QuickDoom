import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/idgames_api_service.dart';
import '../../data/repositories/mod_repository.dart';
import '../../domain/entities/mod_file.dart';

part 'mod_search_provider.g.dart';

final _modRepositoryProvider = Provider<ModRepository>((ref) {
  return ModRepository(IdgamesApiService());
});

@riverpod
class ModSearch extends _$ModSearch {
  @override
  Future<List<ModFile>> build() async => [];

  Future<void> search(String query, {String type = 'title', String sort = 'date'}) async {
    if (query.length < 3) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(_modRepositoryProvider).search(query: query, type: type, sort: sort),
    );
  }
}
