import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fixitzed_app/services/report_service.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  bool _submittingReport = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          'Help Center',
          style: GoogleFonts.urbanist(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _heroCard(),
          const SizedBox(height: 20),
          _sectionTitle('Quick assistance'),
          _supportTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat on WhatsApp',
            subtitle: '+260 979 871 199',
            onTap: () => _launchUrl('https://wa.me/260979871199'),
          ),
          const SizedBox(height: 12),
          _supportTile(
            icon: Icons.call_outlined,
            label: 'Call support',
            subtitle: '+260 979 871 199',
            onTap: () => _launchUrl('tel:+260979871199'),
          ),
          const SizedBox(height: 12),
          _supportTile(
            icon: Icons.email_outlined,
            label: 'Email support',
            subtitle: 'support@fixitzed.com',
            onTap: () => _launchUrl('mailto:support@fixitzed.com'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Self-service'),
          ListTile(
            onTap: () => Navigator.pushNamed(context, '/profile/faqs'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            tileColor: theme.cardColor,
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Read frequently asked questions'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 12),
          ListTile(
            onTap: () => Navigator.pushNamed(context, '/profile/settings'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            tileColor: theme.cardColor,
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Review app preferences'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Need to report something?'),
          ElevatedButton.icon(
            onPressed: _submittingReport ? null : _openReportSheet,
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(_submittingReport ? 'Sending…' : 'Report an issue'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1592A), Color(0xFFFF9155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1592A).withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We are here to help',
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track answers, reach support, or file a report without leaving the app.',
            style: GoogleFonts.urbanist(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }

  Widget _supportTile({
    required IconData icon,
    required String label,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: Colors.white,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x1AF1592A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: const Color(0xFFF1592A)),
      ),
      title: Text(
        label,
        style: GoogleFonts.urbanist(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new_rounded),
    );
  }

  Future<void> _openReportSheet() async {
    String type = 'user';
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Report an issue',
                style: GoogleFonts.urbanist(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: 'Who is involved?',
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Customer')),
                  DropdownMenuItem(value: 'fixer', child: Text('Fixer')),
                ],
                onChanged: (value) => type = value ?? 'user',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: subjectCtrl,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: messageCtrl,
                decoration: const InputDecoration(labelText: 'Details'),
                minLines: 3,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (messageCtrl.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Send report'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result != true) return;
    setState(() => _submittingReport = true);
    final ok = await ReportService().submit(
      type: type,
      subject: subjectCtrl.text.trim().isEmpty
          ? 'FixitZed report'
          : subjectCtrl.text.trim(),
      message: messageCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submittingReport = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Report submitted. We will be in touch.'
              : 'Unable to send report',
        ),
        backgroundColor: ok ? const Color(0xFF2E7D32) : Colors.redAccent,
      ),
    );
  }

  Future<void> _launchUrl(String uri) async {
    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open link')));
    }
  }
}
