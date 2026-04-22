import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isUpdatingPhoto = false;

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).logout();
  }

  Future<void> _changePhoto(String userId) async {
    final picker = ImagePicker();
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85, // Balanced for high quality and < 1MB document limit
    );

    if (picked != null) {
      setState(() => _isUpdatingPhoto = true);
      try {
        await ref.read(authServiceProvider).updateProfilePhoto(userId, File(picked.path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating photo: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUpdatingPhoto = false);
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroupedCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load user.')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in.'));
          }

          final roleLabel = user.role == UserRole.councilPresident
              ? 'Council President'
              : 'Mayor';

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Profile avatar + name header ──────────────────────────
                Container(
                  width: double.infinity,
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          () {
                            final photoUrl = user.photoURL;
                            if (photoUrl != null && photoUrl.isNotEmpty) {
                              if (photoUrl.startsWith('http')) {
                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white.withOpacity(0.25),
                                  backgroundImage: CachedNetworkImageProvider(photoUrl),
                                );
                              } else {
                                // Assume Base64
                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white.withOpacity(0.25),
                                  backgroundImage: MemoryImage(base64Decode(photoUrl)),
                                );
                              }
                            }
                            return CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }(),
                          if (_isUpdatingPhoto)
                            const Positioned.fill(
                              child: Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _changePhoto(user.userId),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── User Information ──────────────────────────────────────
                _buildSectionHeader('User Information'),
                _buildGroupedCard(
                  child: Column(
                    children: [
                      _buildInfoTile(
                        icon: Icons.person_outline,
                        label: 'Full Name',
                        value: user.name,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        icon: Icons.business_outlined,
                        label: 'Department',
                        value: user.department,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: roleLabel,
                      ),
                      if (user.courseSection != null) ...[
                        const Divider(height: 1, indent: 56),
                        _buildInfoTile(
                          icon: Icons.class_outlined,
                          label: 'Section',
                          value: user.courseSection!,
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Sign Out ──────────────────────────────────────────────
                _buildSectionHeader('Account'),
                _buildGroupedCard(
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _signOut,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
