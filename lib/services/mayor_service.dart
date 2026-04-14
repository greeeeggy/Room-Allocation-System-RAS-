import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/mayor_approval_model.dart';
import 'package:flutter/foundation.dart';

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
