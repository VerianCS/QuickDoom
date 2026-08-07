import 'dart:convert';

import '../errors/wad_format_exception.dart';
import '../models/doom_map.dart';
import '../models/linedef.dart';
import '../models/sector.dart';
import '../models/sidedef.dart';
import '../models/thing.dart';
import '../models/vertex.dart';
import '../models/wad_file.dart';

/// Tokenizer + parser for UDMF `TEXTMAP` lumps.
///
/// UDMF uses a block-based text format. Every block (`vertex {}`,
/// `sector {}`, `sidedef {}`, `line {}`, `thing {}`) is parsed into the same
/// domain models shared with the classic binary parser.
class UdmfParser {
  static const Map<String, int> _lineFlagBits = {
    'impassable': 0x0001,
    'blockplayers': 0x0001,
    'blockmonsters': 0x0002,
    'twosided': 0x0004,
    'dontpegtop': 0x0008,
    'upperunpegged': 0x0008,
    'dontpegbottom': 0x0010,
    'lowerunpegged': 0x0010,
    'secret': 0x0020,
    'blocksound': 0x0040,
    'dontdraw': 0x0080,
    'notonmap': 0x0080,
    'mapped': 0x0100,
    'alreadyonmap': 0x0100,
  };

  /// UDMF uses one bit per skill; the classic layout packs skills 1-2 (easy)
  /// and 4-5 (hard) together, so those collapse onto the classic bits.
  static const Map<String, int> _thingFlagBits = {
    'skill1': 0x0001,
    'skill2': 0x0001,
    'skill3': 0x0002,
    'skill4': 0x0004,
    'skill5': 0x0004,
    'ambush': 0x0008,
    'deaf': 0x0008,
    'multiplayer': 0x0010,
    'notmp': 0x0020,
  };

  static const Map<String, int> _thingTypeNames = {
    'playerstart': 1,
    'playe': 1,
    'teleportdest': 14,
    'teleportdestation': 14,
  };

  static DoomMap parseMap(WadMapLumps map) {
    final textmap = map.lumpByName('TEXTMAP');
    if (textmap == null) {
      throw const WadFormatException('UDMF map has no TEXTMAP lump');
    }
    final text = latin1.decode(textmap.bytes);
    return parseText(text, mapName: map.name);
  }

  static DoomMap parseText(String text, {required String mapName}) {
    final parser = _UdmfBlockParser(text);

    final vertices = <Vertex>[];
    final sectors = <Sector>[];
    final sidedefBlocks = <_Block>[];
    final linedefProps = <_Block>[];
    final things = <Thing>[];

    while (parser.hasNext) {
      final block = parser.nextBlock();
      switch (block.name) {
        case 'vertex':
          vertices.add(Vertex(
            x: block.intProp('x'),
            y: block.intProp('y'),
          ));
        case 'sector':
          sectors.add(_parseSector(block));
        case 'sidedef':
          sidedefBlocks.add(block);
        case 'line':
          linedefProps.add(block);
        case 'thing':
          final thing = _parseThing(block);
          if (thing != null) things.add(thing);
      }
    }

    final sidedefs = <Sidedef>[];
    for (final block in sidedefBlocks) {
      sidedefs.add(_parseSidedef(block, sectors));
    }

    final linedefs = <Linedef>[];
    for (final block in linedefProps) {
      final frontSideId = block.intProp('sidefront', fallback: 0);
      final backSideId = block.intProp('sideback', fallback: 0);
      linedefs.add(Linedef(
        startVertexIndex: _vertexRef(block.intProp('v1', fallback: 1), vertices.length),
        endVertexIndex: _vertexRef(block.intProp('v2', fallback: 1), vertices.length),
        flags: _lineFlags(block),
        special: block.intProp('special'),
        tag: block.intProp('id', fallback: block.intProp('tag')),
        frontSidedefIndex: _sidedefRef(frontSideId, sidedefs.length),
        backSidedefIndex: backSideId == 0 ? -1 : _sidedefRef(backSideId, sidedefs.length),
        args: _args(block),
      ));
    }

    return DoomMap(
      name: mapName,
      format: MapFormat.udmf,
      vertices: vertices,
      linedefs: linedefs,
      sidedefs: sidedefs,
      sectors: sectors,
      things: things,
    );
  }

  static Sector _parseSector(_Block block) {
    final specialRaw = block.strProp('special', fallback: '0');
    final special = int.tryParse(specialRaw) ?? 0;
    return Sector(
      floorHeight: block.intProp('heightfloor'),
      ceilingHeight: block.intProp('heightceiling'),
      floorTexture: _texture(block, 'texturefloor'),
      ceilingTexture: _texture(block, 'textureceiling'),
      lightLevel: block.intProp('lightlevel'),
      special: special,
      tag: block.intProp('id', fallback: block.intProp('tag')),
    );
  }

