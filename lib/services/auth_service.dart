import 'dart:convert';
import 'dart:io';
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

  /// Attempts to register a user.  If the email is already taken by an
  /// orphaned Firebase Auth account (Firestore user doc was deleted by a
  /// Council President), this method recovers the account by signing in
  /// and re-creating the Firestore user document.
  ///
  /// Handles four scenarios:
  ///   1. **Fresh email** → normal registration.
  ///   2. **Orphan + correct password** → sign in, re-create Firestore doc.
  ///   3. **Orphan + wrong password** → clear error with recovery guidance.
  ///   4. **Genuine duplicate** → standard "email already exists" error.
  Future<void> registerOrRecoverOrphan({
    required String email,
    required String password,
    required String name,
    required String role,
    required String department,
    String? courseSection,
  }) async {
    try {
      // Attempt normal registration first.
      await register(
        email: email,
        password: password,
        name: name,
        role: role,
        department: department,
        courseSection: courseSection,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;

      // ── email-already-in-use: sign in first, THEN check orphan ─────
      // We can't query Firestore unauthenticated (permission denied),
      // so we try to sign in with the provided password first.
      try {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Signed in successfully → now check if Firestore user doc exists.
        final userDoc = await _db
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (userDoc.exists) {
          // User doc exists → genuine duplicate account.
          // Sign out and tell the user.
          await _auth.signOut();
          throw Exception('An account with this email already exists. Please sign in instead.');
        }

        // No Firestore doc → ORPHAN DETECTED.
        // Re-create the Firestore user document using the signed-in UID.
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
        // User is now signed in with a fresh Firestore doc. Done!

      } on FirebaseAuthException catch (signInError) {
        // Sign-in failed — wrong password for the existing account.
        if (signInError.code == 'wrong-password' ||
            signInError.code == 'invalid-credential') {
          throw Exception(
            'This email was previously registered. '
            'Please sign in with your old password, '
            'or use "Forgot Password" on the login screen to reset it.',
          );
        }
        rethrow;
      }
    }
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

  // Update profile photo (Base64)
  Future<void> updateProfilePhoto(String userId, File photo) async {
    final bytes = await photo.readAsBytes();
    final base64 = base64Encode(bytes);
    
    await _db.collection('users').doc(userId).update({
      'photoURL': base64,
    });
  }
}
