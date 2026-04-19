import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../models/room_model.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/room_usage_log_provider.dart';
import '../../providers/schedule_provider.dart';
import 'room_schedule_screen.dart';
import 'room_usage_log_screen.dart';

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(allRoomsProvider);
    final todayKey = TimeUtils.dayKey(DateTime.now());
    final todayBlocksAsync = ref.watch(roomTodayBlocksProvider(roomId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Usage Log',
            onPressed: () {
              // Determine room number from the rooms data
              final rooms = ref.read(allRoomsProvider).valueOrNull ?? [];
              final room = rooms.where((r) => r.roomId == roomId).firstOrNull;
              final roomNumber = room?.roomNumber ?? roomId;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomUsageLogScreen(
                    roomId: roomId,
                    roomNumber: roomNumber,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rooms) {
          final room = rooms.where((r) => r.roomId == roomId).firstOrNull;
          if (room == null) {
            return const Center(child: Text('Room not found.'));
          }
          return _RoomDetailBody(
              room: room, todayBlocksAsync: todayBlocksAsync, roomId: roomId);
        },
      ),
    );
  }
}

class _RoomDetailBody extends ConsumerWidget {
  final RoomModel room;
  final AsyncValue<List<ScheduleBlockModel>> todayBlocksAsync;
  final String roomId;

  const _RoomDetailBody(
      {required this.room, required this.todayBlocksAsync, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isMayor = user?.isMayor == true;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Room header card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room ${room.roomNumber}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Floor ${room.floor}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _RoomStatusBadge(room: room),
        const SizedBox(height: 24),

        // Features
        const Text('Features',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        room.features.isEmpty
            ? const Text('No listed features.',
                style: TextStyle(color: AppColors.textSecondary))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: room.features
                    .map((f) => Chip(
                          label: Text(_featureLabel(f)),
                          avatar: Icon(_featureIcon(f), size: 16),
                          backgroundColor: Colors.grey.shade100,
                        ))
                    .toList(),
              ),
        const SizedBox(height: 24),

        // Today's schedule
        const Text("Today's Schedule",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        todayBlocksAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (blocks) {
            if (blocks.isEmpty) {
              return const _EmptySchedule();
            }
            return Column(
              children: blocks
                  .map((b) => _TodayBlockTile(block: b))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 32),

        // All Schedules button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RoomScheduleScreen(
                  roomId: roomId,
                  roomNumber: room.roomNumber,
                ),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('All Schedules for this Room'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Use This Room button — visible to mayors only if room is available or noClass (cancelled)
        if (isMayor && (room.status == RoomStatus.available || room.status == RoomStatus.noClass))
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showBorrowSheet(context, ref),
              icon: const Icon(Icons.meeting_room),
              label: const Text('Use This Room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  void _showBorrowSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final now = DateTime.now();
    final dayFull = TimeUtils.dayLabel(TimeUtils.dayKey(now));
    final mayorName = user.name;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _BorrowForm(
          roomId: roomId,
          roomNumber: room.roomNumber,
          mayorId: user.userId,
          mayorName: mayorName,
          dayOfWeek: dayFull,
        );
      },
    );
  }

  String _featureLabel(String f) {
    const m = {
      'tv': 'TV',
      'whiteboard': 'Whiteboard',
      'blackboard': 'Blackboard',
      'aircon': 'Air Conditioning',
      'projector': 'Projector',
    };
    return m[f] ?? f;
  }

  IconData _featureIcon(String f) {
    switch (f) {
      case 'tv':
        return Icons.tv;
      case 'whiteboard':
      case 'blackboard':
        return Icons.square_outlined;
      case 'aircon':
        return Icons.ac_unit;
      case 'projector':
        return Icons.slideshow_outlined;
      default:
        return Icons.check;
    }
  }
}

// ---------- Borrow Form Bottom Sheet ----------

class _BorrowForm extends ConsumerStatefulWidget {
  final String roomId;
  final String roomNumber;
  final String mayorId;
  final String mayorName;
  final String dayOfWeek;

  const _BorrowForm({
    required this.roomId,
    required this.roomNumber,
    required this.mayorId,
    required this.mayorName,
    required this.dayOfWeek,
  });

  @override
  ConsumerState<_BorrowForm> createState() => _BorrowFormState();
}

class _BorrowFormState extends ConsumerState<_BorrowForm> {
  String? _selectedBlockId;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selectedBlockId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a schedule.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final error = await ref.read(scheduleServiceProvider).borrowCheckIn(
            blockId: _selectedBlockId!,
            borrowedRoomId: widget.roomId,
            mayorId: widget.mayorId,
            mayorName: widget.mayorName,
          );

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Checked in to Room ${widget.roomNumber} successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(myBlocksProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Use This Room',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select one of your schedules to check in',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Auto-detected info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.person, label: widget.mayorName),
                _InfoChip(
                    icon: Icons.calendar_today, label: widget.dayOfWeek),
                _InfoChip(
                    icon: Icons.meeting_room,
                    label: 'Room ${widget.roomNumber}'),
              ],
            ),
            const SizedBox(height: 20),

