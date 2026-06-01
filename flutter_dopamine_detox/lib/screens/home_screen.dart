import 'dart:async';
import 'package:android_intent_plus/android_intent_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';
import '../services/foreground_monitor_service.dart';
import 'study_focus_screen.dart';
import 'health_challenge_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// HomeScreen — App-Specific Blocking Orchestrator
///
/// Responsibilities:
///   1. Listens to ForegroundMonitorService stream (which app is in foreground)
///   2. Shows overlay ONLY when foreground app is in the blocked list AND
///      the study focus timer is still running AND we're not in a bypass window.
///   3. Forwards live timer data to the overlay isolate every second.
///   4. Handles messages FROM overlay (emergency bypass, billing).
///   5. Hides overlay when foreground switches to a non-blocked app.
/// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ── Subscriptions & timers ─────────────────────────────────────────────────
  StreamSubscription<String>? _foregroundSub;    // Kotlin service → Dart
  StreamSubscription? _overlayMsgSub;             // Overlay isolate → Dart
  Timer? _timerBroadcast;                         // Pushes timer state to overlay every 1 s
  Timer? _emergencyBypassTimer;                   // 2-min bypass countdown

  // ── Overlay state ──────────────────────────────────────────────────────────
  bool _overlayShowing = false;
  bool _emergencyBypassActive = false;
  int _emergencyBypassSecondsLeft = 0;

  // ── Current foreground app ─────────────────────────────────────────────────
  String _currentForegroundPkg = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startForegroundListener();
    _startOverlayMessageListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-attach to the foreground stream after returning from background
    if (state == AppLifecycleState.resumed) {
      _startForegroundListener();
    }
  }

  // ── Foreground app stream ──────────────────────────────────────────────────

  void _startForegroundListener() {
    _foregroundSub?.cancel();
    _foregroundSub =
        ForegroundMonitorService.foregroundAppStream.listen((pkg) {
      _currentForegroundPkg = pkg;
      _evaluateOverlay();
    });
  }

  /// Core logic: show or hide overlay depending on foreground app.
  void _evaluateOverlay() {
    final provider = context.read<AppStateProvider>();

    final shouldBlock = provider.activeChallenge == ChallengeType.studyFocus &&
        provider.isPackageLocked(_currentForegroundPkg) &&
        !_emergencyBypassActive;

    if (shouldBlock && !_overlayShowing) {
      _showOverlay(provider);
    } else if (!shouldBlock && _overlayShowing) {
      _hideOverlay();
    }
  }

  Future<void> _showOverlay(AppStateProvider provider) async {
    if (_overlayShowing) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) return;

    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: 'Study Focus',
        overlayContent: 'Blocked app detected.',
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.center,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: WindowSize.fullCover,
        width: WindowSize.fullCover,
      );
      _overlayShowing = true;
      _startTimerBroadcast(provider);
    } catch (e) {
      debugPrint('[HomeScreen] Overlay show failed: $e');
    }
  }

  Future<void> _hideOverlay() async {
    if (!_overlayShowing) return;
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
    _overlayShowing = false;
    _timerBroadcast?.cancel();
  }

  // ── Timer broadcast to overlay ─────────────────────────────────────────────
  // Every second, push {'type':'timer_update'} so the overlay has a live countdown.

  void _startTimerBroadcast(AppStateProvider provider) {
    _timerBroadcast?.cancel();
    _timerBroadcast = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_overlayShowing) return;
      final r = provider.remainingTime;
      if (r == Duration.zero) {
        // Session done — close overlay & stop service
        _onSessionComplete();
        return;
      }
      final h = r.inHours.toString().padLeft(2, '0');
      final m = (r.inMinutes % 60).toString().padLeft(2, '0');
      final s = (r.inSeconds % 60).toString().padLeft(2, '0');

      // Get the display name of the blocked app (simple package → name mapping)
      final appName = _friendlyName(_currentForegroundPkg);

      FlutterOverlayWindow.shareData({
        'type': 'timer_update',
        'time': '$h:$m:$s',
        'progress': provider.progressFraction,
        'emergencyUsesLeft': provider.emergencyUsesLeft,
        'appName': appName,
      });
    });
  }

  // ── Overlay messages → HomeScreen ─────────────────────────────────────────

  void _startOverlayMessageListener() {
    _overlayMsgSub?.cancel();
    _overlayMsgSub =
        FlutterOverlayWindow.overlayListener.listen((raw) async {
      if (raw is! Map) return;
      final type = (raw['type'] as String?) ?? '';

      switch (type) {
        case 'emergency_unlock':
          await _handleEmergencyUnlock();
          break;

        case 'pay_penalty':
          await _handleBillingRequest();
          break;
      }
    });
  }

  // ── Emergency bypass — 2-min window ───────────────────────────────────────

  Future<void> _handleEmergencyUnlock() async {
    final provider = context.read<AppStateProvider>();
    if (provider.emergencyUsesLeft <= 0) return;

    // Decrement counter in provider
    provider.consumeEmergencyUse();

    // Overlay already closed itself — mark bypass active
    _overlayShowing = false;
    _timerBroadcast?.cancel();

    setState(() {
      _emergencyBypassActive = true;
      _emergencyBypassSecondsLeft = 120;
    });

    // Countdown in HomeScreen for UI display
    _emergencyBypassTimer?.cancel();
    _emergencyBypassTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _emergencyBypassSecondsLeft--;
        if (_emergencyBypassSecondsLeft <= 0) {
          t.cancel();
          _emergencyBypassActive = false;
          // Re-evaluate: if still on blocked app → show overlay again
          _evaluateOverlay();
        }
      });
    });
  }

  // ── Billing ────────────────────────────────────────────────────────────────

  Future<void> _handleBillingRequest() async {
    final billing = context.read<BillingService>();
    final provider = context.read<AppStateProvider>();

    billing.onPurchaseSuccess = () async {
      provider.unlockAll();
      await ForegroundMonitorService.stop();
      await _hideOverlay();
      // Tell overlay to close (in case it's still showing)
      FlutterOverlayWindow.shareData({'type': 'dismiss'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Penalty paid — focus session ended.')),
        );
      }
    };

    try {
      await billing.buyPenalty();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Payment error: $e')),
        );
      }
    }
  }

  // ── Session complete ───────────────────────────────────────────────────────

  Future<void> _onSessionComplete() async {
    _timerBroadcast?.cancel();
    await ForegroundMonitorService.stop();
    FlutterOverlayWindow.shareData({'type': 'dismiss'});
    _overlayShowing = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('🎉 Study session complete! Great work!')),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _friendlyName(String pkg) {
    // Attempt to extract a readable name from the package string
    if (pkg.isEmpty) return 'Blocked App';
    final parts = pkg.split('.');
    if (parts.length >= 2) {
      final name = parts[parts.length - 1];
      return name[0].toUpperCase() + name.substring(1);
    }
    return pkg;
  }

  Future<void> _openUsageAccessSettings() async {
    const intent =
        AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS');
    try {
      await intent.launch();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundSub?.cancel();
    _overlayMsgSub?.cancel();
    _timerBroadcast?.cancel();
    _emergencyBypassTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isStudyFocus =
        provider.activeChallenge == ChallengeType.studyFocus;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
              child: _Header(isLocked: provider.isLocked)),

          // ── Active session banner ────────────────────────────────────────
          if (provider.isLocked)
            SliverToBoxAdapter(
              child: _ActiveChallengeBanner(provider: provider),
            ),

          // ── Emergency bypass countdown banner ────────────────────────────
          if (_emergencyBypassActive)
            SliverToBoxAdapter(
              child: _EmergencyBypassBanner(
                  secondsLeft: _emergencyBypassSecondsLeft),
            ),

          // ── Usage Access warning (if study focus active but no permission) ──
          if (isStudyFocus && !_overlayShowing && !_emergencyBypassActive)
            SliverToBoxAdapter(
              child: _UsageAccessHint(
                  onOpenSettings: _openUsageAccessSettings),
            ),

          // ── Action cards ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ActionCard(
                  icon: '📚',
                  title: 'Focus on Your Study',
                  subtitle:
                      'Block specific apps while studying. Others work normally.',
                  gradientColors: const [Color(0xFF7C4DFF), Color(0xFF5C6BC0)],
                  glowColor: const Color(0xFF7C4DFF),
                  isLocked: provider.isLocked,
                  onTap: () => Navigator.push(
                      context, _slideRoute(const StudyFocusScreen())),
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
                      context, _slideRoute(const HealthChallengeScreen())),
                ),
                const SizedBox(height: 16),
                _StatsRow(provider: provider),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  PageRouteBuilder _slideRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      );

  void _showMobileLockDialog(
      BuildContext context, AppStateProvider provider) {
    if (provider.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ A challenge is already active.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Duration selected = const Duration(hours: 1);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mobile Lock Duration',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                '⚠️ Full phone lock — cannot use emergency bypass.',
                style: TextStyle(
                    color: Color(0xFFFF6B9D), fontSize: 12),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [for (final h in [1, 2, 3, 6, 12, 24])
                  _DurationChip(
                    label: '${h}h',
                    selected: selected == Duration(hours: h),
                    color: const Color(0xFFFF6B9D),
                    onTap: () => ss(() => selected = Duration(hours: h)),
                  )],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B9D),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final billing = context.read<BillingService>();
                    billing.onPurchaseSuccess = () => provider.unlockAll();
                    provider.startMobileLock(duration: selected);
                    Navigator.pop(ctx);
                  },
                  child: const Text('🔒 Start Mobile Lock',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
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

// ─── Emergency Bypass Banner ──────────────────────────────────────────────────
class _EmergencyBypassBanner extends StatelessWidget {
  final int secondsLeft;
  const _EmergencyBypassBanner({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74D).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFFB74D).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Emergency Bypass Active',
                    style: TextStyle(
                        color: Color(0xFFFFB74D),
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('Lock resumes in $m:$s',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Usage Access Hint ────────────────────────────────────────────────────────
class _UsageAccessHint extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _UsageAccessHint({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('📊', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Grant "Usage Access" so blocked apps are detected.',
              style:
                  TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: onOpenSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Settings',
                  style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLocked ? '🔒 Challenge Active' : '👋 Welcome Back!',
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9999BB),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                  ).createShader(b),
                  child: const Text('Dopamine\nDetox',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1)),
                ),
                const SizedBox(height: 10),
                const Text('Build better habits, one day at a time.',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF6666AA))),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            height: 130,
            child: Lottie.network(
              'https://assets4.lottiefiles.com/packages/lf20_jcikwtux.json',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('🧑‍💻',
                  style: TextStyle(fontSize: 80)),
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

  String get _title => switch (provider.activeChallenge) {
        ChallengeType.studyFocus => '📚 Study Focus Active',
        ChallengeType.mobileLock => '🔒 Mobile Lock Active',
        ChallengeType.healthChallenge => '🏃 Health Challenge Active',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final r = provider.remainingTime;
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)]),
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
                Text(_title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text('Remaining: $h:$m:$s',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
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
              color: gradientColors.first.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: glowColor.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 2),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF8888AA),
                          fontSize: 12,
                          height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: gradientColors.first.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  color: gradientColors.first, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats ────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final AppStateProvider provider;
  const _StatsRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(icon: '🔥', label: 'Streak',
            value: '0 days', color: const Color(0xFFFF6B9D)),
        const SizedBox(width: 12),
        _StatTile(icon: '👟', label: 'Today Steps',
            value: '${provider.currentSteps}', color: const Color(0xFF00E5FF)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _StatTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6666AA))),
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
  const _DurationChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
