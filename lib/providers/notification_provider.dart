import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// Live stream of all notifications for the logged-in user.
final notificationsProvider =
    StreamProvider<List<NotificationModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref
      .watch(notificationServiceProvider)
      .getNotificationsStream(user.userId)
      .handleError((error) {
    if (error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED')) {
      return;
    }
    throw error;
  });
});

/// Live unread notification count — used for the bell badge.
final unreadCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(0);
  return ref
      .watch(notificationServiceProvider)
      .getUnreadCountStream(user.userId)
      .handleError((error) {
    if (error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED')) {
      return;
    }
    throw error;
  });
});
