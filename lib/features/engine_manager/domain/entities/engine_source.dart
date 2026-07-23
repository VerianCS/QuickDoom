class EngineSource {
  final String id;
  final String displayName;
  final String githubOwner;
  final String githubRepo;

  const EngineSource({
    required this.id,
    required this.displayName,
    required this.githubOwner,
    required this.githubRepo,
  });

  static const List<EngineSource> knownEngines = [
    EngineSource(
      id: 'gzdoom',
      displayName: 'GZDoom',
      githubOwner: 'ZDoom',
      githubRepo: 'gzdoom',
    ),
    EngineSource(
      id: 'dsda-doom',
      displayName: 'DSDA-Doom',
      githubOwner: 'kraflab',
      githubRepo: 'dsda-doom',
    ),
    EngineSource(
      id: 'woof',
      displayName: 'Woof!',
      githubOwner: 'fabiangreffrath',
      githubRepo: 'woof',
    ),
    EngineSource(
      id: 'nugget-doom',
      displayName: 'Nugget Doom',
      githubOwner: 'MrAlaux',
      githubRepo: 'Nugget-Doom',
    ),
    EngineSource(
      id: 'helion',
      displayName: 'Helion',
      githubOwner: 'Helion-Engine',
      githubRepo: 'Helion',
    ),
  ];
}
