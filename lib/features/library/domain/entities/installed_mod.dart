import 'package:path/path.dart' as p;

/// A mod that has been downloaded and unpacked into QuickDoom's library.
///
/// [files] holds every loadable file the install produced, in the order they
/// should be handed to the source port: a loose `.wad` drop yields a single
/// entry, while an idgames zip usually yields one `.wad` plus any `.deh`
/// patches shipped alongside it.
class InstalledMod {
  final String id;
  final String name;
  final String installDir;
  final List<String> files;
  final int? idgamesId;
  final String author;
  final int sizeBytes;
  final DateTime installedAt;

  const InstalledMod({
    required this.id,
    required this.name,
    required this.installDir,
    this.files = const [],
    this.idgamesId,
    this.author = '',
    this.sizeBytes = 0,
    required this.installedAt,
  });

  /// The file loaded first, and the one shown in compact list rows.
  String get primaryFile => files.isEmpty ? '' : files.first;

  String get primaryFileName =>
      primaryFile.isEmpty ? '' : p.basename(primaryFile);

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  InstalledMod copyWith({
    String? id,
    String? name,
    String? installDir,
    List<String>? files,
    int? idgamesId,
    String? author,
    int? sizeBytes,
    DateTime? installedAt,
  }) {
    return InstalledMod(
      id: id ?? this.id,
      name: name ?? this.name,
      installDir: installDir ?? this.installDir,
      files: files ?? this.files,
      idgamesId: idgamesId ?? this.idgamesId,
      author: author ?? this.author,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      installedAt: installedAt ?? this.installedAt,
    );
  }
}
