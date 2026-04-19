import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/status_engine.dart';
import '../../providers/schedule_provider.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  // The day key currently shown in the list ('M', 'T', ...)
  String _selectedDayKey = TimeUtils.dayKey(DateTime.now());

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(myBlocksProvider);
    final userAsync = ref.watch(authStateProvider);
    final isMayor = userAsync.valueOrNull?.isMayor ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          if (isMayor)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Block',
              onPressed: () => context.push('/schedule/add'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Day-tab row
          _DayTabBar(
            selected: _selectedDayKey,
            onSelect: (d) => setState(() => _selectedDayKey = d),
          ),
          const Divider(height: 1),

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
                    child: _EmptyDay(day: TimeUtils.dayLabel(_selectedDayKey)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await StatusEngine().runOnAppLoad();
                    } catch (_) {}
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BlockCard(block: filtered[i]),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: isMayor
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/schedule/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Block'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

// ---------- Day tab bar ----------

class _DayTabBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  const _DayTabBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _days
            .map((d) => _DayChip(
                  day: d,
                  label: _shortLabel(d),
                  selected: selected == d,
                  onTap: () => onSelect(d),
                ))
            .toList(),
      ),
    );
  }

  String _shortLabel(String key) {
    return key; // Keys are now already 'Sun', 'Mon', etc.
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip(
      {required this.day,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
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
  const _BlockCard({required this.block});

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

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: block.hasConflict
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // When checked in, go to the check-in screen (which shows the Release button).
        // Otherwise go to the edit screen.
        onTap: () => context.push('/schedule/checkin/${block.blockId}'),
        onLongPress: () => context.push('/schedule/edit/${block.blockId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status indicator bar
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: _statusColor(block),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Block info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(block.subject,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                        if (block.hasConflict)
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 18),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${block.roomId}  ·  ${block.instructor}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${TimeUtils.toDisplayTime(block.startTime)} – ${TimeUtils.toDisplayTime(block.endTime)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Status badge + check-in button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(block).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _statusLabel(block),
                      style: TextStyle(
                          color: _statusColor(block),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (canCheckIn) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () =>
                          context.push('/schedule/checkin/${block.blockId}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Check In',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  if (isCheckedIn) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () =>
                          context.push('/schedule/checkin/${block.blockId}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          'Release',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Empty state ----------

class _EmptyDay extends StatelessWidget {
  final String day;
  const _EmptyDay({required this.day});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_available_outlined,
                  size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No classes on $day',
                  style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Tap + to add a schedule block.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
