class Pwad {
  final String id;
  final String path;
  final bool isEnabled;
  final int loadOrder;

  const Pwad({
    required this.id,
    required this.path,
    this.isEnabled = true,
    this.loadOrder = 0,
  });

  Pwad copyWith({
    String? id,
    String? path,
    bool? isEnabled,
    int? loadOrder,
  }) {
    return Pwad(
      id: id ?? this.id,
      path: path ?? this.path,
      isEnabled: isEnabled ?? this.isEnabled,
      loadOrder: loadOrder ?? this.loadOrder,
    );
  }
}
