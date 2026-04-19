import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../providers/room_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lost_item_provider.dart';
import '../../providers/notification_provider.dart';

class PostLostItemScreen extends ConsumerStatefulWidget {
  const PostLostItemScreen({super.key});

  @override
  ConsumerState<PostLostItemScreen> createState() => _PostLostItemScreenState();
}

class _PostLostItemScreenState extends ConsumerState<PostLostItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _objectNameCtrl = TextEditingController();
  String? _selectedRoom;
  final List<File> _photos = [];
  bool _isSubmitting = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _objectNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 photos allowed')),
      );
      return;
    }

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

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 40, // Significant compression for base64 storage efficiency
    );
    if (picked != null) {
      setState(() => _photos.add(File(picked.path)));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(lostItemServiceProvider);
      final notifService = ref.read(notificationServiceProvider);

      final itemId = await service.postLostItem(
        objectName: _objectNameCtrl.text.trim(),
        roomFound: _selectedRoom ?? '',
        posterName: user.name,
        posterCourseSection: user.courseSection ?? '',
        posterId: user.userId,
        photos: _photos,
      );

      // Fan out notification to all users
      await notifService.writeLostItemNotification(
        itemId: itemId,
        objectName: _objectNameCtrl.text.trim(),
        posterName: user.name,
        posterId: user.userId,
        roomFound: _selectedRoom ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lost item posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Lost Item'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photos section
              const Text('Photos (max 2)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  ..._photos.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  entry.value,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removePhoto(entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_photos.length < 2)
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                color: Colors.grey.shade500, size: 28),
                            const SizedBox(height: 4),
                            Text('Add Photo',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Object name
              TextFormField(
                controller: _objectNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name of Object',
                  hintText: 'e.g. Blue Water Bottle, Calculator',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter the object name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Room found dropdown
              ref.watch(allRoomsProvider).when(
                    data: (rooms) => DropdownButtonFormField<String>(
                      value: _selectedRoom,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Room Found',
                        prefixIcon: Icon(Icons.room_outlined),
                      ),
                      items: rooms.map((room) {
                        return DropdownMenuItem<String>(
                          value: room.roomNumber,
                          child: Text('Room ${room.roomNumber} (Floor ${room.floor})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRoom = val),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please select the room'
                          : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading rooms: $e'),
                  ),
              const SizedBox(height: 16),

              // Auto-filled: Mayor name
              TextFormField(
                initialValue: user?.name ?? '',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Mayor Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 16),

              // Auto-filled: Course & Section
              TextFormField(
                initialValue: user?.courseSection ?? '',
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Course & Section',
                  prefixIcon: const Icon(Icons.school_outlined),
                  fillColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(
                      _isSubmitting ? 'Posting...' : 'Post Lost Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
