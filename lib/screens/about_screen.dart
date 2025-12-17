import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _supportEmail = 'support@fixitzed.com';
  static const String _supportPhone = '+260 979 871 199';
  static const String _supportHours = 'Mon – Fri, 08:00 – 18:00 CAT';
  static const String _scripture =
      '“Whatever you do, work at it with all your heart.” — Colossians 3:23';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = GoogleFonts.urbanistTextTheme(
      Theme.of(context).textTheme,
    );

    Widget infoCard({
      required IconData icon,
      required String title,
      required String message,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1AF1592A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFF1592A)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F4F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          'About FixitZed',
          style: GoogleFonts.urbanist(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
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
                  Text(
                    'Reliable Home Services, On-Demand',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'FixitZed helps you find trusted fixers for repairs, maintenance, and home upgrades. '
                    'We vet experts, simplify bookings, and keep you updated every step of the way.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF1592A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Color(0xFFF1592A)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _scripture,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            infoCard(
              icon: Icons.apartment_rounded,
              title: 'Who We Are',
              message:
                  'FixitZed is a Zambian team passionate about quality workmanship and customer care. '
                  'We bridge the gap between households and skilled service professionals.',
            ),
            const SizedBox(height: 16),
            infoCard(
              icon: Icons.favorite_rounded,
              title: 'Why Customers Choose Us',
              message:
                  '• Curated network of background-checked fixers.\n'
                  '• Transparent pricing and easy digital payments.\n'
                  '• Live updates on bookings and responsive support.',
            ),
            const SizedBox(height: 16),
            infoCard(
              icon: Icons.support_agent_rounded,
              title: 'Need Help?',
              message:
                  'Email: $_supportEmail\n'
                  'Phone: $_supportPhone\n'
                  'Support Hours: $_supportHours',
            ),
          ],
        ),
      ),
    );
  }
}
