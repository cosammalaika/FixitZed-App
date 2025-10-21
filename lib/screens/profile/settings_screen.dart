import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/core/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kPush = 'settings_push_notifications';
  static const _kEmail = 'settings_email_notifications';
  static const _kDark = 'settings_dark_mode';
  static const _kLanguage = 'settings_language';

  bool pushOn = true;
  bool emailOn = true;
  bool darkOn = false;
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
    child: Text(
      text,
      style: GoogleFonts.urbanist(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: Colors.black54,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFFA26C);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Settings',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [brand, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: brand.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 12))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.settings_rounded, color: Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Tune your experience', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Control notifications, theme and language.', style: GoogleFonts.urbanist(color: Colors.white.withOpacity(0.9))),
                        ]),
                      ),
                    ],
                  ),
                ),
                _sectionTitle('General'),
                ListTile(
                  title: Text('Language', style: GoogleFonts.urbanist()),
                  subtitle: Text(
                    language,
                    style: GoogleFonts.urbanist(color: Colors.black54),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black26,
                  ),
                  onTap: () async {
                    final choice = await showModalBottomSheet<String>(
                      context: context,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFFFFF8F3), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  for (final lang in ['English', 'Bemba', 'Nyanja'])
                                    ListTile(
                                      leading: const Icon(Icons.translate_rounded),
                                      title: Text(lang),
                                      onTap: () => Navigator.pop(ctx, lang),
                                    ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
                    AppSettings.setPushEnabled(v);
                  },
                  activeColor: brand,
                  title: Text(
                    'Push Notifications',
                    style: GoogleFonts.urbanist(),
                  ),
                  subtitle: Text(
                    'Receive in-app updates and alerts',
                    style: GoogleFonts.urbanist(color: Colors.black54),
                  ),
                ),
                SwitchListTile(
                  value: emailOn,
                  onChanged: (v) {
                    setState(() => emailOn = v);
                    _saveBool(_kEmail, v);
                  },
                  activeColor: brand,
                  title: Text(
                    'Email Notifications',
                    style: GoogleFonts.urbanist(),
                  ),
                  subtitle: Text(
                    'Get booking and promo emails',
                    style: GoogleFonts.urbanist(color: Colors.black54),
                  ),
                ),

                _sectionTitle('Appearance'),
                SwitchListTile(
                  value: darkOn,
                  onChanged: (v) {
                    setState(() => darkOn = v);
                    _saveBool(_kDark, v);
                    AppTheme.setDark(v);
                  },
                  activeColor: brand,
                  title: Text('Dark Mode', style: GoogleFonts.urbanist()),
                  subtitle: Text(
                    'Reduce eye strain at night',
                    style: GoogleFonts.urbanist(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