  static Sidedef _parseSidedef(_Block block, List<Sector> sectors) {
    return Sidedef(
      xOffset: block.intProp('offsetx'),
      yOffset: block.intProp('offsety'),
      upperTexture: _texture(block, 'texturetop'),
      lowerTexture: _texture(block, 'texturebottom'),
      middleTexture: _texture(block, 'texturemiddle'),
      sectorIndex: _sectorRef(block.intProp('sector', fallback: -1), sectors.length),
    );
  }

  static Thing? _parseThing(_Block block) {
    final typeRaw = block.strProp('type', fallback: '0');
    final typeNum = int.tryParse(typeRaw);
    final args = _args(block);
    final special = block.intProp('special');

    return Thing(
      x: block.intProp('x'),
      y: block.intProp('y'),
      angle: block.intProp('angle'),
      type: typeNum ?? _thingTypeNames[typeRaw.toLowerCase()] ?? 0,
      flags: _thingFlags(block),
      z: block.intProp('z'),
      special: special,
      args: args,
      tid: block.intProp('tid'),
      typeName: typeNum == null ? typeRaw : null,
    );
  }

  // --- helpers ---

  static int _vertexRef(int raw, int vertexCount) {
    final index = raw - 1; // UDMF vertices are 1-based
    return index >= 0 && index < vertexCount ? index : -1;
  }

  static int _sectorRef(int raw, int sectorCount) {
    if (raw < 0 || raw >= sectorCount) return -1;
    return raw;
  }

  /// UDMF sidedefs are referenced by their ordinal in the TEXTMAP, 1-based.
  static int _sidedefRef(int id, int sidedefCount) {
    final index = id - 1;
    return index >= 0 && index < sidedefCount ? index : -1;
  }

  static List<int> _args(_Block block) {
    return [for (var i = 0; i < 5; i++) block.intProp('arg$i')];
  }

  static String _texture(_Block block, String key) {
    final raw = block.strProp(key, fallback: '');
    return raw == '-' ? '' : raw;
  }

  static int _lineFlags(_Block block) {
    final raw = block.strProp('flags', fallback: '0');
    final numeric = int.tryParse(raw);
    if (numeric != null) return numeric;
    return _nameFlags(raw, _lineFlagBits);
  }

  static int _thingFlags(_Block block) {
    final raw = block.strProp('flags', fallback: '0');
    final numeric = int.tryParse(raw);
    if (numeric != null) return numeric;
    return _nameFlags(raw, _thingFlagBits);
  }

  static int _nameFlags(String raw, Map<String, int> table) {
    var flags = 0;
    for (final name in raw.split(RegExp(r'\s+'))) {
      flags |= table[name.toLowerCase()] ?? 0;
    }
    return flags;
  }
}

/// A single UDMF block: `name { key = value; ... }`.
class _Block {
  final String name;
  final Map<String, Object> props;

  _Block(this.name) : props = {};

  int intProp(String key, {int fallback = 0}) {
    final value = props[key];
    if (value is int) return value;
    final parsed = num.tryParse(value?.toString() ?? '');
    return parsed?.round() ?? fallback;
  }

  String strProp(String key, {String fallback = ''}) {
    final value = props[key];
    return value?.toString() ?? fallback;
  }
}

enum _TokenKind { ident, string, number, braceOpen, braceClose, assign, semicolon }

class _Token {
  final _TokenKind kind;
  final String text;

  const _Token(this.kind, this.text);

  @override
  String toString() => '_Token(${kind.name}, "$text")';
}

/// Turns the UDMF text into a token stream.
class _UdmfLexer {
  final String _src;
  int _pos = 0;

  _UdmfLexer(this._src);

