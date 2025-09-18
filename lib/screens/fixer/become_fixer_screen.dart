import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BecomeFixerScreen extends StatelessWidget {
  const BecomeFixerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFF1592A);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Become a Fixer', style: GoogleFonts.urbanist(color: Colors.black, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply to become a verified Fixer', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Tell us about your skills, experience and location. We will review your application and get back to you.',
                style: GoogleFonts.urbanist(color: Colors.black54)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: () {
                  // TODO: implement application form
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application form coming soon')));
                },
                child: const Text('Start Application'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

