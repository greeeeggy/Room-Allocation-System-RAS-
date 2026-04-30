import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bug_report_provider.dart';

class SubmitBugScreen extends ConsumerStatefulWidget {
  const SubmitBugScreen({super.key});
  @override
  ConsumerState<SubmitBugScreen> createState() => _SubmitBugScreenState();
}

class _SubmitBugScreenState extends ConsumerState<SubmitBugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _imageBase64;
  String? _imageName;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ])),
    );
    if (source == null) return;

    final picked = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 70);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      setState(() {
        _imageBase64 = base64Encode(bytes);
        _imageName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      final roleStr = user.isCouncilPresident ? 'council_president' : user.isEngineeringCouncilPresident ? 'engineering_council_president' : 'mayor';
      await ref.read(bugReportServiceProvider).submitBugReport(
        submitterId: user.userId,
        submitterName: user.name,
        submitterRole: roleStr,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imageBase64: _imageBase64,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bug report submitted!'), backgroundColor: Color(0xFF00D4AA)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 4),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('REPORT', style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 6)),
                  Text('A BUG', style: GoogleFonts.outfit(color: const Color(0xFF1A1A1A), fontSize: 28, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -1)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Title
                    Text('TITLE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleCtrl,
                      style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Brief summary of the issue',
                        hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 14),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 20),
                    // Description
                    Text('DESCRIPTION', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 6,
                      style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF1A1A1A), height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Describe what happened, steps to reproduce, expected vs actual behavior...',
                        hintStyle: GoogleFonts.outfit(color: Colors.black26, fontSize: 13),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(0), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (v) => v == null || v.trim().length < 10 ? 'Please describe the issue (min 10 chars)' : null,
                    ),
                    const SizedBox(height: 20),
                    // Image attachment
                    Text('SCREENSHOT (OPTIONAL)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    if (_imageBase64 != null) ...[
                      Stack(children: [
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          width: double.infinity,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.08))),
                          child: Image.memory(base64Decode(_imageBase64!), fit: BoxFit.contain),
                        ),
                        Positioned(top: 8, right: 8, child: GestureDetector(
                          onTap: () => setState(() { _imageBase64 = null; _imageName = null; }),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.red.shade700, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        )),
                      ]),
                      const SizedBox(height: 8),
                      Text(_imageName ?? 'screenshot.jpg', style: GoogleFonts.outfit(fontSize: 11, color: Colors.black38)),
                    ] else
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black.withOpacity(0.08), style: BorderStyle.solid)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.black.withOpacity(0.15)),
                            const SizedBox(height: 6),
                            Text('TAP TO ATTACH', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.2), letterSpacing: 1)),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _submitting
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : GestureDetector(
                              onTap: _submit,
                              child: Container(
                                decoration: BoxDecoration(color: AppColors.primary, boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                                child: Center(child: Text('SUBMIT REPORT', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5))),
                              ),
                            ),
                    ),
                    const SizedBox(height: 40),
                    // My Reports section
                    Text('MY REPORTS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    user == null 
                      ? const SizedBox() 
                      : ref.watch(myBugReportsProvider(user.userId)).when(
                          data: (bugs) {
                            if (bugs.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text('No reports yet.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black12, fontWeight: FontWeight.w600)),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: bugs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final bug = bugs[i];
                                final statusColor = bug.status == BugStatus.open 
                                    ? const Color(0xFF00D4AA) 
                                    : bug.status == BugStatus.inProgress 
                                        ? const Color(0xFFFFB74D) 
                                        : const Color(0xFF757575);
                                
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(bug.title.toUpperCase(), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A))),
                                            const SizedBox(height: 2),
                                            Text(DateFormat('MMM d, y').format(bug.createdAt), style: GoogleFonts.outfit(fontSize: 10, color: Colors.black26)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          border: Border.all(color: statusColor.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          bug.status == BugStatus.open ? 'OPEN' : bug.status == BugStatus.inProgress ? 'IN PROGRESS' : 'RESOLVED',
                                          style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                          error: (err, __) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('Error: $err', style: GoogleFonts.outfit(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                        ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
