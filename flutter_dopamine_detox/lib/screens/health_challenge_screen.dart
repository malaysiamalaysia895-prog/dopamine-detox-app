import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';

class HealthChallengeScreen extends StatefulWidget {
  const HealthChallengeScreen({super.key});

  @override
  State<HealthChallengeScreen> createState() => _HealthChallengeScreenState();
}

class _HealthChallengeScreenState extends State<HealthChallengeScreen>
    with WidgetsBindingObserver {

  // ── Pedometer ──────────────────────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  int _baseStepCount = -1;  // step count at challenge start
  int _sessionSteps = 0;
  String _pedeStatus = 'stopped';

  // ── Permission ─────────────────────────────────────────────────────────────
  PermissionStatus _permStatus = PermissionStatus.denied;
  bool _permChecked = false;

  // ── Billing ────────────────────────────────────────────────────────────────
  bool _billingLoading = false;

  // ── Presets ────────────────────────────────────────────────────────────────
  final List<_ChallengePreset> _presets = const [
    _ChallengePreset(
      emoji: '🚶', title: '10 Min Walk',    subtitle: '~1,000 steps',
      duration: Duration(minutes: 10), targetSteps: 1000,
      color: Color(0xFF00E5FF),
    ),
    _ChallengePreset(
      emoji: '🏃', title: '15 Min Run',     subtitle: '~1,500 steps',
      duration: Duration(minutes: 15), targetSteps: 1500,
      color: Color(0xFF69F0AE),
    ),
    _ChallengePreset(
      emoji: '🔥', title: '30 Min Workout', subtitle: '~3,000 steps',
      duration: Duration(minutes: 30), targetSteps: 3000,
      color: Color(0xFFFF6B9D),
    ),
    _ChallengePreset(
      emoji: '⚡', title: '45 Min Jog',     subtitle: '~4,500 steps',
      duration: Duration(minutes: 45), targetSteps: 4500,
      color: Color(0xFFFFB74D),
    ),
  ];
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permission when user returns from Settings screen
    if (state == AppLifecycleState.resumed && !_permStatus.isGranted) {
      _checkPermission();
    }
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _checkPermission() async {
    final status = await Permission.activityRecognition.status;
    if (mounted) setState(() => _permStatus = status);
  }

  /// Requests ACTIVITY_RECOGNITION. On Android 10+ this shows the system dialog.
  /// If permanently denied, opens App Settings so user can enable manually.
  Future<void> _requestPermission() async {
    if (_permStatus.isPermanentlyDenied) {
      // System dialog will not appear — must open Settings
      await openAppSettings();
      return;
    }

    final result = await Permission.activityRecognition.request();
    if (mounted) {
      setState(() {
        _permStatus = result;
        _permChecked = true;
      });

      if (result.isGranted) {
        // If a challenge is already active, reconnect pedometer
        final provider = context.read<AppStateProvider>();
        if (provider.activeChallenge == ChallengeType.healthChallenge) {
          _startPedometer();
        }
      } else if (result.isPermanentlyDenied) {
        // Show settings guidance
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                '⚠️ Permission denied. Opening App Settings…'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        await openAppSettings();
      }
    }
  }

  bool get _permGranted => _permStatus.isGranted;

  // ── Pedometer ──────────────────────────────────────────────────────────────

  void _startPedometer() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _stepSub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) => setState(() => _pedeStatus = 'sensor_error'),
      cancelOnError: false,
    );
    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (e) { if (mounted) setState(() => _pedeStatus = e.status); },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _onStep(StepCount event) {
    if (!mounted) return;
    if (_baseStepCount < 0) _baseStepCount = event.steps;
    final session = event.steps - _baseStepCount;
    setState(() => _sessionSteps = session);
    context.read<AppStateProvider>().updateSteps(session);
  }

  // ── Start challenge ────────────────────────────────────────────────────────

  Future<void> _startChallenge() async {
    final provider = context.read<AppStateProvider>();

    // Guard: don't allow second challenge
    if (provider.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ A challenge is already active.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_permGranted) {
      await _requestPermission();
      return;
    }

    final billing = context.read<BillingService>();
    billing.onPurchaseSuccess = () {
      provider.unlockAll();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Penalty paid — challenge unlocked.')),
        );
      }
    };

    final preset = _presets[_selectedIndex];
    provider.startHealthChallenge(
      duration: preset.duration,
      targetSteps: preset.targetSteps,
    );

    _baseStepCount = -1;
    _sessionSteps = 0;
    _startPedometer();
  }

  // ── Abort ──────────────────────────────────────────────────────────────────

  Future<void> _attemptAbort() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🚨 Abort Challenge?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Aborting early requires a ₹99 penalty via Google Play.\n\n'
          'The challenge is ONLY removed after a SUCCESSFUL payment. '
          'Cancelling keeps the lock active.',
          style:
              TextStyle(color: Color(0xFFCCCCDD), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Going',
                style: TextStyle(color: Color(0xFF6666AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay ₹99 & Abort',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _billingLoading = true);
    try {
      final billing = context.read<BillingService>();
      await billing.buyPenalty();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _billingLoading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isActive =
        provider.activeChallenge == ChallengeType.healthChallenge;
    final completed = provider.healthCompleted;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppTheme.bg,
            pinned: true,
            expandedHeight: 180,
            leading: GestureDetector(
              onTap: () {
                if (isActive && !completed) {
                  _attemptAbort();
                } else {
                  Navigator.pop(context);
                }
              },
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive
                      ? Icons.close_rounded
                      : Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Health Challenge',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0D0D1A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json',
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🏃', style: TextStyle(fontSize: 70)),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Permission section ────────────────────────────────
                  if (!_permGranted) _buildPermissionCard(),

                  // ── Completed banner ──────────────────────────────────
                  if (completed)
                    _CompletedBanner(onDismiss: () => Navigator.pop(context)),

                  // ── Active challenge tracker ──────────────────────────
                  if (isActive && !completed)
                    _ActiveTracker(
                      provider: provider,
                      sessionSteps: _sessionSteps,
                      pedeStatus: _pedeStatus,
                      billingLoading: _billingLoading,
                      onAbort: _attemptAbort,
                    ),

                  // ── Preset selector ───────────────────────────────────
                  if (!isActive && !completed) ...[
                    const Text('Choose Your Challenge',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Aborting early = ₹99 penalty payment.',
                      style: TextStyle(
                          color: Color(0xFFFF6B9D), fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(
                      _presets.length,
                      (i) => _PresetCard(
                        preset: _presets[i],
                        isSelected: _selectedIndex == i,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── Start button ──────────────────────────────────
                    GestureDetector(
                      onTap: _startChallenge,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _permGranted
                                ? [const Color(0xFF00E5FF), const Color(0xFF00BFA5)]
                                : [Colors.grey.shade800, Colors.grey.shade700],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _permGranted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withOpacity(0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _permGranted
                              ? '🏃 Start Challenge'
                              : _permStatus.isPermanentlyDenied
                                  ? '⚙️ Open Settings to Grant Permission'
                                  : '⚠️ Grant Activity Permission',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    final isPermanent = _permStatus.isPermanentlyDenied;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B9D).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ Activity Recognition Required',
              style: TextStyle(
                  color: Color(0xFFFF6B9D),
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            isPermanent
                ? 'Permission permanently denied. Go to:\nSettings → Apps → Dopamine Detox → Permissions → Physical activity → Allow'
                : 'Tap below to grant "Physical activity" permission so this app can count your steps.',
            style: const TextStyle(
                color: Colors.white54, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _requestPermission,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isPermanent ? '⚙️ Open App Settings' : '✅ Grant Permission',
                style: const TextStyle(
                    color: Color(0xFFFF6B9D),
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Active Tracker ───────────────────────────────────────────────────────────
class _ActiveTracker extends StatelessWidget {
  final AppStateProvider provider;
  final int sessionSteps;
  final String pedeStatus;
  final bool billingLoading;
  final VoidCallback onAbort;

  const _ActiveTracker({
    required this.provider,
    required this.sessionSteps,
    required this.pedeStatus,
    required this.billingLoading,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final r = provider.remainingTime;
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    final stepProgress =
        (sessionSteps / provider.targetSteps).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timer card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF00BFA5)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text('⏱ Time Remaining',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('$h:$m:$s',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 50,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.progressFraction,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Step counter card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('👟 Steps',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text('$sessionSteps / ${provider.targetSteps}',
                      style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: stepProgress,
                  backgroundColor:
                      const Color(0xFF00E5FF).withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5FF)),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 12),
              // Pedometer status pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: pedeStatus == 'walking'
                      ? const Color(0xFF69F0AE).withOpacity(0.15)
                      : pedeStatus == 'sensor_error'
                          ? Colors.red.withOpacity(0.1)
                          : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pedeStatus == 'walking'
                      ? '🟢 Moving'
                      : pedeStatus == 'stopped'
                          ? '🔴 Standing still'
                          : pedeStatus == 'sensor_error'
                              ? '⚠️ Sensor unavailable'
                              : '⚪ $pedeStatus',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Abort button (₹99 penalty)
        GestureDetector(
          onTap: billingLoading ? null : onAbort,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B9D).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: billingLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Column(
                    children: [
                      Text('🚨 Emergency Abort',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      SizedBox(height: 4),
                      Text('Penalty: ₹99 via Google Play',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ─── Preset Card ──────────────────────────────────────────────────────────────
class _PresetCard extends StatelessWidget {
  final _ChallengePreset preset;
  final bool isSelected;
  final VoidCallback onTap;
  const _PresetCard(
      {required this.preset,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:
              isSelected ? preset.color.withOpacity(0.15) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? preset.color.withOpacity(0.6)
                : Colors.white.withOpacity(0.06),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: preset.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child:
                  Text(preset.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(preset.subtitle,
                      style: TextStyle(
                          color: preset.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: preset.color, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Completed Banner ─────────────────────────────────────────────────────────
class _CompletedBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _CompletedBanner({required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF69F0AE), Color(0xFF00E5FF)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          const Text('Challenge Complete!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Bahut badhiya! Aap ne apna challenge pura kiya.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onDismiss,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00BFA5)),
            child: const Text('Back to Home',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────
class _ChallengePreset {
  final String emoji;
  final String title;
  final String subtitle;
  final Duration duration;
  final int targetSteps;
  final Color color;
  const _ChallengePreset({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.targetSteps,
    required this.color,
  });
}
