import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/schedule_provider.dart';
import 'schedule_screen.dart'; // For _EmptyDay

class MyWeeklyScheduleScreen extends ConsumerWidget {
  const MyWeeklyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(myBlocksProvider);

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          'WEEKLY SCHEDULE',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: blocksAsync.when(
        data: (blocks) => _WeeklyScheduleTable(blocks: blocks),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
      ),
    );
  }
}

// ---------- Weekly Schedule Table (Moved from schedule_screen.dart) ----------

class _WeeklyScheduleTable extends ConsumerStatefulWidget {
  final List<ScheduleBlockModel> blocks;
  const _WeeklyScheduleTable({required this.blocks});

  @override
  ConsumerState<_WeeklyScheduleTable> createState() => _WeeklyScheduleTableState();
}

class _WeeklyScheduleTableState extends ConsumerState<_WeeklyScheduleTable> {
  final TransformationController _transformationController = TransformationController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  static const int _startHour = 7;
  static const int _endHour = 20;
  static const double _headerHeight = 50.0;
  static const double _timeColumnWidth = 80.0;

  List<double> _columnWidths = List.filled(7, 150.0);
  Map<int, double> _rowHeights = {};

  double _rowHeight(int hour) => _rowHeights[hour] ?? 60.0;

  static const _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  static const _dayKeys = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

  static const _palette = [
    Color(0xFF4FC3F7), Color(0xFFEF5350), Color(0xFF66BB6A), Color(0xFFFFCA28),
    Color(0xFFAB47BC), Color(0xFFFF7043), Color(0xFF26C6DA), Color(0xFFEC407A),
    Color(0xFF8D6E63), Color(0xFF42A5F5), Color(0xFFFFA726), Color(0xFF26A69A),
    Color(0xFFD4E157), Color(0xFF7E57C2), Color(0xFF29B6F6), Color(0xFFFF5252),
    Color(0xFF69F0AE), Color(0xFFFFD740), Color(0xFFE040FB), Color(0xFF40C4FF),
  ];

  Map<String, Color> _buildColorMap(List<ScheduleBlockModel> blocks) {
    final subjects = blocks.map((b) => b.subject).toSet().toList()..sort();
    final map = <String, Color>{};
    for (int i = 0; i < subjects.length; i++) {
      map[subjects[i]] = _palette[i % _palette.length];
    }
    return map;
  }

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

  @override
  Widget build(BuildContext context) {
    if (widget.blocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            const Text(
              'NO SCHEDULES DETECTED',
              style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ],
        ),
      );
    }

    final colorMap = _buildColorMap(widget.blocks);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[850],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Drag headers to resize  ·  Pinch to zoom',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.grey[900],
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.3,
              maxScale: 2.0,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  child: Stack(
                    children: [
                      _buildGrid(),
                      ..._buildClassOverlays(widget.blocks, colorMap),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                child: Text('Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            ...List.generate(7, (dayIndex) {
              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _columnWidths[dayIndex] = (_columnWidths[dayIndex] + details.delta.dx).clamp(80.0, 300.0);
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
                        child: Text(_dayNames[dayIndex].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Positioned(
                        right: 0, top: 0, bottom: 0,
                        child: Container(width: 20, color: Colors.transparent, child: Center(child: Icon(Icons.drag_handle, color: Colors.grey[600], size: 14))),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        ...List.generate(_endHour - _startHour, (index) {
          final hour = _startHour + index;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeCell(hour),
              ...List.generate(7, (dayIndex) => _buildDayCell(dayIndex, hour)),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTimeCell(int hour) {
    final currentHeight = _rowHeight(hour);
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _rowHeights[hour] = (currentHeight + details.delta.dy).clamp(40.0, 150.0);
        });
      },
      child: Container(
        height: currentHeight,
        width: _timeColumnWidth,
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.6),
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
              child: Text(_formatHour(hour), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(height: 12, color: Colors.transparent, child: Center(child: Icon(Icons.drag_handle, color: Colors.grey[700], size: 10))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(int dayIndex, int hour) {
    return Container(
      height: _rowHeight(hour),
      width: _columnWidths[dayIndex],
      decoration: BoxDecoration(
        color: hour == 12 
            ? Colors.orange.withOpacity(0.15) 
            : Colors.grey[900]!.withOpacity(0.4),
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
    );
  }

  List<Widget> _buildClassOverlays(List<ScheduleBlockModel> blocks, Map<String, Color> colorMap) {
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
          onTap: () => context.push('/schedule/checkin/${block.blockId}'),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              border: Border.all(color: color.withOpacity(0.4), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${TimeUtils.toDisplayTime(block.startTime)}-${TimeUtils.toDisplayTime(block.endTime)}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    block.subject,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    block.instructor,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ROOM ${block.roomId}',
                    style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