            // Schedule block dropdown
            blocksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading schedules: $e'),
              data: (blocks) {
                // Show only pending or released blocks (not already checked in)
                final available = blocks
                    .where((b) =>
                        b.checkInStatus == CheckInStatus.pending ||
                        b.checkInStatus == CheckInStatus.released ||
                        b.checkInStatus == CheckInStatus.noShow)
                    .toList();

                if (available.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No available schedules. All your blocks are currently checked in or you have no schedules.',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_selectedBlockId != null &&
                    !available.any((b) => b.blockId == _selectedBlockId)) {
                  _selectedBlockId = null;
                }

                return DropdownButtonFormField<String>(
                  value: _selectedBlockId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.schedule_outlined),
                    labelText: 'Select Schedule',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: available
                      .map((b) => DropdownMenuItem(
                            value: b.blockId,
                            child: Text(
                              '${b.subject} · ${TimeUtils.toDisplayTime(b.startTime)}-${TimeUtils.toDisplayTime(b.endTime)} (${b.dayOfWeek})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedBlockId = v),
                );
              },
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.login),
                label:
                    Text(_submitting ? 'Checking in...' : 'Check In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ---------- Existing widgets below ----------

class _TodayBlockTile extends StatelessWidget {
  final ScheduleBlockModel block;
  const _TodayBlockTile({required this.block});

  @override
  Widget build(BuildContext context) {
    final isActive = TimeUtils.isNowBetween(block.startTime, block.endTime);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.occupied.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isActive
                ? AppColors.occupied.withOpacity(0.4)
                : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${TimeUtils.toDisplayTime(block.startTime)} – ${TimeUtils.toDisplayTime(block.endTime)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.occupied : AppColors.textPrimary,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.subject,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(block.courseSection,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.occupied,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Now',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.available.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.available.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.available),
          SizedBox(width: 10),
          Expanded(
            child: Text('No classes scheduled today — room is free.',
                style: TextStyle(color: AppColors.available)),
          ),
        ],
      ),
    );
  }
}

class _RoomStatusBadge extends ConsumerWidget {
  final RoomModel room;
  const _RoomStatusBadge({required this.room});

  Color _statusColor(RoomStatus s) {
    switch (s) {
      case RoomStatus.occupied:
        return AppColors.occupied;
      case RoomStatus.soon:
        return AppColors.soon;
      case RoomStatus.available:
        return AppColors.available;
      case RoomStatus.noClass:
        return Colors.blue.shade300; // Distinct color for no class
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (room.status == RoomStatus.available || room.currentOccupantBlockId == null) {
      String label = 'Available';
      if (room.status == RoomStatus.occupied) label = 'Occupied';
      if (room.status == RoomStatus.soon) label = 'Occupied Soon';
      if (room.status == RoomStatus.noClass) label = 'No Class Today';
      
      return _BadgeContainer(
        color: _statusColor(room.status),
        label: label,
      );
    }

    final blockAsync = ref.watch(scheduleBlockProvider(room.currentOccupantBlockId!));

    return blockAsync.when(
      loading: () => _BadgeContainer(
          color: _statusColor(room.status),
          label: room.status == RoomStatus.occupied ? 'Occupied' : 'Occupied Soon'),
      error: (_, __) => _BadgeContainer(
          color: _statusColor(room.status),
          label: room.status == RoomStatus.occupied ? 'Occupied' : 'Occupied Soon'),
      data: (block) {
        if (block == null) {
          return _BadgeContainer(
              color: _statusColor(room.status),
              label: room.status == RoomStatus.occupied ? 'Occupied' : 'Occupied Soon');
        }

        final section = block.courseSection;
        final start = TimeUtils.toDisplayTime(block.startTime);
        final end = TimeUtils.toDisplayTime(block.endTime);

        final label = room.status == RoomStatus.occupied
            ? 'Occupied by $section until $end'
            : (room.status == RoomStatus.noClass
                ? '$section doesnt have a class today'
                : '$section will soon occupy this room at $start-$end');

        return _BadgeContainer(color: _statusColor(room.status), label: label);
      },
    );
  }
}

class _BadgeContainer extends StatelessWidget {
  final Color color;
  final String label;
  const _BadgeContainer({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

// Provider: today's schedule blocks for a specific room (used in room_detail_screen)
final roomTodayBlocksProvider =
    StreamProvider.family<List<ScheduleBlockModel>, String>((ref, roomId) {
  final dayKey = TimeUtils.dayKey(DateTime.now());
  return ref
      .watch(scheduleServiceProvider)
      .getTodayRoomBlocksStream(roomId, dayKey);
});

/// All-week blocks for a specific room (all days this semester, view-only).
final roomAllBlocksProvider =
    StreamProvider.family<List<ScheduleBlockModel>, String>((ref, roomId) {
  return ref
      .watch(scheduleServiceProvider)
      .getRoomAllBlocksStream(roomId);
});
