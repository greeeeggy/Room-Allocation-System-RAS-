import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class RoomModel {
  final String roomId;
  final String roomNumber;
  final int floor;
  final List<String> features;
  final RoomStatus status;
  final String? currentOccupantBlockId;

  // Grid position for isometric map (Phase 3)
  final int col;
  final int row;

  RoomModel({
    required this.roomId,
    required this.roomNumber,
    required this.floor,
    required this.features,
    required this.status,
    this.currentOccupantBlockId,
    this.col = 0,
    this.row = 0,
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      roomId: data['roomId'] ?? doc.id,
      roomNumber: data['roomNumber'] ?? '',
      floor: data['floor'] ?? 1,
      features: List<String>.from(data['features'] ?? []),
      status: _parseStatus(data['status']),
      currentOccupantBlockId: data['currentOccupantBlockId'],
      col: data['col'] ?? 0,
      row: data['row'] ?? 0,
    );
  }

  static RoomStatus _parseStatus(String? value) {
    switch (value) {
      case 'occupied': return RoomStatus.occupied;
      case 'soon':     return RoomStatus.soon;
      default:         return RoomStatus.available;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'roomId': roomId,
    'roomNumber': roomNumber,
    'floor': floor,
    'features': features,
    'status': status.name,
    'currentOccupantBlockId': currentOccupantBlockId,
    'col': col,
    'row': row,
  };
}
