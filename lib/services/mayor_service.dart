import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/mayor_approval_model.dart';

class MayorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of approvals for a specific department.
  Stream<List<MayorApprovalModel>> getApprovalsStream(String department) {
    final normalizedDept = Departments.getAbbreviation(department);
    return _db
        .collection('mayor_approvals')
        .where('department', isEqualTo: normalizedDept)
        .snapshots()
        .map((snap) =>
            snap.docs.map(MayorApprovalModel.fromFirestore).toList());
  }

  /// Add or update a mayor approval.
  Future<void> addApproval({
    required String name,
    required String department,
    required String courseSection,
    required String councilPresidentId,
  }) async {
    final normalizedDept = Departments.getAbbreviation(department.trim());
    final id = '${normalizedDept}_$courseSection';

    // Verify the Council President's own department matches
    final presidentDoc = await _db.collection('users').doc(councilPresidentId).get();
    if (presidentDoc.exists) {
      final rawDept = presidentDoc.data()?['department'] ?? '';
      final presidentDept = Departments.getAbbreviation(rawDept);
      
      // 1. Check if they are managing their own department
      if (presidentDept != normalizedDept) {
        throw Exception('You cant authorize mayors not from your department (Your department: $rawDept)');
      }

      // 2. Check if the course section string matches their department (e.g., "BSIE 2-E" starts with "BSIE")
      if (!courseSection.toUpperCase().startsWith(presidentDept.toUpperCase())) {
        throw Exception('Section "$courseSection" does not belong to your department ($presidentDept)');
      }
    }

    // Check if there is already an authorized mayor for this section
    final doc = await _db.collection('mayor_approvals').doc(id).get();
    if (doc.exists) {
      final existing = MayorApprovalModel.fromFirestore(doc);
      if (existing.name.toLowerCase() != name.toLowerCase()) {
        throw Exception(
          'There is already an authorized mayor for this section ($courseSection). '
          'Please delete the existing entry first if you wish to change the mayor.'
        );
      }
    }

    final approval = MayorApprovalModel(
      id: id,
      name: name,
      department: normalizedDept,
      courseSection: courseSection,
      updatedAt: DateTime.now(),
      addedBy: councilPresidentId,
    );

    await _db.collection('mayor_approvals').doc(id).set(approval.toFirestore());
  }

  /// Delete an approval.
  Future<void> deleteApproval(String id) async {
    await _db.collection('mayor_approvals').doc(id).delete();
  }

  /// Completely remove a mayor from the system.
  ///
  /// Cascade-deletes all Firestore data associated with the mayor:
  ///   1. Releases any rooms currently occupied by the mayor
  ///   2. Deletes all schedule blocks (all semesters)
  ///   3. Deletes all room usage logs
  ///   4. Deletes all notifications
  ///   5. Deletes all lost item posts
  ///   6. Deletes all lost item messages
  ///   7. Deletes the user document
  ///   8. Deletes the mayor_approval entry
  ///
  /// The Firebase Auth account is intentionally left intact (no Admin SDK
  /// on the free Spark plan).  The registration flow handles orphaned
  /// accounts gracefully so the email can be re-used.
  Future<void> deleteMayorCompletely(MayorApprovalModel approval) async {
    // ── Step 1: Find the mayor's userId ────────────────────────────────
    final userSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'mayor')
        .where('department', isEqualTo: approval.department)
        .where('courseSection', isEqualTo: approval.courseSection)
        .limit(1)
        .get();

    final String? mayorUid =
        userSnap.docs.isNotEmpty ? userSnap.docs.first.id : null;

    if (mayorUid != null) {
      // ── Step 2: Release occupied rooms ────────────────────────────────
      final occupiedSnap = await _db
          .collection('scheduleBlocks')
          .where('mayorId', isEqualTo: mayorUid)
          .where('checkInStatus', isEqualTo: 'checked_in')
          .get();

      if (occupiedSnap.docs.isNotEmpty) {
        final releaseBatch = _db.batch();
        for (final doc in occupiedSnap.docs) {
          final roomId = doc.data()['roomId'] as String?;
          if (roomId != null && roomId.isNotEmpty) {
            releaseBatch.update(
              _db.collection('rooms').doc(roomId),
              {'status': 'available', 'currentOccupantBlockId': null},
            );
          }
        }
        await releaseBatch.commit();
      }

      // ── Step 3: Delete all schedule blocks ────────────────────────────
      await _batchDeleteQuery(
        _db.collection('scheduleBlocks').where('mayorId', isEqualTo: mayorUid),
      );

      // ── Step 4: Delete all room usage logs ────────────────────────────
      await _batchDeleteQuery(
        _db.collection('room_usage_logs').where('mayorId', isEqualTo: mayorUid),
      );

      // ── Step 5: Delete all notifications ──────────────────────────────
      await _batchDeleteQuery(
        _db.collection('notifications').where('recipientId', isEqualTo: mayorUid),
      );

      // ── Step 6: Delete all lost item posts ────────────────────────────
      // First get the item IDs so we can delete their messages too.
      final lostItemSnap = await _db
          .collection('lost_items')
          .where('posterId', isEqualTo: mayorUid)
          .get();

      for (final itemDoc in lostItemSnap.docs) {
        // Delete messages for this lost item
        await _batchDeleteQuery(
          _db.collection('lost_item_messages').where('itemId', isEqualTo: itemDoc.id),
        );
      }

      // Now delete the lost items themselves
      await _batchDeleteQuery(
        _db.collection('lost_items').where('posterId', isEqualTo: mayorUid),
      );

      // ── Step 7: Delete messages sent by this mayor (in other threads) ─
      await _batchDeleteQuery(
        _db.collection('lost_item_messages').where('senderId', isEqualTo: mayorUid),
      );

      // ── Step 8: Delete the user document ──────────────────────────────
      await _db.collection('users').doc(mayorUid).delete();
    }

    // ── Step 9: Delete the mayor_approval entry ─────────────────────────
    await _db.collection('mayor_approvals').doc(approval.id).delete();
  }

  /// Batch-deletes all documents matching [query] in chunks of 400.
  Future<void> _batchDeleteQuery(Query query) async {
    const batchSize = 400;
    while (true) {
      final snap = await query.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Validates if a mayor can register.
  /// Throws an exception if not authorized.
  Future<void> validateMayorRegistration({
    required String name,
    required String department,
    required String courseSection,
  }) async {
    final normalizedDept = Departments.getAbbreviation(department.trim());
    final id = '${normalizedDept}_$courseSection';
    final doc = await _db.collection('mayor_approvals').doc(id).get();

    if (!doc.exists) {
      throw Exception('No authorized mayor found for $normalizedDept $courseSection. Please contact your Council President.');
    }

    final approval = MayorApprovalModel.fromFirestore(doc);
    if (approval.name.toLowerCase() != name.toLowerCase()) {
      throw Exception('The name "$name" does not match the authorized mayor for this section.');
    }
  }
}

