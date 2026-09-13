import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/custom_title_bar.dart';
import '../features/splash/presentation/widgets/boot_splash.dart';
import '../data/models/iwad_model.dart';
import '../data/models/launch_profile_model.dart';
import '../data/models/pwad_model.dart';
import '../data/models/source_port_model.dart';
import 'providers/system_tray_provider.dart';
import '../features/launcher/presentation/providers/launch_provider.dart';
import '../features/profiles/presentation/providers/profile_provider.dart';

class QuickDoomApp extends ConsumerWidget {
  const QuickDoomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'QuickDoom',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _BootPipeline(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _BootPipeline extends ConsumerStatefulWidget {
  final Widget child;

  const _BootPipeline({required this.child});

  @override
  ConsumerState<_BootPipeline> createState() => _BootPipelineState();
}

class _BootPipelineState extends ConsumerState<_BootPipeline> {
  bool _ready = false;

  /// True once the splash has finished fading out and can be torn down.
  bool _splashDismissed = false;

  String _status = 'Starting...';
  final Stopwatch _bootStopwatch = Stopwatch();
  final FocusNode _focusNode = FocusNode();


  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.toString().contains('Test')) {
      // Widget tests drive frames by hand; a looping splash would never settle.
      _ready = true;
      _splashDismissed = true;
    } else {
      _bootStopwatch.start();
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }
    _focusNode.requestFocus();
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _setStatus('Preparing window...');
    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(false);
      await windowManager.setTitle('QuickDoom');
      await windowManager.setMinimumSize(const Size(800, 600));
      await windowManager.setSize(const Size(1024, 768));
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.center();

      final tray = SystemTray();
      await tray.initSystemTray(
        iconPath: 'assets/app_icon.ico',
        title: 'QuickDoom',
        toolTip: 'QuickDoom',
      );
      tray.registerSystemTrayEventHandler((eventName) {
        if (eventName == 'leftMouseDown' || eventName == 'leftMouseUp') {
          windowManager.show();
          windowManager.focus();
        }
      });
      await tray.setContextMenu([
        MenuItem(label: 'Show', onClicked: () {
          windowManager.show();
          windowManager.focus();
        }),
        MenuItem(label: 'Quit', onClicked: () {
          windowManager.destroy();
        }),
      ]);
      ref.read(systemTrayProvider.notifier).state = tray;
    } catch (e) {
      debugPrint('Init (non-fatal): $e');
    }

    _setStatus('Opening storage...');
    try {
      await Hive.initFlutter();
    } catch (_) {}

    try {
      Hive.registerAdapter(SourcePortModelAdapter());
      Hive.registerAdapter(IwadModelAdapter());
      Hive.registerAdapter(PwadModelAdapter());
      Hive.registerAdapter(LaunchProfileModelAdapter());
    } catch (_) {}

    try {
      if (!Hive.isBoxOpen('quickdoom')) {
        await Hive.openBox('quickdoom');
      }
    } catch (_) {}

    _bootStopwatch.stop();
    debugPrint('⚡ Bootstrap ready: ${_bootStopwatch.elapsedMilliseconds} ms');

    if (mounted) {
      setState(() {
        _status = 'Ready';
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_splashDismissed) return _shell();

    return Stack(
      fit: StackFit.expand,
      children: [
        // The shell mounts underneath as soon as it has data, so the splash
        // cross-fades onto a painted UI rather than an empty frame.
        if (_ready) _shell(),
        BootSplash(
          bootComplete: _ready,
          status: _status,
          onFinished: () {
            if (mounted) setState(() => _splashDismissed = true);
          },
        ),
      ],
    );
  }

  Widget _shell() {
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
          final state = ref.read(launchNotifierProvider);
          if (state.canLaunch) {
            ref.read(launchNotifierProvider.notifier).launch();
          }
        },
        SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _showNewProfileDialog(context);
        },
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Column(
          children: [
            Material(
              color: AppColors.titleBar,
              child: const CustomTitleBar(),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  void _showNewProfileDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Profile name...',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(profileListProvider.notifier).create(value.trim());
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(profileListProvider.notifier).create(name);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
