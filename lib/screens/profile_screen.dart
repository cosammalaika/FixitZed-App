import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/home_service.dart';
import '../services/auth_service.dart';
import '../core/api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _svc = HomeService();
  final Color brand = const Color(0xFFF1592A);

  String name = '';
  String email = '';
  String? avatarUrl;
  bool _loading = true;
  bool _isFixer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _svc.fetchMe();
    if (!mounted) return;
    setState(() {
      final raw = (me != null && me['user'] is Map)
          ? me['user'] as Map
          : (me ?? {});
      final first = (raw['first_name'] ?? '').toString().trim();
      final last = (raw['last_name'] ?? '').toString().trim();
      final fallbackName =
          (raw['name'] ?? raw['full_name'] ?? raw['username'] ?? '')
              .toString()
              .trim();
      name = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (name.isEmpty) name = fallbackName;
      email = (raw['email'] ?? '').toString();

      // Robust fixer detection across various API shapes
      bool fixer = false;
      final dynamic isFixerFlag = raw['is_fixer'] ?? raw['fixer'];
      if (isFixerFlag is bool) fixer = isFixerFlag;
      if (isFixerFlag is num) fixer = isFixerFlag != 0; // 1 => true
      if (isFixerFlag is String) {
        final v = isFixerFlag.trim().toLowerCase();
        fixer = v == '1' || v == 'true' || v == 'yes';
      }

      String roleStr =
          (raw['role'] ??
                  raw['user_type'] ??
                  raw['type'] ??
                  raw['account_type'] ??
                  '')
              .toString()
              .toLowerCase();
      if (roleStr.contains('fixer') || roleStr.contains('provider'))
        fixer = true;

      final roles = raw['roles'];
      if (roles is List) {
        for (final r in roles) {
          final s = r.toString().toLowerCase();
          if (s.contains('fixer') || s == 'provider') {
            fixer = true;
            break;
          }
        }
      }

      if (raw['fixer_profile'] != null) fixer = true;
      _isFixer = fixer;

      String? avatar =
          (raw['profile_photo_path'] ??
                  raw['avatar'] ??
                  raw['photo'] ??
                  raw['profile_photo_url'] ??
                  raw['image'])
              ?.toString();
      if (avatar != null && avatar.trim().isNotEmpty) {
        avatar = avatar.trim();
        if (!avatar.startsWith('http')) {
          final base = Api.baseUrl;
          final origin = base.endsWith('/api')
              ? base.substring(0, base.length - 4)
              : base;
          final path = avatar.startsWith('/') ? avatar.substring(1) : avatar;
          avatarUrl = path.startsWith('storage/')
              ? '$origin/$path'
              : '$origin/storage/$path';
        } else {
          avatarUrl = avatar;
        }
      }
      _loading = false;
    });
  }

  Widget _menuItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (iconColor ?? brand).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor ?? brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).hintColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage:
                            (avatarUrl != null && avatarUrl!.isNotEmpty)
                            ? (avatarUrl!.startsWith('http')
                                  ? NetworkImage(avatarUrl!) as ImageProvider
                                  : AssetImage(avatarUrl!))
                            : const AssetImage('assets/images/logo-sm.png'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'User' : name,
                              style: GoogleFonts.urbanist(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: GoogleFonts.urbanist(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Theme.of(context).dividerColor, height: 24),

                  _menuItem(
                    Icons.edit_rounded,
                    'Edit Profile',
                    onTap: () => Navigator.pushNamed(context, '/profile/edit'),
                  ),
                  // _menuItem(
                  //   Icons.location_on_rounded,
                  //   'Manage Address',
                  //   onTap: () =>
                  //       Navigator.pushNamed(context, '/profile/addresses'),
                  // ),
                  // _menuItem(
                  //   Icons.credit_card_rounded,
                  //   'Payment Methods',
                  //   onTap: () =>
                  //       Navigator.pushNamed(context, '/profile/payments'),
                  // ),
                  _menuItem(
                    Icons.calendar_today_rounded,
                    'My Booking',
                    onTap: () =>
                        Navigator.pushNamed(context, '/profile/bookings'),
                  ),
                  _menuItem(
                    Icons.settings_rounded,
                    'Settings',
                    onTap: () =>
                        Navigator.pushNamed(context, '/profile/settings'),
                  ),
                  _menuItem(
                    Icons.help_outline_rounded,
                    'FAQs',
                    onTap: () => Navigator.pushNamed(context, '/profile/faqs'),
                  ),
                  if (!_isFixer)
                    _menuItem(
                      Icons.handyman_rounded,
                      'Become a Fixer',
                      onTap: () => Navigator.pushNamed(context, '/fixer/apply'),
                    ),
                  _menuItem(
                    Icons.logout_rounded,
                    'Logout',
                    iconColor: Colors.red,
                    onTap: () async {
                      await AuthService().logout();
                      if (!mounted) return;
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/auth', (r) => false);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
