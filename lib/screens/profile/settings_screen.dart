import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kPush = 'settings_push_notifications';
  static const _kEmail = 'settings_email_notifications';
  static const _kDark = 'settings_dark_mode';
  static const _kBiometric = 'settings_biometric_login';
  static const _kLanguage = 'settings_language';

  bool pushOn = true;
  bool emailOn = true;
  bool darkOn = false;
  bool biometricOn = false;
  String language = 'English';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pushOn = prefs.getBool(_kPush) ?? true;
      emailOn = prefs.getBool(_kEmail) ?? true;
      darkOn = prefs.getBool(_kDark) ?? false;
      biometricOn = prefs.getBool(_kBiometric) ?? false;
      language = prefs.getString(_kLanguage) ?? 'English';
      _loading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black54)),
      );

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Settings', style: GoogleFonts.urbanist(color: Colors.black, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionTitle('General'),
                ListTile(
                  title: Text('Language', style: GoogleFonts.urbanist()),
                  subtitle: Text(language, style: GoogleFonts.urbanist(color: Colors.black54)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  onTap: () async {
                    final choice = await showModalBottomSheet<String>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final lang in ['English', 'Bemba', 'Nyanja'])
                              ListTile(
                                title: Text(lang),
                                onTap: () => Navigator.pop(context, lang),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (choice != null) {
                      setState(() => language = choice);
                      _saveString(_kLanguage, choice);
                    }
                  },
                ),

                _sectionTitle('Notifications'),
                SwitchListTile(
                  value: pushOn,
                  onChanged: (v) {
                    setState(() => pushOn = v);
                    _saveBool(_kPush, v);
                  },
                  activeColor: brand,
                  title: Text('Push Notifications', style: GoogleFonts.urbanist()),
                  subtitle: Text('Receive in-app updates and alerts', style: GoogleFonts.urbanist(color: Colors.black54)),
                ),
                SwitchListTile(
                  value: emailOn,
                  onChanged: (v) {
                    setState(() => emailOn = v);
                    _saveBool(_kEmail, v);
                  },
                  activeColor: brand,
                  title: Text('Email Notifications', style: GoogleFonts.urbanist()),
                  subtitle: Text('Get booking and promo emails', style: GoogleFonts.urbanist(color: Colors.black54)),
                ),

                _sectionTitle('Appearance'),
                SwitchListTile(
                  value: darkOn,
                  onChanged: (v) {
                    setState(() => darkOn = v);
                    _saveBool(_kDark, v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Theme preference saved')), // hook into app theme if needed
                    );
                  },
                  activeColor: brand,
                  title: Text('Dark Mode', style: GoogleFonts.urbanist()),
                  subtitle: Text('Reduce eye strain at night', style: GoogleFonts.urbanist(color: Colors.black54)),
                ),

                _sectionTitle('Security'),
                SwitchListTile(
                  value: biometricOn,
                  onChanged: (v) {
                    setState(() => biometricOn = v);
                    _saveBool(_kBiometric, v);
                  },
                  activeColor: brand,
                  title: Text('Biometric Login', style: GoogleFonts.urbanist()),
                  subtitle: Text('Use fingerprint or face to sign in', style: GoogleFonts.urbanist(color: Colors.black54)),
                ),
                ListTile(
                  title: Text('Change Password', style: GoogleFonts.urbanist()),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  onTap: () {
                    // Route to password update screen if available
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password update coming soon')));
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
    );
  }
}

