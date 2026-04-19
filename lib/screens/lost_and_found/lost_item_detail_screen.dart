import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/lost_item_model.dart';
import '../../models/lost_item_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lost_item_provider.dart';

class LostItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const LostItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<LostItemDetailScreen> createState() =>
      _LostItemDetailScreenState();
}

class _LostItemDetailScreenState extends ConsumerState<LostItemDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  LostItemModel? _item;
  bool _loadingItem = true;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final item =
        await ref.read(lostItemServiceProvider).getLostItem(widget.itemId);
    if (mounted) {
      setState(() {
        _item = item;
        _loadingItem = false;
      });
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    _msgCtrl.clear();

    await ref.read(lostItemServiceProvider).sendMessage(
          itemId: widget.itemId,
          senderId: user.userId,
          senderName: user.name,
          senderCourseSection: user.courseSection ?? '',
          text: text,
        );
  }

  Future<void> _claimItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Claimed?'),
        content: const Text(
          'This will mark the item as claimed and permanently delete all messages in this thread. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Claimed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(lostItemServiceProvider).claimItem(widget.itemId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item marked as claimed!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  void _openImageViewer(int initialIndex) {
    if (_item == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          item: _item!,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final messagesAsync = ref.watch(lostItemMessagesProvider(widget.itemId));

    if (_loadingItem) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lost Item')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final item = _item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lost Item')),
        body: const Center(child: Text('Item not found.')),
      );
    }

    final isPoster = user?.userId == item.posterId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost Item Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isPoster && !item.isClaimed)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              child: ElevatedButton.icon(
                onPressed: _claimItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero, // Override global infinite width
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text(
                  'Claim',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Item detail header
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // Images
                if (item.imageUrls.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: PageView(
                        children: item.imageUrls.asMap().entries.map((entry) {
                          final index = entry.key;
                          final img = entry.value;
                          final heroTag = 'hero_img_${item.itemId}_$index';

                          return GestureDetector(
                            onTap: () => _openImageViewer(index),
                            child: Hero(
                              tag: heroTag,
                              child: img.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: img,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (_, __) => Container(
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.grey.shade100,
                                        child: const Icon(Icons.broken_image,
                                            size: 48, color: Colors.grey),
                                      ),
                                    )
                                  : Image.memory(
                                      base64Decode(img),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // Detail card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.objectName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Room Found',
                          value: item.roomFound,
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Found By',
                          value: item.posterName,
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.school_outlined,
                          label: 'Section',
                          value: item.posterCourseSection,
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          icon: Icons.access_time,
                          label: 'Posted',
                          value: DateFormat('MMM d, yyyy • h:mm a')
                              .format(item.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),

                // Divider
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Text('Messages',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Messages
                messagesAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(child: Text('Error: $e')),
                  ),
                  data: (messages) {
                    _scrollToBottom();
                    if (messages.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No messages yet. Start a conversation!',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _MessageBubble(
                          message: messages[i],
                          isMe: messages[i].senderId == user?.userId,
                        ),
                        childCount: messages.length,
                      ),
                    );
                  },
                ),

                // Bottom spacing
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
            ),
          ),

          // Message input bar
          if (!item.isClaimed)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 8,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Detail row widget ----------

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ---------- Message bubble ----------

class _MessageBubble extends StatelessWidget {
  final LostItemMessageModel message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 48 : 16,
        right: isMe ? 16 : 48,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: isMe
                  ? const Radius.circular(14)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(14),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${message.senderName}  •  ${message.senderCourseSection}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.shade500,
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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}

// ---------- Full-Screen Image Viewer ----------

class _FullScreenImageViewer extends StatefulWidget {
  final LostItemModel item;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.item,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background dismiss focus
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
            ),
          ),

          // Main Image PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.item.imageUrls.length,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final img = widget.item.imageUrls[index];
              return Center(
                child: Hero(
                  tag: 'hero_img_${widget.item.itemId}_$index',
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: img.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: img,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Image.memory(
                            base64Decode(img),
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Page indicator
          if (widget.item.imageUrls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.item.imageUrls.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == entry.key
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
