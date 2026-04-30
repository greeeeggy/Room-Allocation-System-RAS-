import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class BugReportModel {
  final String reportId;
  final String submitterId;
  final String submitterName;
  final String submitterRole;
  final String title;
  final String description;
  final String? imageBase64;
  final BugStatus status;
  final DateTime createdAt;

  BugReportModel({
    required this.reportId,
    required this.submitterId,
    required this.submitterName,
    required this.submitterRole,
    required this.title,
    required this.description,
    this.imageBase64,
    required this.status,
    required this.createdAt,
  });

  factory BugReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BugReportModel(
      reportId: doc.id,
      submitterId: data['submitterId'] ?? '',
      submitterName: data['submitterName'] ?? '',
      submitterRole: data['submitterRole'] ?? 'mayor',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageBase64: data['imageBase64'],
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'submitterId': submitterId,
    'submitterName': submitterName,
    'submitterRole': submitterRole,
    'title': title,
    'description': description,
    'imageBase64': imageBase64,
    'status': statusToString(status),
    'createdAt': FieldValue.serverTimestamp(),
  };

  static BugStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'in_progress':
        return BugStatus.inProgress;
      case 'resolved':
        return BugStatus.resolved;
      case 'open':
      default:
        return BugStatus.open;
    }
  }

  static String statusToString(BugStatus status) {
    switch (status) {
      case BugStatus.inProgress:
        return 'in_progress';
      case BugStatus.resolved:
        return 'resolved';
      case BugStatus.open:
        return 'open';
    }
  }

  /// Human-readable role label for display.
  String get roleLabel {
    switch (submitterRole) {
      case 'council_president':
        return 'Council President';
      case 'engineering_council_president':
        return 'Eng. Council President';
      default:
        return 'Mayor';
    }
  }
}
