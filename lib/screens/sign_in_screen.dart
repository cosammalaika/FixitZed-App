// lib/screens/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _rememberMe = false;
  bool _passwordVisible = false;
  bool _loading = false;
  bool _submitted = false; // control when to show validation
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    // Biometrics removed
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getString('remember_email');
    if (remembered != null && remembered.isNotEmpty) {
      _emailCtrl.text = remembered;
      setState(() => _rememberMe = true);
    }
  }

  // Biometrics removed

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final ok = await AuthService().login(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      if (!mounted) return;

      if (ok) {
        // Persist remembered email if opted in.
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('remember_email', _emailCtrl.text.trim());
        } else {
          await prefs.remove('remember_email');
        }
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showAlert('Sign in failed', 'Invalid email or password');
      }
    } catch (_) {
      if (!mounted) return;
      _showAlert('Network issue', 'Unable to sign in. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAlert(String title, String message) {
    const brand = Color(0xFFF1592A);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: GoogleFonts.urbanist()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.urbanist(
                color: brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: constraints.maxHeight * 0.36,
                    decoration: BoxDecoration(color: Colors.grey.shade900),
                  ),
                  // Top-right logo similar to onboarding
                  Positioned(
                    top: 12,
                    right: 16,
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 150),
                        Text(
                          'Welcome back!',
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Login to your account',
                          style: GoogleFonts.urbanist(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Email
                                SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                  cursorColor: const Color(0xFFF1592A),
                                  decoration: InputDecoration(
                                    labelText: "Email Address",
                                    hintText: "Enter your email",
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant
                                        .withOpacity(0.18),
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                        width: 1,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFF1592A),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty)
                                      return 'Identifier is required';
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
                                    final isUsername = s.length >= 3;
                                    return (isEmail || isPhone || isUsername)
                                        ? null
                                        : 'Enter email, phone or username';
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
                                    fontSize: 14,
                                  ),
                                  cursorColor: const Color(0xFFF1592A),
                                  decoration: InputDecoration(
                                    labelText: "Password",
                                    hintText: "Enter your password",
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant
                                        .withOpacity(0.18),
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                        width: 1,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(context).dividerColor,
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
                                    if (s.isEmpty)
                                      return 'Password is required';
                                    if (s.length < 6) return 'Min 6 characters';
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
                                              () => _rememberMe = val ?? false,
                                            ),
                                    ),
                                    const Text("Remember Me"),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () {
                                              // TODO: push Forgot Password screen
                                            },
                                      child: Text(
                                        "Forgot Password?",
                                        style: GoogleFonts.urbanist(
                                          color: orange,
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
                                          "Sign In",
                                          style: GoogleFonts.urbanist(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),

                                const SizedBox(height: 20),

                                // // Or divider
                                // Row(
                                //   children: [
                                //     Expanded(
                                //       child: Divider(color: Colors.grey.shade400),
                                //     ),
                                //     Padding(
                                //       padding: const EdgeInsets.symmetric(
                                //         horizontal: 8,
                                //       ),
                                //       child: Text("Or", style: GoogleFonts.urbanist()),
                                //     ),
                                //     Expanded(
                                //       child: Divider(color: Colors.grey.shade400),
                                //     ),
                                //   ],
                                // ),

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
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        'Or login with',
                                        style: GoogleFonts.urbanist(
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    CircleAvatar(
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.facebook,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    CircleAvatar(
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.g_mobiledata,
                                        color: Colors.red,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Don’t have an account ? ',
                                      style: GoogleFonts.urbanist(
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _loading
                                          ? null
                                          : () {
                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SignUpScreen(),
                                                ),
                                              );
                                            },
                                      child: Text(
                                        'Sign Up',
                                        style: GoogleFonts.urbanist(
                                          color: orange,
                                          fontWeight: FontWeight.w600,
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
                  ), // end SingleChildScrollView
                ],
              ); // end Stack
            },
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String asset) {
    return InkWell(
      onTap: _loading
          ? null
          : () {
              // TODO: Implement social auth
            },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Image.asset(asset, height: 28),
      ),
    );
  }
}
