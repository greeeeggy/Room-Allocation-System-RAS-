import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/schedule_provider.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  final String blockId;
  const CheckInScreen({super.key, required this.blockId});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  bool _loading = false;
  // null = not yet attempted, empty = success, non-empty = conflict section name
  String? _conflictSection;
  bool _checkedIn = false;

  Future<void> _attemptCheckIn(ScheduleBlockModel block) async {
    setState(() => _loading = true);

    final user = ref.read(authStateProvider).valueOrNull;

    final conflictSection = await ref
        .read(scheduleServiceProvider)
        .attemptCheckIn(
          blockId: block.blockId,
          roomId: block.roomId,
          mayorId: user?.userId ?? '',
          mayorName: user?.name ?? '',
          mayorSection: user?.courseSection ?? block.courseSection,
          mayorDepartment: user?.department ?? '',
        );

    setState(() {
      _loading = false;
      if (conflictSection != null) {
        _conflictSection = conflictSection;
      } else {
        _checkedIn = true;
      }
    });
  }

  Future<void> _releaseRoom(ScheduleBlockModel block) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release Room Early?'),
        content: Text(
            'This will free ${block.roomId} before the scheduled end time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Release')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _loading = true);
    await ref.read(scheduleServiceProvider).releaseRoom(
          blockId: block.blockId,
          roomId: block.roomId,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(myBlocksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Check In')),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (blocks) {
          final block = blocks
              .where((b) => b.blockId == widget.blockId)
              .firstOrNull;

          if (block == null) {
            return const Center(child: Text('Block not found.'));
          }

          // Already checked in — show release option
          if (block.checkInStatus == CheckInStatus.checkedIn || _checkedIn) {
            // Find which room we are ACTUALLY in (for borrowed rooms)
            final rooms = ref.watch(allRoomsProvider).valueOrNull ?? [];
            final actualRoom = rooms
                .where((r) => r.currentOccupantBlockId == block.blockId)
                .firstOrNull;
            final roomDisplay = actualRoom?.roomNumber ?? block.roomId;

            return _CheckedInView(
              block: block,
              actualRoomDisplay: roomDisplay,
              loading: _loading,
              onRelease: () => _releaseRoom(block),
            );
          }

          final minutesUntil = TimeUtils.minutesUntil(block.startTime);
          final canCheckIn = block.checkInStatus == CheckInStatus.pending &&
              minutesUntil <= 15;

          return _PendingView(
            block: block,
            minutesUntil: minutesUntil,
            canCheckIn: canCheckIn,
            loading: _loading,
            conflictSection: _conflictSection,
            onCheckIn: canCheckIn && !_loading ? () => _attemptCheckIn(block) : null,
            onNoClass: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm No Class'),
                  content: const Text(
                      'Are you sure you want to mark this schedule as "No Class"? This will make the room available for others today.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Mark No Class')),
                  ],
                ),
              );
              if (confirm == true) {
                setState(() => _loading = true);
                await ref
                    .read(scheduleServiceProvider)
                    .markNoClassToday(block.blockId);
                if (mounted) {
                  setState(() => _loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scheduled marked as "No Class".')),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }
}

// ---------- Pending / pre-check-in view ----------

class _PendingView extends StatelessWidget {
  final ScheduleBlockModel block;
  final int minutesUntil;
  final bool canCheckIn;
  final bool loading;
  final String? conflictSection;
  final VoidCallback? onCheckIn;
  final VoidCallback? onNoClass;

  const _PendingView({
    required this.block,
    required this.minutesUntil,
    required this.canCheckIn,
    required this.loading,
    required this.conflictSection,
    required this.onCheckIn,
    required this.onNoClass,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block summary card
          _BlockSummaryCard(block: block),
          const SizedBox(height: 24),

          // Conflict warning
          if (conflictSection != null)
            _ConflictWarning(section: conflictSection!),

          if (conflictSection == null) ...[
            // Availability indicator
            if (!canCheckIn)
              _InfoBanner(
                icon: Icons.schedule,
                color: Colors.blue.shade700,
                message: minutesUntil > 0
                    ? 'Check-in opens 15 minutes before start time. ($minutesUntil min remaining)'
                    : 'This block has already passed.',
              ),

            const SizedBox(height: 24),

            // Check-in button
            Consumer(builder: (context, ref, child) {
              final rooms = ref.watch(allRoomsProvider).valueOrNull ?? [];
              final room = rooms.where((r) => r.roomId == block.roomId).firstOrNull;
              final isOccupied = room?.status == RoomStatus.occupied;
              final isToday = block.dayOfWeek == TimeUtils.dayKey(DateTime.now());
              final isCancelled = block.noClassDate == TimeUtils.todayDateKey();

              final actualCanCheckIn = canCheckIn && isToday && !isOccupied && !isCancelled;

              String? disableReason;
              if (!isToday) {
                disableReason = 'This schedule is not for today (${block.dayOfWeek}).';
              } else if (isCancelled) {
                disableReason = 'You marked this schedule as "No Class" today.';
              } else if (minutesUntil > 15) {
                disableReason = 'Check-in opens 15 minutes before start time.';
              } else if (isOccupied) {
                disableReason = 'Room is currently occupied by someone else.';
              }

              return Column(
                children: [
                  if (disableReason != null && !loading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _InfoBanner(
                        icon: Icons.info_outline,
                        color: Colors.orange.shade700,
                        message: disableReason,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: Text(loading ? 'Checking in...' : 'Check In Now'),
                      onPressed: actualCanCheckIn && !loading ? onCheckIn : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actualCanCheckIn ? AppColors.primary : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),

            // No Class button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_busy, color: Colors.orange),
                label: const Text('No Class Today', style: TextStyle(color: Colors.orange)),
                onPressed: loading ? null : onNoClass,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- Checked-in view ----------

class _CheckedInView extends StatelessWidget {
  final ScheduleBlockModel block;
  final String actualRoomDisplay;
  final bool loading;
  final VoidCallback onRelease;

  const _CheckedInView({
    required this.block,
    required this.actualRoomDisplay,
    required this.loading,
    required this.onRelease,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success banner
          _InfoBanner(
            icon: Icons.check_circle_outline,
            color: Colors.green.shade700,
            message:
                'You are checked in to Room $actualRoomDisplay. Room is marked occupied.',
          ),
          const SizedBox(height: 20),

          _BlockSummaryCard(block: block),
          const SizedBox(height: 32),

          // Auto-release info
          Text(
            'Room auto-releases at ${TimeUtils.toDisplayTime(block.endTime)}.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Early release button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.logout, color: Colors.red),
              label: const Text('Release Room Early',
                  style: TextStyle(color: Colors.red)),
              onPressed: loading ? null : onRelease,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Shared widgets ----------

class _BlockSummaryCard extends StatelessWidget {
  final ScheduleBlockModel block;
  const _BlockSummaryCard({required this.block});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.subject,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            _Row(icon: Icons.meeting_room_outlined, label: 'Room ${block.roomId}'),
            _Row(icon: Icons.person_outlined, label: block.instructor),
            _Row(
                icon: Icons.access_time,
                label:
                    '${TimeUtils.toDisplayTime(block.startTime)} – ${TimeUtils.toDisplayTime(block.endTime)}'),
            _Row(icon: Icons.group_outlined, label: block.courseSection),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Row({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _InfoBanner(
      {required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ConflictWarning extends StatelessWidget {
  final String section;
  const _ConflictWarning({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 22),
              const SizedBox(width: 8),
              Text('Room Conflict Detected',
                  style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This room is currently claimed by the class mayor of $section. '
            'Please coordinate with them or update your block to a different room.',
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            'Your department council president has been notified.',
            style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
