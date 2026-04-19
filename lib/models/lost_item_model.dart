import 'package:cloud_firestore/cloud_firestore.dart';

class LostItemModel {
  final String itemId;
  final String objectName;
  final String roomFound;
  final String posterName;
  final String posterCourseSection;
  final String posterId;
  final List<String> imageUrls; // max 2
  final bool isClaimed;
  final DateTime createdAt;

  LostItemModel({
    required this.itemId,
    required this.objectName,
    required this.roomFound,
    required this.posterName,
    required this.posterCourseSection,
    required this.posterId,
    required this.imageUrls, // Can contain base64 strings or URLs
    required this.isClaimed,
    required this.createdAt,
  });

  /// Helper to determine if an image string is base64 data.
  bool isBase64(String image) => !image.startsWith('http');

  factory LostItemModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LostItemModel(
      itemId: d['itemId'] as String? ?? doc.id,
      objectName: d['objectName'] as String? ?? '',
      roomFound: d['roomFound'] as String? ?? '',
      posterName: d['posterName'] as String? ?? '',
      posterCourseSection: d['posterCourseSection'] as String? ?? '',
      posterId: d['posterId'] as String? ?? '',
      imageUrls: List<String>.from(d['imageUrls'] as List? ?? []),
      isClaimed: d['isClaimed'] as bool? ?? false,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'itemId': itemId,
        'objectName': objectName,
        'roomFound': roomFound,
        'posterName': posterName,
        'posterCourseSection': posterCourseSection,
        'posterId': posterId,
        'imageUrls': imageUrls,
        'isClaimed': isClaimed,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
