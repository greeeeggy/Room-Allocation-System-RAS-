import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mayor_provider.dart';
import '../../models/mayor_approval_model.dart';

class MayorManagementScreen extends ConsumerWidget {
  const MayorManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final approvalsAsync = ref.watch(myDepartmentApprovalsProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: Stack(
        children: [
          // Architectural Background Detail (same as Room Search)
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
                    AppColors.accent.withOpacity(0.08),
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
                // Header — Room Search style
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUTHORIZED',
                        style: GoogleFonts.outfit(
                          color: AppColors.accent.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MAYORS',
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

                // Department info bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business_outlined, color: AppColors.accent, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'MANAGING: ${user.department}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black38,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Mayor list
                Expanded(
                  child: approvalsAsync.when(
                    data: (approvals) {
                      if (approvals.isEmpty) {
                        return const _EmptyMayors();
                      }
                      final sorted = [...approvals]
                        ..sort((a, b) =>
                            a.courseSection.compareTo(b.courseSection));

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: sorted.length,
                        itemBuilder: (_, i) => _MayorTile(
                          key: ValueKey(sorted[i].id),
                          approval: sorted[i],
                          index: i,
                        ),
                      );
                    },
                    loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: const TextStyle(color: Colors.black45)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          elevation: 4,
          onPressed: () => _showAddDialog(
              context, ref, user.department, user.userId),
          icon: const Icon(Icons.person_add_outlined, color: Colors.white, size: 20),
          label: const Text(
            'AUTHORIZE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
    );
  }

  void _showAddDialog(
      BuildContext context, WidgetRef ref, String dept, String userId) {
    showDialog(
      context: context,
      builder: (context) =>
          _AddMayorDialog(department: dept, councilPresidentId: userId),
    );
  }
}

// ── Mayor tile (Architect style) ─────────────────────────────────────────────

class _MayorTile extends ConsumerStatefulWidget {
  final MayorApprovalModel approval;
  final int index;
  const _MayorTile({super.key, required this.approval, required this.index});

  @override
  ConsumerState<_MayorTile> createState() => _MayorTileState();
}

class _MayorTileState extends ConsumerState<_MayorTile> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (widget.index * 80).clamp(0, 500)),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 95,
        child: Stack(
          children: [
            // Main Card Body
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F1),
                  border:
                      Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 15),
                child: Row(
                  children: [
                    // Name dominant element
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.approval.name.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.approval.courseSection,
                          style: TextStyle(
                            color: AppColors.accent.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Delete action
                    _deleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _showWarning1(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.2),
                                ),
                              ),
                              child: const Text(
                                'REMOVE',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            // Accent L-shape detail
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 24,
                height: 2,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 2,
                height: 24,
                color: AppColors.primary.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Warning 1: Consequences Overview ──────────────────────────────────
  void _showWarning1(BuildContext context) {
    final name = widget.approval.name;
    final section = widget.approval.courseSection;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Remove Mayor?',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'You are about to remove '),
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' ($section) from the system.\n\n'),
                  const TextSpan(
                    text: 'This will permanently delete:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _bulletPoint('Their user account and profile'),
            _bulletPoint('All schedule blocks (all semesters)'),
            _bulletPoint('Room usage history and logs'),
            _bulletPoint('All notifications'),
            _bulletPoint('Lost item posts and messages'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showWarning2(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Warning 2: Final Confirmation ─────────────────────────────────────
  void _showWarning2(BuildContext outerContext) {
    final name = widget.approval.name;
    final section = widget.approval.courseSection;

    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (ctx) => _FinalConfirmationDialog(
        name: name,
        section: section,
        onConfirm: () async {
          Navigator.pop(ctx);
          await _executeDelete(outerContext);
        },
      ),
    );
  }

  // ── Execute the deletion ──────────────────────────────────────────────
  Future<void> _executeDelete(BuildContext context) async {
    if (!mounted) return;
    final String deletedName = widget.approval.name;
    setState(() => _deleting = true);

    try {
      await ref
          .read(mayorServiceProvider)
          .deleteMayorCompletely(widget.approval);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$deletedName has been permanently removed.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing mayor: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Final Confirmation Dialog (Stateful for loading state) ────────────────────

class _FinalConfirmationDialog extends StatefulWidget {
  final String name;
  final String section;
  final Future<void> Function() onConfirm;

  const _FinalConfirmationDialog({
    required this.name,
    required this.section,
    required this.onConfirm,
  });

  @override
  State<_FinalConfirmationDialog> createState() =>
      _FinalConfirmationDialogState();
}

class _FinalConfirmationDialogState extends State<_FinalConfirmationDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      backgroundColor: Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.delete_forever_rounded,
                color: Colors.red.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Final Confirmation',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Are you absolutely sure?\n\n'),
                TextSpan(
                  text: widget.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                    text: ' (${widget.section}) '
                        'will be permanently removed. They will need to '
                        'be re-authorized and re-register to use the '
                        'system again.'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(
            'Go Back',
            style: GoogleFonts.outfit(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  await widget.onConfirm();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'DELETE PERMANENTLY',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Add Mayor Dialog ─────────────────────────────────────────────────────────

class _AddMayorDialog extends ConsumerStatefulWidget {
  final String department;
  final String councilPresidentId;
  const _AddMayorDialog(
      {required this.department, required this.councilPresidentId});

  @override
  ConsumerState<_AddMayorDialog> createState() => _AddMayorDialogState();
}

class _AddMayorDialogState extends ConsumerState<_AddMayorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(mayorServiceProvider).addApproval(
            name: _nameCtrl.text.trim(),
            department: widget.department,
            courseSection: _sectionCtrl.text.trim().toUpperCase(),
            councilPresidentId: widget.councilPresidentId,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Authorize New Mayor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Mayor Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sectionCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Course & Section (e.g. BSIE 2-E)',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Department: ${widget.department}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyMayors extends StatelessWidget {
  const _EmptyMayors();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 80, color: Colors.black.withOpacity(0.04)),
          const SizedBox(height: 20),
          Text(
            'NO AUTHORIZED MAYORS',
            style: TextStyle(
              color: Colors.black.withOpacity(0.12),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TAP THE + BUTTON TO AUTHORIZE A CLASS MAYOR'.toUpperCase(),
            style: TextStyle(
              color: Colors.black.withOpacity(0.08),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
