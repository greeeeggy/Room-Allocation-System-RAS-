import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/bug_report_model.dart';

class BugReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'bugReports';

  /// Submits a new bug report.
  Future<void> submitBugReport({
    required String submitterId,
    required String submitterName,
    required String submitterRole,
    required String title,
    required String description,
    String? imageBase64,
  }) async {
    await _db.collection(_collection).add({
      'submitterId': submitterId,
      'submitterName': submitterName,
      'submitterRole': submitterRole,
      'title': title,
      'description': description,
      'imageBase64': imageBase64,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Streams all bug reports ordered by most recent first.
  Stream<List<BugReportModel>> allBugReports() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BugReportModel.fromFirestore(d)).toList());
  }

  /// Updates the status of a bug report (admin only).
  Future<void> updateStatus(String reportId, BugStatus status) async {
    await _db.collection(_collection).doc(reportId).update({
      'status': BugReportModel.statusToString(status),
    });
  }

  /// Deletes a bug report (admin only).
  Future<void> deleteReport(String reportId) async {
    await _db.collection(_collection).doc(reportId).delete();
  }

  /// Streams bug reports submitted by a specific user.
  Stream<List<BugReportModel>> myBugReports(String userId) {
    return _db
        .collection(_collection)
        .where('submitterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BugReportModel.fromFirestore(d)).toList());
  }
}
