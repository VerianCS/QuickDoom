enum DownloadStage {
  queued,
  downloading,
  installing,
  done,
  failed,
  cancelled,
}

/// One tracked transfer, from queued through installed.
///
/// Tasks are keyed so a row can render its own progress while other downloads
/// run alongside it; see [DownloadTask.modKey] and [DownloadTask.engineKey].
class DownloadTask {
  final String id;
  final String label;
  final DownloadStage stage;
  final int receivedBytes;
  final int totalBytes;
  final String? error;

  /// Where the payload was installed, once [stage] is [DownloadStage.done].
  final String? installDir;

  const DownloadTask({
    required this.id,
    required this.label,
    this.stage = DownloadStage.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
    this.installDir,
  });

  bool get isActive =>
      stage == DownloadStage.queued ||
      stage == DownloadStage.downloading ||
      stage == DownloadStage.installing;

  bool get isFinished =>
      stage == DownloadStage.done ||
      stage == DownloadStage.failed ||
      stage == DownloadStage.cancelled;

  /// Null while the total size is unknown, so the UI can show an
  /// indeterminate bar instead of a bar stuck at zero.
  double? get fraction {
    if (stage == DownloadStage.done) return 1.0;
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get progressLabel {
    switch (stage) {
      case DownloadStage.queued:
        return 'Queued';
      case DownloadStage.downloading:
        if (totalBytes <= 0) return _mb(receivedBytes);
        return '${_mb(receivedBytes)} / ${_mb(totalBytes)}';
      case DownloadStage.installing:
        return 'Installing';
      case DownloadStage.done:
        return 'Installed';
      case DownloadStage.failed:
        return 'Failed';
      case DownloadStage.cancelled:
        return 'Cancelled';
    }
  }

  static String _mb(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DownloadTask copyWith({
    String? label,
    DownloadStage? stage,
    int? receivedBytes,
    int? totalBytes,
    String? error,
    String? installDir,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id,
      label: label ?? this.label,
      stage: stage ?? this.stage,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: clearError ? null : error ?? this.error,
      installDir: installDir ?? this.installDir,
    );
  }

  static String modKey(int idgamesId) => 'mod:$idgamesId';

  static String engineKey(String engineId, String tag, String assetName) =>
      'engine:$engineId:$tag:$assetName';
}
