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

/// HomeScreen — overlay orchestrator using SharedPreferences polling.
///
/// Bug #2 root-cause fix:
///   Old: EventChannel stream → eventSink becomes null when activity is
///        backgrounded → all detection events silently dropped.
///   New: Timer.periodic(500ms) calls MethodChannel.getForeground() which
///        reads SharedPreferences. Works regardless of activity lifecycle.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {

  // ── Polling timer (replaces broken EventChannel) ───────────────────────────
  Timer? _pollTimer;
  String _lastPkg = '';

  // ── Overlay state ──────────────────────────────────────────────────────────
  bool _overlayShowing = false;

  // ── Emergency bypass ───────────────────────────────────────────────────────
  bool _emergencyActive = false;
  int _emergencySecsLeft = 0;
  Timer? _emergencyTimer;

  // ── Overlay → main app messages ────────────────────────────────────────────
  StreamSubscription? _overlaySub;

  // ── Timer broadcast to overlay ─────────────────────────────────────────────
  Timer? _broadcastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _startOverlayListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-start polling when user returns to app
      _startPolling();
    }
  }

  // ── Polling — the reliable replacement for EventChannel ───────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final provider = context.read<AppStateProvider>();
      if (provider.activeChallenge != ChallengeType.studyFocus) return;

      try {
        final pkg = await ForegroundMonitorService.getForeground();
        if (pkg == _lastPkg) return;
        _lastPkg = pkg;
        _onForegroundChanged(pkg, provider);
      } catch (_) {
        // MethodChannel can throw if called while activity is transitioning
      }
    });
  }

  void _onForegroundChanged(String pkg, AppStateProvider provider) {
    final shouldBlock =
        provider.isPackageLocked(pkg) && !_emergencyActive;

    if (shouldBlock && !_overlayShowing) {
      _showOverlay(provider);
    } else if (!shouldBlock && _overlayShowing) {
      _closeOverlay();
    }
  }

  // ── Overlay show / close ───────────────────────────────────────────────────

  Future<void> _showOverlay(AppStateProvider provider) async {
    if (_overlayShowing) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) return;

    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: 'Study Focus',
        overlayContent: 'Blocked app detected',
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.center,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: WindowSize.fullCover,
        width: WindowSize.fullCover,
      );
      _overlayShowing = true;
      _startBroadcastTimer(provider);
    } catch (e) {
      debugPrint('[HomeScreen] showOverlay failed: $e');
    }
  }

  Future<void> _closeOverlay() async {
    if (!_overlayShowing) return;
    _broadcastTimer?.cancel();
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
    _overlayShowing = false;
  }

  // ── Broadcast timer → overlay (every 1 second) ────────────────────────────
  // Sends live timer data to the overlay isolate via shareData.

  void _startBroadcastTimer(AppStateProvider provider) {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_overlayShowing) return;
      final r = provider.remainingTime;
      if (r <= Duration.zero) {
        await _onSessionDone();
        return;
      }
      final h = r.inHours.toString().padLeft(2, '0');
      final m = (r.inMinutes % 60).toString().padLeft(2, '0');
      final s = (r.inSeconds % 60).toString().padLeft(2, '0');
      try {
        await FlutterOverlayWindow.shareData({
          'type': 'timer_update',
          'time': '$h:$m:$s',
          'progress': provider.progressFraction,
          'emergencyLeft': provider.emergencyUsesLeft,
          'appName': _friendlyName(_lastPkg),
        });
      } catch (_) {}
    });
  }

  // ── Overlay messages → HomeScreen ─────────────────────────────────────────

  void _startOverlayListener() {
    _overlaySub?.cancel();
    _overlaySub = FlutterOverlayWindow.overlayListener.listen((raw) async {
      if (raw is! Map) return;
      final type = raw['type'] as String? ?? '';

      switch (type) {
        case 'emergency_unlock':
          await _doEmergencyUnlock();
          break;
        case 'pay_penalty':
          await _doBilling();
          break;
      }
    });
  }

  // ── Emergency 2-min bypass ─────────────────────────────────────────────────

  Future<void> _doEmergencyUnlock() async {
    final provider = context.read<AppStateProvider>();
    if (provider.emergencyUsesLeft <= 0) return;

    provider.consumeEmergencyUse();
    setState(() { _emergencyActive = true; _emergencySecsLeft = 120; });
    await ForegroundMonitorService.setEmergencyBypass(active: true);
    await _closeOverlay();

    _emergencyTimer?.cancel();
    _emergencyTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _emergencySecsLeft--;
        if (_emergencySecsLeft <= 0) {
          t.cancel();
          _emergencyActive = false;
          ForegroundMonitorService.setEmergencyBypass(active: false);
          // Re-check immediately after bypass ends
          _lastPkg = '';
        }
      });
    });
  }

  // ── Billing ────────────────────────────────────────────────────────────────

  Future<void> _doBilling() async {
    final billing = context.read<BillingService>();
    final provider = context.read<AppStateProvider>();

    billing.onPurchaseSuccess = () async {
      provider.unlockAll();
      await ForegroundMonitorService.stop();
      await _closeOverlay();
      try {
        await FlutterOverlayWindow.shareData({'type': 'dismiss'});
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Penalty paid — session ended.')),
        );
      }
    };
    try {
      await billing.buyPenalty();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Payment error: $e')));
      }
    }
  }

  Future<void> _onSessionDone() async {
    _broadcastTimer?.cancel();
    await ForegroundMonitorService.stop();
    try {
      await FlutterOverlayWindow.shareData({'type': 'dismiss'});
    } catch (_) {}
    _overlayShowing = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Study session complete!')),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _friendlyName(String pkg) {
    if (pkg.isEmpty) return 'Blocked App';
    final parts = pkg.split('.');
    final raw = parts.last;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  Future<void> _openUsageAccess() async {
    try {
      await const AndroidIntent(
              action: 'android.settings.USAGE_ACCESS_SETTINGS')
          .launch();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _broadcastTimer?.cancel();
    _emergencyTimer?.cancel();
    _overlaySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isStudyFocus = provider.activeChallenge == ChallengeType.studyFocus;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(isLocked: provider.isLocked)),

          if (provider.isLocked)
            SliverToBoxAdapter(
                child: _ActiveChallengeBanner(provider: provider)),

          if (_emergencyActive)
            SliverToBoxAdapter(
                child: _EmergencyBanner(secsLeft: _emergencySecsLeft)),

          if (isStudyFocus)
            SliverToBoxAdapter(
                child: _UsageHint(onTap: _openUsageAccess)),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ActionCard(
                  icon: '📚',
                  title: 'Focus on Your Study',
                  subtitle: 'Block specific apps only — others work normally.',
                  colors: const [Color(0xFF7C4DFF), Color(0xFF5C6BC0)],
                  glow: const Color(0xFF7C4DFF),
                  onTap: () => Navigator.push(
                      context, _slide(const StudyFocusScreen())),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  icon: '🔒',
                  title: 'Mobile Lock',
                  subtitle: 'Full detox — lock your entire phone.',
                  colors: const [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
                  glow: const Color(0xFFFF6B9D),
                  onTap: () => _mobileLockSheet(context, provider),
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  icon: '🏃',
                  title: 'Health Improvement',
                  subtitle: 'Physical challenges with real step tracking.',
                  colors: const [Color(0xFF00E5FF), Color(0xFF00BFA5)],
                  glow: const Color(0xFF00E5FF),
                  onTap: () => Navigator.push(
                      context, _slide(const HealthChallengeScreen())),
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

  PageRouteBuilder _slide(Widget p) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => p,
        transitionsBuilder: (_, a, __, c) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: c,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      );

  void _mobileLockSheet(BuildContext context, AppStateProvider provider) {
    if (provider.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ A challenge is already active.')));
      return;
    }
    Duration sel = const Duration(hours: 1);
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
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final h in [1, 2, 3, 6, 12, 24])
                    _Chip(
                      label: '${h}h',
                      selected: sel == Duration(hours: h),
                      color: const Color(0xFFFF6B9D),
                      onTap: () => ss(() => sel = Duration(hours: h)),
                    )
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
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    context.read<BillingService>().onPurchaseSuccess =
                        () => provider.unlockAll();
                    provider.startMobileLock(duration: sel);
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

// ─── Widgets ──────────────────────────────────────────────────────────────────

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
                Text(isLocked ? '🔒 Challenge Active' : '👋 Welcome Back!',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9999BB),
                        fontWeight: FontWeight.w500)),
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
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF6666AA))),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            height: 130,
            child: Lottie.network(
              'https://assets4.lottiefiles.com/packages/lf20_jcikwtux.json',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text('🧑‍💻', style: TextStyle(fontSize: 80)),
            ),
          ),
        ],
      ),
    );
  }
}

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
              offset: const Offset(0, 8))
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

