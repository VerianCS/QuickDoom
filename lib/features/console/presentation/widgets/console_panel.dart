import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/widgets/crt_overlay.dart';
import '../../../launcher/presentation/providers/process_provider.dart';

/// Live output from the running game, as a terminal.
///
/// This is the one surface in the app that is literally a console, so it is
/// drawn as one: phosphor text on near-black, scanlines over the top, and a
/// state rail that reads IDLE / RUNNING / EXIT n.
class ConsolePanel extends ConsumerStatefulWidget {
  const ConsolePanel({super.key});

  @override
  ConsumerState<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends ConsumerState<ConsolePanel> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _lines = [];
  StreamSubscription<String>? _subscription;

  /// Kept so the rail can report how the last session ended.
  int? _lastExitCode;

  /// The process the current subscription belongs to.
  ///
  /// Output arrives on a broadcast stream, so a listener only receives what is
  /// emitted after it subscribes. Re-subscribing on every build — which is
  /// what this did — dropped whatever the game wrote in the gap, which is
  /// exactly the startup banner people want to see.
  RunningProcess? _subscribedTo;

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeIfNew(RunningProcess process) {
    if (identical(process, _subscribedTo)) return;
    _subscribedTo = process;
    _subscription?.cancel();
    _lastExitCode = null;

    // Everything written before this widget existed, then the live stream.
    _appendChunks(process.result.history);

    _subscription = process.result.outputLogs.listen((data) {
      setState(() => _appendChunks([data]));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: AppMotion.fast,
            curve: AppMotion.standard,
          );
        }
      });
    });

    process.result.exitCode.then((code) {
      if (mounted) setState(() => _lastExitCode = code);
    });
  }

  void _appendChunks(Iterable<String> chunks) {
    for (final chunk in chunks) {
      for (final line in chunk.split('\n')) {
        if (line.isNotEmpty) _lines.add(line);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runningProcess = ref.watch(processManagerProvider);
    final isRunning = runningProcess != null;

    if (!isRunning && _lines.isEmpty) return const SizedBox.shrink();
    if (isRunning) _subscribeIfNew(runningProcess);

    return SizedBox(
      height: 168,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StateRail(
            isRunning: isRunning,
            exitCode: _lastExitCode,
            lineCount: _lines.length,
            onClear: isRunning ? null : () => setState(_lines.clear),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.consoleBg),
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) => _ConsoleLine(
                    text: _lines[index],
                    // Only the newest line glows, so the eye lands on what
                    // just arrived rather than the whole wall.
                    fresh: index == _lines.length - 1 && isRunning,
                  ),
                ),
                const CrtOverlayLayer(
                  scanlineOpacity: 0.22,
                  vignetteOpacity: 0.4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of output. stderr is marked at the source and shown in the error
/// colour with its marker stripped.
class _ConsoleLine extends StatelessWidget {
  final String text;
  final bool fresh;

  const _ConsoleLine({required this.text, required this.fresh});

  static const String _stderrMarker = '[STDERR]';

  @override
  Widget build(BuildContext context) {
    final isError = text.contains(_stderrMarker);
    final body =
        isError ? text.replaceAll(_stderrMarker, '').trimLeft() : text;
    final colour = isError ? AppColors.error : AppColors.phosphor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        body,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.35,
          color: colour.withValues(alpha: isError ? 1.0 : 0.86),
          shadows: fresh
              ? [Shadow(color: colour.withValues(alpha: 0.7), blurRadius: 8)]
              : const [],
        ),
      ),
    );
  }
}

/// The rail above the output: what the process is doing, and how much it said.
class _StateRail extends StatelessWidget {
  final bool isRunning;
  final int? exitCode;
  final int lineCount;
  final VoidCallback? onClear;

  const _StateRail({
    required this.isRunning,
    required this.exitCode,
    required this.lineCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final (label, tint) = switch ((isRunning, exitCode)) {
      (true, _) => ('RUNNING', AppColors.success),
      (false, final int code) when code != 0 => ('EXIT $code', AppColors.error),
      (false, final int code) => ('EXIT $code', AppColors.onBackground),
      _ => ('IDLE', AppColors.onSurfaceFaint),
    };

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.titleBar,
        border: Border(
          top: BorderSide(color: AppColors.dividerColor),
          bottom: BorderSide(color: AppColors.dividerSoft),
        ),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, color: tint),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.doomText,
              fontSize: 11,
              letterSpacing: 1.6,
              color: tint,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$lineCount ${lineCount == 1 ? 'line' : 'lines'}',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.onSurfaceFaint,
            ),
          ),
          const Spacer(),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'CLEAR',
                    style: TextStyle(
                      fontFamily: AppFonts.doomText,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: AppColors.onSurfaceFaint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
