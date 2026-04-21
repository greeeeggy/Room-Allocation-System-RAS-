import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class RoomModel {
  final String roomId;
  final String roomNumber;
  final int floor;
  final List<String> features;
  final RoomStatus status;
  final String? currentOccupantBlockId;
  final RoomType roomType;
  // For labs: the specific lab name (e.g. "IE Laboratory", "Computer Laboratory")
  final String? labType;

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
    this.roomType = RoomType.classroom,
    this.labType,
    this.col = 0,
    this.row = 0,
  });

  bool get isOffice => roomType == RoomType.office;
  bool get isLab => roomType == RoomType.laboratory;

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      roomId: data['roomId'] ?? doc.id,
      roomNumber: data['roomNumber'] ?? '',
      floor: data['floor'] ?? 1,
      features: List<String>.from(data['features'] ?? []),
      status: _parseStatus(data['status']),
      currentOccupantBlockId: data['currentOccupantBlockId'],
      roomType: _parseRoomType(data['roomType']),
      labType: data['labType'],
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

  static RoomType _parseRoomType(String? value) {
    switch (value) {
      case 'laboratory': return RoomType.laboratory;
      case 'office':     return RoomType.office;
      case 'unknown':    return RoomType.unknown;
      default:           return RoomType.classroom;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'roomId': roomId,
    'roomNumber': roomNumber,
    'floor': floor,
    'features': features,
    'status': status.name,
    'currentOccupantBlockId': currentOccupantBlockId,
    'roomType': roomType.name,
    'labType': labType,
    'col': col,
    'row': row,
  };
}
