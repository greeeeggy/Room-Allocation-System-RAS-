import 'package:cloud_firestore/cloud_firestore.dart';

class RoomUsageLogModel {
  final String logId;
  final String roomId;
  final String mayorId;
  final String mayorName;
  final String courseSection;
  final String subjectName;
  final String schedule;
  final String dayOfWeek;
  final bool isBorrowed;
  final DateTime checkedInAt;

  RoomUsageLogModel({
    required this.logId,
    required this.roomId,
    required this.mayorId,
    required this.mayorName,
    required this.courseSection,
    required this.subjectName,
    required this.schedule,
    required this.dayOfWeek,
    required this.isBorrowed,
    required this.checkedInAt,
  });

  factory RoomUsageLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomUsageLogModel(
      logId: data['logId'] as String? ?? doc.id,
      roomId: data['roomId'] as String? ?? '',
      mayorId: data['mayorId'] as String? ?? '',
      mayorName: data['mayorName'] as String? ?? '',
      courseSection: data['courseSection'] as String? ?? '',
      subjectName: data['subjectName'] as String? ?? '',
      schedule: data['schedule'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as String? ?? '',
      isBorrowed: data['isBorrowed'] as bool? ?? false,
      checkedInAt:
          (data['checkedInAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'logId': logId,
        'roomId': roomId,
        'mayorId': mayorId,
        'mayorName': mayorName,
        'courseSection': courseSection,
        'subjectName': subjectName,
        'schedule': schedule,
        'dayOfWeek': dayOfWeek,
        'isBorrowed': isBorrowed,
        'checkedInAt': FieldValue.serverTimestamp(),
      };
}
