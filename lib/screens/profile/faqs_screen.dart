import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = <Map<String, String>>[
      {
        'q': 'How do I book a service?',
        'a': 'From the home screen, choose a category, pick a service, and select a time that works for you. Confirm your booking and you are set.'
      },
      {
        'q': 'How do I become a fixer?',
        'a': 'Open Profile and tap "Become a Fixer". Fill in your skills and details and submit your application for review.'
      },
      {
        'q': 'How do I change my email or name?',
        'a': 'Go to Profile > Edit Profile, update your details and save.'
      },
      {
        'q': 'What payment methods are supported?',
        'a': 'You can add and manage cards or mobile money in Profile > Payment Methods.'
      },
      {
        'q': 'How can I contact support?',
        'a': 'Use the Help Center options or reach out via the contact details provided in the app settings.'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: Text('FAQs', style: GoogleFonts.urbanist(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      backgroundColor: Colors.white,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: faqs.length,
        itemBuilder: (context, i) {
          final item = faqs[i];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(item['q']!, style: GoogleFonts.urbanist(fontWeight: FontWeight.w700)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(item['a']!, style: GoogleFonts.urbanist(color: Colors.black54, height: 1.25)),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

