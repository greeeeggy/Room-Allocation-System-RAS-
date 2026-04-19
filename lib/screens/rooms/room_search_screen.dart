import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/room_model.dart';
import '../../providers/room_provider.dart';

// Local filter state
class _RoomFilter {
  final int floor; // 0 = all
  final Set<String> features;
  final RoomStatus? status; // null = all

  const _RoomFilter({
    this.floor = 0,
    this.features = const {},
    this.status,
  });

  _RoomFilter copyWith({
    int? floor,
    Set<String>? features,
    Object? status = _sentinel,
  }) {
    return _RoomFilter(
      floor: floor ?? this.floor,
      features: features ?? this.features,
      status: status == _sentinel ? this.status : status as RoomStatus?,
    );
  }

  static const _sentinel = Object();
}

class RoomSearchScreen extends ConsumerStatefulWidget {
  const RoomSearchScreen({super.key});

  @override
  ConsumerState<RoomSearchScreen> createState() => _RoomSearchScreenState();
}

class _RoomSearchScreenState extends ConsumerState<RoomSearchScreen> {
  _RoomFilter _filter = const _RoomFilter();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RoomModel> _applyFilter(List<RoomModel> rooms) {
    return rooms.where((r) {
      // Text search
      if (_query.isNotEmpty &&
          !r.roomNumber.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      // Floor filter
      if (_filter.floor != 0 && r.floor != _filter.floor) return false;
      // Status filter
      if (_filter.status != null && r.status != _filter.status) return false;
      // Feature filter — room must have ALL selected features
      if (_filter.features.isNotEmpty &&
          !_filter.features.every((f) => r.features.contains(f))) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(allRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Room Search')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by room number…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Filter chips
          _FilterRow(
            filter: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),

          const Divider(height: 1),

          // Results
          Expanded(
            child: roomsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rooms) {
                final filtered = _applyFilter(rooms);
                if (filtered.isEmpty) {
                  return const _EmptySearch();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RoomTile(room: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Filter row ----------

class _FilterRow extends StatelessWidget {
  final _RoomFilter filter;
  final ValueChanged<_RoomFilter> onChanged;

  const _FilterRow({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          // Floor chips
          _chip(
            label: 'All Floors',
            selected: filter.floor == 0,
            onTap: () => onChanged(filter.copyWith(floor: 0)),
          ),
          for (int f = 6; f >= 1; f--)
            _chip(
              label: 'Floor $f',
              selected: filter.floor == f,
              onTap: () => onChanged(filter.copyWith(floor: f)),
            ),
          const VerticalDivider(width: 20),
          // Status chips
          _chip(
            label: 'Available',
            selected: filter.status == RoomStatus.available,
            color: AppColors.available,
            onTap: () => onChanged(filter.copyWith(
              status: filter.status == RoomStatus.available
                  ? null
                  : RoomStatus.available,
            )),
          ),
          _chip(
            label: 'Occupied',
            selected: filter.status == RoomStatus.occupied,
            color: AppColors.occupied,
            onTap: () => onChanged(filter.copyWith(
              status: filter.status == RoomStatus.occupied
                  ? null
                  : RoomStatus.occupied,
            )),
          ),
          _chip(
            label: 'Soon',
            selected: filter.status == RoomStatus.soon,
            color: AppColors.soon,
            onTap: () => onChanged(filter.copyWith(
              status:
                  filter.status == RoomStatus.soon ? null : RoomStatus.soon,
            )),
          ),
          const VerticalDivider(width: 20),
          // Feature chips
          for (final feat in RoomFeatures.all)
            _chip(
              label: _featureLabel(feat),
              selected: filter.features.contains(feat),
              onTap: () {
                final updated = Set<String>.from(filter.features);
                if (updated.contains(feat)) {
                  updated.remove(feat);
                } else {
                  updated.add(feat);
                }
                onChanged(filter.copyWith(features: updated));
              },
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final activeColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? activeColor : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  String _featureLabel(String f) {
    const m = {
      'tv': 'TV',
      'whiteboard': 'Whiteboard',
      'blackboard': 'Blackboard',
      'aircon': 'Aircon',
      'projector': 'Projector',
    };
    return m[f] ?? f;
  }
}

// ---------- Room tile ----------

class _RoomTile extends StatelessWidget {
  final RoomModel room;
  const _RoomTile({required this.room});

  Color _statusColor(RoomStatus s) {
    switch (s) {
      case RoomStatus.occupied:
        return AppColors.occupied;
      case RoomStatus.soon:
        return AppColors.soon;
      case RoomStatus.available:
      case RoomStatus.noClass:
        return AppColors.available;
    }
  }

  String _statusLabel(RoomStatus s) {
    switch (s) {
      case RoomStatus.occupied:
        return 'Occupied';
      case RoomStatus.soon:
        return 'Soon';
      case RoomStatus.available:
        return 'Available';
      case RoomStatus.noClass:
        return 'No Class';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/search/room/${room.roomId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _statusColor(room.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              // Room info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room ${room.roomNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('Floor ${room.floor}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Features icons
              Row(
                children: room.features
                    .take(3)
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(_featureIcon(f),
                              size: 16, color: Colors.grey),
                        ))
                    .toList(),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(room.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel(room.status),
                  style: TextStyle(
                      color: _statusColor(room.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
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

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('No rooms match your filters.',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 4),
          Text('Try adjusting the filters above.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
