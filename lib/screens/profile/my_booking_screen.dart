import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyBookingScreen extends StatelessWidget {
  const MyBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        title: Text('My Booking', style: GoogleFonts.urbanist(color: Theme.of(context).colorScheme.onBackground, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: const Center(child: Text('Your bookings list here')),
    );
  }
}
