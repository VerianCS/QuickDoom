import 'dart:typed_data';

/// One entry of the WAD directory: the lump's name and a view over its raw
/// bytes in the file.
class WadLump {
  final String name;
  final int offset;
  final int size;
  final ByteData data;

  const WadLump({
    required this.name,
    required this.offset,
    required this.size,
    required this.data,
  });

  bool get isEmpty => size == 0;

  Uint8List get bytes =>
      data.buffer.asUint8List(data.offsetInBytes, size);
}
