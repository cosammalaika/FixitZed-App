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
import 'package:fixitzed_app/state/dashboard_controller.dart';
import 'package:fixitzed_app/state/fixers_providers.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

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
    super.dispose();
  }

  Future<void> _loadRememberedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered =
        prefs.getString('remember_identifier') ??
        prefs.getString('remember_email');
    if (remembered != null && remembered.isNotEmpty) {
      _identifierCtrl.text = remembered;
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _preloadAppData() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final futures = <Future<void>>[
      container
          .read(dashboardControllerProvider.future)
          .then((_) {}, onError: (_) {}),
      container.read(topFixersProvider.future).then((_) {}, onError: (_) {}),
    ];
    await Future.wait(futures);
  }

  // Biometrics removed

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
        await _preloadAppData();
        if (!mounted) return;
        unawaited(Navigator.of(context).pushReplacementNamed('/home'));
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
    const brand = Color(0xFFF1592A);
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
                  color: brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: brand,
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
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(color: Colors.black87),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
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
      backgroundColor: Colors.white,
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
    final orange = const Color(0xFFF1592A);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F1F),
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF1592A), Color(0xFF1F1F1F)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(),
                                const Spacer(),
                                Image.asset(
                                  'assets/images/logo.png',
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                            SizedBox(height: 40),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Welcome back',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Sign in to request trusted services',
                              style: GoogleFonts.urbanist(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Track your requests, pay securely and stay updated.',
                              style: GoogleFonts.urbanist(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              margin: const EdgeInsets.only(top: 24),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                20,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                autovalidateMode: _submitted
                                    ? AutovalidateMode.onUserInteraction
                                    : AutovalidateMode.disabled,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Email / Phone
                                    SizedBox(height: 8),
                                    TextFormField(
                                      controller: _identifierCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 15,
                                      ),
                                      cursorColor: const Color(0xFFF1592A),
                                      decoration: InputDecoration(
                                        labelText: 'Email or phone number',
                                        hintText:
                                            'Enter your email or phone number',
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.18),
                                        labelStyle: TextStyle(
                                          color: Theme.of(context).hintColor,
                                        ),
                                        hintStyle: TextStyle(
                                          color: Theme.of(context).hintColor,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                            width: 1,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFF1592A),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
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
                                            digits.length >= 7 &&
                                            digits.length <= 15;
                                        return (isEmail || isPhone)
                                            ? null
                                            : 'Enter a valid email or phone number';
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Password
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: !_passwordVisible,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 15,
                                      ),
                                      cursorColor: const Color(0xFFF1592A),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Enter your password',
                                        filled: true,
                                        fillColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.18),
                                        labelStyle: TextStyle(
                                          color: Theme.of(context).hintColor,
                                        ),
                                        hintStyle: TextStyle(
                                          color: Theme.of(context).hintColor,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                            width: 1,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).dividerColor,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(12),
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFF1592A),
                                            width: 1.2,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _passwordVisible
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          onPressed: () => setState(
                                            () => _passwordVisible =
                                                !_passwordVisible,
                                          ),
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
                                    const SizedBox(height: 12),

                                    // Remember + Forgot
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          activeColor: orange,
                                          onChanged: _loading
                                              ? null
                                              : (val) => setState(
                                                  () => _rememberMe =
                                                      val ?? false,
                                                ),
                                        ),
                                        const Text('Remember Me'),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: _loading
                                              ? null
                                              : _showForgotPassword,
                                          child: Text(
                                            'Forgot password?',
                                            style: GoogleFonts.urbanist(
                                              color: orange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Sign in button
                                    ElevatedButton(
                                      onPressed: _loading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
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
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),

                                    // const SizedBox(height: 20),

                                    // // Social logins
                                    // Row(
                                    //   mainAxisAlignment: MainAxisAlignment.center,
                                    //   children: [
                                    //     _socialButton("assets/images/google.png"),
                                    //     const SizedBox(width: 20),
                                    //     _socialButton("assets/images/facebook.png"),
                                    //   ],
                                    // ),
                                    // const SizedBox(height: 14),
                                    // Row(
                                    //   children: [
                                    //     Expanded(
                                    //       child: Divider(
                                    //         color: Theme.of(context).dividerColor,
                                    //       ),
                                    //     ),
                                    //     Padding(
                                    //       padding: const EdgeInsets.symmetric(
                                    //         horizontal: 8,
                                    //       ),
                                    //       child: Text(
                                    //         'Or continue with',
                                    //         style: GoogleFonts.urbanist(
                                    //           color: Theme.of(context).hintColor,
                                    //         ),
                                    //       ),
                                    //     ),
                                    //     Expanded(
                                    //       child: Divider(
                                    //         color: Theme.of(context).dividerColor,
                                    //       ),
                                    //     ),
                                    //   ],
                                    // ),
                                    // const SizedBox(height: 12),
                                    // Row(
                                    //   mainAxisAlignment: MainAxisAlignment.center,
                                    //   children: const [
                                    //     CircleAvatar(
                                    //       backgroundColor: Colors.white,
                                    //       child: Icon(
                                    //         Icons.facebook,
                                    //         color: Colors.blue,
                                    //       ),
                                    //     ),
                                    //     SizedBox(width: 16),
                                    //     CircleAvatar(
                                    //       backgroundColor: Colors.white,
                                    //       child: Icon(
                                    //         Icons.g_mobiledata,
                                    //         color: Colors.red,
                                    //         size: 28,
                                    //       ),
                                    //     ),
                                    //   ],
                                    // ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                    builder: (_) =>
                                                        const SignUpScreen(),
                                                  ),
                                                ),
                                          child: Text(
                                            'Create one',
                                            style: GoogleFonts.urbanist(
                                              fontSize: 15,
                                              color: orange,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ), // end Column (form fields)
                              ), // end Form
                            ), // end Card Container
                          ],
                        ), // end content Column
                      ), // end ConstrainedBox
                    ), // end Center
                  ), // end SingleChildScrollView
                ],
              ); // end Stack
            },
          ),
        ),
      ),
    );
  }
}
