import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';

/// Service for destructive administrative operations.
///
/// • [deleteAllFirebaseData] — wipes every document in every known collection.
///   Used exclusively by the Engineering Council President at end-of-year.
/// • [deleteAllMySchedules] — removes all schedule blocks for a single mayor
///   in the current semester.  Used by mayors at end-of-semester.
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All Firestore collections that should be wiped during a full reset.
  static const _collections = [
    'users',
    'scheduleBlocks',
    'rooms',
    'notifications',
    'mayorApprovals',
    'lostItems',
    'lostItemMessages',
    'roomUsageLogs',
  ];

  // ── End of School Year (full system reset) ──────────────────────────

  /// Deletes every document in every known Firestore collection.
  ///
  /// Firestore WriteBatch has a 500-operation limit, so we batch-delete
  /// in chunks of 400 to stay comfortably below the cap.
  Future<void> deleteAllFirebaseData() async {
    for (final collection in _collections) {
      await _deleteCollection(collection);
    }
  }

  Future<void> _deleteCollection(String collectionPath) async {
    const batchSize = 400;
    while (true) {
      final snap = await _db
          .collection(collectionPath)
          .limit(batchSize)
          .get();

      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Signs the current user out after all data has been deleted.
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // ── End of Semester (mayor self-wipe) ───────────────────────────────

  /// Deletes all schedule blocks for [mayorId] in the current semester.
  ///
  /// Also releases any rooms that were occupied by those blocks so rooms
  /// don't stay stuck as "occupied" after the schedules are gone.
  Future<void> deleteAllMySchedules(String mayorId) async {
    const batchSize = 400;

    while (true) {
      final snap = await _db
          .collection('scheduleBlocks')
          .where('mayorId', isEqualTo: mayorId)
          .where('semester', isEqualTo: AppStrings.currentSemester)
          .limit(batchSize)
          .get();

      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        final data = doc.data();

        // Release occupied rooms
        if (data['checkInStatus'] == 'checked_in' && data['roomId'] != null) {
          batch.update(
            _db.collection('rooms').doc(data['roomId']),
            {'status': 'available', 'currentOccupantBlockId': null},
          );
        }

        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
