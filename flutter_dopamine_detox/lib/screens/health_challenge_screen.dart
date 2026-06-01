import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';

/// HealthChallengeScreen
///
/// Bug #5 fix — why the permission button did nothing:
///   1. `Permission.activityRecognition.request()` was called but not awaited
///      properly — setState ran BEFORE the system dialog resolved, so the UI
///      showed "denied" even when the user approved.
///   2. `Permission.sensors` was never requested (required on some devices).
///   3. `isPermanentlyDenied` was never checked — on Android 11+ the dialog
///      doesn't appear after being denied twice; we must call openAppSettings().
///   4. The WidgetsBindingObserver was not wired — returning from Settings
///      never re-checked the permission, so the button stayed "denied" forever.
///
///   Fix: Properly await BOTH permissions, check isPermanentlyDenied → openAppSettings(),
///        use WidgetsBindingObserver to re-check on resume.
class HealthChallengeScreen extends StatefulWidget {
  const HealthChallengeScreen({super.key});

  @override
  State<HealthChallengeScreen> createState() => _HealthChallengeScreenState();
}

class _HealthChallengeScreenState extends State<HealthChallengeScreen>
    with WidgetsBindingObserver {

  // ── Permission ─────────────────────────────────────────────────────────────
  // Both permissions must be granted for pedometer to work reliably.
  PermissionStatus _activityStatus = PermissionStatus.denied;
  PermissionStatus _sensorsStatus  = PermissionStatus.denied;
  bool _permChecked = false;
  bool _requestingPerm = false;

  bool get _permGranted =>
      _activityStatus.isGranted && _sensorsStatus.isGranted;

  // ── Pedometer ──────────────────────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;
  int _baseSteps = -1;
  int _sessionSteps = 0;
  String _pedeStatus = 'stopped';

  // ── Billing ────────────────────────────────────────────────────────────────
  bool _billingLoading = false;

  // ── Presets ────────────────────────────────────────────────────────────────
  final _presets = const [
    _Preset(emoji:'🚶', title:'10 Min Walk',    sub:'~1,000 steps',
            duration:Duration(minutes:10), steps:1000, color:Color(0xFF00E5FF)),
    _Preset(emoji:'🏃', title:'15 Min Run',     sub:'~1,500 steps',
            duration:Duration(minutes:15), steps:1500, color:Color(0xFF69F0AE)),
    _Preset(emoji:'🔥', title:'30 Min Workout', sub:'~3,000 steps',
            duration:Duration(minutes:30), steps:3000, color:Color(0xFFFF6B9D)),
    _Preset(emoji:'⚡', title:'45 Min Jog',     sub:'~4,500 steps',
            duration:Duration(minutes:45), steps:4500, color:Color(0xFFFFB74D)),
  ];
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Bug #5 fix: re-check permissions when user returns from Settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  // ── Permission logic — Bug #5 fix ─────────────────────────────────────────

  Future<void> _checkPermissions() async {
    final act = await Permission.activityRecognition.status;
    final sen = await Permission.sensors.status;
    if (mounted) {
      setState(() {
        _activityStatus = act;
        _sensorsStatus  = sen;
        _permChecked    = true;
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (_requestingPerm) return;
    setState(() => _requestingPerm = true);

    try {
      // Check if permanently denied BEFORE requesting (system won't show dialog)
      final actStatus = await Permission.activityRecognition.status;
      final senStatus = await Permission.sensors.status;

      if (actStatus.isPermanentlyDenied || senStatus.isPermanentlyDenied) {
        // Cannot show system dialog — must open app settings
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  '⚠️ Permission permanently denied. Opening App Settings…'),
              action: SnackBarAction(
                  label: 'Settings', onPressed: openAppSettings),
            ),
          );
        }
        await Future.delayed(const Duration(milliseconds: 800));
        await openAppSettings();
        return;
      }

      // Request both permissions and AWAIT the result
      final Map<Permission, PermissionStatus> results = await [
        Permission.activityRecognition,
        Permission.sensors,
      ].request();

      if (!mounted) return;

      final newAct = results[Permission.activityRecognition]
          ?? PermissionStatus.denied;
      final newSen = results[Permission.sensors]
          ?? PermissionStatus.denied;

      setState(() {
        _activityStatus = newAct;
        _sensorsStatus  = newSen;
      });

      if (newAct.isPermanentlyDenied || newSen.isPermanentlyDenied) {
        // Denied permanently on this request — guide to settings
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permission denied. Tap "Settings" to enable.'),
              action: SnackBarAction(
                  label: 'Settings', onPressed: openAppSettings),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else if (newAct.isGranted && newSen.isGranted) {
        // Both granted — check if challenge already active and start pedometer
        final provider = context.read<AppStateProvider>();
        if (provider.activeChallenge == ChallengeType.healthChallenge) {
          _startPedometer();
        }
      }

    } finally {
      if (mounted) setState(() => _requestingPerm = false);
    }
  }

  // ── Pedometer ──────────────────────────────────────────────────────────────

  void _startPedometer() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _baseSteps = -1;

    _stepSub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) {
        if (mounted) setState(() => _pedeStatus = 'sensor_error');
      },
      cancelOnError: false,
    );
    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (e) { if (mounted) setState(() => _pedeStatus = e.status); },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _onStep(StepCount e) {
    if (!mounted) return;
    if (_baseSteps < 0) _baseSteps = e.steps;
    final session = e.steps - _baseSteps;
    setState(() => _sessionSteps = session);
    context.read<AppStateProvider>().updateSteps(session);
  }

  // ── Start challenge ────────────────────────────────────────────────────────

  Future<void> _startChallenge() async {
    final provider = context.read<AppStateProvider>();

    if (provider.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚠️ A challenge is already active.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (!_permGranted) {
      await _requestPermissions();
      return;
    }

    context.read<BillingService>().onPurchaseSuccess = () {
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
      targetSteps: preset.steps,
    );

    _sessionSteps = 0;
    _startPedometer();
    setState(() {});
  }

  // ── Abort (₹99) ────────────────────────────────────────────────────────────

  Future<void> _abort() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        title: const Text('🚨 Abort Challenge?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Requires ₹99 penalty via Google Play.\n'
          'Challenge is removed ONLY after a successful payment.',
          style: TextStyle(
              color: Color(0xFFCCCCDD), fontSize: 13, height: 1.5),
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
            child: const Text('Pay ₹99 & Abort'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _billingLoading = true);
    try {
      await context.read<BillingService>().buyPenalty();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Payment error: $e')));
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
          SliverAppBar(
            backgroundColor: AppTheme.bg,
            pinned: true,
            expandedHeight: 170,
            leading: GestureDetector(
              onTap: () {
                if (isActive && !completed) {
                  _abort();
                } else {
                  Navigator.pop(context);
                }
              },
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.glassWhite,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    isActive
                        ? Icons.close_rounded
                        : Icons.arrow_back_ios_rounded,
                    color: Colors.white,
                    size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Health Challenge',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0D0D1A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                ),
                child: Center(
                  child: Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json',
                    height: 110,
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

                  // ── Permission card — Bug #5 fix ────────────────────────
                  if (!_permGranted && _permChecked)
                    _PermCard(
                      activityStatus: _activityStatus,
                      sensorsStatus: _sensorsStatus,
                      loading: _requestingPerm,
                      onTap: _requestPermissions,
                    ),

                  // ── Completed ───────────────────────────────────────────
                  if (completed) _CompletedCard(
                      onDismiss: () => Navigator.pop(context)),

                  // ── Active tracker ──────────────────────────────────────
                  if (isActive && !completed)
                    _ActiveTracker(
                      provider: provider,
                      sessionSteps: _sessionSteps,
                      pedeStatus: _pedeStatus,
                      billingLoading: _billingLoading,
                      onAbort: _abort,
                    ),

                  // ── Preset selector ─────────────────────────────────────
                  if (!isActive && !completed) ...[
                    const Text('Choose Your Challenge',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Aborting early costs ₹99.',
                        style: TextStyle(
                            color: Color(0xFFFF6B9D), fontSize: 12)),
                    const SizedBox(height: 18),
                    ...List.generate(
                      _presets.length,
                      (i) => _PresetCard(
                        preset: _presets[i],
                        selected: _selectedIndex == i,
                        onTap: () =>
                            setState(() => _selectedIndex = i),
                      ),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: _startChallenge,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _permGranted
                                ? [const Color(0xFF00E5FF),
                                    const Color(0xFF00BFA5)]
                                : [Colors.grey.shade800, Colors.grey.shade700],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _permGranted
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  )
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _permGranted
                              ? '🏃 Start Challenge'
                              : _requestingPerm
                                  ? '⏳ Requesting permission…'
                                  : _activityStatus.isPermanentlyDenied
                                      ? '⚙️ Open App Settings'
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
}

// ─── Permission Card ──────────────────────────────────────────────────────────
class _PermCard extends StatelessWidget {
  final PermissionStatus activityStatus, sensorsStatus;
  final bool loading;
  final VoidCallback onTap;
  const _PermCard({
    required this.activityStatus, required this.sensorsStatus,
    required this.loading, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isPermanent = activityStatus.isPermanentlyDenied ||
        sensorsStatus.isPermanentlyDenied;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B9D).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Activity & Sensor Permissions Required',
                  style: TextStyle(
                      color: Color(0xFFFF6B9D),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          // Show per-permission status
          _PermRow(
              name: 'Physical Activity',
              status: activityStatus),
          const SizedBox(height: 3),
          _PermRow(
              name: 'Body Sensors',
              status: sensorsStatus),
          const SizedBox(height: 8),
          if (isPermanent)
            const Text(
              'One or more permissions are permanently denied.\n'
              'Go to: Settings → Apps → Dopamine Detox → Permissions',
              style: TextStyle(
                  color: Colors.white54, fontSize: 12, height: 1.5),
            )
          else
            const Text(
              'Tap below to grant permissions so step tracking works.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: loading ? null : onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF6B9D), strokeWidth: 2))
                  : Text(
                      isPermanent
                          ? '⚙️ Open App Settings'
                          : '✅ Grant Permissions',
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

class _PermRow extends StatelessWidget {
  final String name;
  final PermissionStatus status;
  const _PermRow({required this.name, required this.status});
  @override
  Widget build(BuildContext context) {
    final granted = status.isGranted;
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? const Color(0xFF69F0AE) : const Color(0xFFFF6B9D),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(name,
            style: TextStyle(
                color: granted
                    ? const Color(0xFF69F0AE)
                    : const Color(0xFFFF6B9D),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          status.isGranted
              ? 'Granted'
              : status.isPermanentlyDenied
                  ? 'Permanently Denied'
                  : 'Denied',
          style: TextStyle(
              color: granted ? Colors.white38 : const Color(0xFFFF6B9D),
              fontSize: 11),
        ),
      ],
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
    required this.provider, required this.sessionSteps,
    required this.pedeStatus, required this.billingLoading,
    required this.onAbort,
  });
  @override
  Widget build(BuildContext context) {
    final r = provider.remainingTime;
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    final stepPct =
        (sessionSteps / provider.targetSteps).clamp(0.0, 1.0);

    return Column(
      children: [
        // Timer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF00BFA5)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              const Text('⏱ Time Remaining',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text('$h:$m:$s',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
              const SizedBox(height: 14),
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
        const SizedBox(height: 16),
        // Steps
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(18),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text('$sessionSteps / ${provider.targetSteps}',
                      style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: stepPct,
                  backgroundColor:
                      const Color(0xFF00E5FF).withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5FF)),
                  minHeight: 9,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: pedeStatus == 'walking'
                      ? const Color(0xFF69F0AE).withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pedeStatus == 'walking'
                      ? '🟢 Moving'
                      : pedeStatus == 'stopped'
                          ? '🔴 Standing still'
                          : '⚠️ Sensor issue',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Abort
        GestureDetector(
          onTap: billingLoading ? null : onAbort,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)]),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: billingLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Column(
                    children: [
                      Text('🚨 Abort Challenge Early',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      SizedBox(height: 3),
                      Text('Requires ₹99 penalty via Google Play',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
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
  final _Preset preset;
  final bool selected;
  final VoidCallback onTap;
  const _PresetCard(
      {required this.preset, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? preset.color.withOpacity(0.14)
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? preset.color.withOpacity(0.55)
                  : Colors.white.withOpacity(0.06),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: preset.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(preset.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(preset.sub,
                        style: TextStyle(
                            color: preset.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 26,
                  height: 26,
                  decoration:
                      BoxDecoration(color: preset.color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
            ],
          ),
        ),
      );
}

class _CompletedCard extends StatelessWidget {
  final VoidCallback onDismiss;
  const _CompletedCard({required this.onDismiss});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF69F0AE), Color(0xFF00E5FF)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 10),
            const Text('Challenge Complete!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Great work! Keep it up.',
                style:
                    TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 18),
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

// ─── Data model ───────────────────────────────────────────────────────────────
class _Preset {
  final String emoji, title, sub;
  final Duration duration;
  final int steps;
  final Color color;
  const _Preset({
    required this.emoji, required this.title, required this.sub,
    required this.duration, required this.steps, required this.color,
  });
}
