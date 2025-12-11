import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';

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
    final home = HomeService();
    final preload = Future.wait([
      home.preloadServices(forceRefresh: true),
      home.fetchCategories().catchError((_) => <dynamic>[]),
      home.fetchSubcategories().catchError((_) => <dynamic>[]),
      NotificationService().fetch(page: 1).catchError((_) => <Map>[]),
    ]).timeout(const Duration(seconds: 12), onTimeout: () => []);

    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      preload,
    ]).catchError((_) {});

    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;
    final token = await TokenStorage.instance.getToken();

    String route;
    if (!hasSeenOnboarding) {
      route = '/onboarding';
    } else if (token == null || token.isEmpty) {
      route = '/auth';
    } else {
      // Lightweight validation: ensure token still works.
      final me = await home.fetchMe();
      route = me != null ? '/home' : '/auth';
    }

    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacementNamed(route));
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
                'assets/images/pattern.png',
                fit: BoxFit.cover,
              ),
            ),

            // Center logo
            Center(
              child: Image.asset(
                'assets/images/logo.png',
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
