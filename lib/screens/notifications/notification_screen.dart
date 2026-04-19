import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.find_in_page_outlined),
            tooltip: 'Lost & Found',
            onPressed: () => context.push('/lost-and-found'),
          ),
          // Mark all as read
          notifAsync.maybeWhen(
            data: (notifs) {
              final hasUnread = notifs.any((n) => !n.isRead);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  if (user != null) {
                    ref
                        .read(notificationServiceProvider)
                        .markAllAsRead(user.userId);
                  }
                },
                child: const Text('Mark all read',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _NotifCard(notif: notifs[i]),
          );
        },
      ),
    );
  }
}

// ---------- Notification card ----------

class _NotifCard extends ConsumerWidget {
  final NotificationModel notif;
  const _NotifCard({required this.notif});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title;
    String body;
    Color color;
    IconData icon;

    switch (notif.type) {
      case NotificationType.conflictDetected:
        title = 'Room Conflict Detected';
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        body = notif.sectionA != null && notif.sectionB != null
            ? '${notif.sectionA} and ${notif.sectionB} are both claiming Room ${notif.roomId}.'
            : 'A conflict was detected for Room ${notif.roomId}.';
        break;
      case NotificationType.conflictResolved:
        title = 'Conflict Resolved';
        color = Colors.green;
        icon = Icons.check_circle_outline;
        body = notif.sectionA != null && notif.sectionB != null
            ? 'The conflict between ${notif.sectionA} and ${notif.sectionB} for Room ${notif.roomId} has been resolved.'
            : 'The conflict for Room ${notif.roomId} has been resolved.';
        break;
      case NotificationType.staticScheduleConflict:
        title = 'Schedule Conflict';
        color = Colors.orange.shade700;
        icon = Icons.event_busy_outlined;
        body = 'You got a schedule conflict with ${notif.sectionB} for Room ${notif.roomId}.';
        break;
      case NotificationType.lostItemPosted:
        title = 'Lost Item Found';
        color = Colors.amber.shade700;
        icon = Icons.find_in_page_outlined;
        body = notif.lostItemMessage ?? 'A lost item was posted. Tap to view.';
        break;
    }

    return GestureDetector(
      onTap: () {
        if (!notif.isRead) {
          ref
              .read(notificationServiceProvider)
              .markAsRead(notif.notifId);
        }
        if (notif.type == NotificationType.lostItemPosted && notif.lostItemId != null) {
          context.push('/lost-and-found/${notif.lostItemId}');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.isRead
                ? Colors.grey.shade200
                : color.withOpacity(0.35),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: notif.isRead
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: color)),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notif.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}

// ---------- Empty state ----------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No notifications yet',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Conflict alerts will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
