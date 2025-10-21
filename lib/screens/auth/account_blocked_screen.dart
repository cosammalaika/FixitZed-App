import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountBlockedScreen extends StatelessWidget {
  const AccountBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF1592A);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_outlined,
                  color: accent,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Account inactive',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F1F1F),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account is currently blocked from accessing FixitZed. Please contact support and we’ll help you restore access.',
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF4A4A4A),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help?',
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 18, color: Color(0xFF6B6B6B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'support@fixitzed.com',
                              style: GoogleFonts.urbanist(color: const Color(0xFF3E3E3E)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF6B6B6B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '+260 976 000 000',
                              style: GoogleFonts.urbanist(color: const Color(0xFF3E3E3E)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
