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

class _HealthChallengeScreenState extends State<HealthChallengeScreen> {
  // ── Pedometer ──────────────────────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  int _initialStepCount = -1;
  int _sessionSteps = 0;
  String _pedometerStatus = 'stopped';

  // ── Permission ─────────────────────────────────────────────────────────────
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  bool _permissionChecked = false;

  // ── Challenge state ────────────────────────────────────────────────────────
  bool _challengeStarted = false;

  // ── Billing loading ────────────────────────────────────────────────────────
  bool _billingLoading = false;

  // ── Presets ────────────────────────────────────────────────────────────────
  final List<_ChallengePreset> _presets = const [
    _ChallengePreset(
      emoji: '🚶',
      title: '10 Min Walk',
      subtitle: '1,000 steps',
      duration: Duration(minutes: 10),
      targetSteps: 1000,
      color: Color(0xFF00E5FF),
    ),
    _ChallengePreset(
      emoji: '🏃',
      title: '15 Min Run',
      subtitle: '1,500 steps',
      duration: Duration(minutes: 15),
      targetSteps: 1500,
      color: Color(0xFF69F0AE),
    ),
    _ChallengePreset(
      emoji: '🔥',
      title: '30 Min Workout',
      subtitle: '3,000 steps',
      duration: Duration(minutes: 30),
      targetSteps: 3000,
      color: Color(0xFFFF6B9D),
    ),
    _ChallengePreset(
      emoji: '⚡',
      title: '45 Min Jog',
      subtitle: '4,500 steps',
      duration: Duration(minutes: 45),
      targetSteps: 4500,
      color: Color(0xFFFFB74D),
    ),
  ];

  int _selectedPresetIndex = 1;

  @override
  void initState() {
    super.initState();
    _requestActivityPermission();
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _requestActivityPermission() async {
    // Explicitly request ACTIVITY_RECOGNITION at runtime
    final status = await Permission.activityRecognition.request();
    setState(() {
      _permissionStatus = status;
      _permissionChecked = true;
    });

    if (status.isGranted) {
      // If a challenge was already running (app reopened), restart pedometer
      final provider = context.read<AppStateProvider>();
      if (provider.activeChallenge == ChallengeType.healthChallenge) {
        _startPedometer();
      }
    }
  }

  bool get _permissionGranted => _permissionStatus.isGranted;

  // ── Pedometer ──────────────────────────────────────────────────────────────

  void _startPedometer() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();

    _stepSubscription = Pedometer.stepCountStream
        .listen(_onStepCount, onError: _onStepError);
    _statusSubscription = Pedometer.pedestrianStatusStream
        .listen(_onPedestrianStatus, onError: _onStatusError);
  }

  void _onStepCount(StepCount event) {
    if (!mounted) return;
    final provider = context.read<AppStateProvider>();
    if (_initialStepCount < 0) _initialStepCount = event.steps;
    final session = event.steps - _initialStepCount;
    setState(() => _sessionSteps = session);
    provider.updateSteps(session);
  }

  void _onStepError(Object error) {
    setState(() => _pedometerStatus = 'error');
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    if (mounted) setState(() => _pedometerStatus = event.status);
  }

  void _onStatusError(Object error) {
    debugPrint('[Pedometer] Status error: $error');
  }

  // ── Start challenge ─────────────────────────────────────────────────────────

