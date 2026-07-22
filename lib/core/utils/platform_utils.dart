import 'dart:io';

enum AppPlatform { windows, linux, macOS }

class PlatformUtils {
  static AppPlatform get current {
    if (Platform.isWindows) return AppPlatform.windows;
    if (Platform.isLinux) return AppPlatform.linux;
    if (Platform.isMacOS) return AppPlatform.macOS;
    return AppPlatform.windows;
  }

  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;

  static String get executableSuffix => isWindows ? '.exe' : '';
}
