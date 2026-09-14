import 'package:window_manager/window_manager.dart';

/// The window operations the launch sequence performs.
///
/// Behind an interface so the sequence can be driven in tests without a real
/// window — the point worth testing is *when* hide is called, which is
/// impossible to assert against window_manager directly.
abstract class WindowController {
  Future<void> hide();
  Future<void> show();
  Future<void> focus();
}

class WindowManagerController implements WindowController {
  const WindowManagerController();

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();
}
