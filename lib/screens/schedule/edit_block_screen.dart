import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/time_utils.dart';
import '../../models/schedule_block_model.dart';
import '../../providers/room_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/schedule_service.dart';

class EditBlockScreen extends ConsumerStatefulWidget {
  final String blockId;
  const EditBlockScreen({super.key, required this.blockId});

  @override
  ConsumerState<EditBlockScreen> createState() => _EditBlockScreenState();
}

class _EditBlockScreenState extends ConsumerState<EditBlockScreen> {
  final _formKey = GlobalKey<FormState>();

  final _subjectCtrl = TextEditingController();
  final _instructorCtrl = TextEditingController();
  String _selectedDay = 'Mon';
  String? _selectedRoomId;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);

  bool _loaded = false;
  bool _saving = false;
  bool _deleting = false;
  ScheduleBlockModel? _original;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _instructorCtrl.dispose();
    super.dispose();
  }

  void _loadBlock(ScheduleBlockModel block) {
    if (_loaded) return;
    _loaded = true;
    _original = block;
    _subjectCtrl.text = block.subject;
    _instructorCtrl.text = block.instructor;
    _selectedDay = block.dayOfWeek;
    _selectedRoomId = block.roomId;
    final startParts = block.startTime.split(':');
    final endParts = block.endTime.split(':');
    _startTime = TimeOfDay(
        hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
    _endTime = TimeOfDay(
        hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room.')),
      );
      return;
    }
    if (_original == null) return;

    setState(() => _saving = true);

    final updated = _original!.copyWith(
      subject: _subjectCtrl.text.trim(),
      instructor: _instructorCtrl.text.trim(),
      dayOfWeek: _selectedDay,
      roomId: _selectedRoomId,
      startTime: TimeUtils.timeOfDayToHHmm(_startTime),
      endTime: TimeUtils.timeOfDayToHHmm(_endTime),
    );

    try {
      await ref.read(scheduleServiceProvider).updateBlock(updated);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        final message = e is ScheduleConflictException ? e.message : 'Error: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Block'),
        content: const Text(
            'This block will be archived and removed from your schedule. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(scheduleServiceProvider).deleteBlock(widget.blockId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(myBlocksProvider);
    final roomsAsync = ref.watch(allRoomsProvider);

    // Pre-fill form when blocks load
    blocksAsync.whenData((blocks) {
      final match = blocks.where((b) => b.blockId == widget.blockId).firstOrNull;
      if (match != null) _loadBlock(match);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Block'),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Subject
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject / Course Name',
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Instructor
              TextFormField(
                controller: _instructorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructor Name',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Day
              const Text('Day of Week',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _days
                    .map((d) => ChoiceChip(
                          label: Text(d),
                          selected: _selectedDay == d,
                          onSelected: (_) =>
                              setState(() => _selectedDay = d),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _selectedDay == d
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Time pickers
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: 'Start Time',
                      time: _startTime,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeTile(
                      label: 'End Time',
                      time: _endTime,
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Room picker
              const Text('Room',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              roomsAsync.when(
                data: (rooms) => DropdownButtonFormField<String>(
                  value: _selectedRoomId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                    labelText: 'Select Room',
                  ),
                  items: rooms
                      .map((r) => DropdownMenuItem(
                            value: r.roomId,
                            child: Text('${r.roomNumber} (Floor ${r.floor})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRoomId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeTile(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hhmm =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final display = TimeUtils.toDisplayTime(hhmm);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(display,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
