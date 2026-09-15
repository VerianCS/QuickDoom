import '../entities/iwad.dart';
import '../entities/launch_profile.dart';
import '../entities/source_port.dart';

class BuildLaunchCommand {
  List<String> buildArgs({
    required LaunchProfile profile,
    required SourcePort port,
    required Iwad iwad,
  }) {
    final args = <String>[];

    args.addAll(tokenize(port.defaultArgs));

    args.addAll(['-iwad', iwad.path]);

    final sortedPwads = profile.pwadList
        .where((p) => p.isEnabled)
        .toList()
      ..sort((a, b) => a.loadOrder.compareTo(b.loadOrder));

    if (sortedPwads.isNotEmpty) {
      args.add('-file');
      args.addAll(sortedPwads.map((p) => p.path));
    }

    args.addAll(tokenize(profile.customArgs));

    return args;
  }

  /// Splits an argument string into arguments, keeping quoted runs together.
  ///
  /// Splitting on every space turned `-file "C:\Program Files\Doom\x.wad"`
  /// into five arguments and handed the port a command line that was wrong
  /// without ever failing, so the port simply could not find the file.
  ///
  /// Both quote characters group, and a quote can open in the middle of a
  /// token so `-file="two words.wad"` survives. A backslash is always
  /// literal: it is the Windows path separator, and treating it as an escape
  /// would mangle every path on the platform this matters most on. An
  /// unterminated quote takes the rest of the string rather than dropping it,
  /// because losing a typed argument in silence is the failure being fixed.
  static List<String> tokenize(String input) {
    final args = <String>[];
    final current = StringBuffer();
    var quote = '';
    var hasToken = false;

    void flush() {
      if (hasToken) {
        args.add(current.toString());
        current.clear();
        hasToken = false;
      }
    }

    for (final char in input.split('')) {
      if (quote.isNotEmpty) {
        if (char == quote) {
          quote = '';
        } else {
          current.write(char);
        }
        continue;
      }

      if (char == '"' || char == "'") {
        quote = char;
        // An empty pair like "" is still an argument.
        hasToken = true;
        continue;
      }

      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
        flush();
        continue;
      }

      current.write(char);
      hasToken = true;
    }

    flush();
    return args;
  }
}
