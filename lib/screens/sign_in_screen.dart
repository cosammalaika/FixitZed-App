// lib/screens/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
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
        _showSnack('Invalid email or password');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to sign in. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFF1592A);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    autovalidateMode:
                        _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Image.asset(
                            "assets/images/logo-sm.png",
                            height: 60,
                          ),
                        ),
                        const SizedBox(height: 40),

                        Text(
                          "Sign In",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: "Email Address",
                            hintText: "Enter your email",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) return 'Email is required';
                            final ok = RegExp(
                              r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$",
                            ).hasMatch(s);
                            return ok ? null : 'Enter a valid email';
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: "Password",
                            hintText: "Enter your password",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
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
                          ),
                          validator: (v) {
                            final s = v ?? '';
                            if (s.isEmpty) return 'Password is required';
                            if (s.length < 8) return 'Min 8 characters';
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
                                style: GoogleFonts.urbanist(color: orange),
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                        const SizedBox(height: 24),
                        // Go to Sign Up
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don’t have an account? ",
                              style: GoogleFonts.urbanist(),
                            ),
                            GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SignUpScreen(),
                                        ),
                                      );
                                    },
                              child: Text(
                                "Sign Up",
                                style: GoogleFonts.urbanist(
                                  color: orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
