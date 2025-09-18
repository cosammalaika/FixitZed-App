import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Help Center', style: GoogleFonts.urbanist(color: Colors.black, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: const Center(child: Text('FAQs and support channels here')),
    );
  }
}

