class EngineAsset {
  final String name;
  final String downloadUrl;
  final int size;
  final int downloadCount;

  const EngineAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.downloadCount,
  });

  String get sizeFormatted {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class EngineRelease {
  final String tagName;
  final String name;
  final bool prerelease;
  final String body;
  final DateTime publishedAt;
  final List<EngineAsset> assets;

  const EngineRelease({
    required this.tagName,
    required this.name,
    required this.prerelease,
    required this.body,
    required this.publishedAt,
    required this.assets,
  });

  List<EngineAsset> assetsForPlatform(String platform) {
    final lower = platform.toLowerCase();
    return assets.where((a) {
      final name = a.name.toLowerCase();
      if (lower == 'windows') {
        return name.contains('win64') || name.contains('win32') || name.contains('windows');
      }
      if (lower == 'linux') {
        return name.contains('linux') && !name.contains('win');
      }
      if (lower == 'macos') {
        return name.contains('mac') || name.contains('osx') || name.contains('darwin');
      }
      return false;
    }).toList();
  }
}
