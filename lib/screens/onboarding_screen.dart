import 'package:flutter/material.dart';

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
      "image": "assets/images/onboarding1.jpg",
      "title": "Professional Help, Anytime",
      "body":
          "Find trusted plumbers, electricians, and cleaners near you all in one app.",
    },
    {
      "image": "assets/images/onboarding2.jpg",
      "title": "Book with Ease, Get Reliable Service",
      "body":
          "Choose your service, pick a time that works for you, and let our vetted Fixers handle the rest, affordable, fast, and reliable.",
    },
    {
      "image": "assets/images/onboarding3.jpg",
      "title": "Support Local Talent",
      "body":
          "By using FixItZed, you’re not just solving problems, you’re empowering skilled Zambians and growing local businesses.",
    },
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache downscaled images to reduce decode time and memory.
    final mq = MediaQuery.of(context);
    final targetWidthPx = (mq.size.width * mq.devicePixelRatio).round();
    for (var item in onboardingData) {
      final provider = ResizeImage(AssetImage(item["image"]!), width: targetWidthPx);
      precacheImage(provider, context);
    }
  }

  void nextPage() {
    if (currentPage < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacementNamed("/auth");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                      return const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.transparent, Colors.white],
                        stops: [0.1, 0.9], // small fade near bottom
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                  child: Builder(builder: (context) {
                    final mq = MediaQuery.of(context);
                    final targetWidthPx = (mq.size.width * mq.devicePixelRatio).round();
                    return Image(
                      image: ResizeImage(AssetImage(item["image"]!), width: targetWidthPx),
                      height: mq.size.height * 0.55,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      gaplessPlayback: true,
                    );
                  }),
                ),
                  Positioned(
                    top: 20, // move down from status bar
                    right: 20,
                    child: Image.asset(
                      "assets/images/logo.png", // ✅ your logo here
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
                            item["title"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            item["body"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
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
                                      ? const Color(0xFFF1592A)
                                      : Colors.grey.shade400,
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
                                backgroundColor: const Color(0xFFF1592A),
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
                                    ? "Get Started"
                                    : "Next",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
    );
  }
}
