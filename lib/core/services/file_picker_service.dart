import 'package:file_picker/file_picker.dart';

class FilePickerService {
  Future<String?> pickFile({
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      dialogTitle: dialogTitle,
    );

    return result?.files.single.path;
  }

  Future<List<String>> pickMultipleFiles({
    List<String>? allowedExtensions,
    String? dialogTitle,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      dialogTitle: dialogTitle,
      allowMultiple: true,
    );

    final paths = result?.files.map((f) => f.path).toList() ?? [];
    return paths.whereType<String>().toList();
  }
}