  void _startChallenge() {
    if (!_permissionGranted) {
      _requestActivityPermission();
      return;
    }

    final preset = _presets[_selectedPresetIndex];
    final provider = context.read<AppStateProvider>();
    final billing = context.read<BillingService>();

    billing.onPurchaseSuccess = () {
      provider.unlockAll();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Penalty paid — challenge unlocked.')),
        );
      }
    };

    provider.startHealthChallenge(
      duration: preset.duration,
      targetSteps: preset.targetSteps,
    );

    _initialStepCount = -1;
    _sessionSteps = 0;
    _startPedometer();
    setState(() => _challengeStarted = true);
  }

  // ── Abort with ₹99 penalty ─────────────────────────────────────────────────

  Future<void> _attemptAbort() async {
    final billing = context.read<BillingService>();

    final shouldPay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AbortDialog(),
    );

    if (shouldPay != true) return;

    setState(() => _billingLoading = true);
    try {
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
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final bool completed = provider.healthCompleted;
    final bool activeChallengeHere =
        provider.activeChallenge == ChallengeType.healthChallenge;

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
                if (activeChallengeHere && !completed) {
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
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 18),
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
                  // ── Permission warning or prompt ────────────────────
                  if (_permissionChecked && !_permissionGranted)
                    _PermissionWarning(
                      status: _permissionStatus,
                      onRequest: _requestActivityPermission,
                    ),

                  // ── Completed banner ────────────────────────────────
                  if (completed)
                    _CompletedBanner(
                        onDismiss: () => Navigator.pop(context)),

                  // ── Active tracker ──────────────────────────────────
                  if (activeChallengeHere && !completed)
                    _ActiveTracker(
                      provider: provider,
                      sessionSteps: _sessionSteps,
                      pedometerStatus: _pedometerStatus,
                      billingLoading: _billingLoading,
                      onAbort: _attemptAbort,
                    ),

                  // ── Preset selector ─────────────────────────────────
                  if (!activeChallengeHere && !completed) ...[
                    const Text('Choose Your Challenge',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Aborting early requires ₹99 penalty payment.',
                      style: TextStyle(
                          color: Color(0xFFFF6B9D), fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(
                      _presets.length,
                      (i) => _PresetCard(
                        preset: _presets[i],
                        isSelected: _selectedPresetIndex == i,
                        onTap: () =>
                            setState(() => _selectedPresetIndex = i),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Start button
                    GestureDetector(
                      onTap: _startChallenge,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _permissionGranted
                                ? [
                                    const Color(0xFF00E5FF),
                                    const Color(0xFF00BFA5)
                                  ]
                                : [
                                    Colors.grey.shade700,
                                    Colors.grey.shade600
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _permissionGranted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _permissionGranted
                              ? '🏃 Start Challenge'
                              : '⚠️ Permission Required',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
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
}

// ─── Active Tracker ───────────────────────────────────────────────────────────
class _ActiveTracker extends StatelessWidget {
  final AppStateProvider provider;
  final int sessionSteps;
  final String pedometerStatus;
  final bool billingLoading;
  final VoidCallback onAbort;

  const _ActiveTracker({
    required this.provider,
    required this.sessionSteps,
    required this.pedometerStatus,
    required this.billingLoading,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = provider.remainingTime;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final stepsProgress =
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
              colors: [Color(0xFF00E5FF), Color(0xFF00BFA5)],
            ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text('$h:$m:$s',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
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

        // Step counter
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
                  value: stepsProgress,
                  backgroundColor:
                      const Color(0xFF00E5FF).withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5FF)),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pedometerStatus == 'walking'
                      ? const Color(0xFF69F0AE).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pedometerStatus == 'walking'
                      ? '🟢 Moving'
                      : pedometerStatus == 'stopped'
                          ? '🔴 Stopped'
                          : '⚪ $pedometerStatus',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Emergency Abort button (₹99 penalty) ───────────────────────
        GestureDetector(
          onTap: billingLoading ? null : onAbort,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
              ),
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
                      Text(
                        '🚨 Emergency Abort',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Penalty: ₹99 via Google Play',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

// ─── Permission Warning ───────────────────────────────────────────────────────
class _PermissionWarning extends StatelessWidget {
  final PermissionStatus status;
  final VoidCallback onRequest;

  const _PermissionWarning(
      {required this.status, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final isPermanentlyDenied = status.isPermanentlyDenied;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B9D).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ Activity Recognition Required',
              style: TextStyle(
                  color: Color(0xFFFF6B9D),
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            isPermanentlyDenied
                ? 'Permission was permanently denied. Please enable it in Settings > Apps > Dopamine Detox > Permissions.'
                : 'Please grant Activity Recognition permission to track your steps in real time.',
            style:
                const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isPermanentlyDenied
                ? () => openAppSettings()
                : onRequest,
            child: Text(
              isPermanentlyDenied
                  ? 'Open App Settings →'
                  : 'Grant Permission →',
              style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
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
          color: isSelected
              ? preset.color.withOpacity(0.15)
              : AppTheme.cardBg,
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
                child: const Icon(Icons.check,
                    color: Colors.white, size: 16),
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
          colors: [Color(0xFF69F0AE), Color(0xFF00E5FF)],
        ),
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

// ─── Abort Dialog ─────────────────────────────────────────────────────────────
class _AbortDialog extends StatelessWidget {
  const _AbortDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('🚨 Abort Challenge?',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
      content: const Text(
        'Aborting early requires a ₹99 penalty payment via Google Play.\n\n'
        'The challenge will ONLY be removed after a SUCCESSFUL payment. '
        'If payment fails or is cancelled, the lock stays active.',
        style: TextStyle(
            color: Color(0xFFCCCCDD), fontSize: 14, height: 1.5),
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
