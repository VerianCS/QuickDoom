class SourcePort {
  final String id;
  final String name;
  final String executablePath;
  final String defaultArgs;

  const SourcePort({
    required this.id,
    required this.name,
    required this.executablePath,
    this.defaultArgs = '',
  });

  SourcePort copyWith({
    String? id,
    String? name,
    String? executablePath,
    String? defaultArgs,
  }) {
    return SourcePort(
      id: id ?? this.id,
      name: name ?? this.name,
      executablePath: executablePath ?? this.executablePath,
      defaultArgs: defaultArgs ?? this.defaultArgs,
    );
  }
}
