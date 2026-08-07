/// Thrown when a file cannot be interpreted as a valid WAD
/// (bad magic, truncated data, out-of-bounds lumps).
class WadFormatException implements Exception {
  final String message;

  const WadFormatException(this.message);

  @override
  String toString() => 'WadFormatException: $message';
}
