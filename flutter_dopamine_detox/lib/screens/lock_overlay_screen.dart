import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../main.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LockOverlayScreen
///
/// Runs inside the Flutter overlay isolate (overlayMain entry point).
/// The main app feeds it timer data every second via FlutterOverlayWindow.shareData().
///
/// Messages FROM main app → overlay:
///   {'type': 'timer_update', 'time': 'HH:MM:SS', 'progress': 0.0…1.0,
///    'emergencyLeft': 0…10, 'appName': 'Instagram'}
///   {'type': 'dismiss'}   — close overlay (timer done or penalty paid)
///
/// Messages FROM overlay → main app:
///   {'type': 'emergency_unlock'}  — user long-pressed emergency button
///   {'type': 'pay_penalty'}       — user tapped ₹99 penalty button
///
/// BUG FIXES vs previous version:
///   1. StreamSubscription from overlayListener is now stored and cancelled
///      in dispose() → fixes the memory leak.
///   2. _activateEmergencyUnlock() no longer calls closeOverlay() directly.
///      The main app calls _closeOverlay() via its own listener. Calling
///      closeOverlay() from BOTH sides caused a double-close crash.
/// ─────────────────────────────────────────────────────────────────────────────
class LockOverlayScreen extends StatefulWidget {
  const LockOverlayScreen({super.key});

  @override
  State<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends State<LockOverlayScreen>
    with SingleTickerProviderStateMixin {

  // ── Data from main app ─────────────────────────────────────────────────────
  String _timeDisplay = '--:--:--';
  double _progress = 0.0;
  int _emergencyUsesLeft = 10;
  String _blockedAppName = 'Blocked App';

  // ── Listener subscription — MUST be cancelled in dispose() ────────────────
  // Bug fix: previous version never stored or cancelled this, causing a leak.
  StreamSubscription? _messageSub;

  // ── Long-press emergency progress ─────────────────────────────────────────
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;
  bool _longPressing = false;
  bool _emergencyFired = false;   // guard: prevents double-fire

  // ── Billing state ──────────────────────────────────────────────────────────
  bool _billingLoading = false;

  // ── Help panel ─────────────────────────────────────────────────────────────
  bool _showHelp = false;

  // ── Pulse animation ────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Bug fix: store the subscription so we can cancel it in dispose().
    _messageSub = FlutterOverlayWindow.overlayListener.listen(_onMessage);
  }

  void _onMessage(dynamic raw) {
    if (raw is! Map) return;
    final type = (raw['type'] as String?) ?? '';

    switch (type) {
      case 'timer_update':
        if (mounted) {
          setState(() {
            _timeDisplay = (raw['time'] as String?) ?? '--:--:--';
            _progress    = ((raw['progress'] as num?) ?? 0.0).toDouble();
            _emergencyUsesLeft =
                (raw['emergencyLeft'] as int?) ?? _emergencyUsesLeft;
            _blockedAppName =
                (raw['appName'] as String?) ?? _blockedAppName;
          });
        }
        break;

      case 'dismiss':
        // Main app confirmed overlay should close (penalty paid or timer done)
        FlutterOverlayWindow.closeOverlay();
        break;
    }
  }

  // ── Long-press emergency unlock ────────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails _) {
    if (_emergencyUsesLeft <= 0 || _emergencyFired) return;
    _longPressing = true;
    _longPressProgress = 0.0;
    _emergencyFired = false;

