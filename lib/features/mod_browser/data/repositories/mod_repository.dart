import '../../../../core/services/idgames_api_service.dart';
import '../../domain/entities/mod_file.dart';

class ModRepository {
  final IdgamesApiService _api;

  ModRepository(this._api);

  Future<List<ModFile>> search({
    required String query,
    String type = 'title',
    String sort = 'date',
    String dir = 'desc',
  }) async {
    final results = await _api.search(query: query, type: type, sort: sort, dir: dir);
    return results.map(_toModFile).toList();
  }

  Future<ModFile?> getDetails(int id) async {
    final result = await _api.getDetails(id);
    return result != null ? _toModFile(result) : null;
  }

  ModFile _toModFile(IdgamesFileResult r) {
    return ModFile(
      id: r.id,
      title: r.title,
      filename: r.filename,
      author: r.author,
      description: r.description,
      size: r.size,
      rating: r.rating,
      votes: r.votes,
      downloadUrl: r.downloadUrl,
      uploadDate: r.date,
      dir: r.dir,
    );
  }
}
