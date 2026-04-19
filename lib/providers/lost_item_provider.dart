import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/lost_item_service.dart';
import '../models/lost_item_model.dart';
import '../models/lost_item_message_model.dart';

final lostItemServiceProvider =
    Provider<LostItemService>((ref) => LostItemService());

/// Real-time stream of all unclaimed lost items.
final lostItemsProvider = StreamProvider<List<LostItemModel>>((ref) {
  return ref.watch(lostItemServiceProvider).getLostItemsStream();
});

/// Per-item message stream (family provider keyed by itemId).
final lostItemMessagesProvider =
    StreamProvider.family<List<LostItemMessageModel>, String>((ref, itemId) {
  return ref.watch(lostItemServiceProvider).getMessagesStream(itemId);
});
