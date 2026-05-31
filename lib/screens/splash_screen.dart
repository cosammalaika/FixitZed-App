import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/session_manager.dart';
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
    Future<void> warm(Future<dynamic> future) {
      return future.then<void>((_) {}).catchError((_) {});
    }

    final preload = Future.wait<void>([
      home.preloadServices(forceRefresh: true),
      warm(home.fetchCategories()),
      warm(home.fetchSubcategories()),
      warm(NotificationService().fetch(page: 1)),
    ]).timeout(const Duration(seconds: 12), onTimeout: () => <void>[]);

    try {
      await Future.wait<void>([
        Future<void>.delayed(const Duration(seconds: 2)),
        preload,
      ]);
    } catch (_) {}

    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('onboarding_seen') ?? false;
    final sessionState = await SessionManager.instance.probeStoredSession();

    String route;
    if (!hasSeenOnboarding) {
      route = '/onboarding';
    } else if (sessionState == SessionValidationResult.missingToken) {
      route = '/home';
    } else if (sessionState == SessionValidationResult.invalidToken) {
      await SessionManager.instance.ensureForcedLogout(
        reason: 'sessionExpired',
      );
      route = '/auth';
    } else if (sessionState == SessionValidationResult.accountDisabled) {
      await SessionManager.instance.ensureForcedLogout(
        reason: 'accountDisabled',
      );
      route = '/account_blocked';
    } else {
      route = '/home';
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
            // Subtle background texture without relying on an extra asset file.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.black.withOpacity(0.02),
                  ],
                ),
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
                            scale: Tween<double>(
                              begin: 0.65,
                              end: 1.05,
                            ).animate(animation),
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
