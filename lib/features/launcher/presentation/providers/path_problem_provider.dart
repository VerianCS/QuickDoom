import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/file_problem.dart';

part 'path_problem_provider.g.dart';

/// Whether the executable at [path] can still be run.
@riverpod
Future<String?> portProblem(PortProblemRef ref, String path) =>
    FileProblem.describe(path, needsExecuteBit: true);

/// Whether the WAD at [path] is still there.
@riverpod
Future<String?> iwadProblem(IwadProblemRef ref, String path) =>
    FileProblem.describe(path, noun: 'IWAD');
