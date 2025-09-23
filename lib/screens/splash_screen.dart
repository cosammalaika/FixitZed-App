import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to onboarding after 2 seconds
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android: white icons
        statusBarBrightness: Brightness.dark, // iOS: white icons
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade900, // dark grey background
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background faded pattern
            Opacity(
              opacity: 0.08, // make it subtle
              child: Image.asset(
                "assets/images/pattern.png",
                fit: BoxFit.cover,
              ),
            ),

            // Center logo
            Center(
              child: Image.asset(
                "assets/images/logo.png",
                width: 350, // adjust size
                height: 350,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
