import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/parsers/mapinfo_parser.dart';

void main() {
  group('MapInfoParser', () {
    test('extracts a single map name', () {
      const text = '''
map MYMAP "My Custom Map"
{
  sky = "SKY1"
}
''';
      expect(MapInfoParser.parseNames(text), {'MYMAP'});
    });

    test('extracts multiple map names', () {
      const text = '''
map LEVEL1
{
}
map LEVEL2 "Second"
{
}
''';
      expect(MapInfoParser.parseNames(text), {'LEVEL1', 'LEVEL2'});
    });

    test('handles quoted map names', () {
      const text = 'map "A Weird Name" { }';
      expect(MapInfoParser.parseNames(text), {'A WEIRD NAME'});
    });

    test('ignores non-map blocks and properties', () {
      const text = '''
defaultmap
{
  gravity = 1.0
}
cluster 1
{
  name = "Intro"
}
episode 1
{
  name = "Knee-deep"
}
map REALMAP
{
  damage = 0
}
''';
      expect(MapInfoParser.parseNames(text), {'REALMAP'});
    });

    test('skips line and block comments', () {
      const text = '''
// a comment with map FAKE not real
map /* map NOTREAL */ TRUE1 { }
/*
map BLOCKED { }
*/
map TRUE2 { }
''';
      expect(MapInfoParser.parseNames(text), {'TRUE1', 'TRUE2'});
    });

    test('does not match "map" inside identifiers', () {
      const text = 'remap SOMETEX NEWTEX\nmap ACTUAL { }';
      expect(MapInfoParser.parseNames(text), {'ACTUAL'});
    });

    test('returns empty set for empty input', () {
      expect(MapInfoParser.parseNames(''), isEmpty);
    });
  });
}
