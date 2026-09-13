import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/download_task.dart';
import '../providers/download_queue_provider.dart';

/// Compact download control for a list row.
///
/// Renders the full lifecycle in a fixed-width slot — idle button, live
/// progress with cancel, installing spinner, installed state, retryable error —
/// so rows do not reflow as a transfer moves between stages.
class DownloadButton extends ConsumerWidget {
  /// Key into the download queue; see [DownloadTask.modKey] / [engineKey].
  final String taskId;

  /// Starts (or retries) the transfer.
  final VoidCallback onStart;

  final String idleLabel;

  const DownloadButton({
    super.key,
    required this.taskId,
    required this.onStart,
    this.idleLabel = 'Download',
  });

  static const double _width = 148;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(
      downloadQueueProvider.select((queue) => queue[taskId]),
    );

    return SizedBox(
      width: _width,
      child: switch (task?.stage) {
        null => _idle(context),
        DownloadStage.queued ||
        DownloadStage.downloading =>
          _progress(context, ref, task!),
        DownloadStage.installing => _installing(context),
        DownloadStage.done => _done(context, ref),
        DownloadStage.failed => _failed(context, ref, task!),
        DownloadStage.cancelled => _idle(context),
      },
    );
  }

  Widget _idle(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onStart,
      icon: const Icon(Icons.download_outlined, size: 16),
      label: Text(idleLabel, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _progress(BuildContext context, WidgetRef ref, DownloadTask task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: task.fraction,
                  minHeight: 5,
                  backgroundColor: AppColors.dividerColor,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                task.progressLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Cancel',
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              ref.read(downloadQueueProvider.notifier).cancel(taskId),
        ),
      ],
    );
  }

  Widget _installing(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          'Installing…',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
          ),
        ),
      ],
    );
  }

  Widget _done(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
        const SizedBox(width: 6),
        const Text(
          'Installed',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close, size: 14),
          tooltip: 'Dismiss',
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              ref.read(downloadQueueProvider.notifier).dismiss(taskId),
        ),
      ],
    );
  }

  Widget _failed(BuildContext context, WidgetRef ref, DownloadTask task) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: task.error ?? 'Download failed',
          child: const Icon(Icons.error_outline,
              size: 16, color: AppColors.error),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ref.read(downloadQueueProvider.notifier).dismiss(taskId);
              onStart();
            },
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
