import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/download_service.dart';

class EngineDownloadState {
  final bool isDownloading;
  final double progress;
  final String? localPath;
  final String? error;

  const EngineDownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.localPath,
    this.error,
  });

  EngineDownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? localPath,
    String? error,
    bool clearError = false,
  }) {
    return EngineDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class EngineDownloadNotifier extends StateNotifier<EngineDownloadState> {
  EngineDownloadNotifier() : super(const EngineDownloadState());

  final DownloadService _service = DownloadService();
  StreamSubscription<DownloadProgress>? _subscription;

  Future<void> download(String url, String filename) async {
    state = state.copyWith(isDownloading: true, progress: 0.0, clearError: true);

    try {
      final appDir = await getApplicationSupportDirectory();
      final enginesDir = '${appDir.path}${p.separator}engines';
      final destPath = '$enginesDir${p.separator}$filename';

      final stream = _service.download(url, destPath);
      _subscription = stream.listen(
        (progress) => state = state.copyWith(progress: progress.fraction),
        onDone: () => state = state.copyWith(
          isDownloading: false,
          progress: 1.0,
          localPath: destPath,
        ),
        onError: (e) => state = state.copyWith(
          isDownloading: false,
          error: 'Download failed: $e',
        ),
      );
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: '$e');
    }
  }

  void cancel() {
    _subscription?.cancel();
    state = const EngineDownloadState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final engineDownloadProvider = StateNotifierProvider<EngineDownloadNotifier, EngineDownloadState>((ref) {
  return EngineDownloadNotifier();
});
