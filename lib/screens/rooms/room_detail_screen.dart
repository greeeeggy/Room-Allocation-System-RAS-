import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../models/room_model.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/room_provider.dart';
import '../../providers/schedule_provider.dart';
import 'room_schedule_screen.dart';

class RoomDetailScreen extends ConsumerWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(allRoomsProvider);
    final todayKey = TimeUtils.dayKey(DateTime.now());
    final todayBlocksAsync = ref.watch(roomTodayBlocksProvider(roomId));

    return Scaffold(
      appBar: AppBar(title: const Text('Room Detail')),
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

class _RoomDetailBody extends StatelessWidget {
  final RoomModel room;
  final AsyncValue<List<ScheduleBlockModel>> todayBlocksAsync;
  final String roomId;

  const _RoomDetailBody(
      {required this.room, required this.todayBlocksAsync, required this.roomId});

  Color _statusColor(RoomStatus s) {
    switch (s) {
      case RoomStatus.occupied:
        return AppColors.occupied;
      case RoomStatus.soon:
        return AppColors.soon;
      case RoomStatus.available:
        return AppColors.available;
    }
  }

  String _statusLabel(RoomStatus s) {
    switch (s) {
      case RoomStatus.occupied:
        return 'Occupied';
      case RoomStatus.soon:
        return 'Occupied Soon';
      case RoomStatus.available:
        return 'Available';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    Text(
                      'Room ${room.roomNumber}',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(room.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(room.status),
                        style: TextStyle(
                            color: _statusColor(room.status),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Floor ${room.floor}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 8),
      ],
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
