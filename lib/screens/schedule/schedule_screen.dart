import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/status_engine.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/admin_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  // The day key currently shown in the list ('M', 'T', ...)
  String _selectedDayKey = TimeUtils.dayKey(DateTime.now());
  static const String _allKey = 'ALL';
  int _headerTapCount = 0;
  bool _showEndOfSemester = false;
  bool _isDeletingSemester = false;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(myBlocksProvider);
    final userAsync = ref.watch(authStateProvider);
    final isMayor = userAsync.valueOrNull?.isMayor ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: Stack(
        children: [
          // Architectural Background Detail (Light)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
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
                _ScheduleHeader(
                  isMayor: isMayor,
                  onTap: () {
                    _headerTapCount++;
                    if (_headerTapCount >= 5 && !_showEndOfSemester) {
                      setState(() => _showEndOfSemester = true);
                    }
                  },
                ),
                
                // Hidden "End of Semester" button (revealed after 5 taps)
                if (_showEndOfSemester && isMayor)
                  _EndOfSemesterBar(
                    isDeleting: _isDeletingSemester,
                    onPressed: () => _handleEndOfSemester(context),
                  ),
                
                // Day-tab row
                _DayTabBar(
                  selected: _selectedDayKey,
                  onSelect: (d) {
                    if (d == _allKey) {
                      context.push('/schedule/weekly');
                    } else {
                      setState(() => _selectedDayKey = d);
                    }
                  },
                ),
                
                // Block list for selected day
                Expanded(
                  child: blocksAsync.when(
                    data: (blocks) {
                      final filtered = blocks
                          .where((b) => b.dayOfWeek == _selectedDayKey)
                          .toList();
                      if (filtered.isEmpty) {
                        return RefreshIndicator(
                          onRefresh: () async {
                            try {
                              await StatusEngine().runOnAppLoad();
                            } catch (_) {}
                          },
                          child: EmptyDay(day: TimeUtils.dayLabel(_selectedDayKey)),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          try {
                            await StatusEngine().runOnAppLoad();
                          } catch (_) {}
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _BlockCard(
                            block: filtered[i],
                            index: i,
                          ),
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isMayor
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton.extended(
                elevation: 4,
                onPressed: () => context.push('/schedule/add'),
                icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                label: const Text(
                  'NEW BLOCK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            )
          : null,
    );
  }

  // ── End of Semester flow ──────────────────────────────────────────

  Future<void> _handleEndOfSemester(BuildContext context) async {
    // Warning 1
    final p1 = await _showSemesterWarning(
      context: context,
      title: 'Delete All Schedules',
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.soon,
      message:
          'You are about to delete all of your schedules for this semester.\n\n'
          'This will remove every class block you\'ve added.',
      confirmLabel: 'PROCEED',
      confirmColor: AppColors.soon,
    );
    if (p1 != true) return;

    // Warning 2
    final p2 = await _showSemesterWarning(
      context: context,
      title: '⚠️  Permanent Deletion',
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange.shade700,
      message:
          'This will permanently delete ALL your schedule blocks.\n\n'
          'Classes, check-ins, and room assignments will be lost.\n\n'
          'Continue?',
      confirmLabel: 'CONTINUE',
      confirmColor: Colors.orange.shade700,
    );
    if (p2 != true) return;

    // Warning 3
    final p3 = await _showSemesterWarning(
      context: context,
      title: '🚨 FINAL WARNING',
      icon: Icons.dangerous_rounded,
      iconColor: Colors.red.shade700,
      message:
          'All of your schedule data for this semester will be permanently '
          'erased.\n\nThis cannot be undone.\n\nAre you absolutely sure?',
      confirmLabel: 'DELETE ALL',
      confirmColor: Colors.red.shade700,
    );
    if (p3 != true) return;

    // Execute
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isDeletingSemester = true);
    try {
      await ref.read(adminServiceProvider).deleteAllMySchedules(user.userId);
      if (mounted) {
        setState(() {
          _isDeletingSemester = false;
          _showEndOfSemester = false;
          _headerTapCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All schedules deleted successfully.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingSemester = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool?> _showSemesterWarning({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBFBFB),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: Colors.black38,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: confirmColor),
              child: Text(
                confirmLabel,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Header ----------

class _ScheduleHeader extends StatelessWidget {
  final bool isMayor;
  final VoidCallback? onTap;
  const _ScheduleHeader({required this.isMayor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY',
              style: GoogleFonts.outfit(
                color: AppColors.primary, 
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'SCHEDULE',
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
      ),
    );
  }
}


class _DayTabBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  static const _days = ['ALL', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  const _DayTabBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Text(
            'TIMELINE',
            style: TextStyle(
              color: Colors.black26,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: _days
                .map((d) => _DayChip(
                      day: d,
                      label: d.toUpperCase(),
                      selected: selected == d,
                      onTap: () => onSelect(d),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  
  const _DayChip({
    required this.day,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : Colors.black.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black45,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Block card ----------

class _BlockCard extends ConsumerStatefulWidget {
  final ScheduleBlockModel block;
  final int index;
  const _BlockCard({required this.block, required this.index});

  @override
  ConsumerState<_BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends ConsumerState<_BlockCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Rebuild every minute so status color/label and canCheckIn stay accurate
    // without refreshing the whole schedule screen.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _statusColor(ScheduleBlockModel block) {
    switch (block.checkInStatus) {
      case CheckInStatus.checkedIn:
        return AppColors.occupied;
      case CheckInStatus.released:
        return Colors.grey;
      case CheckInStatus.noShow:
        return Colors.orange.shade300;
      case CheckInStatus.pending:
        final mins = TimeUtils.minutesUntil(block.startTime);
        if (mins <= 15 && mins >= 0) return AppColors.soon;
        return AppColors.available;
    }
  }

  String _statusLabel(ScheduleBlockModel block) {
    switch (block.checkInStatus) {
      case CheckInStatus.checkedIn:
        return 'Checked In';
      case CheckInStatus.released:
        return 'Released';
      case CheckInStatus.noShow:
        return 'No-show';
      case CheckInStatus.pending:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final canCheckIn = block.checkInStatus == CheckInStatus.pending &&
        TimeUtils.minutesUntil(block.startTime) <= 15;
    final isCheckedIn = block.checkInStatus == CheckInStatus.checkedIn;
    final statusColor = _statusColor(block);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (widget.index * 80).clamp(0, 500)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => context.push('/schedule/checkin/${block.blockId}'),
        onLongPress: () => context.push('/schedule/edit/${block.blockId}'),
        child: Container(
          height: 110,
          child: Stack(
            children: [
              // Main Card Body
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  child: Row(
                    children: [
                      // Time dominant element
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            TimeUtils.toDisplayTime(block.startTime),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'UNLESS RELEASED',
                            style: TextStyle(
                              color: AppColors.primary.withOpacity(0.6),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      // Divider
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.black.withOpacity(0.05),
                      ),
                      const SizedBox(width: 20),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              block.subject.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'ROOM ${block.roomId} · ${block.instructor}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      // Status & Actions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (block.checkInStatus != CheckInStatus.pending)
                            _StatusBadge(
                              label: _statusLabel(block).toUpperCase(),
                              color: statusColor,
                            ),
                          if (canCheckIn || isCheckedIn) ...[
                            const SizedBox(height: 8),
                            _ActionTileButton(
                              label: isCheckedIn ? 'RELEASE' : 'CHECK IN',
                              color: isCheckedIn ? Colors.red.shade400 : AppColors.primary,
                              onTap: () => context.push('/schedule/checkin/${block.blockId}'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Accent L-shape detail
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 24,
                  height: 2,
                  color: block.hasConflict ? Colors.red.withOpacity(0.6) : statusColor.withOpacity(0.4),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 2,
                  height: 24,
                  color: block.hasConflict ? Colors.red.withOpacity(0.6) : statusColor.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ActionTileButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTileButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ---------- Empty state ----------

class EmptyDay extends StatelessWidget {
  final String day;
  const EmptyDay({required this.day, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 80, color: Colors.black.withOpacity(0.04)),
          const SizedBox(height: 20),
          Text(
            'YOUR SCHEDULE IS EMPTY',
            style: TextStyle(
              color: Colors.black.withOpacity(0.12),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Plan your semester by adding your first class block.'.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.08),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- End of Semester bar (hidden, revealed after 5 taps) ----------

class _EndOfSemesterBar extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onPressed;

  const _EndOfSemesterBar({
    required this.isDeleting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade700.withOpacity(0.06),
          border: Border.all(color: Colors.red.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.delete_sweep_outlined,
              color: Colors.red.shade400,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'END OF SEMESTER',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            if (isDeleting)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red.shade400,
                ),
              )
            else
              GestureDetector(
                onTap: onPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                  ),
                  child: const Text(
                    'DELETE ALL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
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

