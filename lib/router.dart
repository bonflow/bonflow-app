import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/auth/application/session_controller.dart';
import 'features/login/presentation/login_screen.dart';
import 'features/menu/presentation/menu_screen.dart';
import 'features/order/presentation/order_screen.dart';
import 'features/tables/presentation/tables_screen.dart';

/// App routes. Without a session everything leads to the login; with one, the login leads on
/// to the tables. While the stored session is still being read, a splash screen is shown.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;
      if (session.restoring) {
        return location == '/splash' ? null : '/splash';
      }
      if (!session.loggedIn) {
        return location == '/login' ? null : '/login';
      }
      return location == '/login' || location == '/splash' ? '/tables' : null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/tables', builder: (_, _) => const TablesScreen()),
      GoRoute(
        path: '/tables/:tableId/order',
        builder: (_, state) =>
            OrderScreen(tableId: state.pathParameters['tableId']!),
        routes: [
          GoRoute(path: 'menu', builder: (_, _) => const MenuScreen()),
        ],
      ),
    ],
  );
});
