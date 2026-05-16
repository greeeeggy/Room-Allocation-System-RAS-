import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

/// Dedicated screen for the Engineering Council President.
///
/// Contains a single destructive action: "End of School Year" which wipes
/// all Firestore data after 3 escalating warnings.
class EndOfYearScreen extends ConsumerStatefulWidget {
  const EndOfYearScreen({super.key});

  @override
  ConsumerState<EndOfYearScreen> createState() => _EndOfYearScreenState();
}

class _EndOfYearScreenState extends ConsumerState<EndOfYearScreen>
    with SingleTickerProviderStateMixin {
  bool _isDeleting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleEndOfYear() async {
    // ── Warning 1 — Informational ────────────────────────────────────
    final proceed1 = await _showWarningDialog(
      level: 1,
      title: 'System Reset',
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.soon,
      message:
          'You are about to reset the entire system.\n\n'
          'All accounts, schedules, room data, notifications, and records '
          'will be permanently deleted.\n\n'
          'Are you sure you want to proceed?',
      confirmLabel: 'PROCEED',
      confirmColor: AppColors.soon,
    );
    if (proceed1 != true) return;

    // ── Warning 2 — Caution ──────────────────────────────────────────
    final proceed2 = await _showWarningDialog(
      level: 2,
      title: '⚠️  THIS ACTION IS IRREVERSIBLE',
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange.shade700,
      message:
          'Every user account, every schedule, every record in the system '
          'will be permanently erased.\n\n'
          'There is NO undo.\n\n'
          'Do you still want to continue?',
      confirmLabel: 'CONTINUE',
      confirmColor: Colors.orange.shade700,
    );
    if (proceed2 != true) return;

    // ── Warning 3 — Final (requires typing CONFIRM) ──────────────────
    final proceed3 = await _showFinalWarningDialog();
    if (proceed3 != true) return;

    // ── Execute deletion ─────────────────────────────────────────────
    setState(() => _isDeleting = true);
    try {
      await ref.read(adminServiceProvider).deleteAllFirebaseData();
      await ref.read(adminServiceProvider).signOut();
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool?> _showWarningDialog({
    required int level,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFBFBFB),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: Colors.black38,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: confirmColor,
              ),
              child: Text(
                confirmLabel,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showFinalWarningDialog() {
    final confirmCtrl = TextEditingController();
    bool isValid = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFBFBFB),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          title: Row(
            children: [
              Icon(Icons.dangerous_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🚨 FINAL WARNING',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.red.shade700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POINT OF NO RETURN\n\n'
                'You are about to DELETE ALL DATA in the Room Availability System.\n\n'
                '• ALL user accounts (including yours)\n'
                '• ALL schedules\n'
                '• ALL room data\n'
                '• ALL notifications\n'
                '• ALL records\n\n'
                'You will be signed out and must re-register.\n\n'
                'Type CONFIRM below to proceed.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isValid ? Colors.red.shade300 : Colors.black12,
                  ),
                ),
                child: TextField(
                  controller: confirmCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) {
                    setDialogState(() => isValid = v.trim().toUpperCase() == 'CONFIRM');
                  },
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: const Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'TYPE "CONFIRM"',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.black12,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'ABORT',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.black38,
                ),
              ),
            ),
            GestureDetector(
              onTap: isValid ? () => Navigator.pop(ctx, true) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isValid ? Colors.red.shade700 : Colors.black12,
                ),
                child: Text(
                  'DELETE EVERYTHING',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: isValid ? Colors.white : Colors.black26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: Stack(
        children: [
          // Architectural Background Detail
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
                    Colors.red.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.04),
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
                        'SYSTEM',
                        style: GoogleFonts.outfit(
                          color: Colors.red.shade300.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RESET',
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

                // Info bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Engineering Council President: ${user?.name ?? '...'}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black45,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center content — The button
                Center(
                  child: _isDeleting
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                color: AppColors.occupied,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'DELETING ALL DATA...',
                              style: GoogleFonts.outfit(
                                color: Colors.red.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Please wait. Do not close the app.',
                              style: GoogleFonts.outfit(
                                color: Colors.black26,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Decorative icon
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (_, child) => Transform.scale(
                                scale: _pulseAnimation.value,
                                child: child,
                              ),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red.withOpacity(0.06),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.12),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.restart_alt_rounded,
                                  size: 42,
                                  color: Colors.red.shade300,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Title
                            Text(
                              'END OF SCHOOL YEAR',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 48),
                              child: Text(
                                'Reset the entire system. All accounts, schedules, '
                                'and data will be permanently deleted.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.black38,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // The button
                            GestureDetector(
                              onTap: _handleEndOfYear,
                              child: Container(
                                width: 240,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // L-shape accent
                                    Positioned(
                                      top: 0, left: 0,
                                      child: Container(width: 20, height: 2, color: Colors.white24),
                                    ),
                                    Positioned(
                                      top: 0, left: 0,
                                      child: Container(width: 2, height: 20, color: Colors.white24),
                                    ),
                                    Positioned(
                                      bottom: 0, right: 0,
                                      child: Container(width: 20, height: 2, color: Colors.white24),
                                    ),
                                    Positioned(
                                      bottom: 0, right: 0,
                                      child: Container(width: 2, height: 20, color: Colors.white24),
                                    ),
                                    Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.restart_alt_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 10),
                                          Text(
                                            'END OF SCHOOL YEAR',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                const Spacer(),

                // Footer label
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Text(
                      'ENGINEERING COUNCIL · SYSTEM ADMINISTRATION',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
