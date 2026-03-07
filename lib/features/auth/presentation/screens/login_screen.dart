import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // The redirect URL must exactly match one of the entries in Supabase
  // Dashboard → Authentication → URL Configuration → Redirect URLs.
  static const String _resetRedirectUrl =
      'io.supabase.artisanmarketplace://reset-password';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 5 : 2),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Please fill in all fields correctly', true);
      return;
    }

    setState(() => _isLoading = true);
    _showMessage('Logging in...', false);

    try {
      await ref.read(authProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        final authState = ref.read(authProvider);
        setState(() => _isLoading = false);

        if (authState.isAuthenticated && authState.user != null) {
          _showMessage('Welcome back, ${authState.user!.name}!', false);
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) context.go('/home');
        } else {
          final errorMsg =
              authState.error ?? 'Login failed. Please check your credentials.';

          // If email not confirmed, show a snackbar with a resend action
          // so the user can get back to the confirmation screen easily.
          // Only show resend option when Supabase explicitly says email
          // is unconfirmed. Do NOT match generic messages that happen to
          // contain the word "confirm" (e.g. wrong password hints).
          final isUnconfirmed = errorMsg == 'email_not_confirmed' ||
              errorMsg.toLowerCase() == 'email not confirmed' ||
              errorMsg.toLowerCase().startsWith('please confirm your email');
          if (isUnconfirmed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Please confirm your email before logging in.',
                ),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'Resend',
                  textColor: Colors.white,
                  onPressed: () {
                    context.go(
                      '/confirm-email?email=${Uri.encodeComponent(_emailController.text.trim())}',
                    );
                  },
                ),
              ),
            );
          } else {
            _showMessage(errorMsg, true);
          }
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error: ${e.toString()}', true);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _showMessage('Signing in with Google...', false);

    try {
      await ref.read(authProvider.notifier).loginWithGoogle();

      if (mounted) {
        final authState = ref.read(authProvider);
        setState(() => _isLoading = false);

        if (authState.isAuthenticated && authState.user != null) {
          _showMessage('Welcome back, ${authState.user!.name}!', false);
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) context.go('/home');
        } else {
          final errorMsg = authState.error ?? 'Google sign-in failed.';
          _showMessage(errorMsg, true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error: ${e.toString()}', true);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Enter a valid email address first.', true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // redirectTo tells Supabase where to send the user after they click
      // the link in the email. Must match your Redirect URLs allow-list in
      // the Supabase dashboard exactly (no trailing slash).
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _resetRedirectUrl,
      );

      _showMessage(
        'Password reset email sent. Check your inbox.',
        false,
      );
    } on AuthException catch (e) {
      _showMessage(e.message, true);
    } catch (e) {
      _showMessage('Failed to send reset email: $e', true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                Icon(
                  Icons.construction,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),

                Text(
                  'Welcome Back!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'Login to continue',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // ── Email ───────────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password ────────────────────────────────────────────────
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Login button ────────────────────────────────────────────
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Logging in...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Google sign-in ──────────────────────────────────────────
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.g_mobiledata, size: 20),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Continue with Google'),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Forgot password ─────────────────────────────────────────
                TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  child: const Text('Forgot Password?'),
                ),

                const SizedBox(height: 24),

                // ── Register link ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => context.push('/register'),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}