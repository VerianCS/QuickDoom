import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/download_service.dart';
import '../../domain/entities/mod_file.dart';

class ModDownloadState {
  final bool isDownloading;
  final double progress;
  final String? localPath;
  final String? error;

  const ModDownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.localPath,
    this.error,
  });

  ModDownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? localPath,
    String? error,
    bool clearError = false,
  }) {
    return ModDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ModDownloadNotifier extends StateNotifier<ModDownloadState> {
  ModDownloadNotifier() : super(const ModDownloadState());

  final DownloadService _service = DownloadService();
  StreamSubscription<DownloadProgress>? _subscription;

  Future<void> download(ModFile mod) async {
    state = state.copyWith(isDownloading: true, progress: 0.0, clearError: true);

    try {
      final appDir = await getApplicationSupportDirectory();
      final modsDir = '${appDir.path}${p.separator}mods';
      final destPath = '$modsDir${p.separator}${mod.filename}';

      final stream = _service.download(mod.downloadUrl, destPath);
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
    state = const ModDownloadState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final modDownloadProvider = StateNotifierProvider<ModDownloadNotifier, ModDownloadState>((ref) {
  return ModDownloadNotifier();
});
