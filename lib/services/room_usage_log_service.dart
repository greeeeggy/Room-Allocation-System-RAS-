import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_usage_log_model.dart';

class RoomUsageLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Logs a room usage entry.
  ///
  /// [isBorrowed] should be `true` when the mayor is using a room that is NOT
  /// part of their assigned schedule (i.e. the "Use This Room" flow).
  /// For normal check-ins via the schedule, pass `false`.
  Future<void> logUsage({
    required String roomId,
    required String mayorId,
    required String mayorName,
    required String courseSection,
    required String subjectName,
    required String schedule,
    required String dayOfWeek,
    required bool isBorrowed,
  }) async {
    final ref = _db.collection('room_usage_logs').doc();
    final log = RoomUsageLogModel(
      logId: ref.id,
      roomId: roomId,
      mayorId: mayorId,
      mayorName: mayorName,
      courseSection: courseSection,
      subjectName: subjectName,
      schedule: schedule,
      dayOfWeek: dayOfWeek,
      isBorrowed: isBorrowed,
      checkedInAt: DateTime.now(), // server timestamp used in toFirestore()
    );
    await ref.set(log.toFirestore());
  }

  /// Live stream of usage logs for a specific room, newest first.
  Stream<List<RoomUsageLogModel>> getLogsStream(String roomId) {
    return _db
        .collection('room_usage_logs')
        .where('roomId', isEqualTo: roomId)
        .orderBy('checkedInAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(RoomUsageLogModel.fromFirestore).toList());
  }
}
