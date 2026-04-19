import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../models/schedule_block_model.dart';
import '../core/constants.dart';
import '../core/utils/time_utils.dart';
import 'notification_service.dart';
import 'room_usage_log_service.dart';

class ScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifService = NotificationService();
  final RoomUsageLogService _logService = RoomUsageLogService();

  /// Live stream of all active blocks for a mayor this semester, sorted by day → startTime.
  Stream<List<ScheduleBlockModel>> getMyBlocksStream(String mayorId) {
    return _db
        .collection('scheduleBlocks')
        .where('mayorId', isEqualTo: mayorId)
        .where('semester', isEqualTo: AppStrings.currentSemester)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final blocks = snap.docs.map(ScheduleBlockModel.fromFirestore).toList();
          const dayOrder = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          blocks.sort((a, b) {
            final dCmp = dayOrder
                .indexOf(a.dayOfWeek)
                .compareTo(dayOrder.indexOf(b.dayOfWeek));
            if (dCmp != 0) return dCmp;
            return a.startTime.compareTo(b.startTime);
          });
          return blocks;
        });
  }

  /// Live stream of today's blocks for a mayor, sorted by startTime.
  Stream<List<ScheduleBlockModel>> getTodayBlocksStream(
      String mayorId, String dayKey) {
    return _db
        .collection('scheduleBlocks')
        .where('mayorId', isEqualTo: mayorId)
        .where('dayOfWeek', isEqualTo: dayKey)
        .where('semester', isEqualTo: AppStrings.currentSemester)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final blocks = snap.docs.map(ScheduleBlockModel.fromFirestore).toList();
          blocks.sort((a, b) => a.startTime.compareTo(b.startTime));
          return blocks;
        });
  }

  /// Live stream of today's blocks assigned to a specific room (for room detail).
  Stream<List<ScheduleBlockModel>> getTodayRoomBlocksStream(
      String roomId, String dayKey) {
    return _db
        .collection('scheduleBlocks')
        .where('roomId', isEqualTo: roomId)
        .where('dayOfWeek', isEqualTo: dayKey)
        .where('semester', isEqualTo: AppStrings.currentSemester)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final blocks = snap.docs.map(ScheduleBlockModel.fromFirestore).toList();
          blocks.sort((a, b) => a.startTime.compareTo(b.startTime));
          return blocks;
        });
  }

  /// Live stream of ALL active blocks for a specific room (all days this semester).
  Stream<List<ScheduleBlockModel>> getRoomAllBlocksStream(String roomId) {
    const dayOrder = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return _db
        .collection('scheduleBlocks')
        .where('roomId', isEqualTo: roomId)
        .where('semester', isEqualTo: AppStrings.currentSemester)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final blocks = snap.docs.map(ScheduleBlockModel.fromFirestore).toList();
          blocks.sort((a, b) {
            final dCmp = dayOrder
                .indexOf(a.dayOfWeek)
                .compareTo(dayOrder.indexOf(b.dayOfWeek));
            if (dCmp != 0) return dCmp;
            return a.startTime.compareTo(b.startTime);
          });
          return blocks;
        });
  }

  /// One-time fetch of a single block.
  Future<ScheduleBlockModel?> getBlock(String blockId) async {
    final doc = await _db.collection('scheduleBlocks').doc(blockId).get();
    return doc.exists ? ScheduleBlockModel.fromFirestore(doc) : null;
  }

  /// Add a new block; Firestore generates the document ID.
  Future<void> addBlock(ScheduleBlockModel block) async {
    await _checkStaticConflict(block);
    final ref = _db.collection('scheduleBlocks').doc();
    await ref.set(block.copyWith(blockId: ref.id).toFirestore());
  }

  /// Update an existing block's editable metadata only (subject, instructor,
  /// dayOfWeek, roomId, startTime, endTime).
  /// Deliberately excludes checkInStatus, hasConflict, isActive, semester,
  /// mayorId, courseSection — those fields are managed elsewhere and must not
  /// be overwritten by an edit, which would risk clobbering concurrent changes
  /// or triggering security-rule rejections on protected fields.
    await _db
        .collection('scheduleBlocks')
        .doc(block.blockId)
        .update({
          'subject': block.subject,
          'instructor': block.instructor,
          'dayOfWeek': block.dayOfWeek,
          'roomId': block.roomId,
          'startTime': block.startTime,
          'endTime': block.endTime,
        });
  }

  /// Mark the next upcoming occurrence of this schedule as "No Class".
  Future<void> markNoClassToday(String blockId) async {
    final block = await getBlock(blockId);
    if (block == null) return;

    final nextDate = TimeUtils.getNextOccurrenceDate(block.dayOfWeek);
    await _db.collection('scheduleBlocks').doc(blockId).update({
      'noClassDate': nextDate,
    });
  }

  Future<void> _checkStaticConflict(ScheduleBlockModel newBlock) async {
    // 1. Check for Room Conflict (Any mayor in this room)
    if (newBlock.roomId != 'unassigned') {
      final roomSnap = await _db
          .collection('scheduleBlocks')
          .where('roomId', isEqualTo: newBlock.roomId)
          .where('dayOfWeek', isEqualTo: newBlock.dayOfWeek)
          .where('semester', isEqualTo: AppStrings.currentSemester)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in roomSnap.docs) {
        if (doc.id == newBlock.blockId) continue;
        final existing = ScheduleBlockModel.fromFirestore(doc);
        if (existing.startTime.compareTo(newBlock.endTime) < 0 &&
            newBlock.startTime.compareTo(existing.endTime) < 0) {
          
          if (existing.mayorId == newBlock.mayorId) {
            // Same user, same room - use the custom message
            throw ScheduleConflictException(
              message: 'You already have a schedule for ${existing.subject} at ${existing.startTime}-${existing.endTime} today. Double check your time schedule.',
              isOwnConflict: true,
            );
          } else {
            // Different user, same room - block and notify
            await _notifService.writeStaticConflictNotification(
              mayorIdA: newBlock.mayorId,
              mayorIdB: existing.mayorId,
              sectionA: newBlock.courseSection,
              sectionB: existing.courseSection,
              roomId: newBlock.roomId,
            );
            throw ScheduleConflictException(
              message: 'This room is already scheduled for ${existing.courseSection} at ${existing.startTime}-${existing.endTime}.',
              isOwnConflict: false,
            );
          }
        }
      }
    }

    // 2. Check for User Schedule Conflict (This mayor in ANY room)
    final mayorSnap = await _db
        .collection('scheduleBlocks')
        .where('mayorId', isEqualTo: newBlock.mayorId)
        .where('dayOfWeek', isEqualTo: newBlock.dayOfWeek)
        .where('semester', isEqualTo: AppStrings.currentSemester)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in mayorSnap.docs) {
      if (doc.id == newBlock.blockId) continue;
      // Skip if it's the same room, as we already checked that above
      if (doc['roomId'] == newBlock.roomId) continue;

      final existing = ScheduleBlockModel.fromFirestore(doc);
      if (existing.startTime.compareTo(newBlock.endTime) < 0 &&
          newBlock.startTime.compareTo(existing.endTime) < 0) {
        
        // Fetch room info to show the room number/name in the error message
        String roomDisplay = existing.roomId;
        try {
          final roomDoc = await _db.collection('rooms').doc(existing.roomId).get();
          if (roomDoc.exists) {
            roomDisplay = roomDoc.data()?['roomNumber'] ?? existing.roomId;
          }
        } catch (_) {}

        throw ScheduleConflictException(
          message: 'You already have a schedule for ${existing.subject} at ${existing.startTime}-${existing.endTime} at room $roomDisplay today. Double check your time schedule.',
          isOwnConflict: true,
        );
      }
    }
  }


  /// Hard-delete: permanently removes the document from Firestore.
  /// If the block was checked in, releases the room first so it doesn't
  /// stay stuck as occupied after the block is gone.
  Future<void> deleteBlock(String blockId) async {
    final doc = await _db.collection('scheduleBlocks').doc(blockId).get();
    if (!doc.exists) return;

    final block = ScheduleBlockModel.fromFirestore(doc);
    final batch = _db.batch();

    // Release the room if it was occupied by this block.
    if (block.checkInStatus == CheckInStatus.checkedIn) {
      batch.update(
        _db.collection('rooms').doc(block.roomId),
        {'status': 'available', 'currentOccupantBlockId': null},
      );
    }

    // Delete the document permanently.
    batch.delete(_db.collection('scheduleBlocks').doc(blockId));

    await batch.commit();
  }

  /// Duplicate all active blocks from [fromSemester] into the current semester.
  Future<void> duplicateSemesterBlocks({
    required String mayorId,
    required String fromSemester,
  }) async {
    final snap = await _db
        .collection('scheduleBlocks')
        .where('mayorId', isEqualTo: mayorId)
        .where('semester', isEqualTo: fromSemester)
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      final ref = _db.collection('scheduleBlocks').doc();
      final original = ScheduleBlockModel.fromFirestore(doc);
      batch.set(
        ref,
        original
            .copyWith(
              blockId: ref.id,
              semester: AppStrings.currentSemester,
              checkInStatus: CheckInStatus.pending,
              hasConflict: false,
            )
            .toFirestore(),
      );
    }
    await batch.commit();
  }

  /// Perform a check-in: marks the block as checked_in and claims the room.
  ///
  /// Returns null on success, or the occupying section name on conflict.
  ///
  /// On conflict this also:
  ///   1. Sets hasConflict = true on both the attempting block and the
  ///      occupying block.
  ///   2. Writes a conflict_detected notification routed to the council
  ///      president of the attempting mayor's department.
  ///
  /// The caller must supply [mayorId], [mayorSection], and [mayorDepartment]
  /// so this method can do the full flagging in one call without extra
  /// Firestore reads outside the service layer.
  Future<String?> attemptCheckIn({
    required String blockId,
    required String roomId,
    required String mayorId,
    required String mayorName,
    required String mayorSection,
    required String mayorDepartment,
  }) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final roomData = roomDoc.data()!;

    if (roomData['status'] == 'occupied' &&
        roomData['currentOccupantBlockId'] != null) {
      final occupyingBlockId = roomData['currentOccupantBlockId'] as String;

      // Fetch occupying block for section info.
      final occupyingDoc = await _db
          .collection('scheduleBlocks')
          .doc(occupyingBlockId)
          .get();

      final occupyingSection =
          occupyingDoc.exists
              ? (occupyingDoc['courseSection'] as String? ?? 'another section')
              : 'another section';

      // ── Flag both blocks as conflicting ──────────────────────────────
      final batch = _db.batch();
      batch.update(
        _db.collection('scheduleBlocks').doc(blockId),
        {'hasConflict': true},
      );
      if (occupyingDoc.exists) {
        batch.update(occupyingDoc.reference, {'hasConflict': true});
      }
      await batch.commit();

      // ── Write conflict notification (fire-and-forget; non-fatal) ─────
      try {
        await _notifService.writeConflictNotification(
          department: mayorDepartment,
          blockIdA: blockId,
          blockIdB: occupyingBlockId,
          roomId: roomId,
          sectionA: mayorSection,
          sectionB: occupyingSection,
        );
      } catch (_) {
        // Notification failure must never block the conflict UX.
      }

      return occupyingSection;
    }

    // ── No conflict — proceed with check-in ──────────────────────────
    final batch = _db.batch();
    batch.update(
      _db.collection('scheduleBlocks').doc(blockId),
      {'checkInStatus': 'checked_in'},
    );
    batch.update(
      _db.collection('rooms').doc(roomId),
      {'status': 'occupied', 'currentOccupantBlockId': blockId},
    );
    await batch.commit();

    // ── Auto-log the check-in to room usage logs ────────────────────
    try {
      final blockDoc = await _db.collection('scheduleBlocks').doc(blockId).get();
      if (blockDoc.exists) {
        final block = ScheduleBlockModel.fromFirestore(blockDoc);
        final now = DateTime.now();
        final dayFull = TimeUtils.dayLabel(TimeUtils.dayKey(now));
        final schedule =
            '${TimeUtils.toDisplayTime(block.startTime)}-${TimeUtils.toDisplayTime(block.endTime)}';
        await _logService.logUsage(
          roomId: roomId,
          mayorId: mayorId,
          mayorName: mayorName,
          courseSection: block.courseSection,
          subjectName: block.subject,
          schedule: schedule,
          dayOfWeek: dayFull,
          isBorrowed: false,
        );
      }
    } catch (_) {
      // Log failure must never block the check-in flow.
    }

    return null;
  }

  /// Borrow check-in: a mayor uses one of their schedule blocks to occupy
  /// a room that is NOT the block's assigned room.
  ///
  /// - Marks the block as checked_in
  /// - Sets the borrowed room as occupied with the block as occupant
  /// - Logs usage with isBorrowed = true
  ///
  /// Returns null on success, or error message on conflict.
  Future<String?> borrowCheckIn({
    required String blockId,
    required String borrowedRoomId,
    required String mayorId,
    required String mayorName,
  }) async {
    // Check if the borrowed room is already occupied
    final roomDoc = await _db.collection('rooms').doc(borrowedRoomId).get();
    final roomData = roomDoc.data()!;

    if (roomData['status'] == 'occupied') {
      return 'This room is currently occupied.';
    }

    // Fetch the block details
    final blockDoc = await _db.collection('scheduleBlocks').doc(blockId).get();
    if (!blockDoc.exists) return 'Schedule block not found.';
    final block = ScheduleBlockModel.fromFirestore(blockDoc);

    // Mark block as checked_in and set room as occupied
    final batch = _db.batch();
    batch.update(
      _db.collection('scheduleBlocks').doc(blockId),
      {'checkInStatus': 'checked_in'},
    );
    batch.update(
      _db.collection('rooms').doc(borrowedRoomId),
      {'status': 'occupied', 'currentOccupantBlockId': blockId},
    );
    await batch.commit();

    // Log usage with isBorrowed = true
    try {
      final now = DateTime.now();
      final dayFull = TimeUtils.dayLabel(TimeUtils.dayKey(now));
      final schedule =
          '${TimeUtils.toDisplayTime(block.startTime)}-${TimeUtils.toDisplayTime(block.endTime)}';
      await _logService.logUsage(
        roomId: borrowedRoomId,
        mayorId: mayorId,
        mayorName: mayorName,
        courseSection: block.courseSection,
        subjectName: block.subject,
        schedule: schedule,
        dayOfWeek: dayFull,
        isBorrowed: true,
      );
    } catch (_) {
      // Log failure must never block the borrow flow.
    }

    return null;
  }

  /// Early release: frees the room and marks the block as released.
  ///
  /// If the block had a conflict flag set, this also:
  ///   1. Clears hasConflict on both the releasing block and the other
  ///      conflicting block (if it can be identified).
  ///   2. Writes a conflict_resolved notification.
  ///
  /// The [roomId] parameter is used as a fallback; the method first queries
  /// for the room whose `currentOccupantBlockId` matches [blockId] so that
  /// borrowed rooms are released correctly (block.roomId still points to the
  /// original assigned room, not the borrowed one).
  Future<void> releaseRoom({
    required String blockId,
    required String roomId,
  }) async {
    // Fetch the block being released to check for an existing conflict.
    final releasingDoc =
        await _db.collection('scheduleBlocks').doc(blockId).get();
    final hadConflict =
        releasingDoc.exists && (releasingDoc['hasConflict'] as bool? ?? false);

    // Find the actual room occupied by this block (handles borrowed rooms).
    String actualRoomId = roomId;
    final occupiedSnap = await _db
        .collection('rooms')
        .where('currentOccupantBlockId', isEqualTo: blockId)
        .limit(1)
        .get();
    if (occupiedSnap.docs.isNotEmpty) {
      actualRoomId = occupiedSnap.docs.first.id;
    }

    final batch = _db.batch();
    batch.update(
      _db.collection('scheduleBlocks').doc(blockId),
      {'checkInStatus': 'released', 'hasConflict': false},
    );
    batch.update(
      _db.collection('rooms').doc(actualRoomId),
      {'status': 'available', 'currentOccupantBlockId': null},
    );
    await batch.commit();

    // ── Conflict auto-clear ───────────────────────────────────────────
    if (hadConflict) {
      try {
        // Find all other blocks for this room that still have hasConflict set.
        final conflictingSnap = await _db
            .collection('scheduleBlocks')
            .where('roomId', isEqualTo: roomId)
            .where('hasConflict', isEqualTo: true)
            .get();

        if (conflictingSnap.docs.isNotEmpty) {
          final clearBatch = _db.batch();
          for (final doc in conflictingSnap.docs) {
            clearBatch.update(doc.reference, {'hasConflict': false});
          }
          await clearBatch.commit();

          // Write resolved notification using the first other block found.
          final otherDoc = conflictingSnap.docs.first;
          final releasingBlock =
              ScheduleBlockModel.fromFirestore(releasingDoc);
          final otherBlock =
              ScheduleBlockModel.fromFirestore(otherDoc);

          await _notifService.writeResolvedNotification(
            blockIdA: blockId,
            blockIdB: otherDoc.id,
            roomId: roomId,
            sectionA: releasingBlock.courseSection,
            sectionB: otherBlock.courseSection,
          );
        }
      } catch (_) {
        // Notification/clear failure must never block the release flow.
      }
    }
  }
}

class ScheduleConflictException implements Exception {
  final String message;
  final bool isOwnConflict;
  ScheduleConflictException({required this.message, required this.isOwnConflict});

  @override
  String toString() => message;
}
