import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../state/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final Color brand = const Color(0xFFF1592A);

  Widget _menuItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? iconColor,
    bool showDivider = true,
  }) {
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
                gradient: const LinearGradient(
                  colors: [Color(0x1AF1592A), Color(0x33F1592A)],
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
                  color: const Color(0xFF1F1F1F),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );

    return Column(
      children: [
        tile,
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
                  'We couldn\'t load your profile.',
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
                  onPressed: () =>
                      ref.read(profileControllerProvider.notifier).refresh(),
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
  }

  Widget _buildBody(ProfileState profile) {
    final name = profile.name;
    final email = profile.email;
    final avatarUrl = profile.avatarUrl;
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
                  color: const Color(0xFFF1592A).withOpacity(0.22),
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
                    _ProfileAvatar(url: avatarUrl, radius: 36),
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
                              color: Colors.white.withOpacity(0.85),
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
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white.withOpacity(0.8),
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
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  phone,
                                  style: GoogleFonts.urbanist(
                                    color: Colors.white.withOpacity(0.8),
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
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
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
                          'Manage your bookings and keep your details up to date.',
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
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
                  onTap: () async {
                    final res = await Navigator.pushNamed(
                      context,
                      '/profile/edit',
                    );
                    if (res == true) {
                      await ref
                          .read(profileControllerProvider.notifier)
                          .refresh();
                    }
                  },
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
  final double radius;
  const _ProfileAvatar({required this.url, this.radius = 32});

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _failed = false;

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

    Widget child;
    if (!_failed && validUrl) {
      child = ClipOval(
        child: Image.network(
          url,
          width: innerRadius * 2,
          height: innerRadius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            if (!_failed && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failed = true);
              });
            }
            return placeholder;
          },
        ),
      );
    } else {
      child = placeholder;
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.white,
      child: child,
    );
  }
}

extension _ReportSheet on _ProfileScreenState {
  Future<void> _showReportSheet({required String type}) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool submitting = false;
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
                              color: const Color(0xFFF1592A).withOpacity(0.2),
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
                                color: Colors.white.withOpacity(0.2),
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
                                      color: Colors.white.withOpacity(0.9),
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
