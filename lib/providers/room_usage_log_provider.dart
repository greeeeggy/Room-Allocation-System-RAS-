import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/room_usage_log_service.dart';
import '../models/room_usage_log_model.dart';

final roomUsageLogServiceProvider =
    Provider<RoomUsageLogService>((ref) => RoomUsageLogService());

/// Live stream of usage logs for a specific room.
final roomUsageLogsProvider =
    StreamProvider.family<List<RoomUsageLogModel>, String>((ref, roomId) {
  return ref.watch(roomUsageLogServiceProvider).getLogsStream(roomId);
});
