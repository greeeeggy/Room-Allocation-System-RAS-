import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/lost_item_model.dart';
import '../models/lost_item_message_model.dart';

class LostItemService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Real-time stream of all active (unclaimed) lost items, newest first.
  Stream<List<LostItemModel>> getLostItemsStream() {
    return _db
        .collection('lost_items')
        .where('isClaimed', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LostItemModel.fromFirestore).toList());
  }

  /// Fetch a single lost item by ID.
  Future<LostItemModel?> getLostItem(String itemId) async {
    final doc = await _db.collection('lost_items').doc(itemId).get();
    if (!doc.exists) return null;
    return LostItemModel.fromFirestore(doc);
  }

  /// Convert image files to base64 strings.
  Future<List<String>> _convertToBase64(List<File> photos) async {
    final list = <String>[];
    for (final photo in photos) {
      final bytes = await photo.readAsBytes();
      final base64 = base64Encode(bytes);
      list.add(base64);
    }
    return list;
  }

  /// Post a new lost item, encoding photos to base64 first.
  Future<String> postLostItem({
    required String objectName,
    required String roomFound,
    required String posterName,
    required String posterCourseSection,
    required String posterId,
    required List<File> photos,
  }) async {
    final itemId = _uuid.v4();

    // Convert images to base64 (may be empty list)
    final imageUrls =
        photos.isNotEmpty ? await _convertToBase64(photos) : <String>[];

    final item = LostItemModel(
      itemId: itemId,
      objectName: objectName,
      roomFound: roomFound,
      posterName: posterName,
      posterCourseSection: posterCourseSection,
      posterId: posterId,
      imageUrls: imageUrls,
      isClaimed: false,
      createdAt: DateTime.now(),
    );

    await _db.collection('lost_items').doc(itemId).set(item.toFirestore());
    return itemId;
  }

  /// Real-time stream of messages for a specific lost item.
  Stream<List<LostItemMessageModel>> getMessagesStream(String itemId) {
    return _db
        .collection('lost_item_messages')
        .where('itemId', isEqualTo: itemId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map(LostItemMessageModel.fromFirestore).toList());
  }

  /// Send a new message in a lost item thread.
  Future<void> sendMessage({
    required String itemId,
    required String senderId,
    required String senderName,
    required String senderCourseSection,
    required String text,
  }) async {
    final msgId = _uuid.v4();
    final msg = LostItemMessageModel(
      messageId: msgId,
      itemId: itemId,
      senderId: senderId,
      senderName: senderName,
      senderCourseSection: senderCourseSection,
      text: text,
      createdAt: DateTime.now(),
    );
    await _db
        .collection('lost_item_messages')
        .doc(msgId)
        .set(msg.toFirestore());
  }

  /// Mark item as claimed and delete all its messages.
  Future<void> claimItem(String itemId) async {
    // 1. Mark as claimed
    await _db
        .collection('lost_items')
        .doc(itemId)
        .update({'isClaimed': true});

    // 2. Delete all messages for this item
    final msgSnap = await _db
        .collection('lost_item_messages')
        .where('itemId', isEqualTo: itemId)
        .get();

    if (msgSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in msgSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
