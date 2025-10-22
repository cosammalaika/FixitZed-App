import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import 'package:fixitzed_app/state/profile_controller.dart';

class InviteFriendScreen extends ConsumerWidget {
  const InviteFriendScreen({super.key});

  static const String _defaultLink = 'https://fixitzed.com/app';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider).valueOrNull;
    final name = profile?.name.trim();
    final inviteLink = _buildInviteLink(profile);
    final message = _buildShareMessage(name, inviteLink);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Invite a Friend',
          style: GoogleFonts.urbanist(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F1F1F),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InviteHero(name: name, onShare: () => _share(message)),
                const SizedBox(height: 24),
                _InviteCard(
                  inviteLink: inviteLink,
                  onShare: () => _share(message),
                  onCopy: () => _copyLink(context, inviteLink),
                ),
                const SizedBox(height: 24),
                _PerksCard(
                  perks: const [
                    'Friends can connect with trusted fixers right away using your link.',
                    'Your name travels with the message so they know who invited them.',
                    'Need to resend it? Copy or share the link again anytime from this page.',
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _buildInviteLink(ProfileState? profile) {
    final email = profile?.email.trim();
    if (email != null && email.isNotEmpty) {
      final encoded = Uri.encodeComponent(email.toLowerCase());
      return '$_defaultLink?ref=$encoded';
    }
    return _defaultLink;
  }

  static String _buildShareMessage(String? name, String link) {
    final friendlyName = (name != null && name.isNotEmpty) ? name : 'I';
    return '$friendlyName just booked trusted fixers on FixitZed. '
        'Join me and get your repairs sorted in minutes: $link';
  }

  static Future<void> _share(String message) async {
    await Share.share(message, subject: 'Join me on FixitZed');
  }

  static void _copyLink(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Invite link copied to clipboard',
          style: GoogleFonts.urbanist(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero({required this.name, required this.onShare});

  final String? name;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFFF1592A);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1592A), Color(0xFFFF9155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.25),
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name != null && name!.isNotEmpty
                      ? '$name, invite your friends'
                      : 'Invite your friends',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Share FixitZed with someone you care about. They get reliable fixers, you unlock loyalty rewards.',
            style: GoogleFonts.urbanist(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onShare,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(
              'Share invite',
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.inviteLink,
    required this.onShare,
    required this.onCopy,
  });

  final String inviteLink;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFFF1592A);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share your link',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Send this link in chats, groups or social media. '
            'The first booking your friend completes unlocks rewards for both of you.',
            style: GoogleFonts.urbanist(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    inviteLink,
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy link',
                  icon: const Icon(Icons.copy_rounded),
                  color: brand,
                  onPressed: onCopy,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brand,
                    side: BorderSide(color: brand.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    'Share again',
                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerksCard extends StatelessWidget {
  const _PerksCard({required this.perks});

  final List<String> perks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: GoogleFonts.urbanist(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...perks.map(
            (perk) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF1592A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFFF1592A),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      perk,
                      style: GoogleFonts.urbanist(color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
