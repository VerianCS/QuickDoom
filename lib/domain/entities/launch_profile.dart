import 'pwad.dart';

class LaunchProfile {
  final String id;
  final String name;
  final String sourcePortId;
  final String iwadId;
  final List<Pwad> pwadList;
  final String customArgs;

  const LaunchProfile({
    required this.id,
    required this.name,
    required this.sourcePortId,
    required this.iwadId,
    this.pwadList = const [],
    this.customArgs = '',
  });

  LaunchProfile copyWith({
    String? id,
    String? name,
    String? sourcePortId,
    String? iwadId,
    List<Pwad>? pwadList,
    String? customArgs,
  }) {
    return LaunchProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      sourcePortId: sourcePortId ?? this.sourcePortId,
      iwadId: iwadId ?? this.iwadId,
      pwadList: pwadList ?? this.pwadList,
      customArgs: customArgs ?? this.customArgs,
    );
  }
}
