import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../core/utils/status_engine.dart';
import '../../services/room_service.dart';
import '../../core/utils/time_utils.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final selectedFloor = ref.watch(selectedFloorProvider);
    final roomsAsync = ref.watch(filteredRoomsProvider);
    final nextClass = ref.watch(nextClassProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Availability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Rooms',
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Seed Rooms',
            onPressed: () async {
              await ref.read(roomServiceProvider).seedRooms();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rooms seeded successfully!')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/dashboard/settings'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome + next class card
          userAsync.when(
            data: (user) => user == null
                ? const SizedBox()
                : _WelcomeCard(
                    name: user.name,
                    section: user.courseSection,
                    nextClass: nextClass,
                  ),
            loading: () => const SizedBox(height: 72),
            error: (_, __) => const SizedBox(),
          ),

          // Floor filter tabs
          _FloorFilterTabs(
            selected: selectedFloor,
            onSelect: (f) =>
                ref.read(selectedFloorProvider.notifier).state = f,
          ),

          // Legend
          const _StatusLegend(),

          // Room grid
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  await StatusEngine().runOnAppLoad();
                } catch (_) {}
              },
              child: roomsAsync.when(
                data: (rooms) => rooms.isEmpty
                    ? const _EmptyState()
                    : _RoomGrid(rooms: rooms),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Sub-widgets ----------

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String? section;
  final ScheduleBlockModel? nextClass;

  const _WelcomeCard({
    required this.name,
    this.section,
    this.nextClass,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, $name',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          if (section != null)
            Text(section!,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (nextClass != null) ...[
            const SizedBox(height: 12),
            _MyNextClassCard(block: nextClass!),
          ],
        ],
      ),
    );
  }
}

class _MyNextClassCard extends ConsumerStatefulWidget {
  final ScheduleBlockModel block;
  const _MyNextClassCard({required this.block});

  @override
  ConsumerState<_MyNextClassCard> createState() => _MyNextClassCardState();
}

class _MyNextClassCardState extends ConsumerState<_MyNextClassCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Rebuild every minute so time labels and canCheckIn stay accurate
    // without refreshing the whole dashboard screen.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final minutesUntil = TimeUtils.minutesUntil(block.startTime);
    final isActive = TimeUtils.isNowBetween(block.startTime, block.endTime);
    final canCheckIn = block.checkInStatus == CheckInStatus.pending &&
        (minutesUntil <= 15);

    String timeLabel;
    if (isActive) {
      timeLabel = 'Until ${TimeUtils.toDisplayTime(block.endTime)}';
    } else if (minutesUntil > 0) {
      timeLabel = 'In $minutesUntil min · ${TimeUtils.toDisplayTime(block.startTime)}';
    } else {
      timeLabel = TimeUtils.toDisplayTime(block.startTime);
    }

    return GestureDetector(
      onTap: canCheckIn
          ? () => context.push('/dashboard/checkin/${block.blockId}')
          : (block.roomId == 'unassigned' ? null : () => context.push('/dashboard/room/${block.roomId}')),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.class_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.subject,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(block.roomId == 'unassigned' ? 'No assigned room · $timeLabel' : '${block.roomId} · $timeLabel',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            if (canCheckIn)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Check In',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _FloorFilterTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _FloorFilterTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _FloorChip(label: 'All', value: 0, selected: selected, onSelect: onSelect),
          for (int f = 6; f >= 1; f--)
            _FloorChip(label: '${f}F', value: f, selected: selected, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _FloorChip extends StatelessWidget {
  final String label;
  final int value;
  final int selected;
  final ValueChanged<int> onSelect;
  const _FloorChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _LegendDot(color: AppColors.available, label: 'Available'),
          const SizedBox(width: 12),
          _LegendDot(color: AppColors.occupied, label: 'Occupied'),
          const SizedBox(width: 12),
          _LegendDot(color: AppColors.soon, label: 'Soon'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _RoomGrid extends StatelessWidget {
  final List<RoomModel> rooms;
  const _RoomGrid({required this.rooms});

  Color _statusColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.occupied:
        return AppColors.occupied;
      case RoomStatus.soon:
        return AppColors.soon;
      case RoomStatus.available:
      case RoomStatus.noClass:
        return AppColors.available;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: rooms.length,
      itemBuilder: (_, i) {
        final room = rooms[i];
        return GestureDetector(
          onTap: () => context.push('/dashboard/room/${room.roomId}'),
          child: Container(
            decoration: BoxDecoration(
              color: _statusColor(room.status),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Center(
              child: Text(
                room.roomNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No rooms found.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              SizedBox(height: 4),
              Text('Tap the upload icon in the app bar to seed rooms.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
