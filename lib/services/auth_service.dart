import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Current Firebase user (raw)
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Stream of UserModel for the logged-in user
  Stream<UserModel?> get currentUserStream {
    return _auth.authStateChanges().asyncExpand((user) async* {
      if (user == null) {
        yield null;
      } else {
        try {
          final stream = _db
              .collection('users')
              .doc(user.uid)
              .snapshots()
              .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);

          await for (final userModel in stream) {
            // Self-healing: Automatically normalize department if it's a legacy/full name
            if (userModel != null) {
              final normalized = Departments.getAbbreviation(userModel.department);
              if (normalized != userModel.department) {
                print('[AuthService] Normalizing user profile department: '
                    '${userModel.department} -> $normalized');
                _db.collection('users').doc(user.uid).update({'department': normalized});
              }
            }
            yield userModel;
          }
        } catch (e) {
          // If we hit a permission error (common during sign-out transition),
          // yield null to signal that we are no longer authenticated.
          if (e.toString().contains('permission-denied') ||
              e.toString().contains('PERMISSION_DENIED')) {
            yield null;
          } else {
            rethrow;
          }
        }
      }
    });
  }

  // Register new user
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String department,
    String? courseSection,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final normalizedDept = Departments.getAbbreviation(department);

    await _db.collection('users').doc(cred.user!.uid).set({
      'userId': cred.user!.uid,
      'name': name,
      'email': email,
      'role': role,
      'department': normalizedDept,
      'courseSection': courseSection,
      'createdAt': FieldValue.serverTimestamp(),
      'photoURL': cred.user!.photoURL,
    });
  }

  // Login
  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
