import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2),
        ),
        suffixIcon: suffix,
      );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await AuthService().changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Password updated' : 'Failed to update password')),
    );
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        centerTitle: true,
        title: Text(
          'Change Password',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _currentCtrl,
                  obscureText: !_showCurrent,
                  decoration: _dec(
                    'Current Password',
                    suffix: IconButton(
                      icon: Icon(_showCurrent ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showCurrent = !_showCurrent),
                    ),
                  ),
                  cursorColor: brand,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: !_showNew,
                  decoration: _dec(
                    'New Password',
                    suffix: IconButton(
                      icon: Icon(_showNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showNew = !_showNew),
                    ),
                  ),
                  cursorColor: brand,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  validator: (v) {
                    final s = v ?? '';
                    if (s.isEmpty) return 'Required';
                    if (s.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: !_showConfirm,
                  decoration: _dec(
                    'Confirm New Password',
                    suffix: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                  cursorColor: brand,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Required';
                    if (v != _newCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

