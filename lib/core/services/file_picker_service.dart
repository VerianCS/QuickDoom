import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

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

  /// Opens a dialog for choosing a program to run.
  ///
  /// Only Windows identifies an executable by its extension. On Linux a
  /// source port is usually an extensionless binary, and on macOS it is inside
  /// a bundle, so an extension filter hides exactly the files being looked
  /// for. The old filter tried to cover this with an empty string in the
  /// list — `['exe', 'AppImage', '']` — but a file dialog matches on suffix
  /// and nothing has an empty suffix, so extensionless binaries were simply
  /// invisible and a Linux user could not select a port at all.
  Future<String?> pickExecutable({String? dialogTitle}) {
    return pickFile(
      allowedExtensions: executableExtensions(Platform.isWindows),
      dialogTitle: dialogTitle,
    );
  }

  /// The extension filter for [pickExecutable], or null for no filter.
  @visibleForTesting
  static List<String>? executableExtensions(bool isWindows) =>
      isWindows ? const ['exe', 'bat', 'cmd', 'com'] : null;
}
