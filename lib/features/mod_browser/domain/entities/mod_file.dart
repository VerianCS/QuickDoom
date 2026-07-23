class ModFile {
  final int id;
  final String title;
  final String filename;
  final String author;
  final String description;
  final int size;
  final double rating;
  final int votes;
  final String downloadUrl;
  final DateTime uploadDate;
  final String dir;

  const ModFile({
    required this.id,
    required this.title,
    required this.filename,
    required this.author,
    required this.description,
    required this.size,
    required this.rating,
    required this.votes,
    required this.downloadUrl,
    required this.uploadDate,
    required this.dir,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
