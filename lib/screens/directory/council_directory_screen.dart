import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../services/council_service.dart';

// Provider
final _councilServiceProvider = Provider<CouncilService>((ref) => CouncilService());

final _usersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(_councilServiceProvider).getUsersStream().handleError((error) {
    debugPrint('CouncilDirectory Error: $error');
    throw error;
  });
});

class CouncilDirectoryScreen extends ConsumerStatefulWidget {
  const CouncilDirectoryScreen({super.key});

  @override
  ConsumerState<CouncilDirectoryScreen> createState() => _CouncilDirectoryScreenState();
}

class _CouncilDirectoryScreenState extends ConsumerState<CouncilDirectoryScreen> {
  String _selectedDept = 'All';

  static const _deptFilters = [
    'All',
    'Eng Council',
    'BSIE',
    'BSASE',
    'BSEE',
    'BSECE',
    'BSME',
    'BSCpE',
    'BSCE',
  ];

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_usersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: Stack(
        children: [
          // Architectural Background Details
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetropolisHeader(),
                
                // Filter Console
                _MetropolisFilterConsole(
                  selected: _selectedDept,
                  options: _deptFilters,
                  onSelect: (d) => setState(() => _selectedDept = d),
                ),

                Expanded(
                  child: usersAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) {
                      if (e.toString().contains('permission-denied')) {
                        return const _ArchitectErrorState(
                          title: 'ACCESS RESTRICTED',
                          message: 'COUNCIL CLEARANCE REQUIRED FOR DIRECTORY ACCESS.',
                          icon: Icons.lock_outline_rounded,
                        );
                      }
                      return Center(child: Text('Error: $e'));
                    },
                    data: (users) {
                      final filtered = _selectedDept == 'All'
                          ? users
                          : users.where((u) => 
                              Departments.getAbbreviation(u.department) == 
                              Departments.getAbbreviation(_selectedDept)).toList();

                      if (filtered.isEmpty) {
                        return _ArchitectEmptyState(dept: _selectedDept);
                      }

                      // Group by department
                      final grouped = <String, List<UserModel>>{};
                      for (final u in filtered) {
                        grouped.putIfAbsent(u.department, () => []).add(u);
                      }

                      final sortedKeys = grouped.keys.toList()
                        ..sort((a, b) {
                          final abbs = Departments.allAbbreviations;
                          final ai = abbs.indexOf(a);
                          final bi = abbs.indexOf(b);
                          return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
                        });

                      return RefreshIndicator(
                        onRefresh: () async => ref.refresh(_usersProvider),
                        color: AppColors.primary,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            for (final dept in sortedKeys) ...[
                              _DepartmentSliverHeader(dept: dept),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final deptUsers = grouped[dept]!;
                                      // Sort within department
                                      deptUsers.sort((a, b) {
                                        // EC President first, then council presidents, then mayors
                                        int roleOrder(UserModel u) {
                                          if (u.isEngineeringCouncilPresident) return 0;
                                          if (u.isCouncilPresident) return 1;
                                          return 2;
                                        }
                                        final rCmp = roleOrder(a).compareTo(roleOrder(b));
                                        if (rCmp != 0) return rCmp;
                                        if (a.isMayor && b.isMayor) {
                                          return (a.courseSection ?? '').compareTo(b.courseSection ?? '');
                                        }
                                        return a.name.compareTo(b.name);
                                      });
                                      return _ArchitectUserTile(user: deptUsers[index], index: index);
                                    },
                                    childCount: grouped[dept]!.length,
                                  ),
                                ),
                              ),
                            ],
                            const SliverToBoxAdapter(child: SizedBox(height: 120)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _MetropolisHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COUNCIL',
            style: GoogleFonts.outfit(
              color: AppColors.accent.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'DIRECTORY',
            style: GoogleFonts.outfit(
              color: const Color(0xFF1A1A1A),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetropolisFilterConsole extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _MetropolisFilterConsole({
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Text(
            'CATEGORIES',
            style: GoogleFonts.outfit(
              color: Colors.black26,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: options.length,
            itemBuilder: (context, i) {
              final opt = options[i];
              final isSel = selected == opt;
              return GestureDetector(
                onTap: () => onSelect(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6, bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.accent : Colors.white,
                    border: Border.all(
                      color: isSel ? AppColors.accent : Colors.black.withOpacity(0.06),
                      width: 1,
                    ),
                    boxShadow: isSel ? [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ] : null,
                  ),
                  child: Center(
                    child: Text(
                      opt.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: isSel ? Colors.white : Colors.black45,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _DepartmentSliverHeader extends StatelessWidget {
  final String dept;
  const _DepartmentSliverHeader({required this.dept});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Row(
          children: [
            Text(
              Departments.getAbbreviation(dept).toUpperCase(),
              style: GoogleFonts.outfit(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchitectUserTile extends StatelessWidget {
  final UserModel user;
  final int index;

  const _ArchitectUserTile({required this.user, required this.index});

  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    final String position = user.isEngineeringCouncilPresident
        ? 'EC PRESIDENT'
        : user.isCouncilPresident
            ? 'PRESIDENT'
            : 'MAYOR · ${user.courseSection ?? "N/A"}';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 500)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(10 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 70,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Badge-style Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          position,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.black26,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (user.isCouncilPresident || user.isEngineeringCouncilPresident)
                    Icon(
                      user.isEngineeringCouncilPresident
                          ? Icons.shield_rounded
                          : Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                ],
              ),
            ),
            // L-shape Detail
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 2,
                color: AppColors.accent.withOpacity(0.3),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 2,
                height: 12,
                color: AppColors.accent.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchitectEmptyState extends StatelessWidget {
  final String dept;
  const _ArchitectEmptyState({required this.dept});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 80, color: Colors.black.withOpacity(0.04)),
          const SizedBox(height: 20),
          Text(
            'DIRECTORY EMPTY',
            style: GoogleFonts.outfit(
              color: Colors.black.withOpacity(0.12),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NO REGISTRATIONS FOR $dept'.toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.black.withOpacity(0.08),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchitectErrorState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _ArchitectErrorState({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black26,
              height: 1.5,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

