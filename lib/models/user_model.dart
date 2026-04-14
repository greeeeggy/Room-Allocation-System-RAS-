import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final UserRole role;
  final String department;
  final String? courseSection; // mayors only
  final DateTime createdAt;
  final String? photoURL;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.courseSection,
    required this.createdAt,
    this.photoURL,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: data['userId'] ?? doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] == 'council_president'
          ? UserRole.councilPresident
          : UserRole.mayor,
      department: data['department'] ?? '',
      courseSection: data['courseSection'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoURL: data['photoURL'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'name': name,
    'email': email,
    'role': role == UserRole.councilPresident ? 'council_president' : 'mayor',
    'department': department,
    'courseSection': courseSection,
    'createdAt': FieldValue.serverTimestamp(),
  };

  bool get isMayor => role == UserRole.mayor;
  bool get isCouncilPresident => role == UserRole.councilPresident;
}
