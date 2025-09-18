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
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.urbanist(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _firstCtrl,
                      decoration: _dec('First Name'),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastCtrl,
                      decoration: _dec('Last Name'),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: _dec('Email Address'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Required';
                        final ok = RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}',
                        ).hasMatch(s);
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                    const Spacer(),
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
                  ],
                ),
              ),
            ),
    );
  }
}
