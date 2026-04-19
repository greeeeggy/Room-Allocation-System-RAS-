import 'package:cloud_firestore/cloud_firestore.dart';

class LostItemMessageModel {
  final String messageId;
  final String itemId;
  final String senderId;
  final String senderName;
  final String senderCourseSection;
  final String text;
  final DateTime createdAt;

  LostItemMessageModel({
    required this.messageId,
    required this.itemId,
    required this.senderId,
    required this.senderName,
    required this.senderCourseSection,
    required this.text,
    required this.createdAt,
  });

  factory LostItemMessageModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LostItemMessageModel(
      messageId: d['messageId'] as String? ?? doc.id,
      itemId: d['itemId'] as String? ?? '',
      senderId: d['senderId'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      senderCourseSection: d['senderCourseSection'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'messageId': messageId,
        'itemId': itemId,
        'senderId': senderId,
        'senderName': senderName,
        'senderCourseSection': senderCourseSection,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
