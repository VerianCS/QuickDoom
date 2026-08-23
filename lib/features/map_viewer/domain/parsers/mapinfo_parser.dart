/// Parses the `MAPINFO` lump (ZDoom / Hexen format) to discover map names
/// that don't follow the classic `E#M#` / `MAP##` marker convention.
///
/// The parser only extracts `map <name>` declarations; it is intentionally
/// lenient and ignores everything else (clusters, episodes, properties...).
class MapInfoParser {
  /// Returns the uppercase set of map names declared in [text].
  static Set<String> parseNames(String text) {
    final names = <String>{};
    final len = text.length;
    var i = 0;
    var depth = 0;
    var inString = false;

    while (i < len) {
      final c = text[i];

      if (inString) {
        if (c == '\\') {
          i += 2;
          continue;
        }
        if (c == '"') {
          inString = false;
          i++;
          continue;
        }
        i++;
        continue;
      }

      if (c == '"') {
        inString = true;
        i++;
        continue;
      }
      if (c == '{') {
        depth++;
        i++;
        continue;
      }
      if (c == '}') {
        if (depth > 0) depth--;
        i++;
        continue;
      }
      if (c == '/' && i + 1 < len && text[i + 1] == '/') {
        while (i < len && text[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < len && text[i + 1] == '*') {
        i += 2;
        while (i + 1 < len && !(text[i] == '*' && text[i + 1] == '/')) {
          i++;
        }
        i += 2;
        continue;
      }

      if (depth == 0 && _matchWord(text, i, 'map')) {
        // The name may be preceded by whitespace and/or comments.
        final j = _skipWhitespaceAndComments(text, i + 3);
        if (j < len) {
          final (name, next) = _readName(text, j);
          if (name.isNotEmpty) {
            names.add(name.toUpperCase());
            i = next;
            continue;
          }
        }
      }

      i++;
    }

    return names;
  }

  static bool _matchWord(String text, int i, String word) {
    if (i + word.length > text.length) return false;
    for (var k = 0; k < word.length; k++) {
      if (text[i + k].toLowerCase() != word[k]) return false;
    }
    final beforeOk = i == 0 || !_isIdentChar(text[i - 1]);
    final afterOk =
        i + word.length >= text.length || !_isIdentChar(text[i + word.length]);
    return beforeOk && afterOk;
  }

  static int _skipWhitespaceAndComments(String text, int i) {
    while (i < text.length) {
      final c = text[i];
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        i++;
        continue;
      }
      if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
        while (i < text.length && text[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < text.length && text[i + 1] == '*') {
        i += 2;
        while (i + 1 < text.length && !(text[i] == '*' && text[i + 1] == '/')) {
          i++;
        }
        i += 2;
        continue;
      }
      break;
    }
    return i;
  }

  /// Reads an identifier or a double-quoted string starting at [i].
  static (String, int) _readName(String text, int i) {
    if (text[i] == '"') {
      final buffer = StringBuffer();
      var j = i + 1;
      while (j < text.length && text[j] != '"') {
        buffer.write(text[j]);
        j++;
      }
      return (buffer.toString(), j + 1);
    }

    final start = i;
    while (i < text.length && _isIdentChar(text[i])) {
      i++;
    }
    return (text.substring(start, i), i);
  }

  static bool _isIdentChar(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x30 && code <= 0x39) ||
        code == 0x5F; // underscore
  }
}
