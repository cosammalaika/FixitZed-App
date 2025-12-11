import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';
import 'package:fixitzed_app/services/preload_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixitzed_app/state/service_providers.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
    if (route == '/home') {
      final container = ProviderScope.containerOf(context, listen: false);
      unawaited(container.read(preloadServiceProvider).preloadAll());
    }
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

            // Bottom loader
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42),
                child: SizedBox(
                  height: 22,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final animation = CurvedAnimation(
                        parent: _pulseController,
                        curve: Interval(
                          0.15 * index,
                          0.6 + 0.15 * index,
                          curve: Curves.easeInOut,
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.65, end: 1.05)
                                .animate(animation),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.shade400,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepOrange.shade400
                                        .withOpacity(0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
