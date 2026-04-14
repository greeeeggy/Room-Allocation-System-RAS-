import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class CouncilService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live stream of all registered users (Mayors and Presidents).
  Stream<List<UserModel>> getUsersStream() {
    return _db
        .collection('users')
        .orderBy('department')
        .snapshots()
        .map((snap) =>
            snap.docs.map(UserModel.fromFirestore).toList());
  }

  // Seeding logic removed as per user request.
}
