import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:lottie/lottie.dart';

import '../main.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      animationUrl:
          'https://assets3.lottiefiles.com/packages/lf20_wnqlfojb.json',
      fallbackEmoji: '📚',
      title: 'Focus on Study',
      subtitle: 'Padhaai per focus karein,\napna focus banaye rakhein.',
      gradientColors: [const Color(0xFF7C4DFF), const Color(0xFF00E5FF)],
    ),
    _OnboardingData(
      animationUrl:
          'https://assets6.lottiefiles.com/packages/lf20_touohxv0.json',
      fallbackEmoji: '🎯',
      title: 'Stay Determined',
      subtitle: 'Apna focus banaye rakhein,\nbhatke nahi.',
      gradientColors: [const Color(0xFF00E5FF), const Color(0xFF00BFA5)],
    ),
    _OnboardingData(
      animationUrl:
          'https://assets2.lottiefiles.com/packages/lf20_qp1q7mct.json',
      fallbackEmoji: '⛓️',
      title: 'Break Bad Habits',
      subtitle: 'Daru aur buri aadatein chhodein,\napni jindagi bachayein.',
      gradientColors: [const Color(0xFFFF6B9D), const Color(0xFFFF8A65)],
    ),
    _OnboardingData(
      animationUrl:
          'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json',
      fallbackEmoji: '🏃',
      title: 'Improve Your Health',
      subtitle: 'Apne health ka khyal rakhiye,\naaj hi shuru karein.',
      gradientColors: [const Color(0xFF69F0AE), const Color(0xFF7C4DFF)],
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboarded', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) =>
                _OnboardingPage(data: _pages[index]),
          ),

          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 24,
            child: GestureDetector(
              onTap: _completeOnboarding,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2)),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 40,
            child: Column(
              children: [
                // Page indicator
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: _pages[_currentPage]
                        .gradientColors
                        .first,
                    dotColor: Colors.white.withOpacity(0.25),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                    spacing: 6,
                  ),
                ),
                const SizedBox(height: 32),

                // CTA button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentPage == _pages.length - 1
                        ? _GradientButton(
                            key: const ValueKey('start'),
                            label: "Let's Start!",
                            colors: _pages[_currentPage].gradientColors,
                            onTap: _completeOnboarding,
                          )
                        : _GradientButton(
                            key: const ValueKey('next'),
                            label: 'Next →',
                            colors: _pages[_currentPage].gradientColors,
                            onTap: () {
                              _pageController.nextPage(
                                duration:
                                    const Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Individual Onboarding Page ───────────────────────────────────────────────
class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            data.gradientColors.first.withOpacity(0.15),
            AppTheme.bg,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),

            // Lottie animation with emoji fallback
            SizedBox(
              height: 280,
              child: _LottieOrEmoji(
                url: data.animationUrl,
                emoji: data.fallbackEmoji,
              ),
            ),

            const Spacer(flex: 1),

            // Decorative glass card with text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: data.gradientColors.first.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradientColors.first.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: data.gradientColors,
                      ).createShader(bounds),
                      child: Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.subtitle,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Color(0xFFCCCCDD),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

// ─── Lottie with fallback ─────────────────────────────────────────────────────
class _LottieOrEmoji extends StatelessWidget {
  final String url;
  final String emoji;

  const _LottieOrEmoji({required this.url, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Lottie.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(
        child: Text(emoji, style: const TextStyle(fontSize: 120)),
      ),
    );
  }
}

// ─── Gradient Button ──────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _GradientButton({
    super.key,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────
class _OnboardingData {
  final String animationUrl;
  final String fallbackEmoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;

  const _OnboardingData({
    required this.animationUrl,
    required this.fallbackEmoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });
}
