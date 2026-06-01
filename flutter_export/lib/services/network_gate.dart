// ============================================================
// network_gate.dart — Global Internet Connectivity Guard
// Tech Tycoon Merge
//
// Wraps the entire app tree. Shows an un-dismissible 3D
// blocking screen whenever ConnectivityResult.none is detected.
// Player MUST reconnect and press "Retry" to resume.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ─── Network Gate Widget ──────────────────────────────────────────────────────
// Place this directly above your game root in the widget tree.

class NetworkGate extends StatefulWidget {
  final Widget child;
  const NetworkGate({super.key, required this.child});

  @override
  State<NetworkGate> createState() => _NetworkGateState();
}

class _NetworkGateState extends State<NetworkGate>
    with SingleTickerProviderStateMixin {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOffline = false;
  bool _checking  = false;

  // Animations for the warning icon pulse and button glow
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Check connectivity immediately on startup
    _checkNow();

    // Subscribe to ongoing connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Connectivity helpers ──────────────────────────────────────────────────

  Future<void> _checkNow() async {
    final results = await _connectivity.checkConnectivity();
    _onConnectivityChanged(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (offline != _isOffline) {
      setState(() => _isOffline = offline);
    }
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkNow();
    if (mounted) setState(() => _checking = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The actual game content (always rendered but covered when offline)
        widget.child,

        // Blocking overlay — present when offline
        if (_isOffline)
          Positioned.fill(
            child: _OfflineBlocker(
              pulseAnim:  _pulseAnim,
              checking:   _checking,
              onRetry:    _retry,
            ),
          ),
      ],
    );
  }
}

// ─── Offline Blocker Screen ───────────────────────────────────────────────────

class _OfflineBlocker extends StatelessWidget {
  final Animation<double> pulseAnim;
  final bool checking;
  final VoidCallback onRetry;

  const _OfflineBlocker({
    required this.pulseAnim,
    required this.checking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        // Dark glassmorphic full-screen backdrop
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: [
              Color(0xFF0D001A),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background static noise dots for depth
            const _StaticNoise(),

            // Centred dialog
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _OfflineCard(
                  pulseAnim: pulseAnim,
                  checking:  checking,
                  onRetry:   onRetry,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Offline Card (3D look) ───────────────────────────────────────────────────

class _OfflineCard extends StatelessWidget {
  final Animation<double> pulseAnim;
  final bool checking;
  final VoidCallback onRetry;

  const _OfflineCard({
    required this.pulseAnim,
    required this.checking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Transform.scale(scale: pulseAnim.value, child: child),
      child: Container(
        decoration: BoxDecoration(
          // Deep 3D card with layered gradients
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0A2E),
              Color(0xFF0A0014),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFFF4444).withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            // Red outer glow — danger signal
            BoxShadow(
              color: const Color(0xFFFF0000).withOpacity(0.35),
              blurRadius: 40,
              spreadRadius: 4,
            ),
            // Deep drop shadow for 3D lift
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Pulsing ⚠️ icon with glow ring ──────────────────────────────
            _GlowingWarningIcon(pulseAnim: pulseAnim),

            const SizedBox(height: 20),

            // ── "No Internet Connection!" headline ──────────────────────────
            const Text(
              'No Internet\nConnection!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                height: 1.2,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 14),

            // ── Sub-copy ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Please connect your internet\nto play Tech Tycoon Merge.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Ad requirement note ─────────────────────────────────────────
            const Text(
              'An active connection is required\nfor ads and game progression.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.5),
            ),

            const SizedBox(height: 28),

            // ── Retry button ────────────────────────────────────────────────
            _RetryButton(checking: checking, onRetry: onRetry),

          ],
        ),
      ),
    );
  }
}

// ─── Glowing Warning Icon ─────────────────────────────────────────────────────

class _GlowingWarningIcon extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _GlowingWarningIcon({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: 96 * pulseAnim.value,
              height: 96 * pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4444).withOpacity(0.4 * pulseAnim.value),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
            // Mid ring
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4444).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFFFF4444).withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
            // Icon
            const Text('⚠️', style: TextStyle(fontSize: 40)),
          ],
        );
      },
    );
  }
}

// ─── Retry Button ─────────────────────────────────────────────────────────────

class _RetryButton extends StatelessWidget {
  final bool checking;
  final VoidCallback onRetry;

  const _RetryButton({required this.checking, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: checking
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF4444)],
                ),
          color: checking ? Colors.white12 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: checking
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFFF4444).withOpacity(0.55),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: checking ? null : onRetry,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white24,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: checking
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white54, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Retry / Refresh',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Static Background Noise ──────────────────────────────────────────────────

class _StaticNoise extends StatelessWidget {
  const _StaticNoise();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _NoisePainter(),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Object.hashCode(size) ^ 0xDEADBEEF; // stable across frames
    final paint = Paint();
    for (int i = 0; i < 200; i++) {
      // Deterministic pseudo-random from index
      final x = ((i * 1637 + rng) % 1000) / 1000.0 * size.width;
      final y = ((i * 2741 + rng) % 1000) / 1000.0 * size.height;
      final r = ((i * 317 + rng) % 10) / 10.0 * 1.2 + 0.2;
      final o = ((i * 499 + rng) % 10) / 10.0 * 0.12 + 0.02;
      paint.color = Colors.white.withOpacity(o);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
