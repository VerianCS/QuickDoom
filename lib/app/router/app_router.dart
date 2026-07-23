import 'package:go_router/go_router.dart';

import '../../features/main/presentation/screens/main_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'main',
      builder: (context, state) => const MainScreen(),
    ),
  ],
);
