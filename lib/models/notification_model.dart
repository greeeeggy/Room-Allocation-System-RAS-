import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { conflictDetected, conflictResolved, staticScheduleConflict, lostItemPosted }

class NotificationModel {
  final String notifId;
  final String recipientId;
  final NotificationType type;
  final List<String> involvedBlockIds;
  final String roomId;
  final bool isRead;
  final DateTime createdAt;

  // Denormalized fields written at creation time for display purposes
  final String? sectionA;   // first conflicting section
  final String? sectionB;   // second conflicting section

  // Lost & Found navigation reference
  final String? lostItemId;
  final String? lostItemMessage;

  NotificationModel({
    required this.notifId,
    required this.recipientId,
    required this.type,
    required this.involvedBlockIds,
    required this.roomId,
    required this.isRead,
    required this.createdAt,
    this.sectionA,
    this.sectionB,
    this.lostItemId,
    this.lostItemMessage,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notifId: d['notifId'] as String? ?? doc.id,
      recipientId: d['recipientId'] as String? ?? '',
      type: _parseType(d['type'] as String?),
      involvedBlockIds:
          List<String>.from(d['involvedBlockIds'] as List? ?? []),
      roomId: d['roomId'] as String? ?? '',
      isRead: d['isRead'] as bool? ?? false,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sectionA: d['sectionA'] as String?,
      sectionB: d['sectionB'] as String?,
      lostItemId: d['lostItemId'] as String?,
      lostItemMessage: d['lostItemMessage'] as String?,
    );
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'conflict_resolved':
        return NotificationType.conflictResolved;
      case 'static_schedule_conflict':
        return NotificationType.staticScheduleConflict;
      case 'lost_item_posted':
        return NotificationType.lostItemPosted;
      default:
        return NotificationType.conflictDetected;
    }
  }

  String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.conflictResolved:
        return 'conflict_resolved';
      case NotificationType.staticScheduleConflict:
        return 'static_schedule_conflict';
      case NotificationType.lostItemPosted:
        return 'lost_item_posted';
      case NotificationType.conflictDetected:
        return 'conflict_detected';
    }
  }

  Map<String, dynamic> toFirestore() => {
        'notifId': notifId,
        'recipientId': recipientId,
        'type': _typeToString(type),
        'involvedBlockIds': involvedBlockIds,
        'roomId': roomId,
        'isRead': isRead,
        'createdAt': FieldValue.serverTimestamp(),
        'sectionA': sectionA,
        'sectionB': sectionB,
        'lostItemId': lostItemId,
        'lostItemMessage': lostItemMessage,
      };
}
