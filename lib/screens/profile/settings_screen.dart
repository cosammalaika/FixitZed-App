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
    final pushPref = prefs.getBool(_kPush) ?? true;
    final emailPref = prefs.getBool(_kEmail) ?? true;
    final darkPref = prefs.getBool(_kDark) ?? false;
    final languagePref = prefs.getString(_kLanguage) ?? 'English';
    if (!mounted) return;
    setState(() {
      pushOn = pushPref;
      emailOn = emailPref;
      darkOn = darkPref;
      language = languagePref;
      _loading = false;
    });

    final remote = await _notificationService.fetch();
    if (!mounted || remote.isEmpty) return;

    final resolvedPush = pushOn == pushPref
        ? (remote['push'] ?? pushOn)
        : pushOn;
    final resolvedEmail = emailOn == emailPref
        ? (remote['email'] ?? emailOn)
        : emailOn;
    await prefs.setBool(_kPush, resolvedPush);
    await prefs.setBool(_kEmail, resolvedEmail);
    if (!mounted) return;
    setState(() {
      pushOn = resolvedPush;
      emailOn = resolvedEmail;
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
    final colors = Theme.of(context).fx;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? colors.success : colors.danger,
      ),
    );
  }

  Widget _settingsSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colors = theme.fx;
    final divider = Divider(height: 1, color: colors.border);

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
                color: colors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
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
    final colors = Theme.of(context).fx;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            final sheetColors = theme.fx;
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: sheetColors.shadow,
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
                        color: sheetColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final lang in ['English', 'Bemba', 'Nyanja'])
                      ListTile(
                        leading: Icon(
                          Icons.translate_rounded,
                          color: sheetColors.brand,
                        ),
                        title: Text(
                          lang,
                          style: GoogleFonts.urbanist(
                            fontWeight: lang == language
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: sheetColors.textPrimary,
                          ),
                        ),
                        trailing: lang == language
                            ? Icon(
                                Icons.check_rounded,
                                color: sheetColors.brand,
                              )
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
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
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
    final colors = Theme.of(context).fx;
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
                color: resolvedIconColor.withValues(alpha: 0.12),
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
                : Icon(Icons.chevron_right_rounded, color: colors.textMuted),
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
    final destructive = Theme.of(context).fx.danger;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.fx;
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
                              color: colors.border,
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
                              color: destructive.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
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
                              color: colors.textPrimary,
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
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: destructive.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: destructive.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: destructive,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Pending bookings may be cancelled and you will lose access to booking history, settings and saved account data.',
                                  style: GoogleFonts.urbanist(
                                    color: colors.textPrimary,
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
                            color: colors.textPrimary,
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
                            fillColor: colors.surfaceSubtle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
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
                              disabledBackgroundColor: destructive.withValues(
                                alpha: 0.28,
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
    const brand = AppTheme.brand;
    const accent = AppTheme.brandAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = LinearGradient(
      colors: isDark
          ? [brand.withValues(alpha: 0.95), accent.withValues(alpha: 0.85)]
          : const [brand, accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              color: Theme.of(context).fx.shadow,
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
              color: Colors.white.withValues(alpha: 0.22),
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
                    color: Colors.white.withValues(alpha: 0.9),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = theme.fx;
    final onSurface = colors.textPrimary;
    final hintColor = colors.textSecondary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: scheme.onSurface),
        title: Text(
          'Settings',
          style: GoogleFonts.urbanist(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      iconColor: colors.danger,
                      textColor: colors.danger,
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
