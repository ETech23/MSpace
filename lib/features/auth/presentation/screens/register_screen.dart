import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/install_referrer_service.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController();
  String _selectedRole = 'artisan';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _prefillReferralCode();
  }

  Future<void> _prefillReferralCode() async {
    final code = await InstallReferrerService().peekPendingReferralCode();
    if (!mounted) return;
    if (code != null && code.isNotEmpty && _referralController.text.isEmpty) {
      setState(() => _referralController.text = code);
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Password must include an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Password must include a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Password must include a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return 'Password must include a symbol';
    return null;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  // ── Handlers (logic unchanged) ─────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final cs = Theme.of(context).colorScheme;

    final success = await ref.read(authProvider.notifier).register(
          email: email,
          password: _passwordController.text,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          userType: _selectedRole,
          referralCode: _referralController.text.trim(),
        );

    if (mounted) {
      final authState = ref.read(authProvider);

      if (success) {
        await InstallReferrerService().takePendingReferralCode();
        context.go('/confirm-email?email=${Uri.encodeComponent(email)}');
      } else {
        final error = authState.error!;
        final isAlreadyRegistered =
            error.toLowerCase().contains('already exists') ||
                error.toLowerCase().contains('already registered');

        if (isAlreadyRegistered && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "This email is already registered. If you haven't confirmed it yet, tap Resend.",
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: 'Resend',
                textColor: Colors.white,
                onPressed: () => context.go(
                  '/confirm-email?email=${Uri.encodeComponent(email)}',
                ),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(error)),
                ],
              ),
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final selectedRole = await _promptRoleForGoogle();
    if (selectedRole == null) return;

    await ref.read(authProvider.notifier).loginWithGoogle(
          preferredUserType: selectedRole,
        );

    if (!mounted) return;

    final authState = ref.read(authProvider);
    final cs = Theme.of(context).colorScheme;

    if (authState.isAuthenticated && authState.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Welcome, ${authState.user!.name}!'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

      final isArtisan = authState.user!.isArtisan;
      context.go('/location-setup?userId=${authState.user!.id}&isArtisan=$isArtisan');
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(authState.error!)),
            ],
          ),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String?> _promptRoleForGoogle() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _GoogleRoleSheet(),
    );
  }

  // ── UI helpers — all colors resolved from theme/colorScheme ───────────────

  Widget _buildRoleTile({
    required ColorScheme cs,
    required ThemeData theme,
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == value;
    final tileBg = isSelected
        ? cs.primaryContainer.withOpacity(0.35)
        : cs.surfaceContainerLow;
    final borderColor = isSelected ? cs.primary : cs.outlineVariant;
    final iconBg = isSelected ? cs.primary : cs.surfaceContainerHighest;
    final iconColor = isSelected ? cs.onPrimary : cs.onSurfaceVariant;
    final labelColor = isSelected ? cs.primary : cs.onSurface;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.2),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1 : 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
                child: Icon(Icons.check, size: 13, color: cs.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styledField({
    required ColorScheme cs,
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
        helperText: helperText,
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 11.5,
          height: 1.4,
        ),
        helperMaxLines: 2,
        prefixIcon: Icon(icon, size: 19, color: cs.onSurfaceVariant),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.8),
        ),
        errorStyle: theme.textTheme.bodySmall?.copyWith(color: cs.error, fontSize: 12),
      ),
      validator: validator,
    );
  }

  Widget _visibilityToggle({
    required bool obscure,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 19,
        color: cs.onSurfaceVariant,
      ),
      onPressed: onTap,
    );
  }

  Widget _sectionLabel(String text, ThemeData theme, ColorScheme cs) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _orDivider(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant, thickness: 1)),
      ],
    );
  }

  Widget _googleButton(bool isLoading, ThemeData theme, ColorScheme cs) {
    return OutlinedButton(
      onPressed: isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outlineVariant, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(Icons.g_mobiledata, size: 18, color: cs.onSurface),
          ),
          const SizedBox(width: 10),
          Text(
            'Continue with Google',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(bool isLoading, ThemeData theme, ColorScheme cs) {
    return FilledButton(
      onPressed: isLoading ? null : _handleRegister,
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        disabledBackgroundColor: cs.primary.withOpacity(0.45),
        foregroundColor: cs.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
            )
          : Text(
              'Create Account',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(Icons.arrow_back, size: 18, color: cs.onSurface),
          ),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: cs.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Account',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Join MSpace and start connecting',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Personal info ────────────────────────────────────────
                  _sectionLabel('PERSONAL INFORMATION', theme, cs),
                  const SizedBox(height: 12),
                  _styledField(
                    cs: cs, theme: theme,
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  _styledField(
                    cs: cs, theme: theme,
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your email';
                      if (!v.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _styledField(
                    cs: cs, theme: theme,
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your phone number';
                      if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v)) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Security ─────────────────────────────────────────────
                  _sectionLabel('SECURITY', theme, cs),
                  const SizedBox(height: 12),
                  _styledField(
                    cs: cs, theme: theme,
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    helperText: 'Min 8 chars · uppercase · lowercase · number · symbol',
                    suffixIcon: _visibilityToggle(
                      cs: cs,
                      obscure: _obscurePassword,
                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),
                  _styledField(
                    cs: cs, theme: theme,
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: _visibilityToggle(
                      cs: cs,
                      obscure: _obscureConfirmPassword,
                      onTap: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm your password';
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Account type ─────────────────────────────────────────
                  _sectionLabel('ACCOUNT TYPE', theme, cs),
                  const SizedBox(height: 12),
                  _buildRoleTile(
                    cs: cs, theme: theme,
                    value: 'artisan',
                    label: 'Artisan',
                    subtitle: 'Offer your skills and services',
                    icon: Icons.handyman_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildRoleTile(
                    cs: cs, theme: theme,
                    value: 'business',
                    label: 'Business',
                    subtitle: 'Manage a team or company',
                    icon: Icons.store_mall_directory_outlined,
                  ),
                  const SizedBox(height: 10),
                  _buildRoleTile(
                    cs: cs, theme: theme,
                    value: 'customer',
                    label: 'Client',
                    subtitle: 'Discover and hire professionals',
                    icon: Icons.person_search_outlined,
                  ),
                  const SizedBox(height: 24),

                  // ── Referral ─────────────────────────────────────────────
                  _styledField(
                    cs: cs, theme: theme,
                    controller: _referralController,
                    label: 'Referral Code (optional)',
                    icon: Icons.card_giftcard_rounded,
                  ),
                  const SizedBox(height: 28),

                  _orDivider(theme, cs),
                  const SizedBox(height: 16),
                  _googleButton(authState.isLoading, theme, cs),
                  const SizedBox(height: 12),
                  _primaryButton(authState.isLoading, theme, cs),
                  const SizedBox(height: 24),

                  // ── Login link ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Sign in',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Google role bottom sheet ───────────────────────────────────────────────

class _GoogleRoleSheet extends StatelessWidget {
  const _GoogleRoleSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose account type',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "If you already have an account, we'll keep your existing role.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _roleOption(context, theme: theme, cs: cs,
                icon: Icons.handyman_outlined,
                label: 'Artisan', subtitle: 'Offer services & skills', value: 'artisan'),
              const SizedBox(height: 10),
              _roleOption(context, theme: theme, cs: cs,
                icon: Icons.store_mall_directory_outlined,
                label: 'Business', subtitle: 'A team or company', value: 'business'),
              const SizedBox(height: 10),
              _roleOption(context, theme: theme, cs: cs,
                icon: Icons.person_search_outlined,
                label: 'Client', subtitle: 'Looking for services', value: 'customer'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleOption(
    BuildContext context, {
    required ThemeData theme,
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}