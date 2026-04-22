import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
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
      backgroundColor: const Color(0xFFFBFBFB),
      body: Stack(
        children: [
          // Architectural Background Details
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetropolisHeader(
                  onMarkAllRead: () {
                    if (user != null) {
                      ref.read(notificationServiceProvider).markAllAsRead(user.userId);
                    }
                  },
                  hasUnread: notifAsync.maybeMap(
                    data: (d) => d.value.any((n) => !n.isRead),
                    orElse: () => false,
                  ),
                ),
                
                Expanded(
                  child: notifAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (notifs) {
                      if (notifs.isEmpty) {
                        return const _EmptyState();
                      }

                      // Group notifications
                      final now = DateTime.now();
                      final today = <NotificationModel>[];
                      final yesterday = <NotificationModel>[];
                      final earlier = <NotificationModel>[];

                      for (final n in notifs) {
                        final diff = now.difference(n.createdAt).inDays;
                        if (diff == 0) {
                          today.add(n);
                        } else if (diff == 1) {
                          yesterday.add(n);
                        } else {
                          earlier.add(n);
                        }
                      }

                      return RefreshIndicator(
                        onRefresh: () async => ref.refresh(notificationsProvider),
                        color: AppColors.primary,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            if (today.isNotEmpty) ...[
                              const _TimelineHeading(label: 'TODAY'),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _NotifArchitectCard(notif: today[i], index: i),
                                  childCount: today.length,
                                ),
                              ),
                            ],
                            if (yesterday.isNotEmpty) ...[
                              const _TimelineHeading(label: 'YESTERDAY'),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _NotifArchitectCard(notif: yesterday[i], index: i + today.length),
                                  childCount: yesterday.length,
                                ),
                              ),
                            ],
                            if (earlier.isNotEmpty) ...[
                              const _TimelineHeading(label: 'EARLIER'),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _NotifArchitectCard(notif: earlier[i], index: i + today.length + yesterday.length),
                                  childCount: earlier.length,
                                ),
                              ),
                            ],
                            const SliverToBoxAdapter(child: SizedBox(height: 120)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Lost & Found Shortcut
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea(
              child: IconButton(
                onPressed: () => context.push('/lost-and-found'),
                icon: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetropolisHeader extends StatelessWidget {
  final VoidCallback onMarkAllRead;
  final bool hasUnread;
  const _MetropolisHeader({required this.onMarkAllRead, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'NOTIFICATIONS',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1A1A1A),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          if (hasUnread)
            GestureDetector(
              onTap: onMarkAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'MARK ALL READ',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineHeading extends StatelessWidget {
  final String label;
  const _TimelineHeading({required this.label});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.black26,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.black.withOpacity(0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifArchitectCard extends ConsumerWidget {
  final NotificationModel notif;
  final int index;

  const _NotifArchitectCard({required this.notif, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title;
    String body;
    Color color;
    IconData icon;

    switch (notif.type) {
      case NotificationType.conflictDetected:
        title = 'ROOM CONFLICT';
        color = AppColors.occupied;
        icon = Icons.warning_amber_rounded;
        body = notif.sectionA != null && notif.sectionB != null
            ? '${notif.sectionA} AND ${notif.sectionB} ARE CLAIMING ROOM ${notif.roomId}.'
            : 'A CONFLICT WAS DETECTED FOR ROOM ${notif.roomId}.';
        break;
      case NotificationType.conflictResolved:
        title = 'CONFLICT RESOLVED';
        color = Colors.teal;
        icon = Icons.check_circle_outline_rounded;
        body = notif.sectionA != null && notif.sectionB != null
            ? 'THE CONFLICT BETWEEN ${notif.sectionA} AND ${notif.sectionB} FOR ROOM ${notif.roomId} HAS BEEN RESOLVED.'
            : 'THE CONFLICT FOR ROOM ${notif.roomId} HAS BEEN RESOLVED.';
        break;
      case NotificationType.staticScheduleConflict:
        title = 'SCHEDULE CLASH';
        color = AppColors.soon;
        icon = Icons.event_busy_outlined;
        body = 'YOU HAVE A SCHEDULE CONFLICT WITH ${notif.sectionB} FOR ROOM ${notif.roomId}.';
        break;
      case NotificationType.lostItemPosted:
        title = 'LOST ITEM FOUND';
        color = AppColors.accent;
        icon = Icons.find_in_page_outlined;
        body = notif.lostItemMessage?.toUpperCase() ?? 'A LOST ITEM WAS POSTED. TAP TO VIEW.';
        break;
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 60).clamp(0, 500)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (!notif.isRead) {
            ref.read(notificationServiceProvider).markAsRead(notif.notifId);
          }
          if (notif.type == NotificationType.lostItemPosted && notif.lostItemId != null) {
            context.push('/lost-and-found/${notif.lostItemId}');
          }
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: notif.isRead ? Colors.white : color.withOpacity(0.04),
                  border: Border.all(
                    color: notif.isRead ? Colors.black.withOpacity(0.06) : color.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Container
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        border: Border.all(color: color.withOpacity(0.1)),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 16),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: color,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              if (!notif.isRead)
                                _PulseIndicator(color: color),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            body,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF4A4A4A),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatTime(notif.createdAt).toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.black26,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Corner Detail
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 20,
                  height: 2,
                  color: color.withOpacity(0.3),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 2,
                  height: 20,
                  color: color.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    return DateFormat('MMM D, H:MM A').format(dt);
  }
}

class _PulseIndicator extends StatefulWidget {
  final Color color;
  const _PulseIndicator({required this.color});

  @override
  _PulseIndicatorState createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(1.0 - _controller.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5 * (1.0 - _controller.value)),
                blurRadius: 4 * _controller.value,
                spreadRadius: 2 * _controller.value,
              )
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.black.withOpacity(0.04)),
          const SizedBox(height: 20),
          Text(
            'ALL CLEAR',
            style: GoogleFonts.outfit(
              color: Colors.black.withOpacity(0.12),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'STAY TUNED FOR UPDATES',
            style: GoogleFonts.outfit(
              color: Colors.black.withOpacity(0.08),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

