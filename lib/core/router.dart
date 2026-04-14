import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/schedule/add_block_screen.dart';
import '../screens/schedule/edit_block_screen.dart';
import '../screens/checkin/checkin_screen.dart';
import '../screens/rooms/room_detail_screen.dart';
import '../screens/rooms/room_search_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/directory/council_directory_screen.dart';
import '../screens/main_shell.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/mayors/mayor_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final isLoggedIn = authAsync.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // ── Auth routes (outside the shell) ──────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // ── Main shell with bottom nav ────────────────────────────────
      // Branches: 0=Dashboard, 1=Schedule, 2=Map, 3=Search,
      //           4=Notifications, 5=Directory
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // ── Branch 0 — Dashboard ────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'room/:roomId',
                    builder: (_, state) => RoomDetailScreen(
                        roomId: state.pathParameters['roomId']!),
                  ),
                  GoRoute(
                    path: 'checkin/:blockId',
                    builder: (_, state) => CheckInScreen(
                        blockId: state.pathParameters['blockId']!),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, __) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),

          // ── Branch 1 — Schedule ─────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) {
                  final user = ref.watch(authStateProvider).valueOrNull;
                  if (user?.isCouncilPresident == true) {
                    return const MayorManagementScreen();
                  }
                  return const ScheduleScreen();
                },
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (_, __) => const AddBlockScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:blockId',
                    builder: (_, state) => EditBlockScreen(
                        blockId: state.pathParameters['blockId']!),
                  ),
                  GoRoute(
                    path: 'checkin/:blockId',
                    builder: (_, state) => CheckInScreen(
                        blockId: state.pathParameters['blockId']!),
                  ),
                ],
              ),
            ],
          ),


          // ── Branch 3 — Room Search ──────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, __) => const RoomSearchScreen(),
                routes: [
                  GoRoute(
                    path: 'room/:roomId',
                    builder: (_, state) => RoomDetailScreen(
                        roomId: state.pathParameters['roomId']!),
                  ),
                ],
              ),
            ],
          ),

          // ── Branch 4 — Notifications ────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (_, __) => const NotificationScreen(),
              ),
            ],
          ),

          // ── Branch 5 — Council Directory ────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/directory',
                builder: (_, __) => const CouncilDirectoryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// A Listenable that notifies its listeners (GoRouter) whenever
/// authStateProvider changes.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    _subscription = ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
