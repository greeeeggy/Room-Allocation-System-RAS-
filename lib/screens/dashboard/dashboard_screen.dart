import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              try {
                await StatusEngine().runOnAppLoad();
              } catch (_) {}
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'app_logo',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/RAS_logo.png',
                              height: 40,
                              errorBuilder: (context, error, stackTrace) => 
                                  const Icon(Icons.room_preferences, color: AppColors.primary, size: 32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.appName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  color: AppColors.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                          onPressed: () async {
                            await ref.read(roomServiceProvider).seedRooms();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Rooms seeded successfully!')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Welcome card
                SliverToBoxAdapter(
                  child: userAsync.when(
                    data: (user) => user == null
                        ? const SizedBox()
                        : _WelcomeCard(
                            name: user.name,
                            section: user.courseSection,
                            nextClass: nextClass,
                          ),
                    loading: () => const SizedBox(height: 120),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                // Floor filter tabs & Legend (now in a simple adapter to avoid sliver geometry issues)
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FloorFilterTabs(
                          selected: selectedFloor,
                          onSelect: (f) =>
                              ref.read(selectedFloorProvider.notifier).state = f,
                        ),
                        const _StatusLegend(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Room grid / segments
                roomsAsync.when(
                  data: (rooms) => rooms.isEmpty
                      ? const SliverFillRemaining(child: _EmptyState())
                      : _FloorGroupedGrid(rooms: rooms, selectedFloor: selectedFloor),
                  loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => SliverFillRemaining(
                      child: Center(child: Text('Error: $e'))),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: const _ClassyFloatingSettings(),
    );
  }
}

class _ClassyFloatingSettings extends StatelessWidget {

  const _ClassyFloatingSettings();

  @override
  Widget build(BuildContext context) {
    const double size = 52.0;
    const Color accentColor = Color(0xFF00B894); // Premium Emerald Green

    return Padding(
      padding: const EdgeInsets.only(bottom: 95, right: 8),
      child: GestureDetector(
        onTap: () => context.push('/dashboard/settings'),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            // Glossy highlight
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(1.0),
                accentColor.withOpacity(0.85),
              ],
            ),
          ),
          child: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 26,
          ),
        ),
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
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hey, $name!',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (section != null)
                              Text(
                                section!,
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (nextClass != null) ...[
                    const SizedBox(height: 20),
                    _MyNextClassCard(block: nextClass!),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    final checkInStatus = block.checkInStatus;
    final canCheckIn = checkInStatus == CheckInStatus.pending &&
        (minutesUntil <= 15);

    String timeLabel;
    if (isActive) {
      timeLabel = 'Ends at ${TimeUtils.toDisplayTime(block.endTime)}';
    } else if (minutesUntil > 0) {
      timeLabel = 'Starts in $minutesUntil min (${TimeUtils.toDisplayTime(block.startTime)})';
    } else {
      timeLabel = TimeUtils.toDisplayTime(block.startTime);
    }

    return GestureDetector(
      onTap: canCheckIn
          ? () => context.push('/dashboard/checkin/${block.blockId}')
          : (block.roomId == 'unassigned' ? null : () => context.push('/dashboard/room/${block.roomId}')),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white30),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.subject,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        block.roomId == 'unassigned' ? 'TBA · $timeLabel' : '${block.roomId} · $timeLabel',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canCheckIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Check In',
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
              ],
            ),
          ),
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
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _FloorChip(label: 'All Floors', value: 0, selected: selected, onSelect: onSelect),
          for (int f = 6; f >= 1; f--)
            _FloorChip(label: 'Floor $f', value: f, selected: selected, onSelect: onSelect),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : AppColors.primary.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _LegendDot(gradient: AppColors.availableGradient, label: 'Available'),
          const SizedBox(width: 16),
          _LegendDot(gradient: AppColors.occupiedGradient, label: 'Occupied'),
          const SizedBox(width: 16),
          _LegendDot(gradient: AppColors.soonGradient, label: 'Soon'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final LinearGradient gradient;
  final String label;
  const _LegendDot({required this.gradient, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.last.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FloorGroupedGrid extends StatelessWidget {
  final List<RoomModel> rooms;
  final int selectedFloor;
  const _FloorGroupedGrid({required this.rooms, required this.selectedFloor});

  @override
  Widget build(BuildContext context) {
    // Group rooms by floor
    final groupedRooms = <int, List<RoomModel>>{};
    for (final room in rooms) {
      groupedRooms.putIfAbsent(room.floor, () => []).add(room);
    }
    
    // Sort floors descending
    final sortedFloors = groupedRooms.keys.toList()..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final floor = sortedFloors[index];
          final floorRooms = groupedRooms[floor] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Floor $floor',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.2),
                              AppColors.primary.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85, 
                ),
                itemCount: floorRooms.length,
                itemBuilder: (_, i) => _RoomTile(room: floorRooms[i]),
              ),
              if (index < sortedFloors.length - 1)
                const SizedBox(height: 8),
            ],
          );
        },
        childCount: sortedFloors.length,
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final RoomModel room;
  const _RoomTile({required this.room});

  LinearGradient _statusGradient() {
    if (room.isOffice) return AppColors.officeGradient;
    switch (room.status) {
      case RoomStatus.occupied:
        return AppColors.occupiedGradient;
      case RoomStatus.soon:
        return AppColors.soonGradient;
      case RoomStatus.available:
      case RoomStatus.noClass:
        return AppColors.availableGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffice = room.isOffice;
    final isLab = room.isLab;

    final content = Container(
      decoration: BoxDecoration(
        gradient: _statusGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Background icon pattern
          Positioned(
            right: -10,
            bottom: -5,
            child: Icon(
              isOffice ? Icons.business_rounded : (isLab ? Icons.biotech_rounded : Icons.meeting_room_rounded),
              size: 48,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      room.roomNumber,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (isLab)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LAB',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (room.features.contains(RoomFeatures.blackboard))
                      Icon(Icons.border_all_rounded, size: 10, color: Colors.white.withOpacity(0.9)),
                    if (room.features.contains(RoomFeatures.whiteboard))
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.rectangle_outlined, size: 10, color: Colors.white.withOpacity(0.9)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isOffice) {
      return content;
    }

    return GestureDetector(
      onTap: () {
        context.push('/dashboard/room/${room.roomId}');
      },
      child: content,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined, size: 80, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            'No Rooms Found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try seeding rooms using the icon above.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
