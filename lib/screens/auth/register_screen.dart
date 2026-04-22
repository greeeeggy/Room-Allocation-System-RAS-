import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mayor_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();

  String _selectedRole = 'mayor';
  String _selectedDept = Departments.allFullNames.first;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'mayor' && _sectionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Course & section is required for mayors.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      if (_selectedRole == 'mayor') {
        await ref.read(mayorServiceProvider).validateMayorRegistration(
          name: _nameCtrl.text.trim(),
          department: _selectedDept,
          courseSection: _sectionCtrl.text.trim(),
        );
      }

      await ref.read(authServiceProvider).register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
        role: _selectedRole,
        department: _selectedDept,
        courseSection: _selectedRole == 'mayor'
            ? _sectionCtrl.text.trim()
            : null,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (raw.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (raw.contains('invalid-email')) return 'Invalid email format.';
    if (raw.startsWith('Exception: ')) return raw.replaceFirst('Exception: ', '');
    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: Stack(
        children: [
          // Radial glow — huge circle anchored at top-left corner.
          // Center is off-screen; only the soft outer falloff bleeds in.
          Positioned(
            top: -500,
            left: -500,
            child: Container(
              width: 1000,
              height: 1000,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.authGlow.withOpacity(0.70),
                    AppColors.authGlow.withOpacity(0.30),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Create Account',
                            style: GoogleFonts.outfit(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Room Allocation System · Engineering Building',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textOnDark.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _GlassField(
                            controller: _nameCtrl,
                            label: 'Fast name',
                            hint: 'Full name',
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 14),
                          // Email
                          _GlassField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Enter your email' : null,
                          ),
                          const SizedBox(height: 14),
                          // Password
                          _GlassField(
                            controller: _passwordCtrl,
                            label: 'Password',
                            hint: 'At least 6 characters',
                            icon: Icons.lock_outline,
                            obscureText: _obscure,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          // Role label
                          Text(
                            'Role',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textOnDark.withOpacity(0.75),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Role cards
                          Row(
                            children: [
                              Expanded(
                                child: _RoleCard(
                                  label: 'Class Mayor',
                                  icon: Icons.school_outlined,
                                  selected: _selectedRole == 'mayor',
                                  onTap: () =>
                                      setState(() => _selectedRole = 'mayor'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoleCard(
                                  label: 'Council President',
                                  icon: Icons.admin_panel_settings_outlined,
                                  selected: _selectedRole == 'council_president',
                                  onTap: () => setState(
                                      () => _selectedRole = 'council_president'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Department dropdown (glass styled)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Department',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textOnDark.withOpacity(0.75),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.authSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFDA9F93).withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedDept,
                                  dropdownColor: const Color(0xFF3A0A10),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  iconEnabledColor: AppColors.accent,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(
                                      Icons.business_outlined,
                                      color: AppColors.accent,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.authSurface,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  items: Departments.allFullNames
                                      .map((d) => DropdownMenuItem(
                                            value: d,
                                            child: Text(d,
                                                style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 13)),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedDept = v!),
                                ),
                              ),
                            ],
                          ),
                          // Course & section — only for mayors
                          if (_selectedRole == 'mayor') ...[
                            const SizedBox(height: 14),
                            _GlassField(
                              controller: _sectionCtrl,
                              label: 'Course & Section',
                              hint: 'e.g. BSIE 3-A',
                              icon: Icons.group_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ],
                          // Error
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFF6B6B),
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 28),
                          // Submit button
                          _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryLight,
                                  ),
                                )
                              : _GradientButton(
                                  label: 'Continue',
                                  onPressed: _register,
                                ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                              'Already have an account? Sign in',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: AppColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
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

// ── Role card (dark glass style) ─────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.6)
              : AppColors.authSurface,
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.authBorder,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.accent,
              size: 22,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : AppColors.textOnDark.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared glass text field ───────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textOnDark.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.authSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.authBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.authBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primaryLight, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
            ),
            errorStyle:
                GoogleFonts.outfit(color: const Color(0xFFFF6B6B), fontSize: 12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ── Gradient button ───────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
