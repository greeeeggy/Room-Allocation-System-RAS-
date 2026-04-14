import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/schedule_service.dart';
import '../models/schedule_block_model.dart';
import '../core/constants.dart';
import '../core/utils/time_utils.dart';
import 'auth_provider.dart';

final scheduleServiceProvider =
    Provider<ScheduleService>((ref) => ScheduleService());

/// All active schedule blocks for the logged-in mayor this semester.
final myBlocksProvider = StreamProvider<List<ScheduleBlockModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !user.isMayor) return const Stream.empty();
  return ref
      .watch(scheduleServiceProvider)
      .getMyBlocksStream(user.userId)
      .handleError((error) {
    if (error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED')) {
      return;
    }
    throw error;
  });
});

/// Today's blocks for the logged-in mayor (filtered by weekday).
final todayBlocksProvider = StreamProvider<List<ScheduleBlockModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !user.isMayor) return const Stream.empty();
  final dayKey = TimeUtils.dayKey(DateTime.now());
  return ref
      .watch(scheduleServiceProvider)
      .getTodayBlocksStream(user.userId, dayKey)
      .handleError((error) {
    if (error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED')) {
      return;
    }
    throw error;
  });
});

/// The next upcoming (or active) block for the logged-in mayor today.
/// Used by the dashboard "My Next Class" card.
final nextClassProvider = Provider<ScheduleBlockModel?>((ref) {
  final todayBlocks = ref.watch(todayBlocksProvider).valueOrNull ?? [];
  final now = DateTime.now();

  // Find blocks that haven't ended yet and haven't been no-showed or released
  final upcoming = todayBlocks.where((b) {
    if (b.checkInStatus == CheckInStatus.released ||
        b.checkInStatus == CheckInStatus.noShow) {
      return false;
    }
    final end = TimeUtils.parseHHmm(b.endTime, now);
    return now.isBefore(end);
  }).toList();

  if (upcoming.isEmpty) return null;

  // Return the block with the earliest startTime
  upcoming.sort(
      (a, b) => a.startTime.compareTo(b.startTime));
  return upcoming.first;
});
