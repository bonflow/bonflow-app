import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/login/presentation/login_screen.dart';
import 'features/menu/presentation/menu_screen.dart';
import 'features/order/presentation/order_screen.dart';
import 'features/tables/presentation/tables_screen.dart';

/// App routes. An auth redirect (token present?) is added together with the login feature.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/tables', builder: (_, __) => const TablesScreen()),
      GoRoute(
        path: '/tables/:tableId/order',
        builder: (_, state) =>
            OrderScreen(tableId: state.pathParameters['tableId']!),
        routes: [
          GoRoute(path: 'menu', builder: (_, __) => const MenuScreen()),
        ],
      ),
    ],
  );
});
