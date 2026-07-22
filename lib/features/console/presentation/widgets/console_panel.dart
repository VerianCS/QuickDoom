import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../launcher/presentation/providers/process_provider.dart';

class ConsolePanel extends ConsumerStatefulWidget {
  const ConsolePanel({super.key});

  @override
  ConsumerState<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends ConsumerState<ConsolePanel> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _lines = [];
  StreamSubscription<String>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToStream(Stream<String>? stream) {
    _subscription?.cancel();
    _subscription = null;
    if (stream == null) return;
    _subscription = stream.listen(
      (data) {
        final lines = data.split('\n');
        setState(() {
          for (final line in lines) {
            if (line.isNotEmpty) _lines.add(line);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final runningProcess = ref.watch(processManagerProvider);

    final isRunning = runningProcess != null;

    if (!isRunning && _lines.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isRunning) {
      _subscribeToStream(runningProcess.result.outputLogs);
    }

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.consoleBg,
        border: Border(
          top: BorderSide(color: AppColors.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.titleBar,
            ),
            child: Row(
              children: [
                Icon(
                  isRunning ? Icons.terminal : Icons.terminal_outlined,
                  size: 14,
                  color: isRunning ? AppColors.success : AppColors.onSurface.withAlpha(128),
                ),
                const SizedBox(width: 6),
                Text(
                  isRunning ? 'Game Running...' : 'Console Output',
                  style: TextStyle(
                    fontSize: 12,
                    color: isRunning ? AppColors.success : AppColors.onSurface.withAlpha(180),
                  ),
                ),
                const Spacer(),
                if (!isRunning && _lines.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _lines.clear()),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.onSurface.withAlpha(128),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                final isError = line.contains('[STDERR]') || line.contains('Error');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isError
                          ? AppColors.error
                          : AppColors.onSurface.withAlpha(180),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
