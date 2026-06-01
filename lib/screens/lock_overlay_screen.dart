import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../main.dart';

/// Rendered inside the overlay window (separate Flutter isolate).
/// Communicates with the main app via FlutterOverlayWindow.shareData().
///
/// Features:
///   • Live countdown timer (received from main app via shareData messages)
///   • Emergency unlock: long-press → 2-min window, max 10/day
///   • Pay ₹99 penalty → opens main app billing flow
///   • Android 13+ Restricted Settings guidance
class LockOverlayScreen extends StatefulWidget {
  const LockOverlayScreen({super.key});

  @override
  State<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends State<LockOverlayScreen>
    with SingleTickerProviderStateMixin {

  // ── State received from main app via message channel ──────────────────────
  String _timeRemaining = '--:--:--';
  int _emergencyUsesLeft = 10;
  bool _isMobileLock = false;
  double _progress = 0.0;

  // ── Emergency unlock ───────────────────────────────────────────────────────
  // _emergencyActive and _emergencyRemainingSeconds are pushed from the main
  // app via timer_update messages — the overlay never manages its own timer.
  bool _emergencyActive = false;
  int _emergencyRemainingSeconds = 120;

  // ── Long-press progress ────────────────────────────────────────────────────
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;
  bool _longPressing = false;

  // ── Billing loading ────────────────────────────────────────────────────────
  bool _billingLoading = false;
  bool _showRestrictedGuide = false;

  // ── Pulse animation ────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Listen for messages from the main app
    FlutterOverlayWindow.overlayListener.listen(_onMessage);
  }

