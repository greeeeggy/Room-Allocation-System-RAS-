import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../core/constants.dart';

class RoomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Live stream of all rooms
  // Sorting is done client-side to avoid requiring a composite Firestore index.
  Stream<List<RoomModel>> getRoomsStream() {
    return _db
        .collection('rooms')
        .snapshots()
        .map((snap) {
          final rooms = snap.docs.map(RoomModel.fromFirestore).toList();
          rooms.sort((a, b) {
            final floorCmp = b.floor.compareTo(a.floor);
            if (floorCmp != 0) return floorCmp;
            return a.roomNumber.compareTo(b.roomNumber);
          });
          return rooms;
        });
  }

  // Live stream filtered by floor
  Stream<List<RoomModel>> getRoomsByFloor(int floor) {
    return _db
        .collection('rooms')
        .where('floor', isEqualTo: floor)
        .orderBy('roomNumber')
        .snapshots()
        .map((snap) => snap.docs.map(RoomModel.fromFirestore).toList());
  }

  // One-time fetch of a single room
  Future<RoomModel?> getRoom(String roomId) async {
    final doc = await _db.collection('rooms').doc(roomId).get();
    return doc.exists ? RoomModel.fromFirestore(doc) : null;
  }

  /// Mark a room as occupied (used by the "Use This Room" borrow flow).
  /// Sets status to 'occupied' without linking to a schedule block.
  Future<void> setRoomOccupied(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'status': 'occupied',
      'currentOccupantBlockId': null,
    });
  }

  // Seed rooms into Firestore (run once during setup)
  Future<void> seedRooms() async {
    final batch = _db.batch();

    // 1. Delete all existing rooms to ensure a clean slate
    final existingRooms = await _db.collection('rooms').get();
    for (var doc in existingRooms.docs) {
      batch.delete(doc.reference);
    }

    // 2. Build and add new rooms
    final rooms = _buildSeedRooms();
    for (final room in rooms) {
      final ref = _db.collection('rooms').doc(room.roomId);
      batch.set(ref, room.toFirestore());
    }
    await batch.commit();
  }

  List<RoomModel> _buildSeedRooms() {
    final rooms = <RoomModel>[];
    // 6 floors, rooms labeled FloorNumber + Room index (e.g. 101, 102 ... 610)
    const roomsPerFloor = 8;
    const features = [
      [RoomFeatures.whiteboard, RoomFeatures.projector],
      [RoomFeatures.blackboard],
      [RoomFeatures.whiteboard, RoomFeatures.tv, RoomFeatures.aircon],
      [RoomFeatures.projector, RoomFeatures.aircon],
      [RoomFeatures.whiteboard],
      [RoomFeatures.blackboard, RoomFeatures.projector],
      [RoomFeatures.tv, RoomFeatures.whiteboard],
      [RoomFeatures.aircon, RoomFeatures.projector, RoomFeatures.whiteboard],
    ];

    for (int floor = 1; floor <= 6; floor++) {
      for (int i = 1; i <= roomsPerFloor; i++) {
        final roomNumber = '${floor}0$i';
        rooms.add(RoomModel(
          roomId: roomNumber,
          roomNumber: roomNumber,
          floor: floor,
          features: List<String>.from(features[(i - 1) % features.length]),
          status: RoomStatus.available,
          col: i - 1,
          row: floor - 1,
        ));
      }
    }
    return rooms;
  }
}
