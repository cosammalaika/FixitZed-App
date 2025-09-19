import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/home_service.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  // Security (password change)
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await HomeService().fetchMe();
    final raw = (me != null && me['user'] is Map)
        ? me['user'] as Map
        : (me ?? {});
    final name = (raw['name'] ?? raw['full_name'] ?? '').toString();
    String first = (raw['first_name'] ?? '').toString();
    String last = (raw['last_name'] ?? '').toString();
    if (first.isEmpty && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      first = parts.isNotEmpty ? parts.first : '';
      last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    _firstCtrl.text = first;
    _lastCtrl.text = last;
    _emailCtrl.text = (raw['email'] ?? '').toString();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await AuthService().updateProfile(
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Profile updated successfully.' : 'Failed to update profile.',
        ),
      ),
    );
    if (ok) Navigator.of(context).pop(true);
  }

  InputDecoration _dec(String label) => InputDecoration(
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
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Text(
          text,
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Theme.of(context).hintColor,
          ),
        ),
      );

  Future<void> _changePassword() async {
    final cur = _currentCtrl.text;
    final neu = _newCtrl.text;
    final conf = _confirmCtrl.text;

    // Only proceed if user entered something
    final wantsChange = cur.isNotEmpty || neu.isNotEmpty || conf.isNotEmpty;
    if (!wantsChange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter password fields to update')),
      );
      return;
    }

    // Basic validation inline
    if (cur.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is required')),
      );
      return;
    }
    if (neu.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters')),
      );
      return;
    }
    if (neu != conf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _savingPassword = true);
    final ok = await AuthService().changePassword(
      currentPassword: cur,
      newPassword: neu,
    );
    if (!mounted) return;
    setState(() => _savingPassword = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Password updated' : 'Failed to update password')),
    );
    if (ok) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    }
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
        title: Text(
          'Edit Profile',
          style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('Name'),
                      TextFormField(
                        controller: _firstCtrl,
                        decoration: _dec('First Name'),
                        textInputAction: TextInputAction.next,
                        cursorColor: brand,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastCtrl,
                        decoration: _dec('Last Name'),
                        textInputAction: TextInputAction.next,
                        cursorColor: brand,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: _dec('Email Address'),
                        keyboardType: TextInputType.emailAddress,
                        cursorColor: brand,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          final ok = RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}',
                          ).hasMatch(s);
                          return ok ? null : 'Enter a valid email';
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Changes'),
                      ),

                      // Security section
                      _sectionTitle('Security'),
                      TextFormField(
                        controller: _currentCtrl,
                        obscureText: !_showCurrent,
                        decoration: _dec(
                          'Current Password',
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_showCurrent ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _showCurrent = !_showCurrent),
                          ),
                        ),
                        cursorColor: brand,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newCtrl,
                        obscureText: !_showNew,
                        decoration: _dec('New Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_showNew ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _showNew = !_showNew),
                          ),
                        ),
                        cursorColor: brand,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: !_showConfirm,
                        decoration: _dec('Confirm New Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(_showConfirm ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _showConfirm = !_showConfirm),
                          ),
                        ),
                        cursorColor: brand,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _savingPassword ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _savingPassword
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
