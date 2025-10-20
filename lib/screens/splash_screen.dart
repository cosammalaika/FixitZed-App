import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;
    final route = hasSeenOnboarding ? '/auth' : '/onboarding';
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
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