class _EmergencyBanner extends StatelessWidget {
  final int secsLeft;
  const _EmergencyBanner({required this.secsLeft});
  @override
  Widget build(BuildContext context) {
    final m = (secsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secsLeft % 60).toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74D).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFFB74D).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Emergency Bypass Active',
                    style: TextStyle(
                        color: Color(0xFFFFB74D),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text('Lock resumes in $m:$s',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageHint extends StatelessWidget {
  final VoidCallback onTap;
  const _UsageHint({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('📊', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Grant "Usage Access" so blocked apps are detected.',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

class _ActionCard extends StatelessWidget {
  final String icon, title, subtitle;
  final List<Color> colors;
  final Color glow;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.title, required this.subtitle,
    required this.colors, required this.glow, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.first.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: glow.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18)),
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
                  color: colors.first.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  color: colors.first, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AppStateProvider provider;
  const _StatsRow({required this.provider});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          _StatTile(
              icon: '🔥', label: 'Streak',
              value: '0 days', color: const Color(0xFFFF6B9D)),
          const SizedBox(width: 12),
          _StatTile(
              icon: '👟', label: 'Today Steps',
              value: '${provider.currentSteps}',
              color: const Color(0xFF00E5FF)),
        ],
      );
}

class _StatTile extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _StatTile(
      {required this.icon, required this.label,
       required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
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
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6666AA))),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected,
       required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
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
