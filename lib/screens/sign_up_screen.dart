import 'package:fixitzed_app/screens/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
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
      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.18),
      labelStyle: TextStyle(color: Theme.of(context).hintColor),
      hintStyle: TextStyle(color: Theme.of(context).hintColor),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFF1592A), width: 1.2),
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
    final brand = const Color(0xFFF1592A);
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
                        SizedBox(
                          height: 10 + MediaQuery.of(context).padding.top,
                        ),
                        Text(
                          'Create your account',
                          style: GoogleFonts.urbanist(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 15),
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
                                // Inputs
                                _row2(
                                  context,
                                  TextFormField(
                                    controller: firstNameCtrl,
                                    textInputAction: TextInputAction.next,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                    cursorColor: brand,
                                    decoration: _dec('First Name'),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'First name is required'
                                        : null,
                                  ),
                                  TextFormField(
                                    controller: lastNameCtrl,
                                    textInputAction: TextInputAction.next,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                    cursorColor: brand,
                                    decoration: _dec('Last Name'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: emailCtrl,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                  cursorColor: brand,
                                  decoration: _dec('Email Address'),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Email is required';
                                    final ok = RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
                                    ).hasMatch(s);
                                    return ok ? null : 'Enter a valid email';
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: passCtrl,
                                  obscureText: !_pwVisible,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                  cursorColor: brand,
                                  decoration: _dec(
                                    'Password',
                                    suffix: IconButton(
                                      icon: Icon(
                                        _pwVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: _loading
                                          ? null
                                          : () => setState(
                                              () => _pwVisible = !_pwVisible,
                                            ),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = v ?? '';
                                    if (s.isEmpty)
                                      return 'Password is required';
                                    if (s.length < 8)
                                      return 'Minimum 8 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: confirmPassCtrl,
                                  obscureText: !_cpwVisible,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                  cursorColor: brand,
                                  decoration: _dec(
                                    'Confirm Password',
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
                                const SizedBox(height: 12),
                                _row2(
                                  context,
                                  TextFormField(
                                    controller: phoneCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                    cursorColor: brand,
                                    decoration: _dec('Contact Number'),
                                    validator: (v) => (v ?? '').trim().isEmpty
                                        ? 'Contact number is required'
                                        : null,
                                  ),
                                  TextFormField(
                                    controller: addressCtrl,
                                    textInputAction: TextInputAction.next,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                    cursorColor: brand,
                                    decoration: _dec('Address (optional)'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Remember + forgot row
                                Row(
                                  children: [
                                    Checkbox(value: false, onChanged: (_) {}),
                                    Text(
                                      'Remember me',
                                      style: GoogleFonts.urbanist(),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Forgot Password ?',
                                      style: GoogleFonts.urbanist(
                                        color: brand,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // CTA
                                ElevatedButton(
                                  onPressed: _loading ? null : handleSignUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brand,
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
                                      : const Text('Sign Up'),
                                ),
                                const SizedBox(height: 16),
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
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account ? ',
                                      style: GoogleFonts.urbanist(
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _loading
                                          ? null
                                          : () => Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const SignInScreen(),
                                              ),
                                            ),
                                      child: Text(
                                        'Login',
                                        style: GoogleFonts.urbanist(
                                          color: brand,
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
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
