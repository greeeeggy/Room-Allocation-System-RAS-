import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/room_usage_log_model.dart';
import '../../providers/room_usage_log_provider.dart';

class RoomUsageLogScreen extends ConsumerWidget {
  final String roomId;
  final String roomNumber;
  const RoomUsageLogScreen({
    super.key,
    required this.roomId,
    required this.roomNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(roomUsageLogsProvider(roomId));

    return Scaffold(
      appBar: AppBar(title: Text('Room $roomNumber — Usage Log')),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'No usage logs for this room yet.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _LogCard(log: logs[index]),
          );
        },
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final RoomUsageLogModel log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMMM d, yyyy • h:mm a').format(log.checkedInAt);

    return Card(
      elevation: log.isBorrowed ? 3 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: log.isBorrowed
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Borrowed badge
            if (log.isBorrowed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Borrowed',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // Details rows
            _DetailRow(
                label: 'Course Year and Section', value: log.courseSection),
            const SizedBox(height: 6),
            _DetailRow(label: 'Subject Name', value: log.subjectName),
            const SizedBox(height: 6),
            _DetailRow(label: 'Schedule', value: log.schedule),
            const SizedBox(height: 6),
            _DetailRow(label: 'Mayor', value: log.mayorName),
            const SizedBox(height: 6),
            _DetailRow(label: 'Day', value: log.dayOfWeek),

            const SizedBox(height: 10),
            // Timestamp
            Text(
              formattedDate,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
