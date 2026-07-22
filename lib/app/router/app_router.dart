import 'package:go_router/go_router.dart';

import '../../features/launcher/presentation/screens/launcher_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'launcher',
      builder: (context, state) => const LauncherScreen(),
    ),
  ],
);
