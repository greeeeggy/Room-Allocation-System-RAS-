import 'package:cloud_firestore/cloud_firestore.dart';

class MayorApprovalModel {
  final String id; // department_courseSection
  final String name;
  final String department;
  final String courseSection;
  final DateTime updatedAt;
  final String addedBy;

  MayorApprovalModel({
    required this.id,
    required this.name,
    required this.department,
    required this.courseSection,
    required this.updatedAt,
    required this.addedBy,
  });

  factory MayorApprovalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MayorApprovalModel(
      id: doc.id,
      name: data['name'] ?? '',
      department: data['department'] ?? '',
      courseSection: data['courseSection'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedBy: data['addedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'department': department,
        'courseSection': courseSection,
        'updatedAt': FieldValue.serverTimestamp(),
        'addedBy': addedBy,
      };
}
