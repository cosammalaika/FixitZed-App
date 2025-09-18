import 'package:fixitzed_app/screens/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final orange = const Color(0xFFF1592A);

  final _formKey = GlobalKey<FormState>();
  bool _submitted = false; // control when to show validation

  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final usernameCtrl = TextEditingController(); 
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool _loading = false;
  bool _pwVisible = false;
  bool _cpwVisible = false;

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    usernameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> handleSignUp() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}'
        .trim();
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final username = usernameCtrl.text.trim();
    final password = passCtrl.text;

    setState(() => _loading = true);
    try {
      final ok = await AuthService().register(
        name,
        email,
        phone,
        password,
        address: address.isEmpty ? null : address,
        username: username.isEmpty ? null : username,
      );
      if (!mounted) return;

      if (ok) {
        // Optional: clear remembered email on a fresh sign-up
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('remember_email');

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnack('Registration failed. Check your details and try again.');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unable to register right now. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _dec(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffix,
    );
  }

  Widget _row2(BuildContext context, Widget a, Widget b) {
    final wide = MediaQuery.of(context).size.width >= 600;
    if (wide) {
      return Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );
    }
    return Column(children: [a, const SizedBox(height: 12), b]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
                    const SizedBox(height: 30),

                    Text(
                      "Create Account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),

                    _row2(
                      context,
                      TextFormField(
                        controller: firstNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _dec("First Name"),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'First name is required'
                            : null,
                      ),
                      TextFormField(
                        controller: lastNameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _dec("Last Name"),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _row2(
                      context,
                      TextFormField(
                        controller: usernameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _dec("Username (optional)"),
                      ),
                      TextFormField(
                        controller: emailCtrl,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec("Email"),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Email is required';
                          final ok = RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
                          ).hasMatch(s);
                          return ok ? null : 'Enter a valid email';
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    _row2(
                      context,
                      TextFormField(
                        controller: phoneCtrl,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        decoration: _dec("Contact Number"),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Contact number is required'
                            : null,
                      ),
                      TextFormField(
                        controller: addressCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _dec("Address (optional)"),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _row2(
                      context,
                      TextFormField(
                        controller: passCtrl,
                        obscureText: !_pwVisible,
                        textInputAction: TextInputAction.next,
                        decoration: _dec(
                          "Password",
                          suffix: IconButton(
                            icon: Icon(
                              _pwVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: _loading
                                ? null
                                : () =>
                                      setState(() => _pwVisible = !_pwVisible),
                          ),
                        ),
                        validator: (v) {
                          final s = v ?? '';
                          if (s.isEmpty) return 'Password is required';
                          if (s.length < 8) return 'Minimum 8 characters';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: confirmPassCtrl,
                        obscureText: !_cpwVisible,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => handleSignUp(),
                        decoration: _dec(
                          "Confirm Password",
                          suffix: IconButton(
                            icon: Icon(
                              _cpwVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: _loading
                                ? null
                                : () => setState(
                                    () => _cpwVisible = !_cpwVisible,
                                  ),
                          ),
                        ),
                        validator: (v) => v != passCtrl.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: _loading ? null : handleSignUp,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              "Sign Up",
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: GoogleFonts.urbanist(),
                        ),
                        GestureDetector(
                          onTap: _loading
                              ? null
                              : () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignInScreen(),
                                    ),
                                  );
                                },
                          child: Text(
                            "Sign In",
                            style: GoogleFonts.urbanist(
                              color: orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
