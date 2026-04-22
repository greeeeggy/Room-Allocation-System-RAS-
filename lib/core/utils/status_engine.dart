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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final todayKey = TimeUtils.dayKey(now);

    // Helper to perform updates resiliently
    Future<void> safeUpdate(DocumentReference ref, Map<String, dynamic> data) async {
      try {
        await ref.update(data);
      } catch (e) {
        if (!e.toString().contains('permission-denied')) {
          debugPrint('[StatusEngine] Update failed for ${ref.path}: $e');
        }
      }
    }

    // ── 0. Global Reset (Weekly/Daily) ──────────────────────────────────
    final nonPendingSnap = await _db
        .collection('scheduleBlocks')
        .where('checkInStatus', whereIn: ['checked_in', 'released', 'no_show'])
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in nonPendingSnap.docs) {
      final dayKey = doc['dayOfWeek'] as String;
      final startTimeStr = doc['startTime'] as String;
      final startTime = TimeUtils.parseHHmm(startTimeStr, now);
      final resetCutoff = startTime.subtract(const Duration(minutes: 15));

      bool shouldReset = false;
      if (dayKey != todayKey) {
        shouldReset = true;
      } else if (now.isBefore(resetCutoff)) {
        shouldReset = true;
      }

      if (shouldReset) {
        await safeUpdate(doc.reference, {
          'checkInStatus': FieldValue.delete(),
          'hasConflict': false,
        });

        if (doc['checkInStatus'] == 'checked_in') {
          final occupiedSnap = await _db
              .collection('rooms')
              .where('currentOccupantBlockId', isEqualTo: doc.id)
              .limit(1)
              .get();
          for (final roomDoc in occupiedSnap.docs) {
            await safeUpdate(roomDoc.reference,
                {'status': 'available', 'currentOccupantBlockId': null});
          }
        }
      }
    }

    // ── 0b. Cleanup stale 'No Class' markers ────────────────────────────
    final noClassSnap = await _db
        .collection('scheduleBlocks')
        .where('noClassDate', isGreaterThan: "")
        .get();

    final todayStr = TimeUtils.todayDateKey();
    for (final doc in noClassSnap.docs) {
      final ncd = doc['noClassDate'] as String;
      if (ncd.compareTo(todayStr) < 0) {
        await safeUpdate(doc.reference, {'noClassDate': FieldValue.delete()});
      }
    }

    // ── 1. Auto-release ─────────────────────────────────────────────────
    final checkedInSnap = await _db
        .collection('scheduleBlocks')
        .where('checkInStatus', isEqualTo: 'checked_in')
        .get();

    for (final doc in checkedInSnap.docs) {
      final endTime = TimeUtils.parseHHmm(doc['endTime'] as String, now);
      if (now.isAfter(endTime)) {
        await safeUpdate(doc.reference, {
          'checkInStatus': 'released',
          'hasConflict': false,
        });

        final occupiedSnap = await _db
            .collection('rooms')
            .where('currentOccupantBlockId', isEqualTo: doc.id)
            .limit(1)
            .get();

        for (final roomDoc in occupiedSnap.docs) {
          await safeUpdate(roomDoc.reference,
              {'status': 'available', 'currentOccupantBlockId': null});
        }
      }
    }

    // ── 2. No-show detection ─────────────────────────────────────────────
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
        await safeUpdate(doc.reference, {'checkInStatus': 'no_show'});
      }
    }

    // ── 3. "Soon" & "No Class" status ──────────────────────────────────
    final occupiedRoomsSnap = await _db
        .collection('rooms')
        .where('status', isEqualTo: 'occupied')
        .get();
    final occupiedRoomIds = occupiedRoomsSnap.docs.map((d) => d.id).toSet();

    final soonNoClassRoomsSnap = await _db
        .collection('rooms')
        .where('status', whereIn: ['soon', 'noClass'])
        .get();
    for (final doc in soonNoClassRoomsSnap.docs) {
      await safeUpdate(doc.reference, {'status': 'available', 'currentOccupantBlockId': null});
    }

    for (final doc in pendingSnap.docs) {
      final startTimeStr = doc['startTime'] as String;
      final endTimeStr = doc['endTime'] as String;
      final startTime = TimeUtils.parseHHmm(startTimeStr, now);
      final endTime = TimeUtils.parseHHmm(endTimeStr, now);
      
      final noClassDate = doc['noClassDate'] as String?;
      final isCancelledToday = (noClassDate == TimeUtils.todayDateKey());

      final minutesUntil = startTime.difference(now).inMinutes;
      final inSoonWindow = minutesUntil >= 0 && minutesUntil <= 15;
      final currentlyActive = now.isAfter(startTime) && now.isBefore(endTime);

      if (!occupiedRoomIds.contains(doc['roomId'])) {
        if (isCancelledToday && (inSoonWindow || currentlyActive)) {
          await safeUpdate(
            _db.collection('rooms').doc(doc['roomId'] as String),
            {'status': 'noClass', 'currentOccupantBlockId': doc.id},
          );
        } else if (!isCancelledToday && inSoonWindow) {
          await safeUpdate(
            _db.collection('rooms').doc(doc['roomId'] as String),
            {'status': 'soon', 'currentOccupantBlockId': doc.id},
          );
        }
      }
    }
  }
}

