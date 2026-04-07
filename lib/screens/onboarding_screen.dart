import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/core/app_theme.dart';
import 'package:fixitzed_app/services/app_analytics.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      'image': 'assets/images/onboarding1.jpg',
      'title': 'Professional Help, Anytime',
      'body':
          'Find trusted plumbers, electricians, and cleaners near you all in one app.',
    },
    {
      'image': 'assets/images/onboarding2.jpg',
      'title': 'Book with Ease, Get Reliable Service',
      'body':
          'Choose your service, pick a time that works for you, and let our vetted Fixers handle the rest, affordable, fast, and reliable.',
    },
    {
      'image': 'assets/images/onboarding3.jpg',
      'title': 'Support Local Talent',
      'body':
          'By using FixItZed, you’re not just solving problems, you’re empowering skilled Zambians and growing local businesses.',
    },
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache downscaled images to reduce decode time and memory.
    final mq = MediaQuery.of(context);
    final targetWidthPx = (mq.size.width * mq.devicePixelRatio).round();
    for (var item in onboardingData) {
      final provider = ResizeImage(
        AssetImage(item['image']!),
        width: targetWidthPx,
      );
      precacheImage(provider, context);
    }
  }

  Future<void> nextPage() async {
    if (currentPage < onboardingData.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    AppAnalytics.instance.logEvent('onboarding_completed');
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacementNamed('/home'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.fx;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlayStyle(context),
      child: Scaffold(
        backgroundColor: colors.page,
        body: PageView.builder(
          controller: _controller,
          itemCount: onboardingData.length,
          onPageChanged: (index) {
            setState(() => currentPage = index);
          },
          itemBuilder: (context, index) {
            final item = onboardingData[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top image + fade + logo
                Stack(
                  children: [
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.transparent, colors.page],
                          stops: const [0.1, 0.9],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Builder(
                        builder: (context) {
                          final mq = MediaQuery.of(context);
                          final targetWidthPx =
                              (mq.size.width * mq.devicePixelRatio).round();
                          return Image(
                            image: ResizeImage(
                              AssetImage(item['image']!),
                              width: targetWidthPx,
                            ),
                            height: mq.size.height * 0.55,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            gaplessPlayback: true,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 20, // move down from status bar
                      right: 20,
                      child: Image.asset(
                        'assets/images/logo.png', // ✅ your logo here
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),

                // Text + Controls
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),

                        Column(
                          children: [
                            Text(
                              item['title']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item['body']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // Dots + Button
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                onboardingData.length,
                                (dotIndex) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: currentPage == dotIndex ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: currentPage == dotIndex
                                        ? colors.brand
                                        : colors.border,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: nextPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.brand,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  index == onboardingData.length - 1
                                      ? 'Get Started'
                                      : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
