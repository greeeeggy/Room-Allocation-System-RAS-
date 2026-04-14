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
    final checkedInSnap = await _db
        .collection('scheduleBlocks')
        .where('checkInStatus', isEqualTo: 'checked_in')
        .where('dayOfWeek', isEqualTo: todayKey)
        .get();

    for (final doc in checkedInSnap.docs) {
      final endTime = TimeUtils.parseHHmm(doc['endTime'] as String, now);
      if (now.isAfter(endTime)) {
        batch.update(doc.reference, {
          'checkInStatus': 'released',
          'hasConflict': false,
        });
        batch.update(
          _db.collection('rooms').doc(doc['roomId'] as String),
          {'status': 'available', 'currentOccupantBlockId': null},
        );
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

    // ── 3. "Soon" status ─────────────────────────────────────────────────
    // Reset any rooms currently marked 'soon' back to 'available',
    // then re-evaluate which rooms should be 'soon' right now.
    final soonRoomsSnap = await _db
        .collection('rooms')
        .where('status', isEqualTo: 'soon')
        .get();
    for (final doc in soonRoomsSnap.docs) {
      batch.update(doc.reference, {'status': 'available'});
      hasPendingWrites = true;
    }

    // Re-run the pending snap (already fetched above) to find blocks
    // starting within the next 15 minutes.
    for (final doc in pendingSnap.docs) {
      // Skip if this block was just marked no_show above
      final startTime = TimeUtils.parseHHmm(doc['startTime'] as String, now);
      final minutesUntil = startTime.difference(now).inMinutes;
      if (minutesUntil >= 0 && minutesUntil <= 15) {
        batch.update(
          _db.collection('rooms').doc(doc['roomId'] as String),
          {'status': 'soon'},
        );
        hasPendingWrites = true;
      }
    }

    if (hasPendingWrites) {
      await batch.commit();
    }
  }
}
