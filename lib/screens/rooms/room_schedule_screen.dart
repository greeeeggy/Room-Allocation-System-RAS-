import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_block_model.dart';
import 'room_detail_screen.dart'; // for roomAllBlocksProvider

/// View-only weekly schedule table for a specific room.
/// Architecture mirrors aeternum_app/lib/class_schedule/class_scheduler.dart:
///   - Dark background (Colors.grey[900])
///   - InteractiveViewer (pinch-zoom + pan) wrapping two ScrollControllers
///   - _buildGrid()  → dumb visual layer (time col + 7 day cols × hour rows)
///   - _buildClassOverlays() → smart layer (colored blocks positioned by time math)
///   - Drag handles on column right edges and row bottom edges (resize, same as aeternum)
///   - Read-only: no edit, no add, no delete
class RoomScheduleScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomNumber;

  const RoomScheduleScreen({
    super.key,
    required this.roomId,
    required this.roomNumber,
  });

  @override
  ConsumerState<RoomScheduleScreen> createState() =>
      _RoomScheduleScreenState();
}

class _RoomScheduleScreenState extends ConsumerState<RoomScheduleScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // ── Grid constants — identical to class_scheduler.dart ──────────────────
  static const int _startHour = 7;
  static const int _endHour = 20;
  static const double _headerHeight = 50.0;
  static const double _timeColumnWidth = 80.0;

  // Resizable — mirrors class_scheduler.dart mutable state
  List<double> _columnWidths = List.filled(7, 150.0);
  Map<int, double> _rowHeights = {};

  double _rowHeight(int hour) => _rowHeights[hour] ?? 60.0;

  // ── Day order — matches class_scheduler.dart ────────────────────────────
  static const _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  static const _dayKeys = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

  // ── Full palette — 20 visually distinct colors ──────────────────────────
  // Spread across hue wheel so adjacent entries never look similar.
  // Colors are assigned to subjects by their sorted index within the
  // current room's block list, so no two subjects ever share a color.
  static const _palette = [
    Color(0xFF4FC3F7), // sky blue
    Color(0xFFEF5350), // red
    Color(0xFF66BB6A), // green
    Color(0xFFFFCA28), // yellow
    Color(0xFFAB47BC), // purple
    Color(0xFFFF7043), // deep orange
    Color(0xFF26C6DA), // cyan
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFF42A5F5), // blue
    Color(0xFFFFA726), // amber
    Color(0xFF26A69A), // teal
    Color(0xFFD4E157), // lime
    Color(0xFF7E57C2), // deep purple
    Color(0xFF29B6F6), // light blue
    Color(0xFFFF5252), // red accent
    Color(0xFF69F0AE), // green accent
    Color(0xFFFFD740), // amber accent
    Color(0xFFE040FB), // purple accent
    Color(0xFF40C4FF), // light blue accent
  ];

  // ── Color map: built once per block list, guarantees no duplicates ───────
  // Key = subject string, Value = palette color
  Map<String, Color> _buildColorMap(List<ScheduleBlockModel> blocks) {
    // Collect unique subjects in a stable sorted order
    final subjects = blocks.map((b) => b.subject).toSet().toList()..sort();
    final map = <String, Color>{};
    for (int i = 0; i < subjects.length; i++) {
      map[subjects[i]] = _palette[i % _palette.length];
    }
    return map;
  }

  // ── Time → pixel helpers (same math as class_scheduler.dart) ────────────

  double _yForHHmm(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    double y = _headerHeight;
    for (int h = _startHour; h < hour; h++) {
      y += _rowHeight(h);
    }
    y += _rowHeight(hour) * (minute / 60.0);
    return y;
  }

  double _xForDayIndex(int dayIndex) {
    double x = _timeColumnWidth;
    for (int i = 0; i < dayIndex; i++) {
      x += _columnWidths[i];
    }
    return x;
  }

  double _blockPixelHeight(String startHHmm, String endHHmm) {
    return _yForHHmm(endHHmm) - _yForHHmm(startHHmm);
  }

  // ── Formatters ───────────────────────────────────────────────────────────

  bool _isLunchHour(int hour) => hour == 12;

  String _formatHour(int hour) {
    if (hour == 12) return '12:00 PM\nLUNCH';
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // ========================================================================
  // GRID — dumb visual layer
  // Resize handles on row bottoms + column right edges, same as aeternum.
  // ========================================================================

  Widget _buildTimeCell(int hour) {
    final isLunch = _isLunchHour(hour);
    final currentHeight = _rowHeight(hour);

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _rowHeights[hour] =
              (currentHeight + details.delta.dy).clamp(40.0, 150.0);
        });
      },
      child: Container(
        height: currentHeight,
        width: _timeColumnWidth,
        decoration: BoxDecoration(
          color: isLunch ? Colors.orange.withOpacity(0.1) : Colors.grey[900]!.withOpacity(0.6),
          image: const DecorationImage(
            image: AssetImage('assets/images/bg.png'),
            fit: BoxFit.cover,
            opacity: 0.2,
          ),
          border: Border(
            bottom: const BorderSide(color: Colors.black, width: 1),
            right: const BorderSide(color: Colors.black, width: 2),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                _formatHour(hour),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isLunch ? Colors.orange : Colors.white70,
                  fontSize: 12,
                  fontWeight: isLunch ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            // Resize handle at bottom — mirrors class_scheduler.dart
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 16,
                color: Colors.transparent,
                child: Center(
                  child: Icon(
                    Icons.drag_handle,
                    color: Colors.grey[700],
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(int dayIndex, int hour) {
    final isLunch = _isLunchHour(hour);
    final height = _rowHeight(hour);
    final width = _columnWidths[dayIndex];

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isLunch ? Colors.orange.withOpacity(0.1) : Colors.grey[900]!.withOpacity(0.4),
        image: const DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
          opacity: 0.15,
        ),
        border: Border(
          bottom: const BorderSide(color: Colors.black),
          right: const BorderSide(color: Colors.black),
        ),
      ),
      child: isLunch
          ? const Center(child: Text('🍽️', style: TextStyle(fontSize: 20)))
          : null,
    );
  }

  Widget _buildGrid() {
    return Column(
      children: [
        // ── Header row ──────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time header
            Container(
              height: _headerHeight,
              width: _timeColumnWidth,
              decoration: BoxDecoration(
                color: Colors.grey[850]!.withOpacity(0.8),
                image: const DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                  opacity: 0.2,
                ),
                border: Border(
                  bottom: const BorderSide(color: Colors.black, width: 2),
                  right: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              child: const Center(
                child: Text(
                  'Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // Day headers — with horizontal drag handle for column resize
            ...List.generate(7, (dayIndex) {
              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _columnWidths[dayIndex] =
                        (_columnWidths[dayIndex] + details.delta.dx)
                            .clamp(80.0, 300.0);
                  });
                },
                child: Container(
                  height: _headerHeight,
                  width: _columnWidths[dayIndex],
                  decoration: BoxDecoration(
                    color: Colors.grey[850]!.withOpacity(0.8),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/bg.png'),
                      fit: BoxFit.cover,
                      opacity: 0.2,
                    ),
                    border: Border(
                      bottom: const BorderSide(color: Colors.black, width: 2),
                      right: const BorderSide(color: Colors.black, width: 1),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          _dayNames[dayIndex].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Resize handle at right edge — mirrors class_scheduler.dart
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          color: Colors.transparent,
                          child: Center(
                            child: Icon(
                              Icons.drag_handle,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        // ── Hour rows ────────────────────────────────────────────────────
        ...List.generate(_endHour - _startHour, (index) {
          final hour = _startHour + index;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeCell(hour),
              ...List.generate(
                  7, (dayIndex) => _buildDayCell(dayIndex, hour)),
            ],
          );
        }),
      ],
    );
  }

  // ========================================================================
  // CLASS OVERLAYS — smart layer positioned by time math
  // ========================================================================

  List<Widget> _buildClassOverlays(
      List<ScheduleBlockModel> blocks, Map<String, Color> colorMap) {
    return blocks.map((block) {
      final dayIndex = _dayKeys.indexOf(block.dayOfWeek);
      if (dayIndex == -1) return const SizedBox.shrink();

      final top = _yForHHmm(block.startTime);
      final left = _xForDayIndex(dayIndex);
      final height = _blockPixelHeight(block.startTime, block.endTime);
      final width = _columnWidths[dayIndex];
      final color = colorMap[block.subject] ?? _palette[0];

      return Positioned(
        top: top,
        left: left,
        width: width,
        height: height,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${block.subject} · ${block.courseSection} · '
                  '${TimeUtils.toDisplayTime(block.startTime)}–'
                  '${TimeUtils.toDisplayTime(block.endTime)}',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              border: Border.all(color: color.withOpacity(0.4), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${TimeUtils.toDisplayTime(block.startTime)} - '
                    '${TimeUtils.toDisplayTime(block.endTime)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    block.subject,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    block.courseSection,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    block.instructor,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final allBlocksAsync = ref.watch(roomAllBlocksProvider(widget.roomId));

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          'Room ${widget.roomNumber} — All Schedules',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: allBlocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white70)),
        ),
        data: (blocks) {
          if (blocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today,
                      size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No schedules for Room ${widget.roomNumber}',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedules are added from the Add Schedule block.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            );
          }

          // Build color map once per block list — no two subjects share a color
          final colorMap = _buildColorMap(blocks);

          return Column(
            children: [
              // Instructions bar — mirrors class_scheduler.dart
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[850],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey[400], size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Drag headers to resize  ·  Pinch to zoom  ·  View-only',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin:
                      const EdgeInsets.all(double.infinity),
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: Stack(
                        children: [
                          _buildGrid(),
                          ..._buildClassOverlays(blocks, colorMap),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
