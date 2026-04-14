import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/room_model.dart';
import '../../providers/room_provider.dart';
import 'isometric_painter.dart';

class FloorMapScreen extends ConsumerStatefulWidget {
  const FloorMapScreen({super.key});

  @override
  ConsumerState<FloorMapScreen> createState() => _FloorMapScreenState();
}

class _FloorMapScreenState extends ConsumerState<FloorMapScreen> {
  int _selectedFloor = 1;
  String? _selectedRoomId;

  @override
  Widget build(BuildContext context) {
    final allRoomsAsync = ref.watch(allRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Map'),
      ),
      body: allRoomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allRooms) {
          final floorRooms = allRooms
              .where((r) => r.floor == _selectedFloor)
              .toList();

          return Column(
            children: [
              // ── Floor selector ──────────────────────────────────────
              _FloorSelector(
                selected: _selectedFloor,
                onSelect: (f) => setState(() {
                  _selectedFloor = f;
                  _selectedRoomId = null;
                }),
              ),

              // ── Legend ──────────────────────────────────────────────
              const _Legend(),

              // ── Isometric canvas ────────────────────────────────────
              Expanded(
                child: floorRooms.isEmpty
                    ? const Center(
                        child: Text('No rooms on this floor.',
                            style: TextStyle(color: AppColors.textSecondary)))
                    : _IsometricView(
                        rooms: floorRooms,
                        selectedRoomId: _selectedRoomId,
                        onRoomTap: (roomId) {
                          setState(() => _selectedRoomId = roomId);
                          _showRoomSheet(context, roomId);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRoomSheet(BuildContext context, String roomId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RoomPreviewSheet(
        roomId: roomId,
        onViewDetail: () {
          Navigator.pop(context);
          context.push('/map/room/$roomId');
        },
      ),
    );
  }
}

// ---------- Isometric view with gesture detection ----------

class _IsometricView extends StatefulWidget {
  final List<RoomModel> rooms;
  final String? selectedRoomId;
  final ValueChanged<String> onRoomTap;

  const _IsometricView({
    required this.rooms,
    required this.selectedRoomId,
    required this.onRoomTap,
  });

  @override
  State<_IsometricView> createState() => _IsometricViewState();
}

class _IsometricViewState extends State<_IsometricView> {
  // Store the painter so we can call hitTest on it.
  IsometricFloorPainter? _painter;
  Size? _canvasSize;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 3.0,
      child: GestureDetector(
        onTapDown: (details) {
          if (_painter == null || _canvasSize == null) return;
          final roomId =
              _painter!.getRoomAtPosition(details.localPosition, _canvasSize!);
          if (roomId != null) widget.onRoomTap(roomId);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _canvasSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            _painter = IsometricFloorPainter(
              rooms: widget.rooms,
              selectedRoomId: widget.selectedRoomId,
            );
            return CustomPaint(
              painter: _painter,
              size: _canvasSize!,
            );
          },
        ),
      ),
    );
  }
}

// ---------- Floor selector ----------

class _FloorSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _FloorSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: List.generate(6, (i) {
          final floor = i + 1;
          final sel = floor == selected;
          return GestureDetector(
            onTap: () => onSelect(floor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? AppColors.primary : Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  '${floor}F',
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------- Legend ----------

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _LegendDot(color: AppColors.available, label: 'Available'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.soon, label: 'Soon'),
          const SizedBox(width: 16),
          _LegendDot(color: AppColors.occupied, label: 'Occupied'),
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
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ---------- Room preview bottom sheet ----------

class _RoomPreviewSheet extends ConsumerWidget {
  final String roomId;
  final VoidCallback onViewDetail;
  const _RoomPreviewSheet(
      {required this.roomId, required this.onViewDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRoomsAsync = ref.watch(allRoomsProvider);
    final room = allRoomsAsync.valueOrNull
        ?.where((r) => r.roomId == roomId)
        .firstOrNull;

    if (room == null) {
      return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()));
    }

    final statusColor = switch (room.status) {
      RoomStatus.occupied => AppColors.occupied,
      RoomStatus.soon => AppColors.soon,
      RoomStatus.available => AppColors.available,
    };

    final statusLabel = switch (room.status) {
      RoomStatus.occupied => 'Occupied',
      RoomStatus.soon => 'Occupied Soon',
      RoomStatus.available => 'Available',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Room number + status badge
          Row(
            children: [
              Text('Room $roomId',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Floor
          Text('Floor ${room.floor}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),

          // Features
          if (room.features.isNotEmpty)
            Wrap(
              spacing: 6,
              children: room.features
                  .map((f) => Chip(
                        label: Text(f,
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),

          // View detail button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewDetail,
              child: const Text('View Room Detail'),
            ),
          ),
        ],
      ),
    );
  }
}
