import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import 'study_focus_screen.dart';
import 'health_challenge_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(child: _Header(isLocked: provider.isLocked)),

          // ── Active Challenge Banner ──────────────────────────────────
          if (provider.isLocked)
            SliverToBoxAdapter(
              child: _ActiveChallengeBanner(provider: provider),
            ),

          // ── Action Cards ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ActionCard(
                  icon: '📚',
                  title: 'Focus on Your Study',
                  subtitle: 'Lock distracting apps & study without interruptions.',
                  gradientColors: const [Color(0xFF7C4DFF), Color(0xFF5C6BC0)],
                  glowColor: const Color(0xFF7C4DFF),
                  isLocked: provider.isLocked,
                  onTap: () => Navigator.push(
                    context,
                    _slideRoute(const StudyFocusScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  icon: '🔒',
                  title: 'Mobile Lock',
                  subtitle: 'Full detox — lock your phone completely.',
                  gradientColors: const [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
                  glowColor: const Color(0xFFFF6B9D),
                  isLocked: provider.isLocked,
                  onTap: () => _showMobileLockDialog(context, provider),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  icon: '🏃',
                  title: 'Health Improvement',
                  subtitle: 'Physical challenges with real step tracking.',
                  gradientColors: const [Color(0xFF00E5FF), Color(0xFF00BFA5)],
                  glowColor: const Color(0xFF00E5FF),
                  isLocked: provider.isLocked,
                  onTap: () => Navigator.push(
                    context,
                    _slideRoute(const HealthChallengeScreen()),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Stats row ─────────────────────────────────────────
                _StatsRow(provider: provider),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  PageRouteBuilder _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _showMobileLockDialog(BuildContext context, AppStateProvider provider) {
    if (provider.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A challenge is already active.')),
      );
      return;
    }

    Duration selected = const Duration(hours: 1);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mobile Lock Duration',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final h in [1, 2, 3, 6, 12, 24])
                    _DurationChip(
                      label: '${h}h',
                      selected: selected == Duration(hours: h),
                      color: const Color(0xFFFF6B9D),
                      onTap: () =>
                          setState(() => selected = Duration(hours: h)),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B9D),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    provider.startMobileLock(duration: selected);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    '🔒 Start Mobile Lock',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isLocked;
  const _Header({required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 20, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
        ),
      ),
      child: Row(
        children: [
          // Text section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocked ? '🔒 Challenge Active' : '👋 Welcome Back!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9999BB),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                  ).createShader(bounds),
                  child: const Text(
                    'Dopamine\nDetox',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Build better habits, one day at a time.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6666AA),
                  ),
                ),
              ],
            ),
          ),

          // Anime illustration (Lottie)
          SizedBox(
            width: 130,
            height: 130,
            child: Lottie.network(
              'https://assets4.lottiefiles.com/packages/lf20_jcikwtux.json',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                '🧑‍💻',
                style: TextStyle(fontSize: 80),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Active Challenge Banner ──────────────────────────────────────────────────
class _ActiveChallengeBanner extends StatelessWidget {
  final AppStateProvider provider;
  const _ActiveChallengeBanner({required this.provider});

  String get _title {
    switch (provider.activeChallenge) {
      case ChallengeType.studyFocus:
        return '📚 Study Focus Active';
      case ChallengeType.mobileLock:
        return '🔒 Mobile Lock Active';
      case ChallengeType.healthChallenge:
        return '🏃 Health Challenge Active';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = provider.remainingTime;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remaining: $h:$m:$s',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Progress ring
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: provider.progressFraction,
              strokeWidth: 4,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Card ──────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color glowColor;
  final bool isLocked;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.glowColor,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: gradientColors.first.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container with gradient
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8888AA),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Arrow
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: gradientColors.first.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: gradientColors.first,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final AppStateProvider provider;
  const _StatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: '🔥',
          label: 'Streak',
          value: '0 days',
          color: const Color(0xFFFF6B9D),
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: '👟',
          label: 'Today Steps',
          value: '${provider.currentSteps}',
          color: const Color(0xFF00E5FF),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6666AA),
                )),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
