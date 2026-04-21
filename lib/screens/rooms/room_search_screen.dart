import 'dart:ui';
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
      if (_query.isNotEmpty &&
          !r.roomNumber.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_filter.floor != 0 && r.floor != _filter.floor) return false;
      if (_filter.status != null && r.status != _filter.status) return false;
      if (_filter.features.isNotEmpty &&
          !_filter.features.every((f) => r.features.contains(f))) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(allRoomsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: Stack(
        children: [
          // Architectural Background Detail (Light)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.08),
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
                _MetropolisHeader(query: _query),
                
                _SearchDeck(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),

                _FilterConsole(
                  filter: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),

                Expanded(
                  child: roomsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.black45))),
                    data: (rooms) {
                      final filtered = _applyFilter(rooms);
                      if (filtered.isEmpty) {
                        return const _EmptySearchNoir();
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ArchitectTile(
                          room: filtered[i],
                          index: i,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetropolisHeader extends StatelessWidget {
  final String query;
  const _MetropolisHeader({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROOM',
            style: TextStyle(
              color: AppColors.accent.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            query.isEmpty ? 'SEARCH' : 'FINDING...',
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchDeck extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchDeck({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 54, // Smaller height
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
          decoration: InputDecoration(
            hintText: 'ENTER ROOM NUMBER',
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.2),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.accent.withOpacity(0.6), size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black26, size: 18),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _FilterConsole extends StatelessWidget {
  final _RoomFilter filter;
  final ValueChanged<_RoomFilter> onChanged;

  const _FilterConsole({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Text(
            'CONSTRAINTS',
            style: TextStyle(
              color: Colors.black26,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 44, // Smaller height
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _ConsoleButton(
                label: 'ANY FLOOR',
                selected: filter.floor == 0,
                onTap: () => onChanged(filter.copyWith(floor: 0)),
              ),
              for (int f = 6; f >= 1; f--)
                _ConsoleButton(
                  label: '${f}F',
                  selected: filter.floor == f,
                  onTap: () => onChanged(filter.copyWith(floor: f)),
                ),
              _Divider(),
              _ConsoleButton(
                label: 'AVAILABLE',
                selected: filter.status == RoomStatus.available,
                accent: AppColors.available,
                onTap: () => onChanged(filter.copyWith(
                  status: filter.status == RoomStatus.available ? null : RoomStatus.available,
                )),
              ),
              _ConsoleButton(
                label: 'OCCUPIED',
                selected: filter.status == RoomStatus.occupied,
                accent: AppColors.occupied,
                onTap: () => onChanged(filter.copyWith(
                  status: filter.status == RoomStatus.occupied ? null : RoomStatus.occupied,
                )),
              ),
              _Divider(),
              for (final feat in RoomFeatures.all)
                _ConsoleButton(
                  label: feat.toUpperCase(),
                  selected: filter.features.contains(feat),
                  onTap: () {
                    final updated = Set<String>.from(filter.features);
                    updated.contains(feat) ? updated.remove(feat) : updated.add(feat);
                    onChanged(filter.copyWith(features: updated));
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _ConsoleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _ConsoleButton({
    required this.label,
    required this.selected,
    this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accent ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          border: Border.all(
            color: selected ? activeColor : Colors.black.withOpacity(0.06),
            width: 1,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: activeColor.withOpacity(0.2),
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      color: Colors.black.withOpacity(0.05),
    );
  }
}

class _ArchitectTile extends StatelessWidget {
  final RoomModel room;
  final int index;

  const _ArchitectTile({required this.room, required this.index});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(room.status);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 80).clamp(0, 500)),
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
        onTap: () => context.push('/search/room/${room.roomId}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 95, // Smaller height
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
                      // Room numeric dominant element
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            room.roomNumber,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 28, // Smaller proportional font
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'FLOOR ${room.floor}',
                            style: TextStyle(
                              color: AppColors.accent.withOpacity(0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Features summary
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (room.isLab)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _StatusBadge(label: 'LAB', color: AppColors.accent),
                                ),
                              _StatusBadge(
                                label: room.isOffice ? 'OFFICE' : _getStatusLabel(room.status), 
                                color: room.isOffice ? Colors.grey.shade500 : statusColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: room.features.take(3).map((f) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(_getFeatureIcon(f), color: Colors.black12, size: 14),
                            )).toList(),
                          ),
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
                  color: room.isLab ? AppColors.accent.withOpacity(0.4) : statusColor.withOpacity(0.4),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 2,
                  height: 24,
                  color: room.isLab ? AppColors.accent.withOpacity(0.4) : statusColor.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(RoomStatus s) {
    switch (s) {
      case RoomStatus.occupied: return AppColors.occupied;
      case RoomStatus.soon: return AppColors.soon;
      default: return AppColors.available;
    }
  }

  String _getStatusLabel(RoomStatus s) {
    switch (s) {
      case RoomStatus.occupied: return 'OCCUPIED';
      case RoomStatus.soon: return 'SOON';
      case RoomStatus.noClass: return 'NO CLASS';
      default: return 'AVAILABLE';
    }
  }

  IconData _getFeatureIcon(String f) {
    switch (f) {
      case 'tv': return Icons.tv_rounded;
      case 'aircon': return Icons.ac_unit_rounded;
      case 'projector': return Icons.videocam_rounded;
      case 'whiteboard': return Icons.square_outlined;
      case 'blackboard': return Icons.square;
      default: return Icons.check_circle_outline_rounded;
    }
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

class _EmptySearchNoir extends StatelessWidget {
  const _EmptySearchNoir();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.architecture_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 20),
          Text(
            'NULL_RESULTS',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ADJUST PARAMETERS',
            style: TextStyle(
              color: Colors.white10,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