  List<_Token> tokenize() {
    final tokens = <_Token>[];
    while (_pos < _src.length) {
      final c = _src[_pos];

      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        _pos++;
        continue;
      }
      if (c == '/' && _pos + 1 < _src.length && _src[_pos + 1] == '/') {
        _skipLineComment();
        continue;
      }
      if (c == '/' && _pos + 1 < _src.length && _src[_pos + 1] == '*') {
        _skipBlockComment();
        continue;
      }
      if (c == '{') {
        tokens.add(const _Token(_TokenKind.braceOpen, '{'));
        _pos++;
        continue;
      }
      if (c == '}') {
        tokens.add(const _Token(_TokenKind.braceClose, '}'));
        _pos++;
        continue;
      }
      if (c == '=') {
        tokens.add(const _Token(_TokenKind.assign, '='));
        _pos++;
        continue;
      }
      if (c == ';') {
        tokens.add(const _Token(_TokenKind.semicolon, ';'));
        _pos++;
        continue;
      }
      if (c == '"') {
        tokens.add(_readString());
        continue;
      }
      if (_isNumberStart(c)) {
        tokens.add(_readNumber());
        continue;
      }
      if (_isIdentStart(c)) {
        tokens.add(_readIdent());
        continue;
      }

      throw WadFormatException('Unexpected character "$c" in TEXTMAP at offset $_pos');
    }
    return tokens;
  }

  void _skipLineComment() {
    while (_pos < _src.length && _src[_pos] != '\n') {
      _pos++;
    }
  }

  void _skipBlockComment() {
    _pos += 2;
    while (_pos + 1 < _src.length &&
        !(_src[_pos] == '*' && _src[_pos + 1] == '/')) {
      _pos++;
    }
    if (_pos + 1 >= _src.length) {
      throw const WadFormatException('Unterminated block comment in TEXTMAP');
    }
    _pos += 2;
  }

  _Token _readString() {
    final buffer = StringBuffer();
    _pos++; // skip opening quote
    while (_pos < _src.length) {
      final c = _src[_pos];
      if (c == '"') {
        _pos++;
        return _Token(_TokenKind.string, buffer.toString());
      }
      if (c == '\\' && _pos + 1 < _src.length) {
        buffer.write(_src[_pos + 1]);
        _pos += 2;
        continue;
      }
      buffer.write(c);
      _pos++;
    }
    throw const WadFormatException('Unterminated string in TEXTMAP');
  }

  _Token _readNumber() {
    final start = _pos;
    if (_pos + 1 < _src.length &&
        _src[_pos] == '0' &&
        (_src[_pos + 1] == 'x' || _src[_pos + 1] == 'X')) {
      _pos += 2;
      final hexStart = _pos;
      while (_pos < _src.length && _isHexDigit(_src[_pos])) {
        _pos++;
      }
      if (_pos == hexStart) {
        throw const WadFormatException('Invalid hex number in TEXTMAP');
      }
      return _Token(_TokenKind.number, _src.substring(start, _pos));
    }
    if (_src[_pos] == '-') {
      _pos++;
    }
    while (_pos < _src.length) {
      final c = _src[_pos];
      if (c == '.') {
        _pos++;
        continue;
      }
      if (_isDigit(c)) {
        _pos++;
        continue;
      }
      break;
    }
    final raw = _src.substring(start, _pos);
    if (!_isValidNumber(raw)) {
      throw WadFormatException('Invalid number "$raw" in TEXTMAP at offset $start');
    }
    return _Token(_TokenKind.number, raw);
  }

  static bool _isValidNumber(String raw) {
    if (raw.startsWith('0x') || raw.startsWith('0X')) {
      return int.tryParse(raw.substring(2), radix: 16) != null;
    }
    return num.tryParse(raw) != null;
  }

  bool _isHexDigit(String c) {
    final code = c.codeUnitAt(0);
    return _isDigit(c) ||
        (code >= 0x41 && code <= 0x46) ||
        (code >= 0x61 && code <= 0x66);
  }

  _Token _readIdent() {
    final start = _pos;
    while (_pos < _src.length &&
        (_isIdentStart(_src[_pos]) || _isDigit(_src[_pos]))) {
      _pos++;
    }
    return _Token(_TokenKind.ident, _src.substring(start, _pos));
  }

  bool _isNumberStart(String c) =>
      _isDigit(c) || (c == '-' && _pos + 1 < _src.length && _isDigit(_src[_pos + 1]));

  bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  bool _isIdentStart(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        c == '_';
  }
}

/// Consumes tokens into block objects.
class _UdmfBlockParser {
  final List<_Token> _tokens;
  int _i = 0;

  _UdmfBlockParser(String text) : _tokens = _UdmfLexer(text).tokenize();

  bool get hasNext => _i < _tokens.length;

  _Block nextBlock() {
    final nameTok = _expect(_TokenKind.ident, 'expected block name');
    _expect(_TokenKind.braceOpen, 'expected "{" after "${nameTok.text}"');

    final block = _Block(nameTok.text);
    while (_i < _tokens.length && _tokens[_i].kind != _TokenKind.braceClose) {
      final key = _expect(_TokenKind.ident, 'expected property key').text;
      _expect(_TokenKind.assign, 'expected "=" after "$key"');

      final valueTok = _tokens[_i];
      switch (valueTok.kind) {
        case _TokenKind.number:
          block.props[key] = _parseNumber(valueTok.text);
        case _TokenKind.string:
          block.props[key] = valueTok.text;
        case _TokenKind.ident:
          block.props[key] = valueTok.text;
        default:
          throw WadFormatException('Expected value for "$key" in TEXTMAP');
      }
      _i++;

      if (_i < _tokens.length && _tokens[_i].kind == _TokenKind.semicolon) {
        _i++;
      }
    }
    _expect(_TokenKind.braceClose, 'expected "}" to close "${nameTok.text}" block');
    return block;
  }

  _Token _expect(_TokenKind kind, String what) {
    if (_i >= _tokens.length || _tokens[_i].kind != kind) {
      throw WadFormatException('TEXTMAP parse error: $what');
    }
    return _tokens[_i++];
  }

  static Object _parseNumber(String raw) {
    if (raw.startsWith('0x') || raw.startsWith('0X')) {
      return int.parse(raw.substring(2), radix: 16);
    }
    return num.parse(raw);
  }
}
