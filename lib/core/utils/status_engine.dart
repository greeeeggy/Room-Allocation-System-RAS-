import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'time_utils.dart';

/// Runs client-side status logic on every app load/resume.
/// Handles: auto-release, no-show detection, and "soon" room marking.
/// All writes are batched into a single Firestore commit.
class StatusEngine {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _timer;

  /// Starts a repeating 1-minute timer that re-runs all status checks.
  /// This ensures rooms auto-release even when the app stays open past endTime.
  void startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        await runOnAppLoad();
      } catch (e) {
        debugPrint('[StatusEngine] periodic check failed: $e');
      }
    });
  }

  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> runOnAppLoad() async {
    // If no user is logged in, skip status checks to avoid permission errors.
    if (FirebaseAuth.instance.currentUser == null) return;

    final now = DateTime.now();
    final todayKey = TimeUtils.dayKey(now);
    final batch = _db.batch();
    bool hasPendingWrites = false;

    // ── 1. Auto-release ─────────────────────────────────────────────────
    // checked_in blocks whose endTime has passed → release room
    // Find the room by currentOccupantBlockId (works for both normal
    // and borrowed check-ins).
    final checkedInSnap = await _db
        .collection('scheduleBlocks')
        .where('checkInStatus', isEqualTo: 'checked_in')
        .get();

    for (final doc in checkedInSnap.docs) {
      final endTime = TimeUtils.parseHHmm(doc['endTime'] as String, now);
      if (now.isAfter(endTime)) {
        batch.update(doc.reference, {
          'checkInStatus': 'released',
          'hasConflict': false,
        });

        // Find the room occupied by this block (handles both normal
        // check-ins and borrowed rooms).
        final occupiedSnap = await _db
            .collection('rooms')
            .where('currentOccupantBlockId', isEqualTo: doc.id)
            .limit(1)
            .get();

        for (final roomDoc in occupiedSnap.docs) {
          batch.update(roomDoc.reference,
              {'status': 'available', 'currentOccupantBlockId': null});
        }

        hasPendingWrites = true;
      }
    }

    // ── 2. No-show detection ─────────────────────────────────────────────
    // pending blocks where startTime + 20 min has passed → mark no_show
    final pendingSnap = await _db
        .collection('scheduleBlocks')
        .where('checkInStatus', isEqualTo: 'pending')
        .where('dayOfWeek', isEqualTo: todayKey)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in pendingSnap.docs) {
      final startTime = TimeUtils.parseHHmm(doc['startTime'] as String, now);
      final noShowCutoff = startTime.add(const Duration(minutes: 20));
      if (now.isAfter(noShowCutoff)) {
        batch.update(doc.reference, {'checkInStatus': 'no_show'});
        hasPendingWrites = true;
      }
    }

    // ── 3. "Soon" & "No Class" status ──────────────────────────────────
    // 1. Identify currently occupied rooms so we don't overwrite them.
    final occupiedRoomsSnap = await _db
        .collection('rooms')
        .where('status', isEqualTo: 'occupied')
        .get();
    final occupiedRoomIds = occupiedRoomsSnap.docs.map((d) => d.id).toSet();

    // 2. Reset any rooms currently marked 'soon' or 'noClass' back to 'available',
    // then re-evaluate which rooms should be 'soon' or 'noClass' right now.
    final soonNoClassRoomsSnap = await _db
        .collection('rooms')
        .where('status', whereIn: ['soon', 'noClass'])
        .get();
    for (final doc in soonNoClassRoomsSnap.docs) {
      batch.update(doc.reference, {'status': 'available', 'currentOccupantBlockId': null});
      hasPendingWrites = true;
    }

    // Re-run the pending snap (already fetched above) to find blocks
    // starting within the next 15 minutes OR currently active but cancelled.
    for (final doc in pendingSnap.docs) {
      final startTimeStr = doc['startTime'] as String;
      final endTimeStr = doc['endTime'] as String;
      final startTime = TimeUtils.parseHHmm(startTimeStr, now);
      final endTime = TimeUtils.parseHHmm(endTimeStr, now);
      
      final noClassDate = doc['noClassDate'] as String?;
      final isCancelledToday = (noClassDate == TimeUtils.todayDateKey());

      // Logic for "Soon" notice window (starts 15 mins before)
      final minutesUntil = startTime.difference(now).inMinutes;
      final inSoonWindow = minutesUntil >= 0 && minutesUntil <= 15;
      
      // Logic for "Occupied" window (now between start and end)
      final currentlyActive = now.isAfter(startTime) && now.isBefore(endTime);

      // ONLY apply soon/noClass if the room is NOT currently occupied.
      if (!occupiedRoomIds.contains(doc['roomId'])) {
        if (isCancelledToday && (inSoonWindow || currentlyActive)) {
          // Mark as noClass notice
          batch.update(
            _db.collection('rooms').doc(doc['roomId'] as String),
            {'status': 'noClass', 'currentOccupantBlockId': doc.id},
          );
          hasPendingWrites = true;
        } else if (!isCancelledToday && inSoonWindow) {
          // Mark as soon
          batch.update(
            _db.collection('rooms').doc(doc['roomId'] as String),
            {'status': 'soon', 'currentOccupantBlockId': doc.id},
          );
          hasPendingWrites = true;
        }
      }
    }
    if (hasPendingWrites) {
      await batch.commit();
    }
  }
}

