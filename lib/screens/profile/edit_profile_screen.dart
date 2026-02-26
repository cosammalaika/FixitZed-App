import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/services/auth_service.dart';
import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/core/app_spacing.dart';
import 'package:fixitzed_app/widgets/app_text_field.dart';
import 'package:fixitzed_app/widgets/keyboard_safe_form.dart';

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
  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();
  final _emailFocus = FocusNode();
  String _initialEmail = '';
  bool _loading = true;
  bool _saving = false;
  Map<String, String> _backendFieldErrors = {};

  // Security (password change)
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();
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
    var first = (raw['first_name'] ?? '').toString();
    var last = (raw['last_name'] ?? '').toString();
    if (first.isEmpty && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      first = parts.isNotEmpty ? parts.first : '';
      last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    _firstCtrl.text = first;
    _lastCtrl.text = last;
    _emailCtrl.text = (raw['email'] ?? '').toString();
    _initialEmail = _emailCtrl.text.trim();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _firstFocus.dispose();
    _lastFocus.dispose();
    _emailFocus.dispose();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _backendFieldErrors = {};
    });
    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final includeEmail = email != _initialEmail.trim().toLowerCase();

    final result = await AuthService().updateProfile(
      firstName: first,
      lastName: last,
      email: includeEmail ? email : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop(true);
      return;
    }

    if (result.fieldErrors.isNotEmpty) {
      setState(() {
        _backendFieldErrors = Map<String, String>.from(result.fieldErrors);
      });
      _formKey.currentState?.validate();
    }

    final message = result.displayMessage?.trim();
    if (result.fieldErrors.isNotEmpty &&
        (message == null ||
            message.isEmpty ||
            message == 'The given data was invalid.' ||
            message == 'Please double-check your details and try again.')) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message?.isNotEmpty == true ? message! : 'Failed to update profile.')),
    );
  }

  void _clearBackendFieldErrors(Iterable<String> keys) {
    if (_backendFieldErrors.isEmpty) return;
    var changed = false;
    final next = Map<String, String>.from(_backendFieldErrors);
    for (final key in keys) {
      if (next.remove(key) != null) changed = true;
    }
    if (changed && mounted) {
      setState(() => _backendFieldErrors = next);
    }
  }

  String? _backendFieldError(Iterable<String> keys) {
    for (final key in keys) {
      final msg = _backendFieldErrors[key];
      if (msg != null && msg.trim().isNotEmpty) return msg.trim();
    }
    return null;
  }

  bool _hasDigits(String value) => RegExp(r'\d').hasMatch(value);

  String? _validateNameField(
    String? value, {
    required String requiredMessage,
    required Iterable<String> backendKeys,
  }) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return requiredMessage;
    if (_hasDigits(s)) return 'Name cannot contain numbers';
    return _backendFieldError(backendKeys);
  }

  String? _validateEmailField(String? value) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return 'Required';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s);
    if (!ok) return 'Enter a valid email';
    final parts = s.split('@');
    if (parts.length == 2 && parts[1].toLowerCase() == 'example.com') {
      return 'Please use a real email address';
    }
    return _backendFieldError(const ['email']);
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
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
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.2,
      ),
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
        const SnackBar(
          content: Text('New password must be at least 6 characters'),
        ),
      );
      return;
    }
    if (neu != conf) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
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
      SnackBar(
        content: Text(ok ? 'Password updated' : 'Failed to update password'),
      ),
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
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : KeyboardSafeForm(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Name'),
                    FocusAware(
                      focusNode: _firstFocus,
                      child: AppTextField(
                        controller: _firstCtrl,
                        focusNode: _firstFocus,
                        nextFocusNode: _lastFocus,
                        textInputAction: TextInputAction.next,
                        labelText: 'First Name',
                        onChanged: (_) => _clearBackendFieldErrors(
                          const ['first_name', 'firstName', 'name', 'full_name'],
                        ),
                        validator: (v) => _validateNameField(
                          v,
                          requiredMessage: 'Required',
                          backendKeys: const [
                            'first_name',
                            'firstName',
                            'name',
                            'full_name',
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FocusAware(
                      focusNode: _lastFocus,
                      child: AppTextField(
                        controller: _lastCtrl,
                        focusNode: _lastFocus,
                        nextFocusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        labelText: 'Last Name',
                        onChanged: (_) => _clearBackendFieldErrors(
                          const ['last_name', 'lastName', 'name', 'full_name'],
                        ),
                        validator: (v) => _validateNameField(
                          v,
                          requiredMessage: 'Required',
                          backendKeys: const [
                            'last_name',
                            'lastName',
                            'name',
                            'full_name',
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FocusAware(
                      focusNode: _emailFocus,
                      child: AppTextField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        labelText: 'Email Address',
                        onChanged: (_) =>
                            _clearBackendFieldErrors(const ['email']),
                        validator: _validateEmailField,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),

                    // Security section
                    _sectionTitle('Security'),
                    FocusAware(
                      focusNode: _currentFocus,
                      child: AppTextField(
                        controller: _currentCtrl,
                        focusNode: _currentFocus,
                        nextFocusNode: _newFocus,
                        obscureText: !_showCurrent,
                        labelText: 'Current Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showCurrent
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _showCurrent = !_showCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FocusAware(
                      focusNode: _newFocus,
                      child: AppTextField(
                        controller: _newCtrl,
                        focusNode: _newFocus,
                        nextFocusNode: _confirmFocus,
                        obscureText: !_showNew,
                        labelText: 'New Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showNew
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _showNew = !_showNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FocusAware(
                      focusNode: _confirmFocus,
                      child: AppTextField(
                        controller: _confirmCtrl,
                        focusNode: _confirmFocus,
                        textInputAction: TextInputAction.done,
                        obscureText: !_showConfirm,
                        labelText: 'Confirm New Password',
                        onFieldSubmitted: (_) => _changePassword(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _showConfirm = !_showConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: _savingPassword ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _savingPassword
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                    ],
                  ),
                ),
              ),
            );
  }
}
