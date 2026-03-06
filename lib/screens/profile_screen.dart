import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show NetworkImageLoadException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fixitzed_app/services/auth_service.dart';
import 'package:fixitzed_app/services/profile_photo_service.dart';
import 'package:fixitzed_app/services/report_service.dart';
import 'package:fixitzed_app/state/dashboard_controller.dart';
import 'package:fixitzed_app/state/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  WidgetRef? _ref;
  final Color brand = const Color(0xFFF1592A);
  bool _uploadingPhoto = false;
  String? _optimisticAvatarPath;
  String? _pendingNetworkAvatarUrl;
  String _lastLoggedAvatarDisplayUrl = '';

  Widget _menuItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? iconColor,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          brand.withOpacity(0.32),
                          scheme.secondary.withOpacity(0.18),
                        ]
                      : const [Color(0x1AF1592A), Color(0x33F1592A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor ?? brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withOpacity(isDark ? 0.45 : 0.35),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        tile,
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outline.withOpacity(isDark ? 0.12 : 0.06),
          ),
      ],
    );
  }

  Future<void> _openEditProfile() async {
    final res = await Navigator.pushNamed(context, '/profile/edit');
    if (res == true) {
      final ref = _ref;
      if (ref == null) return;
      await ref.read(profileControllerProvider.notifier).refresh();
    }
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await _showLogoutConfirmationSheet();
    if (shouldLogout != true) return;

    await AuthService().logout();
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (r) => false),
    );
  }

  Future<bool?> _showLogoutConfirmationSheet() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const destructiveColor = Color(0xFFD64545);

    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, -8),
                      ),
                    ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: isDark ? 0.35 : 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: brand.withValues(alpha: isDark ? 0.22 : 0.14),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: brand.withValues(alpha: isDark ? 0.2 : 0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: brand,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Are you sure you want to log out?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You'll need to sign in again to access your account.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.onSurface.withValues(alpha: 0.78),
                            side: BorderSide(
                              color: scheme.outline.withValues(alpha: isDark ? 0.3 : 0.2),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: destructiveColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: GoogleFonts.urbanist(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          child: const Text('Log out'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showChangePhotoSheet() async {
    if (_uploadingPhoto) return;
    final selection = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Capture photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || selection == null) return;

    final picker = ProfilePhotoService.instance;
    String? path;
    if (selection == 'camera') {
      path = await picker.pickFromCamera();
    } else if (selection == 'gallery') {
      path = await picker.pickFromGallery();
    }
    if (!mounted || path == null || path.isEmpty) return;

    await _uploadProfilePhoto(path);
  }

  Future<void> _uploadProfilePhoto(String path) async {
    if (_uploadingPhoto) return;
    final previousOptimisticPath = _optimisticAvatarPath;
    final previousAvatarUrl = _currentPersistedAvatarUrl();
    setState(() {
      _uploadingPhoto = true;
      _optimisticAvatarPath = path;
      _pendingNetworkAvatarUrl = null;
    });

    var success = false;
    try {
      success = await AuthService().updateProfilePhoto(path);
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
    if (!mounted) return;

    if (success) {
      final ref = _ref;
      var avatarConfirmed = ref == null;
      if (ref != null) {
        avatarConfirmed = await _refreshAndConfirmAvatar(
          ref,
          previousAvatarUrl: previousAvatarUrl,
        );
        unawaited(ref.read(dashboardControllerProvider.notifier).refresh());
      }
      if (mounted && avatarConfirmed) {
        final refreshedAvatarUrl = _currentPersistedAvatarUrl();
        setState(() {
          _pendingNetworkAvatarUrl =
              refreshedAvatarUrl.isEmpty ? null : refreshedAvatarUrl;
        });
        _logAvatarFlow(
          'waiting for network avatar load before clearing preview '
          'pending="$_pendingNetworkAvatarUrl"',
        );
      }
      if (!avatarConfirmed) {
        _logAvatarFlow(
          'upload reported success but refreshed profile avatar was not confirmed; keeping local preview',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo upload succeeded, but profile sync is still pending.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _optimisticAvatarPath = previousOptimisticPath;
        _pendingNetworkAvatarUrl = null;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update profile photo.')),
    );
  }

  String _currentPersistedAvatarUrl() {
    final ref = _ref;
    if (ref == null) return '';
    final current = ref.read(profileControllerProvider).valueOrNull;
    final avatar = current?.avatarUrl?.trim() ?? '';
    return avatar.toLowerCase() == 'null' ? '' : avatar;
  }

  Future<bool> _refreshAndConfirmAvatar(
    WidgetRef ref, {
    required String previousAvatarUrl,
  }) async {
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      await ref.read(profileControllerProvider.notifier).refresh();
      final current = ref.read(profileControllerProvider).valueOrNull;
      final avatar = current?.avatarUrl?.trim() ?? '';
      final normalizedAvatar = avatar.toLowerCase() == 'null' ? '' : avatar;
      final hasAvatar = normalizedAvatar.isNotEmpty;
      final isAbsolute = _isAbsoluteHttpUrl(normalizedAvatar);
      final changed = previousAvatarUrl.isEmpty || normalizedAvatar != previousAvatarUrl;

      _logAvatarFlow(
        'confirm attempt=$attempt hasAvatar=$hasAvatar isAbsolute=$isAbsolute changed=$changed '
        'previous="$previousAvatarUrl" current="$normalizedAvatar"',
      );

      if (hasAvatar && isAbsolute) {
        return true;
      }
    }

    return false;
  }

  void _logAvatarFlow(String message) {
    if (!kDebugMode) return;
    debugPrint('[ProfileScreen.avatar] $message');
  }

  bool _isAbsoluteHttpUrl(String url) {
    if (url.isEmpty) return false;
    final parsed = Uri.tryParse(url);
    if (parsed == null) return false;
    if (!parsed.hasScheme || parsed.host.isEmpty) return false;
    return parsed.scheme == 'http' || parsed.scheme == 'https';
  }

  void _logAvatarUrlIfChanged(String url) {
    if (!kDebugMode) return;
    final trimmed = url.trim();
    if (trimmed == _lastLoggedAvatarDisplayUrl) return;
    _lastLoggedAvatarDisplayUrl = trimmed;
    debugPrint('[ProfileScreen.avatar] render final url="$trimmed"');
  }

  void _onProfileAvatarNetworkLoaded(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty || !mounted) return;
    final pending = _pendingNetworkAvatarUrl?.trim() ?? '';
    _logAvatarFlow(
      'network avatar loaded url="$normalized" pending="$pending" '
      'localPreview="${_optimisticAvatarPath ?? ''}"',
    );

    if (_optimisticAvatarPath == null) return;
    if (pending.isEmpty) {
      _logAvatarFlow('ignoring network load because no pending avatar url is set yet');
      return;
    }
    if (pending.isNotEmpty && pending != normalized) {
      _logAvatarFlow(
        'ignoring stale network load because pending url differs '
        'loaded="$normalized"',
      );
      return;
    }

    setState(() {
      _optimisticAvatarPath = null;
      _pendingNetworkAvatarUrl = null;
    });
  }

  void _showAvatarPreview(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return;
    }
    _logAvatarFlow('view photo url="$trimmed"');
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            child: Image.network(
              trimmed,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) {
                  _logAvatarFlow('[Avatar] LOADED SUCCESS url=$trimmed');
                  return child;
                }
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (_, error, __) {
                _logAvatarFlow('view photo load failed url="$trimmed" error=$error');
                return Image.asset('assets/images/logo-sm.png', fit: BoxFit.cover);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        _ref = ref;
        final profileAsync = ref.watch(profileControllerProvider);

        return Scaffold(
          backgroundColor: const Color(0xFFF9F4F1),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            centerTitle: true,
            title: Text(
              'Profile',
              style: GoogleFonts.urbanist(
                color: const Color(0xFF2C2C2C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: profileAsync.when(
            loading: () {
              final previous = profileAsync.valueOrNull;
              if (previous != null) return _buildBody(previous);
              return const Center(child: CircularProgressIndicator());
            },
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: Colors.black38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "We couldn't load your profile.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(profileControllerProvider.notifier)
                          .refresh(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1592A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: _buildBody,
          ),
        );
      },
    );
  }

  Widget _buildBody(ProfileState profile) {
    final name = profile.name;
    final email = profile.email;
    final avatarUrl = profile.avatarUrl ?? '';
    final avatarDisplayUrl = avatarUrl;
    _logAvatarUrlIfChanged(avatarDisplayUrl);
    final location = profile.location;
    final phone = profile.phone;
    final isFixer = profile.isFixer;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF1592A), Color(0xFFFF8A5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF1592A).withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ProfileAvatar(
                      url: avatarDisplayUrl,
                      localFilePath: _optimisticAvatarPath,
                      radius: 36,
                      isUploading: _uploadingPhoto,
                      onChangePhoto: _showChangePhotoSheet,
                      onViewPhoto: () => _showAvatarPreview(avatarDisplayUrl),
                      onNetworkImageLoaded: _onProfileAvatarNetworkLoaded,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Hello there' : name,
                            style: GoogleFonts.urbanist(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email.isEmpty ? 'No email on file' : email,
                            style: GoogleFonts.urbanist(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  phone,
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Manage your requests and keep your details up to date.',
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Column(
              children: [
                _menuItem(
                  Icons.edit_rounded,
                  'Edit Profile',
                  onTap: _openEditProfile,
                ),
                _menuItem(
                  Icons.settings_rounded,
                  'Settings',
                  onTap: () =>
                      Navigator.pushNamed(context, '/profile/settings'),
                ),
                _menuItem(
                  Icons.card_giftcard_rounded,
                  'Invite a friend',
                  onTap: () => Navigator.pushNamed(context, '/profile/invite'),
                ),
                _menuItem(
                  Icons.help_outline_rounded,
                  'FAQs',
                  onTap: () => Navigator.pushNamed(context, '/profile/faqs'),
                ),
                _menuItem(
                  Icons.info_rounded,
                  'About FixitZed',
                  onTap: () => Navigator.pushNamed(context, '/about'),
                ),
                _menuItem(
                  Icons.flag_outlined,
                  'Report a Fixer',
                  onTap: () => _showReportSheet(type: 'fixer'),
                ),
                _menuItem(
                  Icons.logout_rounded,
                  'Logout',
                  iconColor: Colors.red,
                  showDivider: false,
                  onTap: _confirmAndLogout,
                ),
              ],
            ),
          ),
          if (!isFixer) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD9C9), Color(0xFFFFF1EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 10),
                          ],
                        ),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: Color(0xFFF1592A),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Interested in earning as a Fixer?',
                          style: GoogleFonts.urbanist(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: const Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Apply in a few minutes and start taking on service requests tailored to your skills.',
                    style: GoogleFonts.urbanist(color: const Color(0xFF5B5B5B)),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/fixer/apply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1592A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Become a Fixer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatefulWidget {
  final String? url;
  final String? localFilePath;
  final double radius;
  final bool isUploading;
  final VoidCallback? onChangePhoto;
  final VoidCallback? onViewPhoto;
  final ValueChanged<String>? onNetworkImageLoaded;
  const _ProfileAvatar({
    required this.url,
    this.localFilePath,
    this.radius = 32,
    this.isUploading = false,
    this.onChangePhoto,
    this.onViewPhoto,
    this.onNetworkImageLoaded,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  String _lastLoggedNetworkUrl = '';
  String _lastLoadedNetworkUrl = '';

  @override
  void didUpdateWidget(covariant _ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newUrl = widget.url?.trim() ?? '';
    final oldUrl = oldWidget.url?.trim() ?? '';
    if (oldUrl != newUrl) {
      _lastLoadedNetworkUrl = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final innerRadius = widget.radius - 2;
    final placeholder = ClipOval(
      child: Image.asset(
        'assets/images/logo-sm.png',
        width: innerRadius * 2,
        height: innerRadius * 2,
        fit: BoxFit.cover,
      ),
    );

    final url = widget.url?.trim() ?? '';
    final validUrl = url.isNotEmpty && url.toLowerCase() != 'null';
    final localPath = widget.localFilePath?.trim() ?? '';
    final hasLocalPreview = localPath.isNotEmpty;
    final networkLoadedForCurrentUrl = _lastLoadedNetworkUrl == url;
    final shouldKeepPreview = hasLocalPreview && (!validUrl || !networkLoadedForCurrentUrl);

    final localPreview = ClipOval(
      child: Image.file(
        File(localPath),
        width: innerRadius * 2,
        height: innerRadius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );

    Widget child = placeholder;
    if (validUrl) {
      _logNetworkUrlIfChanged(url);
      final networkImage = ClipOval(
        child: Image.network(
          url,
          width: innerRadius * 2,
          height: innerRadius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (_, networkChild, progress) {
            if (progress == null) {
              _logNetworkLoadSuccess(url);
              _notifyLoaded(url);
              return networkChild;
            }
            return SizedBox(
              width: innerRadius * 2,
              height: innerRadius * 2,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, error, __) {
            _debugAvatarError('LOAD FAILED url=$url error=${_describeImageError(error)}');
            return placeholder;
          },
        ),
      );

      if (shouldKeepPreview) {
        child = Stack(
          alignment: Alignment.center,
          children: [
            networkImage,
            localPreview,
          ],
        );
      } else {
        child = networkImage;
      }
    } else if (hasLocalPreview) {
      child = localPreview;
    }

    return GestureDetector(
      onTap: () => _showOptions(context, hasImage: validUrl),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.white,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            child,
            if (widget.isUploading)
              Container(
                width: innerRadius * 2,
                height: innerRadius * 2,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            if (widget.isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, {required bool hasImage}) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_rounded),
              title: const Text('View profile photo'),
              enabled: hasImage,
              onTap: hasImage
                  ? () {
                      Navigator.of(ctx).pop();
                      if (widget.onViewPhoto != null) {
                        widget.onViewPhoto!.call();
                      } else {
                        _defaultPreview(context);
                      }
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Edit profile photo'),
              enabled: widget.onChangePhoto != null,
              onTap: widget.onChangePhoto != null
                  ? () {
                      Navigator.of(ctx).pop();
                      widget.onChangePhoto!.call();
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _defaultPreview(BuildContext context) {
    final url = widget.url?.trim() ?? '';
    _debugAvatarLog('default preview url="$url"');
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            child: url.isEmpty
                ? Image.asset('assets/images/logo-sm.png', fit: BoxFit.cover)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) {
                        _debugAvatarLog('[Avatar] LOADED SUCCESS url=$url');
                        return child;
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (_, error, __) {
                      _debugAvatarError('default preview load failed: $error');
                      return Image.asset(
                        'assets/images/logo-sm.png',
                        fit: BoxFit.cover,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  void _logNetworkUrlIfChanged(String url) {
    if (!kDebugMode) return;
    if (url == _lastLoggedNetworkUrl) return;
    _lastLoggedNetworkUrl = url;
    debugPrint('[Avatar] LOAD ATTEMPT url=$url');
  }

  void _logNetworkLoadSuccess(String url) {
    if (!kDebugMode) return;
    if (_lastLoadedNetworkUrl == url) return;
    _lastLoadedNetworkUrl = url;
    debugPrint('[Avatar] LOADED SUCCESS url=$url');
  }

  void _notifyLoaded(String url) {
    if (widget.onNetworkImageLoaded == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onNetworkImageLoaded?.call(url);
    });
  }

  void _debugAvatarError(String message) {
    if (!kDebugMode) return;
    debugPrint('[Avatar] $message');
  }

  void _debugAvatarLog(String message) {
    if (!kDebugMode) return;
    debugPrint('[Avatar] $message');
  }

  String _describeImageError(Object error) {
    if (error is NetworkImageLoadException) {
      return 'NetworkImageLoadException(statusCode=${error.statusCode}, uri=${error.uri})';
    }
    return error.toString();
  }
}

extension _ReportSheet on _ProfileScreenState {
  Future<void> _showReportSheet({required String type}) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    var submitting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF8F3), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
              child: StatefulBuilder(
                builder: (ctx, setLocal) {
                  InputDecoration deco(
                    String label, {
                    String? hint,
                    IconData? icon,
                  }) => InputDecoration(
                    labelText: label,
                    hintText: hint,
                    prefixIcon: icon != null ? Icon(icon) : null,
                    filled: true,
                    fillColor: const Color(0xFFF3F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF1592A), Color(0xFFFFA26C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF1592A,
                              ).withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flag_outlined,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Report ${type == 'fixer' ? 'a Fixer' : 'an Issue'}',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Help us keep the community safe.',
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: subjectCtrl,
                        decoration: deco(
                          'Subject',
                          hint: 'Short title',
                          icon: Icons.subject_rounded,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 5,
                        decoration: deco(
                          'Message',
                          hint: 'Describe the issue',
                          icon: Icons.message_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  setLocal(() => submitting = true);
                                  final ok = await ReportService().submit(
                                    type: type,
                                    subject: subjectCtrl.text.trim(),
                                    message: messageCtrl.text.trim(),
                                  );
                                  if (!mounted) return;
                                  setLocal(() => submitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Report submitted'
                                            : 'Failed to submit report',
                                      ),
                                    ),
                                  );
                                  if (ok) Navigator.of(ctx).pop();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1592A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(submitting ? 'Submitting…' : 'Submit'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
