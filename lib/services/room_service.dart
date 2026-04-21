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

    void add(
      String number,
      int floor,
      List<String> features, {
      RoomType roomType = RoomType.classroom,
      String? labType,
      int col = 0,
      int row = 0,
    }) {
      rooms.add(RoomModel(
        roomId: number,
        roomNumber: number,
        floor: floor,
        features: features,
        status: RoomStatus.available,
        roomType: roomType,
        labType: labType,
        col: col,
        row: row,
      ));
    }

    // ── 6th Floor ──────────────────────────────────────────
    add('601', 6, [RoomFeatures.whiteboard], col: 0, row: 0);
    add('602', 6, [RoomFeatures.whiteboard], col: 1, row: 0);
    add('603', 6, [RoomFeatures.whiteboard], col: 2, row: 0);
    add('604', 6, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 3, row: 0);
    add('605', 6, [], roomType: RoomType.office, col: 4, row: 0);
    add('606', 6, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 5, row: 0);
    add('607', 6, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 6, row: 0);
    add('608', 6, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 7, row: 0);
    add('609', 6, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 8, row: 0);
    add('610', 6, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 9, row: 0);

    // ── 5th Floor ──────────────────────────────────────────
    add('501', 5, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 0, row: 1);
    add('502', 5, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 1, row: 1);
    add('503', 5, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 2, row: 1);
    add('504', 5, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 3, row: 1);
    add('505', 5, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.blackboard], col: 4, row: 1);
    add('506', 5, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.blackboard], col: 5, row: 1);
    add('507', 5, [RoomFeatures.blackboard], col: 6, row: 1);
    add('508', 5, [RoomFeatures.blackboard], col: 7, row: 1);
    add('509', 5, [RoomFeatures.blackboard], col: 8, row: 1);
    add('510', 5, [RoomFeatures.blackboard], col: 9, row: 1);
    add('511', 5, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.blackboard], col: 10, row: 1);
    add('512', 5, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.aircon], col: 11, row: 1);

    // ── 4th Floor ──────────────────────────────────────────
    add('401-402', 4, [RoomFeatures.whiteboard, RoomFeatures.blackboard],
        roomType: RoomType.laboratory, labType: 'IE Laboratory', col: 0, row: 2);
    add('403', 4, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.blackboard],
        roomType: RoomType.laboratory, labType: 'IE Laboratory', col: 1, row: 2);
    add('404', 4, [RoomFeatures.whiteboard, RoomFeatures.aircon, RoomFeatures.computer],
        roomType: RoomType.laboratory, labType: 'Computer Laboratory', col: 2, row: 2);
    add('405', 4, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.aircon], col: 3, row: 2);
    add('406', 4, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.aircon], col: 4, row: 2);
    add('407', 4, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 5, row: 2);
    add('408', 4, [RoomFeatures.tv, RoomFeatures.whiteboard], col: 6, row: 2);
    add('409', 4, [RoomFeatures.blackboard, RoomFeatures.whiteboard], col: 7, row: 2);
    add('410', 4, [RoomFeatures.blackboard], col: 8, row: 2);
    add('411', 4, [RoomFeatures.whiteboard, RoomFeatures.blackboard], col: 9, row: 2);
    add('412', 4, [RoomFeatures.blackboard], col: 10, row: 2);

    // ── 3rd Floor ──────────────────────────────────────────
    add('301-302', 3, [], roomType: RoomType.office, col: 0, row: 3);
    add('303', 3, [RoomFeatures.whiteboard, RoomFeatures.tv, RoomFeatures.aircon, RoomFeatures.computer],
        roomType: RoomType.laboratory, labType: 'Computer Laboratory', col: 1, row: 3);
    add('304', 3, [RoomFeatures.aircon, RoomFeatures.computer],
        roomType: RoomType.laboratory, labType: 'Computer Laboratory', col: 2, row: 3);
    add('305-306', 3, [RoomFeatures.projector, RoomFeatures.whiteboard, RoomFeatures.blackboard],
        roomType: RoomType.laboratory, labType: 'Innovation Laboratory', col: 3, row: 3);
    add('307', 3, [RoomFeatures.blackboard, RoomFeatures.whiteboard, RoomFeatures.aircon], col: 4, row: 3);
    add('308', 3, [], roomType: RoomType.office, col: 5, row: 3);
    add('309', 3, [], roomType: RoomType.unknown, col: 6, row: 3);
    add('310', 3, [], roomType: RoomType.unknown, col: 7, row: 3);
    add('311', 3, [RoomFeatures.projector, RoomFeatures.whiteboard], col: 8, row: 3);
    add('312', 3, [], roomType: RoomType.office, col: 9, row: 3);

    // ── 2nd Floor ──────────────────────────────────────────
    add('201', 2, [], roomType: RoomType.office, col: 0, row: 4);
    add('202', 2, [], roomType: RoomType.office, col: 1, row: 4);
    add('203', 2, [], roomType: RoomType.office, col: 2, row: 4);
    add('204', 2, [], roomType: RoomType.laboratory, labType: 'Graphics and Design Laboratory', col: 3, row: 4);
    add('205', 2, [RoomFeatures.tv, RoomFeatures.whiteboard, RoomFeatures.computer],
        roomType: RoomType.laboratory, labType: 'Computer Laboratory', col: 4, row: 4);
    add('206', 2, [], roomType: RoomType.office, col: 5, row: 4);
    add('207', 2, [], roomType: RoomType.laboratory, labType: 'Chemistry Laboratory', col: 6, row: 4);
    add('208', 2, [], roomType: RoomType.laboratory, labType: 'Physics Laboratory', col: 7, row: 4);

    // ── 1st Floor ──────────────────────────────────────────
    add('101', 1, [], roomType: RoomType.laboratory, labType: 'Soil Mechanics Laboratory', col: 0, row: 5);
    add('102', 1, [], roomType: RoomType.laboratory, labType: 'Construction Materials Testing Laboratory', col: 1, row: 5);
    add('103', 1, [], roomType: RoomType.laboratory, labType: 'Hydraulics Laboratory', col: 2, row: 5);
    add('104', 1, [], roomType: RoomType.laboratory, labType: 'FCM and IDT Technology Lab', col: 3, row: 5);
    add('105', 1, [], roomType: RoomType.laboratory, col: 4, row: 5);
    add('106', 1, [], roomType: RoomType.laboratory, col: 5, row: 5);
    add('107', 1, [], roomType: RoomType.laboratory, col: 6, row: 5);
    add('108', 1, [], roomType: RoomType.laboratory, labType: 'Power Plant Technology and Marine Engineering Shop', col: 7, row: 5);

    return rooms;
  }
}
