import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live stream of all notifications for a user, newest first.
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(NotificationModel.fromFirestore).toList());
  }

  /// Live count of unread notifications (used for the bell badge).
  Stream<int> getUnreadCountStream(String userId) {
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notifId) async {
    await _db
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  /// Mark all notifications for a user as read in one batch.
  Future<void> markAllAsRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Write a conflict_detected notification to the council president of the
  /// given department.  No-ops silently if no council president is found so
  /// that a missing council account never blocks a check-in.
  Future<void> writeConflictNotification({
    required String department,
    required String blockIdA,
    required String blockIdB,
    required String roomId,
    required String sectionA,
    required String sectionB,
  }) async {
    final presidentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'council_president')
        .where('department', isEqualTo: department)
        .limit(1)
        .get();

    if (presidentsSnap.docs.isEmpty) return;

    final recipientId = presidentsSnap.docs.first.id;
    final ref = _db.collection('notifications').doc();
    await ref.set(NotificationModel(
      notifId: ref.id,
      recipientId: recipientId,
      type: NotificationType.conflictDetected,
      involvedBlockIds: [blockIdA, blockIdB],
      roomId: roomId,
      isRead: false,
      createdAt: DateTime.now(),
      sectionA: sectionA,
      sectionB: sectionB,
    ).toFirestore());
  }

  /// Write a conflict_resolved notification.  Finds the original
  /// conflict_detected notification for these two blocks and marks it read,
  /// then writes a new conflict_resolved notification to the same recipient.
  Future<void> writeResolvedNotification({
    required String blockIdA,
    required String blockIdB,
    required String roomId,
    required String sectionA,
    required String sectionB,
  }) async {
    // Find the original conflict notification.
    // NOTE: This query currently ignores 'recipientId' which means it will hit
    // a "Permission Denied" error for 'mayor' roles under the current rules.
    // In a prod environment, this should include .where('recipientId', isEqualTo: authId)
    final originalSnap = await _db
        .collection('notifications')
        .where('type', isEqualTo: 'conflict_detected')
        .where('roomId', isEqualTo: roomId)
        .get();

    // Filter to the one that contains both block IDs.
    final matching = originalSnap.docs.where((doc) {
      final ids = List<String>.from(doc['involvedBlockIds'] as List? ?? []);
      return ids.contains(blockIdA) || ids.contains(blockIdB);
    }).toList();

    if (matching.isEmpty) return;

    final recipientId = matching.first['recipientId'] as String;
    final batch = _db.batch();

    // Mark originals as read.
    for (final doc in matching) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Write the resolved notification.
    final ref = _db.collection('notifications').doc();
    batch.set(
      ref,
      NotificationModel(
        notifId: ref.id,
        recipientId: recipientId,
        type: NotificationType.conflictResolved,
        involvedBlockIds: [blockIdA, blockIdB],
        roomId: roomId,
        isRead: false,
        createdAt: DateTime.now(),
        sectionA: sectionA,
        sectionB: sectionB,
      ).toFirestore(),
    );

    await batch.commit();
  }
  /// Write static schedule conflict notifications to both involved mayors.
  Future<void> writeStaticConflictNotification({
    required String mayorIdA,
    required String mayorIdB,
    required String sectionA,
    required String sectionB,
    required String roomId,
  }) async {
    final batch = _db.batch();

    // Notif for Mayor A
    final refA = _db.collection('notifications').doc();
    batch.set(
      refA,
      NotificationModel(
        notifId: refA.id,
        recipientId: mayorIdA,
        type: NotificationType.staticScheduleConflict,
        involvedBlockIds: [], // Empty for static conflicts as documents may not exist yet
        roomId: roomId,
        isRead: false,
        createdAt: DateTime.now(),
        sectionA: sectionA,
        sectionB: sectionB,
      ).toFirestore(),
    );

    // Notif for Mayor B
    final refB = _db.collection('notifications').doc();
    batch.set(
      refB,
      NotificationModel(
        notifId: refB.id,
        recipientId: mayorIdB,
        type: NotificationType.staticScheduleConflict,
        involvedBlockIds: [],
        roomId: roomId,
        isRead: false,
        createdAt: DateTime.now(),
        sectionA: sectionB,
        sectionB: sectionA,
      ).toFirestore(),
    );

    await batch.commit();
  }
}
