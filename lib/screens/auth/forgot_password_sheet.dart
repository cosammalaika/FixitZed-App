import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/services/auth_service.dart';

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    this.initialIdentifier,
  });

  final String? initialIdentifier;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _identifierCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _requestKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  bool _requesting = false;
  bool _resetting = false;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialIdentifier?.trim();
    if (seed != null && seed.isNotEmpty) {
      _identifierCtrl.text = seed;
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_requesting) return;
    if (!(_requestKey.currentState?.validate() ?? false)) return;

    setState(() => _requesting = true);
    final result = await AuthService().forgotPassword(
      _identifierCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _codeSent = result.success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.displayMessage ??
            'If we find a matching account, a reset code will be emailed shortly.'),
        backgroundColor: result.success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_resetting) return;
    if (!(_resetKey.currentState?.validate() ?? false)) return;

    setState(() => _resetting = true);
    final result = await AuthService().resetPassword(
      identifier: _identifierCtrl.text.trim(),
      token: _codeCtrl.text.trim(),
      password: _passwordCtrl.text,
      passwordConfirmation: _confirmCtrl.text,
    );
    if (!mounted) return;
    setState(() => _resetting = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.displayMessage ??
              'Password updated successfully. You can now sign in.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.displayMessage ?? 'Unable to update the password. Try again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    const accent = Color(0xFFF1592A);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _codeSent ? Icons.lock_reset_rounded : Icons.mark_email_read_outlined,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset password',
                            style: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _codeSent
                                ? 'We just sent you a 6-digit code. Enter it below and set a new password to finish.'
                                : 'Forgot your password? Enter the email or phone number on your account and we’ll email you a reset code.',
                            style: GoogleFonts.urbanist(
                              color: theme.hintColor,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _codeSent ? _buildResetForm(accent) : _buildRequestForm(accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestForm(Color accent) {
    return Form(
      key: _requestKey,
      child: Column(
        children: [
          TextFormField(
            controller: _identifierCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email or phone number',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the email or phone number for your account.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _requesting ? null : _sendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _requesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Send reset code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetForm(Color accent) {
    return Form(
      key: _resetKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '6-digit code',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.length != 6) {
                return 'Enter the 6-digit code from the email.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
            ),
            validator: (value) {
              final text = value ?? '';
              if (text.length < 8) {
                return 'Password must be at least 8 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
            ),
            validator: (value) {
              if (value != _passwordCtrl.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _resetting ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _resetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Update password'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _requesting
                ? null
                : () => setState(() => _codeSent = false),
            style: TextButton.styleFrom(
              foregroundColor: accent,
            ),
            child: const Text(
              'Send code again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