  void _onMessage(dynamic data) {
    if (data is! Map) return;
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'timer_update':
        if (mounted) {
          setState(() {
            _timeRemaining = data['time'] as String? ?? '--:--:--';
            _emergencyUsesLeft = data['emergencyUsesLeft'] as int? ?? 10;
            _isMobileLock = data['isMobileLock'] as bool? ?? false;
            _progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
            _emergencyActive = data['emergencyActive'] as bool? ?? false;
            _emergencyRemainingSeconds =
                data['emergencyRemainingSeconds'] as int? ?? 120;
          });
          // If emergency is active the overlay should be closed — the main app
          // closes it, but close defensively here too in case of race condition.
          if (_emergencyActive) FlutterOverlayWindow.closeOverlay();
        }
        break;

      case 'unlock':
        // Main app confirmed unlock (penalty paid or challenge done)
        FlutterOverlayWindow.closeOverlay();
        break;

      case 'restricted_settings':
        if (mounted) setState(() => _showRestrictedGuide = true);
        break;
    }
  }

  // ── Long-press emergency ───────────────────────────────────────────────────
  void _onLongPressStart(LongPressStartDetails _) {
    if (_emergencyUsesLeft <= 0 || _emergencyActive || _isMobileLock) return;
    _longPressing = true;
    _longPressProgress = 0.0;

    _longPressTimer =
        Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!_longPressing) {
        t.cancel();
        if (mounted) setState(() => _longPressProgress = 0.0);
        return;
      }
      if (mounted) {
        setState(() {
          _longPressProgress += 0.03;
          if (_longPressProgress >= 1.0) {
            t.cancel();
            _longPressProgress = 0.0;
            _longPressing = false;
            _triggerEmergencyUnlock();
          }
        });
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _longPressing = false;
    _longPressTimer?.cancel();
    if (mounted) setState(() => _longPressProgress = 0.0);
  }

  void _triggerEmergencyUnlock() {
    if (_emergencyUsesLeft <= 0 || _isMobileLock) return;

    // Tell the main app to:
    //   1. Decrement the daily emergency count in AppStateProvider
    //   2. Schedule re-showing this overlay after 2 minutes
    // The main app handles re-activation because timers in the overlay
    // isolate are killed when the overlay closes.
    FlutterOverlayWindow.shareData({'type': 'emergency_unlock_requested'});

    // Close overlay — user gets 2 minutes free. Main app re-opens us.
    FlutterOverlayWindow.closeOverlay();
  }

  // ── Penalty billing ────────────────────────────────────────────────────────
  Future<void> _payPenalty() async {
    if (_billingLoading) return;

    final confirmed = await _showPenaltyDialog();
    if (!confirmed) return;

    setState(() => _billingLoading = true);
    // Tell the main app to trigger billing
    FlutterOverlayWindow.shareData({'type': 'open_billing'});
    // Main app will send back 'unlock' message on successful purchase
    setState(() => _billingLoading = false);
  }

  Future<bool> _showPenaltyDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💳 Pay ₹99 Penalty?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Early unlock requires a ₹99 payment via Google Play.\n\n'
          'The lock will ONLY be removed after a SUCCESSFUL payment. '
          'Cancelling or failing payment keeps the lock active.',
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
            child: const Text('Pay ₹99 & Unlock',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0D0D1A).withOpacity(0.97),
              const Color(0xFF1A0A2E).withOpacity(0.97),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                // ── Lock icon (pulsing) ──────────────────────────────────
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isMobileLock
                          ? Icons.phonelink_lock_rounded
                          : Icons.lock_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Main message ─────────────────────────────────────────
                const Text(
                  'Kripya apna challenge\ncomplete karein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isMobileLock
                      ? 'Full phone lock is active.'
                      : 'App is locked until your challenge ends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ── Countdown timer ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF7C4DFF).withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      const Text('⏱ Time Remaining',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(
                        _timeRemaining,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF7C4DFF)),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Emergency section (not for Mobile Lock) ──────────────
                if (!_isMobileLock) ...[
                  _emergencyUsesLeft > 0
                      ? _EmergencyButton(
                          usesLeft: _emergencyUsesLeft,
                          progress: _longPressProgress,
                          onLongPressStart: _onLongPressStart,
                          onLongPressEnd: _onLongPressEnd,
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.red.withOpacity(0.25)),
                          ),
                          child: const Text(
                            '🚫 Daily emergency uses exhausted (10/10).\nResets at midnight.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                  const SizedBox(height: 16),
                ],

                // ── Pay penalty ──────────────────────────────────────────
                GestureDetector(
                  onTap: _billingLoading ? null : _payPenalty,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B9D).withOpacity(0.3),
                          blurRadius: 20,
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
                              Text('💳 Early Unlock',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17)),
                              SizedBox(height: 3),
                              Text('Pay ₹99 Penalty via Google Play',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Android 13+ Restricted Settings Guide ────────────────
                if (_showRestrictedGuide) _RestrictedSettingsGuide(),

                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showRestrictedGuide = !_showRestrictedGuide),
                  child: Text(
                    _showRestrictedGuide
                        ? 'Hide help ▲'
                        : 'Overlay not showing? Tap for help ▼',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Emergency Button Widget ──────────────────────────────────────────────────
class _EmergencyButton extends StatelessWidget {
  final int usesLeft;
  final double progress;
  final void Function(LongPressStartDetails) onLongPressStart;
  final void Function(LongPressEndDetails) onLongPressEnd;

  const _EmergencyButton({
    required this.usesLeft,
    required this.progress,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚡ Emergency Uses Today: ',
                style:
                    TextStyle(color: Color(0xFFFFB74D), fontSize: 12)),
            Text(
              '$usesLeft / 10 remaining',
              style: const TextStyle(
                  color: Color(0xFFFFB74D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (progress > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFB74D)),
                minHeight: 4,
              ),
            ),
          ),
        GestureDetector(
          onLongPressStart: onLongPressStart,
          onLongPressEnd: onLongPressEnd,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFFB74D).withOpacity(0.35)),
            ),
            alignment: Alignment.center,
            child: const Column(
              children: [
                Text('🔓 Long Press for Emergency Unlock',
                    style: TextStyle(
                        color: Color(0xFFFFB74D),
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                SizedBox(height: 4),
                Text('Unlocks for 2 minutes • Auto-relocks',
                    style: TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 11,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Android 13+ Restricted Settings Guide ───────────────────────────────────
class _RestrictedSettingsGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📱 Android 13+ — Overlay Not Working?',
            style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'Android 13+ blocks "Display over other apps" for sideloaded apps.\n\n'
            'To fix:\n'
            '1. Open phone Settings\n'
            '2. Go to Apps → Dopamine Detox\n'
            '3. Tap "3-dot menu" (top right)\n'
            '4. Tap "Allow Restricted Settings"\n'
            '5. Return here and enable the permission',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}
