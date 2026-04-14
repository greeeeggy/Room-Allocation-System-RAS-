import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

/// Bottom navigation shell wrapping the five main branches:
/// Dashboard (0), Schedule (1), Floor Map (2), Search (3),
/// Notifications (4), Directory (5).
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    // Only subscribe to unread count when there is a logged-in user.
    final unreadAsync = user != null
        ? ref.watch(unreadCountProvider)
        : const AsyncData<int>(0);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(user?.isCouncilPresident == true
                ? Icons.people_outline
                : Icons.calendar_today_outlined),
            selectedIcon: Icon(user?.isCouncilPresident == true
                ? Icons.people
                : Icons.calendar_today),
            label: user?.isCouncilPresident == true ? 'Mayors' : 'Schedule',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: _BellIcon(count: unreadCount, selected: false),
            selectedIcon: _BellIcon(count: unreadCount, selected: true),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Directory',
          ),
        ],
      ),
    );
  }
}

/// Bell icon with an unread badge overlay.
class _BellIcon extends StatelessWidget {
  final int count;
  final bool selected;
  const _BellIcon({required this.count, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(selected
            ? Icons.notifications
            : Icons.notifications_none_outlined),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints:
                  const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
