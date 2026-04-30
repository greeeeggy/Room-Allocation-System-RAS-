import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../core/theme.dart';

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final unreadAsync = user != null
        ? ref.watch(unreadCountProvider)
        : const AsyncValue.data(0);
    final unreadCount = unreadAsync.valueOrNull ?? 0;
    final isECPresident = user?.isEngineeringCouncilPresident ?? false;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // The main content area
          Positioned.fill(
            child: navigationShell,
          ),
          
          // Floating Nav Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: _GlassFloatingNavbar(
                navigationShell: navigationShell,
                unreadCount: unreadCount,
                isCouncilPresident: user?.isCouncilPresident ?? false,
                isECPresident: isECPresident,
                isAdmin: isAdmin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassFloatingNavbar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final int unreadCount;
  final bool isCouncilPresident;
  final bool isECPresident;
  final bool isAdmin;

  const _GlassFloatingNavbar({
    required this.navigationShell,
    required this.unreadCount,
    required this.isCouncilPresident,
    this.isECPresident = false,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = totalWidth / 5;
        final activeIndex = navigationShell.currentIndex;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              // Subtle Elevation Shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.glassBackground.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(32),
                  // The "Sharp Outline"
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                children: [
                  // Sliding Indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    left: (activeIndex * itemWidth) + (itemWidth - 60) / 2-1.5,
                    top: 10,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Navbar Items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StylishNavbarItem(
                        icon: Icons.travel_explore_rounded,
                        label: 'Search',
                        isSelected: activeIndex == 0,
                        onTap: () => _onTap(0),
                      ),
                      _StylishNavbarItem(
                        icon: isAdmin
                            ? Icons.bug_report_rounded
                            : isECPresident
                                ? Icons.restart_alt_rounded
                                : isCouncilPresident
                                    ? Icons.groups_rounded
                                    : Icons.event_available_rounded,
                        label: isAdmin
                            ? 'Bugs'
                            : isECPresident
                                ? 'Reset'
                                : isCouncilPresident
                                    ? 'Mayors'
                                    : 'Schedule',
                        isSelected: activeIndex == 1,
                        onTap: () => _onTap(1),
                      ),
                      // Dashboard (Center)
                      _StylishNavbarItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Home',
                        isSelected: activeIndex == 2,
                        isCenter: true,
                        onTap: () => _onTap(2),
                      ),
                      _StylishNavbarItem(
                        icon: Icons.notifications_active_rounded,
                        label: 'Alerts',
                        isSelected: activeIndex == 3,
                        unreadCount: unreadCount,
                        onTap: () => _onTap(3),
                      ),
                      _StylishNavbarItem(
                        icon: Icons.contact_mail_rounded,
                        label: 'Directory',
                        isSelected: activeIndex == 4,
                        onTap: () => _onTap(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _StylishNavbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int unreadCount;
  final bool isCenter;

  const _StylishNavbarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.unreadCount = 0,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeTextColor = Colors.white;
    final inactiveColor = AppColors.textSecondary.withOpacity(0.7);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? activeTextColor : inactiveColor,
                  size: isCenter ? 30 : 26,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeTextColor : inactiveColor,
                fontSize: label == 'Directory' ? 8.5 : 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
