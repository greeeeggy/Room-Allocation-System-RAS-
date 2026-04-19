import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class ScheduleBlockModel {
  final String blockId;
  final String mayorId;
  final String subject;
  final String instructor;
  final String courseSection;
  final String roomId;
  final String dayOfWeek; // 'M', 'T', 'W', 'Th', 'F', 'S'
  final String startTime; // HH:mm 24h
  final String endTime;   // HH:mm 24h
  final String semester;  // e.g. '2025-2'
  final bool isActive;
  final CheckInStatus checkInStatus;
  final bool hasConflict;
  final String? noClassDate; // yyyy-MM-dd

  ScheduleBlockModel({
    required this.blockId,
    required this.mayorId,
    required this.subject,
    required this.instructor,
    required this.courseSection,
    required this.roomId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.semester,
    required this.isActive,
    required this.checkInStatus,
    required this.hasConflict,
    this.noClassDate,
  });

  factory ScheduleBlockModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleBlockModel(
      blockId: data['blockId'] as String? ?? doc.id,
      mayorId: data['mayorId'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      instructor: data['instructor'] as String? ?? '',
      courseSection: data['courseSection'] as String? ?? '',
      roomId: data['roomId'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as String? ?? 'M',
      startTime: data['startTime'] as String? ?? '07:00',
      endTime: data['endTime'] as String? ?? '08:00',
      semester: data['semester'] as String? ?? AppStrings.currentSemester,
      isActive: data['isActive'] as bool? ?? true,
      checkInStatus: _parseCheckInStatus(data['checkInStatus'] as String?),
      hasConflict: data['hasConflict'] as bool? ?? false,
      noClassDate: data['noClassDate'] as String?,
    );
  }

  static CheckInStatus _parseCheckInStatus(String? v) {
    switch (v) {
      case 'checked_in': return CheckInStatus.checkedIn;
      case 'released':   return CheckInStatus.released;
      case 'no_show':    return CheckInStatus.noShow;
      default:           return CheckInStatus.pending;
    }
  }

  static String _checkInStatusToString(CheckInStatus s) {
    switch (s) {
      case CheckInStatus.checkedIn: return 'checked_in';
      case CheckInStatus.released:  return 'released';
      case CheckInStatus.noShow:    return 'no_show';
      case CheckInStatus.pending:   return 'pending';
    }
  }

  Map<String, dynamic> toFirestore() => {
    'blockId': blockId,
    'mayorId': mayorId,
    'subject': subject,
    'instructor': instructor,
    'courseSection': courseSection,
    'roomId': roomId,
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'semester': semester,
    'isActive': isActive,
    'checkInStatus': _checkInStatusToString(checkInStatus),
    'hasConflict': hasConflict,
    'noClassDate': noClassDate,
  };

  ScheduleBlockModel copyWith({
    String? blockId,
    String? mayorId,
    String? subject,
    String? instructor,
    String? courseSection,
    String? roomId,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? semester,
    bool? isActive,
    CheckInStatus? checkInStatus,
    bool? hasConflict,
    String? noClassDate,
  }) {
    return ScheduleBlockModel(
      blockId: blockId ?? this.blockId,
      mayorId: mayorId ?? this.mayorId,
      subject: subject ?? this.subject,
      instructor: instructor ?? this.instructor,
      courseSection: courseSection ?? this.courseSection,
      roomId: roomId ?? this.roomId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      semester: semester ?? this.semester,
      isActive: isActive ?? this.isActive,
      checkInStatus: checkInStatus ?? this.checkInStatus,
      hasConflict: hasConflict ?? this.hasConflict,
      noClassDate: noClassDate ?? this.noClassDate,
    );
  }
}
