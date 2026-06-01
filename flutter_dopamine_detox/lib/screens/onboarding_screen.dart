import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:lottie/lottie.dart';

import '../main.dart';
import 'home_screen.dart';

/// Onboarding shows on EVERY app launch.
/// User can skip or swipe through all 6 pages.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _current = 0;

  // ── 6 motivational quote pages ────────────────────────────────────────────
  final List<_QuotePage> _pages = const [
    _QuotePage(
      emoji: '🎯',
      lottieUrl:
          'https://assets3.lottiefiles.com/packages/lf20_wnqlfojb.json',
      author: 'Aristotle',
      quote:
          '"We are what we repeatedly do. Excellence, then, is not an act, but a habit."',
      sub: 'Every lock you set is a vote for the person you want to become.',
      gradientColors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
    ),
    _QuotePage(
      emoji: '🔥',
      lottieUrl:
          'https://assets6.lottiefiles.com/packages/lf20_touohxv0.json',
      author: 'Robin Sharma',
      quote:
          '"Change is hard at first, messy in the middle, and gorgeous at the end."',
      sub:
          'Your dopamine detox starts today. The first 24 hours are the hardest.',
      gradientColors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
    ),
    _QuotePage(
      emoji: '📚',
      lottieUrl:
          'https://assets2.lottiefiles.com/packages/lf20_qp1q7mct.json',
      author: 'Jim Rohn',
      quote:
          '"Either you run the day, or the day runs you."',
      sub:
          'Lock your distractions. Own your time. The future you will thank you.',
      gradientColors: [Color(0xFF00E5FF), Color(0xFF00BFA5)],
    ),
    _QuotePage(
      emoji: '💪',
      lottieUrl:
          'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json',
      author: 'David Goggins',
      quote:
          '"You are in danger of living a life so comfortable and soft that you will die without ever realising your true potential."',
      sub: 'Set a challenge. Endure it. Become stronger.',
      gradientColors: [Color(0xFF69F0AE), Color(0xFF7C4DFF)],
    ),
    _QuotePage(
      emoji: '🧠',
      lottieUrl:
          'https://assets4.lottiefiles.com/packages/lf20_jcikwtux.json',
      author: 'James Clear',
      quote:
          '"Every action you take is a vote for the type of person you wish to become."',
      sub:
          'Small daily disciplines compound into extraordinary results.',
      gradientColors: [Color(0xFFFFB74D), Color(0xFFFF6B9D)],
    ),
    _QuotePage(
      emoji: '🌅',
      lottieUrl:
          'https://assets3.lottiefiles.com/packages/lf20_wnqlfojb.json',
      author: 'Winston Churchill',
      quote:
          '"Success is not final, failure is not fatal: it is the courage to continue that counts."',
      sub: 'Begin your detox right now. Tap "Let\'s Go" to take control.',
      gradientColors: [Color(0xFF7C4DFF), Color(0xFFFF6B9D)],
    ),
  ];

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _current == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // ── Pages ──────────────────────────────────────────────────────
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => _PageView(page: _pages[i]),
          ),

          // ── Skip button ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: GestureDetector(
              onTap: _goToHome,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2)),
                ),
                child: const Text('Skip',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          ),

          // ── Bottom controls ────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 36,
            child: Column(
              children: [
                // Dot indicator
                SmoothPageIndicator(
                  controller: _controller,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor:
                        _pages[_current].gradientColors.first,
                    dotColor: Colors.white.withOpacity(0.22),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                    spacing: 6,
                  ),
                ),
                const SizedBox(height: 28),

                // CTA button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: GestureDetector(
                    onTap: isLast
                        ? _goToHome
                        : () => _controller.nextPage(
                              duration:
                                  const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                            ),
                    child: Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _pages[_current].gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _pages[_current]
                                .gradientColors
                                .first
                                .withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isLast ? "🚀 Let's Go!" : 'Next →',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

// ─── Individual quote page ────────────────────────────────────────────────────
class _PageView extends StatelessWidget {
  final _QuotePage page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            page.gradientColors.first.withOpacity(0.18),
            AppTheme.bg,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Animation / emoji
            SizedBox(
              height: 220,
              child: Lottie.network(
                page.lottieUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  page.emoji,
                  style: const TextStyle(fontSize: 100),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const Spacer(flex: 1),

            // Glass quote card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color:
                        page.gradientColors.first.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: page.gradientColors.first.withOpacity(0.08),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Author badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: page.gradientColors),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '— ${page.author}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quote
                    Text(
                      page.quote,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sub-text
                    Text(
                      page.sub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        height: 1.5,
                      ),
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

// ─── Data model ───────────────────────────────────────────────────────────────
class _QuotePage {
  final String emoji;
  final String lottieUrl;
  final String author;
  final String quote;
  final String sub;
  final List<Color> gradientColors;

  const _QuotePage({
    required this.emoji,
    required this.lottieUrl,
    required this.author,
    required this.quote,
    required this.sub,
    required this.gradientColors,
  });
}