    _longPressTimer =
        Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!_longPressing) {
        t.cancel();
        if (mounted) setState(() => _longPressProgress = 0.0);
        return;
      }
      if (mounted) {
        setState(() {
          _longPressProgress += 30 / 2000; // fills in exactly 2 seconds
          if (_longPressProgress >= 1.0) {
            t.cancel();
            _longPressProgress = 1.0;
            _longPressing = false;
            _activateEmergencyUnlock();
          }
        });
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (_emergencyFired) return;
    _longPressing = false;
    _longPressTimer?.cancel();
    if (mounted) setState(() => _longPressProgress = 0.0);
  }

  void _activateEmergencyUnlock() {
    if (_emergencyFired) return;
    _emergencyFired = true;

    // Tell the main app to handle bypass logic (decrement count, hide overlay
    // for 2 minutes via its own _doEmergencyUnlock → _closeOverlay).
    // BUG FIX: Do NOT call FlutterOverlayWindow.closeOverlay() here.
    // The main app's _doEmergencyUnlock() already calls _closeOverlay(),
    // which calls FlutterOverlayWindow.closeOverlay(). Calling it from both
    // sides simultaneously causes a crash on the second call.
    FlutterOverlayWindow.shareData({'type': 'emergency_unlock'});

    // Reset guard after short delay so it can be used again if needed
    Future.delayed(const Duration(seconds: 3),
        () => _emergencyFired = false);
  }

  // ── ₹99 Penalty billing ────────────────────────────────────────────────────

  Future<void> _onPayPenalty() async {
    if (_billingLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('💳 Pay ₹99 to Unlock?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will end your focus session early.\n\n'
          'Payment of ₹99 via Google Play is required.\n'
          'Lock is removed ONLY after a successful payment.',
          style: TextStyle(
              color: Color(0xFFCCCCDD), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Studying',
                style: TextStyle(color: Color(0xFF6666AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay ₹99 & Unlock',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _billingLoading = true);
    // Ask main app to trigger billing via Google Play.
    // Main app sends 'dismiss' back on successful payment.
    // Do NOT close overlay here — only dismiss after payment confirmation.
    FlutterOverlayWindow.shareData({'type': 'pay_penalty'});
    // Reset loading after a short window (if main app doesn't respond)
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() => _billingLoading = false);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _longPressTimer?.cancel();
    // Bug fix: cancel the subscription to prevent the memory leak.
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF20D0D1A), Color(0xF21A0A2E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            child: Column(
              children: [
                // ── Pulsing lock icon ────────────────────────────────────
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)]),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 46),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Blocked app name ─────────────────────────────────────
                Text(
                  '$_blockedAppName is Blocked',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete your study session to regain access.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Color(0xFF8888AA), fontSize: 13),
                ),
                const SizedBox(height: 22),

                // ── Countdown timer card ─────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 22, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.055),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: const Color(0xFF7C4DFF).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('⏱ Session Remaining',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(
                        _timeDisplay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white12,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF7C4DFF)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Emergency unlock (long-press 2 sec) ──────────────────
                if (_emergencyUsesLeft > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('⚡ Emergency uses left: ',
                          style: TextStyle(
                              color: Color(0xFFFFB74D), fontSize: 12)),
                      Text('$_emergencyUsesLeft / 10',
                          style: const TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_longPressProgress > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _longPressProgress,
                          backgroundColor:
                              Colors.white.withOpacity(0.07),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFB74D)),
                          minHeight: 4,
                        ),
                      ),
                    ),

                  GestureDetector(
                    onLongPressStart: _onLongPressStart,
                    onLongPressEnd: _onLongPressEnd,
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFFFB74D)
                                .withOpacity(0.35)),
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Text('🔓 Hold for 2-Min Emergency Bypass',
                              style: TextStyle(
                                  color: Color(0xFFFFB74D),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          SizedBox(height: 4),
                          Text(
                            'Hold 2 sec → unlocked for 2 min → auto-relocks',
                            style: TextStyle(
                                color: Color(0xFFFFB74D),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.redAccent.withOpacity(0.25)),
                    ),
                    child: const Text(
                      '🚫 Emergency uses exhausted (10/10).\nResets at midnight.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── ₹99 Penalty unlock ────────────────────────────────────
                GestureDetector(
                  onTap: _billingLoading ? null : _onPayPenalty,
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF6B9D),
                            Color(0xFFFF8E53)
                          ]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B9D).withOpacity(0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _billingLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Column(
                            children: [
                              Text('💳 End Session Early',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17)),
                              SizedBox(height: 3),
                              Text('Pay ₹99 penalty via Google Play',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Android 13+ help toggle ───────────────────────────────
                GestureDetector(
                  onTap: () =>
                      setState(() => _showHelp = !_showHelp),
                  child: Text(
                    _showHelp
                        ? 'Hide help ▲'
                        : 'Overlay not showing correctly? ▼',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 11),
                  ),
                ),

                if (_showHelp) ...[
                  const SizedBox(height: 10),
                  _RestrictedSettingsCard(),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestrictedSettingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF00E5FF).withOpacity(0.22)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📱 Android 13+ Overlay Fix',
              style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          SizedBox(height: 6),
          Text(
            '1. Open phone Settings\n'
            '2. Apps → Dopamine Detox\n'
            '3. Tap ⋮ (3-dot menu) → Allow Restricted Settings\n'
            '4. Return here → grant "Display over other apps"',
            style: TextStyle(
                color: Colors.white54, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }
}
