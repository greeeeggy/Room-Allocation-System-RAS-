import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/room_service.dart';
import '../models/room_model.dart';
import 'auth_provider.dart';

final roomServiceProvider = Provider<RoomService>((ref) => RoomService());

// All rooms — live stream (only while authenticated)
final allRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  final service = ref.watch(roomServiceProvider);
  return service.getRoomsStream().handleError((error) {
    if (error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED')) {
      return;
    }
    throw error;
  });
});

// Selected floor filter (default: show all = 0)
final selectedFloorProvider = StateProvider<int>((ref) => 0);

// Rooms filtered by selected floor
final filteredRoomsProvider = Provider<AsyncValue<List<RoomModel>>>((ref) {
  final floor = ref.watch(selectedFloorProvider);
  final allRooms = ref.watch(allRoomsProvider);

  return allRooms.whenData(
    (rooms) => rooms
        .where((r) => r.floor >= 1 && (floor == 0 || r.floor == floor))
        .toList(),
  );
});
