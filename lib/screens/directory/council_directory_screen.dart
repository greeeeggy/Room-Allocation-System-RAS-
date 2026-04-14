import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../services/council_service.dart';

// Provider
final _councilServiceProvider =
    Provider<CouncilService>((ref) => CouncilService());

final _usersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref
      .watch(_councilServiceProvider)
      .getUsersStream()
      .handleError((error) {
    debugPrint('CouncilDirectory Error: $error');
    throw error;
  });
});

class CouncilDirectoryScreen extends ConsumerStatefulWidget {
  const CouncilDirectoryScreen({super.key});

  @override
  ConsumerState<CouncilDirectoryScreen> createState() =>
      _CouncilDirectoryScreenState();
}

class _CouncilDirectoryScreenState
    extends ConsumerState<CouncilDirectoryScreen> {
  String _selectedDept = 'All';

  static const _deptFilters = [
    'All',
    ...Departments.all,
  ];

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Council Directory'),
      ),
      body: Column(
        children: [
          // ── Department filter tabs ──────────────────────────────────
          _DeptFilterBar(
            selected: _selectedDept,
            depts: _deptFilters,
            onSelect: (d) => setState(() => _selectedDept = d),
          ),
          const Divider(height: 1),

          // ── User list ───────────────────────────────────────────────
          Expanded(
            child: usersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                final errorStr = e.toString();
                if (errorStr.contains('permission-denied') ||
                    errorStr.contains('PERMISSION_DENIED')) {
                  return const _ErrorState(
                    title: 'Access Denied',
                    message:
                        'You do not have permission to view the directory. Please check your system configuration.',
                    icon: Icons.lock_person_outlined,
                  );
                }
                return Center(child: Text('Error: $e'));
              },
              data: (users) {
                final filtered = _selectedDept == 'All'
                    ? users
                    : users
                        .where((u) => u.department == _selectedDept)
                        .toList();

                if (filtered.isEmpty) {
                  return _EmptyState(dept: _selectedDept);
                }

                // Group by department
                final grouped = <String, List<UserModel>>{};
                for (final u in filtered) {
                  grouped.putIfAbsent(u.department, () => []).add(u);
                }

                // Sort departments
                final sortedKeys = grouped.keys.toList()
                  ..sort((a, b) {
                    final ai = Departments.all.indexOf(a);
                    final bi = Departments.all.indexOf(b);
                    return (ai == -1 ? 999 : ai)
                        .compareTo(bi == -1 ? 999 : bi);
                  });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: sortedKeys.length,
                  itemBuilder: (_, i) {
                    final dept = sortedKeys[i];
                    final deptUsers = grouped[dept]!;

                    // Sort within department: Presidents first, then Mayors by section
                    deptUsers.sort((a, b) {
                      if (a.isCouncilPresident && b.isMayor) return -1;
                      if (a.isMayor && b.isCouncilPresident) return 1;
                      if (a.isMayor && b.isMayor) {
                        return (a.courseSection ?? '')
                            .compareTo(b.courseSection ?? '');
                      }
                      return a.name.compareTo(b.name);
                    });

                    return _DepartmentSection(
                        dept: dept, users: deptUsers);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Department section ----------

class _DepartmentSection extends StatelessWidget {
  final String dept;
  final List<UserModel> users;
  const _DepartmentSection({required this.dept, required this.users});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            dept,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: users
                .map((u) => _UserTile(user: u))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------- User tile ----------

class _UserTile extends StatelessWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = user.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    final String position = user.isCouncilPresident
        ? 'Council President ($initials)'
        : 'Mayor - ${user.courseSection ?? "No Section"}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.15),
        child: Text(
          initials,
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ),
      title: Text(user.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(position,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12)),
      trailing: user.isCouncilPresident
          ? const Icon(Icons.verified_user, size: 18, color: AppColors.primary)
          : null,
      dense: true,
    );
  }
}

// ---------- Dept filter bar ----------

class _DeptFilterBar extends StatelessWidget {
  final String selected;
  final List<String> depts;
  final ValueChanged<String> onSelect;
  const _DeptFilterBar(
      {required this.selected,
      required this.depts,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: depts
            .map((d) => _FilterChip(
                  label: d,
                  selected: selected == d,
                  onTap: () => onSelect(d),
                ))
            .toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              )),
        ),
      ),
    );
  }
}

// ---------- Empty state ----------

class _EmptyState extends StatelessWidget {
  final String dept;
  const _EmptyState({required this.dept});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            dept == 'All'
                ? 'No users registered yet.'
                : 'No registered users for $dept.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ---------- Error state ----------

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _ErrorState({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
