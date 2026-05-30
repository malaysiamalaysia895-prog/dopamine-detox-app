import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// This screen is rendered INSIDE the overlay window (separate isolate).
/// It communicates back to the main app via FlutterOverlayWindow message passing.
///
/// Emergency unlock: long-press — max 2 uses, 2 minutes each.
/// Penalty unlock: pay ₹99 via the main app (button opens main app).
class LockOverlayScreen extends StatefulWidget {
  const LockOverlayScreen({super.key});

  @override
  State<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends State<LockOverlayScreen>
    with SingleTickerProviderStateMixin {
  // ── Emergency state ────────────────────────────────────────────────────────
  int _emergencyUsesLeft = 2;
  bool _emergencyActive = false;
  Duration _emergencyRemaining = const Duration(minutes: 2);
  Timer? _emergencyTimer;

  // ── Long press progress ────────────────────────────────────────────────────
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;
  bool _longPressing = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen to messages from the main app (e.g., emergency count updates)
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        final type = data['type'] as String?;
        if (type == 'emergency_uses_left') {
          setState(() => _emergencyUsesLeft = data['value'] as int? ?? 0);
        }
        if (type == 'unlock') {
          FlutterOverlayWindow.closeOverlay();
        }
      }
    });
  }

  // ── Long press logic ───────────────────────────────────────────────────────
  void _onLongPressStart(LongPressStartDetails _) {
    if (_emergencyUsesLeft <= 0 || _emergencyActive) return;
    _longPressing = true;
    _longPressProgress = 0.0;

    _longPressTimer =
        Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!_longPressing) {
        timer.cancel();
        setState(() => _longPressProgress = 0.0);
        return;
      }
      setState(() {
        _longPressProgress += 0.03;
        if (_longPressProgress >= 1.0) {
          timer.cancel();
          _longPressProgress = 0.0;
          _longPressing = false;
          _activateEmergency();
        }
      });
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _longPressing = false;
    _longPressTimer?.cancel();
    setState(() => _longPressProgress = 0.0);
  }

  void _activateEmergency() {
    if (_emergencyUsesLeft <= 0) return;

    setState(() {
      _emergencyUsesLeft--;
      _emergencyActive = true;
      _emergencyRemaining = const Duration(minutes: 2);
    });

    // Notify main app
    FlutterOverlayWindow.shareData({
      'type': 'emergency_unlock',
      'usesLeft': _emergencyUsesLeft,
    });

    // Close overlay temporarily
    FlutterOverlayWindow.closeOverlay();

    // Schedule re-lock after 2 minutes
    _emergencyTimer = Timer(const Duration(minutes: 2), () {
      _reActivateOverlay();
    });

    // Countdown for UI (if overlay is somehow still visible)
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (_emergencyRemaining.inSeconds <= 0 || !_emergencyActive) {
        t.cancel();
        return;
      }
      setState(() {
        _emergencyRemaining -= const Duration(seconds: 1);
      });
    });
  }

  Future<void> _reActivateOverlay() async {
    setState(() {
      _emergencyActive = false;
      _emergencyRemaining = const Duration(minutes: 2);
    });

    await FlutterOverlayWindow.showOverlay(
      enableDrag: false,
      overlayTitle: 'Challenge Active',
      overlayContent: 'Kripya apna challenge complete karein.',
      flag: OverlayFlag.defaultFlag,
      alignment: OverlayAlignment.center,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: WindowSize.fullCover,
      width: WindowSize.fullCover,
    );
  }

  void _openMainApp() {
    // Share message to main app to trigger billing
    FlutterOverlayWindow.shareData({'type': 'open_billing'});
    // The main app should respond by bringing itself to foreground
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _emergencyTimer?.cancel();
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Pulse lock icon ─────────────────────────────────────────
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
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
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Main message ────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Kripya apna challenge\ncomplete karein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'App locked until your challenge ends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Emergency button ────────────────────────────────────────
              if (_emergencyUsesLeft > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        '⚠️ Emergency Uses Left: $_emergencyUsesLeft / 2',
                        style: const TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Long-press progress indicator
                      if (_longPressProgress > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _longPressProgress,
                              backgroundColor:
                                  Colors.white.withOpacity(0.1),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFFB74D)),
                              minHeight: 5,
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
                            color: const Color(0xFFFFB74D).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFFFB74D)
                                    .withOpacity(0.4)),
                          ),
                          alignment: Alignment.center,
                          child: const Column(
                            children: [
                              Text(
                                '🔓 Long Press for Emergency',
                                style: TextStyle(
                                  color: Color(0xFFFFB74D),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Unlocks for 2 minutes only',
                                style: TextStyle(
                                  color: Color(0xFFFFB74D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Text(
                      '🚫 Emergency uses exhausted.',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Pay Penalty button ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GestureDetector(
                  onTap: _openMainApp,
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
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '💳 Pay ₹99 Penalty to Unlock',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
