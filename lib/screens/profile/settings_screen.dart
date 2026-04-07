import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/core/settings.dart';
import 'package:fixitzed_app/services/auth_service.dart';
import 'package:fixitzed_app/services/notification_settings_service.dart';
import 'package:fixitzed_app/utils/app_snack.dart';

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

  final NotificationSettingsService _notificationService =
      NotificationSettingsService();
  bool pushOn = true;
  bool emailOn = true;
  bool darkOn = false;
  String language = 'English';
  bool _loading = true;
  bool _pushSyncing = false;
  bool _emailSyncing = false;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var pushPref = prefs.getBool(_kPush) ?? true;
    var emailPref = prefs.getBool(_kEmail) ?? true;
    final remote = await _notificationService.fetch();
    if (remote.isNotEmpty) {
      pushPref = remote['push'] ?? pushPref;
      emailPref = remote['email'] ?? emailPref;
      await prefs.setBool(_kPush, pushPref);
      await prefs.setBool(_kEmail, emailPref);
    }
    setState(() {
      pushOn = pushPref;
      emailOn = emailPref;
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

  void _showSnack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2E7D32) : Colors.redAccent,
      ),
    );
  }

  Widget _settingsSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sectionColor = scheme.surface;
    final divider = Divider(
      height: 1,
      color: scheme.outline.withOpacity(isDark ? 0.15 : 0.08),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: scheme.onSurface.withOpacity(isDark ? 0.65 : 0.55),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: sectionColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) divider,
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileWrapper({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 18,
    ),
  }) {
    return Padding(padding: padding, child: child);
  }

  Widget _languageTile(BuildContext context, Color textColor, Color hintColor) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            final sc = theme.colorScheme;
            final isDark = theme.brightness == Brightness.dark;
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sc.surface,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -6),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sc.outlineVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final lang in ['English', 'Bemba', 'Nyanja'])
                      ListTile(
                        leading: const Icon(Icons.translate_rounded),
                        title: Text(
                          lang,
                          style: GoogleFonts.urbanist(
                            fontWeight: lang == language
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: lang == language
                            ? Icon(Icons.check_rounded, color: sc.primary)
                            : null,
                        onTap: () => Navigator.pop(ctx, lang),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
        if (choice != null) {
          setState(() => language = choice);
          await _saveString(_kLanguage, choice);
        }
      },
      child: _tileWrapper(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  language,
                  style: GoogleFonts.urbanist(fontSize: 13, color: hintColor),
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePushToggle(bool value) async {
    final previous = pushOn;
    setState(() {
      pushOn = value;
      _pushSyncing = true;
    });
    await _saveBool(_kPush, value);
    await AppSettings.setPushEnabled(value);
    final ok = await _notificationService.update(push: value);
    if (!mounted) return;
    setState(() => _pushSyncing = false);
    if (!ok) {
      setState(() => pushOn = previous);
      _showSnack('Unable to update push notifications', success: false);
    }
  }

  Future<void> _handleEmailToggle(bool value) async {
    final previous = emailOn;
    setState(() {
      emailOn = value;
      _emailSyncing = true;
    });
    await _saveBool(_kEmail, value);
    final ok = await _notificationService.update(email: value);
    if (!mounted) return;
    setState(() => _emailSyncing = false);
    if (!ok) {
      setState(() => emailOn = previous);
      _showSnack('Unable to update email notifications', success: false);
    }
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
    required Color hintColor,
    bool loading = false,
  }) {
    return _tileWrapper(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.urbanist(fontSize: 13, color: hintColor),
                ),
              ],
            ),
          ),
          loading
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color textColor,
    required Color hintColor,
    required VoidCallback? onTap,
    Color? iconColor,
    bool loading = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedIconColor = iconColor ?? scheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: loading ? null : onTap,
      child: _tileWrapper(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: resolvedIconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: resolvedIconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.urbanist(fontSize: 13, color: hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDeleteAccountFlow() async {
    if (_deletingAccount) return;

    final confirmed = await _showDeleteAccountSheet();
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    final result = await AuthService().deleteAccount();
    if (!mounted) return;
    setState(() => _deletingAccount = false);

    if (result.success) {
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (route) => false);
      AppSnack.show(result.displayMessage ?? 'Your account has been deleted.');
      return;
    }

    _showSnack(
      result.displayMessage ?? 'Unable to delete your account right now.',
      success: false,
    );
  }

  Future<bool?> _showDeleteAccountSheet() {
    final controller = TextEditingController();
    const destructive = Color(0xFFD64545);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        var canDelete = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Container(
                  color: theme.cardColor,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: destructive.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_forever_rounded,
                              color: destructive,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'Delete account permanently?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.urbanist(
                              color: scheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'This action cannot be undone. Your profile will be deleted, active sessions will be revoked, and personal app data such as saved locations, notifications and profile details will be removed or anonymized according to FixItZed policy.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.urbanist(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: destructive.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: destructive.withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: destructive,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Pending bookings may be cancelled and you will lose access to booking history, settings and saved account data.',
                                  style: GoogleFonts.urbanist(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Type DELETE to confirm',
                          style: GoogleFonts.urbanist(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) => setSheetState(
                            () => canDelete = value.trim() == 'DELETE',
                          ),
                          decoration: InputDecoration(
                            hintText: 'DELETE',
                            filled: true,
                            fillColor: scheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: destructive,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canDelete
                                ? () => Navigator.of(ctx).pop(true)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: destructive,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: destructive.withOpacity(
                                0.28,
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Delete Account'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Keep Account'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Widget _heroCard(BuildContext context) {
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFFA26C);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = LinearGradient(
      colors: isDark
          ? [brand.withOpacity(0.95), accent.withOpacity(0.85)]
          : const [brand, accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              color: brand.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: shadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tune your experience',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Control notifications, theme and language.',
                  style: GoogleFonts.urbanist(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final hintColor = scheme.onSurface.withOpacity(
      Theme.of(context).brightness == Brightness.dark ? 0.6 : 0.55,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        title: Text(
          'Settings',
          style: GoogleFonts.urbanist(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _heroCard(context),
                _settingsSection(
                  context: context,
                  title: 'General',
                  children: [_languageTile(context, onSurface, hintColor)],
                ),
                _settingsSection(
                  context: context,
                  title: 'Notifications',
                  children: [
                    _switchTile(
                      title: 'Push Notifications',
                      subtitle: 'Receive in-app updates and alerts',
                      value: pushOn,
                      onChanged: _handlePushToggle,
                      textColor: onSurface,
                      hintColor: hintColor,
                      loading: _pushSyncing,
                    ),
                    _switchTile(
                      title: 'Email Notifications',
                      subtitle: 'Get booking and promo emails',
                      value: emailOn,
                      onChanged: _handleEmailToggle,
                      textColor: onSurface,
                      hintColor: hintColor,
                      loading: _emailSyncing,
                    ),
                  ],
                ),
                _settingsSection(
                  context: context,
                  title: 'Appearance',
                  children: [
                    _switchTile(
                      title: 'Dark Mode',
                      subtitle: 'Reduce eye strain at night',
                      value: darkOn,
                      onChanged: (v) async {
                        setState(() => darkOn = v);
                        await _saveBool(_kDark, v);
                        await AppTheme.setDark(v);
                      },
                      textColor: onSurface,
                      hintColor: hintColor,
                    ),
                  ],
                ),
                _settingsSection(
                  context: context,
                  title: 'Account',
                  children: [
                    _actionTile(
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your FixItZed account',
                      icon: Icons.delete_forever_rounded,
                      iconColor: const Color(0xFFD64545),
                      textColor: const Color(0xFFD64545),
                      hintColor: hintColor,
                      loading: _deletingAccount,
                      onTap: _openDeleteAccountFlow,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
