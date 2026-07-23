import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/engine_source.dart';

part 'engine_list_provider.g.dart';

@riverpod
List<EngineSource> engineList(EngineListRef ref) => EngineSource.knownEngines;
