// lib/screens/sign_in_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:fixitzed_app/services/auth_service.dart';
import 'package:fixitzed_app/screens/sign_up_screen.dart';
import 'package:fixitzed_app/screens/auth/forgot_password_sheet.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/core/app_spacing.dart';
import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/widgets/app_text_field.dart';
import 'package:fixitzed_app/widgets/keyboard_safe_form.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.returnOnSuccess = false});

  final bool returnOnSuccess;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _rememberMe = false;
  bool _passwordVisible = false;
  bool _loading = false;
  bool _submitted = false; // control when to show validation

  @override
  void initState() {
    super.initState();
    _loadRememberedIdentifier();
    // Biometrics removed
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    _identifierFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final remembered =
        prefs.getString('remember_identifier') ??
        prefs.getString('remember_email');
    if (remembered != null && remembered.isNotEmpty) {
      _identifierCtrl.text = remembered;
      setState(() => _rememberMe = true);
    }
  }

  // Biometrics removed

  void _goHome() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final result = await AuthService().login(
        _identifierCtrl.text.trim(),
        _passCtrl.text,
      );

      if (!mounted) return;

      if (result.success) {
        // Persist remembered email if opted in.
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString(
            'remember_identifier',
            _identifierCtrl.text.trim(),
          );
          await prefs.remove('remember_email');
        } else {
          await prefs.remove('remember_identifier');
          await prefs.remove('remember_email');
        }
        final container = ProviderScope.containerOf(context, listen: false);
        unawaited(container.read(preloadServiceProvider).preloadAll());
        if (!mounted) return;
        if (widget.returnOnSuccess) {
          Navigator.of(context).pop(true);
        } else {
          unawaited(Navigator.of(context).pushReplacementNamed('/home'));
        }
      } else if (result.message == 'inactive') {
        await AuthService().logout();
        if (!mounted) return;
        unawaited(
          Navigator.of(context).pushReplacementNamed('/account_blocked'),
        );
      } else {
        await _showAlert(
          'Sign in failed',
          result.displayMessage ?? 'Invalid email/phone or password',
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _showAlert(
        'Network issue',
        'Unable to sign in. Check your connection.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAlert(String title, String message) async {
    final colors = Theme.of(context).fx;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: colors.brand,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('OK, got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPassword() async {
    final seed = _identifierCtrl.text.trim();
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).fx.surface,
      builder: (ctx) =>
          ForgotPasswordSheet(initialIdentifier: seed.isEmpty ? null : seed),
    );

    if (!mounted || completed != true) return;
    _passCtrl.clear();
    await _showAlert(
      'Password updated',
      'Your password was reset successfully. Sign in with the new password you created.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    final orange = colors.brand;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F1F),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF9F391A), Color(0xFF1F1F1F)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            KeyboardSafeForm(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _loading ? null : _goHome,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.home_rounded, size: 16),
                        label: Text(
                          'Back to home',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Image.asset(
                        'assets/images/logo.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Sign in to request trusted services',
                    style: GoogleFonts.urbanist(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Track your requests, pay securely and stay updated.',
                    style: GoogleFonts.urbanist(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow,
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: colors.border),
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _submitted
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.xs),
                          FocusAware(
                            focusNode: _identifierFocus,
                            child: AppTextField(
                              controller: _identifierCtrl,
                              focusNode: _identifierFocus,
                              nextFocusNode: _passFocus,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              labelText: 'Email or phone number',
                              hintText: 'Enter your email or phone number',
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) {
                                  return 'Identifier is required';
                                }
                                final isEmail = RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
                                ).hasMatch(s);
                                final digits = s.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                final isPhone =
                                    digits.length >= 7 && digits.length <= 15;
                                return (isEmail || isPhone)
                                    ? null
                                    : 'Enter a valid email or phone number';
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FocusAware(
                            focusNode: _passFocus,
                            child: AppTextField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              textInputAction: TextInputAction.done,
                              obscureText: !_passwordVisible,
                              onFieldSubmitted: (_) => _submit(),
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                              ),
                              validator: (v) {
                                final s = v ?? '';
                                if (s.isEmpty) {
                                  return 'Password is required';
                                }
                                if (s.length < 6) {
                                  return 'Min 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: orange,
                                shape: const CircleBorder(),
                                onChanged: _loading
                                    ? null
                                    : (val) => setState(
                                        () => _rememberMe = val ?? false,
                                      ),
                              ),
                              Text(
                                'Remember Me',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : _showForgotPassword,
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.urbanist(
                                    color: orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Sign In',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Don’t have an account? ',
                                style: GoogleFonts.urbanist(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SignUpScreen(
                                            returnOnSuccess:
                                                widget.returnOnSuccess,
                                          ),
                                        ),
                                      ),
                                child: Text(
                                  'Create one',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 15,
                                    color: orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
