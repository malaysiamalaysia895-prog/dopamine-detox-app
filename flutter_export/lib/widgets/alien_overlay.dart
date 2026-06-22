// ============================================================
// alien_overlay.dart — Space Alien Boss Full UI System
// Level 31: Warning → Ships merge → Alien #2 (Standing)
// Level 32: Ships merge → Alien #3 (Smiling)
// Level 33: Ships explode → Alien #1 (Waving) walks out
// AAA 2026 quality animations
// ============================================================

import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../controllers/alien_controller.dart';

// ─── Public Entry Point ───────────────────────────────────────────────────────

class AlienOverlay extends StatelessWidget {
  final AlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  final Offset? Function() getSpawnerCenter;
  final bool isDialogActive;

  const AlienOverlay({
    super.key,
    required this.controller,
    required this.getCellRect,
    required this.getSpawnerCenter,
    this.isDialogActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        if (phase == AlienPhase.idle) return const SizedBox.shrink();
        if (isDialogActive) return const SizedBox.shrink();

        return Stack(
          children: [
            // ── Warning Screen (L31 only) ──────────────────────────────────
            if (phase == AlienPhase.warningEntry)
              _WarningScreen(controller: controller),

            // ── Ship Entry Animation ───────────────────────────────────────
            if (phase == AlienPhase.shipEntry)
              _ShipEntryAnimation(controller: controller, getCellRect: getCellRect),

            // ── Active Alien + Meteors + Laser ────────────────────────────
            if (phase == AlienPhase.active ||
                phase == AlienPhase.laserHit)
              _AlienActiveWidget(
                controller: controller,
                getCellRect: getCellRect,
                getSpawnerCenter: getSpawnerCenter,
              ),

            // ── Win Blast ─────────────────────────────────────────────────
            if (phase == AlienPhase.winBlast)
              _AlienWinBlast(controller: controller),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WARNING SCREEN (Level 31 only)
// ═══════════════════════════════════════════════════════════════════════════════

class _WarningScreen extends StatefulWidget {
  final AlienController controller;
  const _WarningScreen({required this.controller});
  @override
  State<_WarningScreen> createState() => _WarningScreenState();
}

class _WarningScreenState extends State<_WarningScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeIn = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        color: Colors.black.withOpacity(0.93),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated alien silhouette icon ─────────────────────────
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A0040).withOpacity(0.9),
                      border: Border.all(
                          color: const Color(0xFFCC00FF).withOpacity(0.9),
                          width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFCC00FF).withOpacity(0.6),
                            blurRadius: 30,
                            spreadRadius: 5),
                      ],
                    ),
                    child: const Center(
                      child: Text('👾', style: TextStyle(fontSize: 56)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── WARNING Title ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Text(
                  '⚠  ALIEN INVASION  ⚠',
                  style: TextStyle(
                    color: Color.lerp(const Color(0xFFFF4444),
                        const Color(0xFFFF8800), _pulseAnim.value),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                          color: const Color(0xFFFF4444).withOpacity(0.8),
                          blurRadius: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0020).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFCC00FF).withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFCC00FF).withOpacity(0.2),
                        blurRadius: 20),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'ALIEN BOSS — LEVEL 31',
                      style: TextStyle(
                        color:
                            const Color(0xFFCC00FF).withOpacity(0.9),
                        fontSize: 13,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'An alien fleet is descending!\nIt will throw METEOR BLOCKS\nevery 2 seconds onto your grid.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.6),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC00FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFCC00FF)
                                .withOpacity(0.4)),
                      ),
                      child: const Text(
                        '🔫  MERGE ITEMS → LASER FIRES → HITS ALIEN\n'
                        '22 MERGES NEEDED TO DESTROY IT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '⚡ Meteor destroys a block → You lose 3 HP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFFFF8800),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Face the Alien button ──────────────────────────────────
              GestureDetector(
                onTap: widget.controller.dismissWarning,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(const Color(0xFF6600CC),
                              const Color(0xFFCC00FF),
                              _pulseAnim.value)!,
                          const Color(0xFF3300AA),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFCC00FF)
                                .withOpacity(0.6 * _pulseAnim.value),
                            blurRadius: 20,
                            spreadRadius: 2),
                      ],
                    ),
                    child: const Text(
                      '👾  FACE THE ALIEN!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHIP ENTRY ANIMATION
// 4 ships fly in from all 4 edges → converge to center → merge → alien appears
// Level 33: ships explode before merging → alien walks out
// ═══════════════════════════════════════════════════════════════════════════════

class _ShipEntryAnimation extends StatefulWidget {
  final AlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _ShipEntryAnimation({required this.controller, required this.getCellRect});
  @override
  State<_ShipEntryAnimation> createState() => _ShipEntryAnimationState();
}

class _ShipEntryAnimationState extends State<_ShipEntryAnimation>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  late AnimationController _shipCtrl;    // ships flying in
  late AnimationController _blastCtrl;   // mega blast
  late AnimationController _darkCtrl;    // dark pause after blast
  late AnimationController _villainCtrl; // villain full-screen reveal
  late AnimationController _spinCtrl;    // UFO fast spin
  late AnimationController _orbitCtrl;   // orbital wobble
  late AnimationController _dimCtrl;     // cinematic dimmer

  late Animation<double> _shipProgress;
  late Animation<double> _blastFlash;
  late Animation<double> _darkFade;

  bool _shipsArrived = false;
  bool _blastDone    = false;

  final List<Color> _shipColors = [
    const Color(0xFF9B30FF), // purple
    const Color(0xFFFF3030), // red
    const Color(0xFF30AAFF), // blue
    const Color(0xFFFF8800), // orange
  ];

  @override
  void initState() {
    super.initState();
    final isL33 = widget.controller.currentLevel == 33;

    final shipMs    = isL33 ? 2600 : 3200;
    final blastMs   = isL33 ? 700  : 800;
    final pauseMs   = isL33 ? 1300 : 1500;
    final villainMs = isL33 ? 2500 : 2900;

    _shipCtrl    = AnimationController(vsync: this, duration: Duration(milliseconds: shipMs));
    _blastCtrl   = AnimationController(vsync: this, duration: Duration(milliseconds: blastMs));
    _darkCtrl    = AnimationController(vsync: this, duration: Duration(milliseconds: pauseMs));
    _villainCtrl = AnimationController(vsync: this, duration: Duration(milliseconds: villainMs));
    _spinCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..repeat();
    _orbitCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
    _dimCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _shipProgress = CurvedAnimation(parent: _shipCtrl, curve: Curves.easeOut);
    _blastFlash   = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 88),
    ]).animate(_blastCtrl);
    _darkFade = CurvedAnimation(parent: _darkCtrl, curve: Curves.easeInOut);

    _shipCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _shipsArrived = true);
        _spinCtrl.stop();
        Future.delayed(Duration(milliseconds: isL33 ? 0 : 280), () {
          if (!mounted) return;
          _blastCtrl.forward().then((_) {
            if (!mounted) return;
            setState(() => _blastDone = true);
            _darkCtrl.forward().then((_) {
              if (!mounted) return;
              _darkCtrl.reverse();
              _villainCtrl.forward();
            });
          });
        });
      }
    });

    _dimCtrl.forward();
    _shipCtrl.forward();
  }

  @override
  void dispose() {
    _shipCtrl.dispose();
    _blastCtrl.dispose();
    _darkCtrl.dispose();
    _villainCtrl.dispose();
    _spinCtrl.dispose();
    _orbitCtrl.dispose();
    _dimCtrl.dispose();
    super.dispose();
  }

  Offset _boosterDir(int i, Offset start, Offset target) {
    final dx = start.dx - target.dx;
    final dy = start.dy - target.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return Offset.zero;
    return Offset(dx / len, dy / len);
  }

  double _pv(double t, double s, double e) {
    if (t <= s) return 0.0;
    if (t >= e) return 1.0;
    return (t - s) / (e - s);
  }

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final cx      = size.width / 2;
    final firstCell = widget.getCellRect(0, 0);
    final gridTop = firstCell?.top ?? size.height * 0.45;
    final cy      = gridTop - 10.0;

    final starts = [
      Offset(-80, -80),
      Offset(size.width + 80, -80),
      Offset(-80, size.height + 80),
      Offset(size.width + 80, size.height + 80),
    ];

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_shipCtrl, _blastCtrl, _darkCtrl, _villainCtrl, _spinCtrl, _orbitCtrl, _dimCtrl]),
      builder: (_, __) {
        final t      = _shipProgress.value;
        final rv     = _villainCtrl.value;
        final spin   = _spinCtrl.value * math.pi * 2;
        final orbit  = _orbitCtrl.value * math.pi * 2;
        final target = Offset(cx, cy);

        return Stack(
          clipBehavior: Clip.none,
          children: [

            // ── 1. Cinematic dimmer (ramps during ship phase) ────────────
            if (_dimCtrl.value > 0 && !_blastDone)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(_dimCtrl.value * 0.82),
                  ),
                ),
              ),

            // ── 2. SHIPS — orbital spinning approach ─────────────────────
            if (!_shipsArrived)
              ...List.generate(4, (i) {
                final start   = starts[i];
                final booster = _boosterDir(i, start, target);
                final perpX   = -booster.dy;
                final perpY   =  booster.dx;

                // Base path: corner → center with easeOut
                final baseX = cx + (start.dx - cx) * (1 - Curves.easeOut.transform(t));
                final baseY = cy + (start.dy - cy) * (1 - Curves.easeOut.transform(t));
                // Orbital wobble: perpendicular oscillation (decreases as ship arrives)
                final wobble = math.sin(orbit + i * math.pi / 2) * 30 * (1 - t) * (1 - t);
                final dx = baseX + perpX * wobble;
                final dy = baseY + perpY * wobble;
                // Ship self-spin: speeds up as it approaches
                final selfSpin = spin * (1.2 + t * 1.8);

                return Stack(clipBehavior: Clip.none, children: [

                  // ── REAL SMOKE TRAIL (gray, expands, dissipates) ────────
                  ...List.generate(26, (lag) {
                    final lagT = (t - lag * 0.024).clamp(0.0, 1.0);
                    if (lagT <= 0.01) return const SizedBox.shrink();
                    final lagProg = Curves.easeOut.transform(lagT);
                    final lagWobble = math.sin(orbit + i * math.pi / 2 - lag * 0.07)
                        * 30 * (1 - lagT) * (1 - lagT);
                    final lx = cx + (start.dx - cx) * (1 - lagProg) + perpX * lagWobble;
                    final ly = cy + (start.dy - cy) * (1 - lagProg) + perpY * lagWobble;

                    // Puff ages: fresh (lag=0) → old (lag=25)
                    final age = lag / 26.0;
                    // Real smoke: starts dark/dense, expands and lightens
                    final puffSize = (8.0 + age * 36.0).clamp(8.0, 44.0);
                    final opacity  = ((1 - age * 0.85) * 0.65 * math.min(t * 3, 1.0))
                        .clamp(0.0, 1.0);
                    // Color: near-black fresh → mid-gray → light gray old
                    final smokeColor = Color.lerp(
                      const Color(0xFF1A1A1A),
                      const Color(0xFFAAAAAA),
                      age.clamp(0.0, 1.0),
                    )!;
                    // Drift perpendicular (natural turbulence)
                    final drift = (lag % 5 - 2) * 5.0;
                    return Positioned(
                      left: lx + perpX * drift - puffSize / 2,
                      top:  ly + perpY * drift - puffSize / 2,
                      child: IgnorePointer(
                        child: Container(
                          width: puffSize, height: puffSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: smokeColor.withOpacity(opacity),
                          ),
                        ),
                      ),
                    );
                  }),

                  // ── Colored exhaust sparks (engine heat) ────────────────
                  ...List.generate(6, (p) {
                    final sT = (t - p * 0.02).clamp(0.0, 1.0);
                    if (sT <= 0.02) return const SizedBox.shrink();
                    final sP = Curves.easeOut.transform(sT);
                    final sx = cx + (start.dx - cx) * (1 - sP) + booster.dx * 14;
                    final sy = cy + (start.dy - cy) * (1 - sP) + booster.dy * 14;
                    final sOff = (p % 3 - 1) * 5.0;
                    final sFade = (1 - p / 6.0) * 0.9 * t;
                    return Positioned(
                      left: sx + perpX * sOff - 3,
                      top:  sy + perpY * sOff - 3,
                      child: IgnorePointer(
                        child: Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(_shipColors[i],
                                const Color(0xFFFF8800), 0.5)!
                                .withOpacity(sFade.clamp(0.0, 1.0)),
                            boxShadow: [
                              BoxShadow(
                                color: _shipColors[i].withOpacity(0.8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // ── Booster flame (orange-hot exhaust) ──────────────────
                  Positioned(
                    left: dx + booster.dx * 22 - 18,
                    top:  dy + booster.dy * 14 - 18,
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: const Size(36, 36),
                        painter: _BoosterFlamePainter(
                          color: Color.lerp(
                              _shipColors[i], const Color(0xFFFF6600), 0.65)!,
                          direction: booster,
                          intensity: t,
                        ),
                      ),
                    ),
                  ),

                  // ── UFO with orbital tilt ────────────────────────────────
                  Positioned(
                    left: dx - 45,
                    top:  dy - 28,
                    child: Transform.rotate(
                      angle: math.sin(orbit + i * math.pi / 2) * 0.25 * (1 - t),
                      child: CustomPaint(
                        size: const Size(90, 56),
                        painter: _UfoPainter(
                          color: _shipColors[i],
                          glowIntensity: t,
                          rotation: selfSpin,
                        ),
                      ),
                    ),
                  ),
                ]);
              }),

            // ── 3. Ships converged glow at center (pre-blast hover) ──────
            if (_shipsArrived && !_blastDone && _blastCtrl.value < 0.04)
              Positioned(
                left: cx - 70, top: cy - 70,
                child: IgnorePointer(
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white.withOpacity(0.95),
                        const Color(0xFFCC00FF).withOpacity(0.7),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ),

            // ── 4. MEGA BLAST ─────────────────────────────────────────────
            if (_blastCtrl.value > 0 && !_blastDone) ...[
              IgnorePointer(
                child: Container(
                  color: Color.lerp(
                    Colors.white,
                    const Color(0xFFCC00FF),
                    (1 - _blastFlash.value).clamp(0.0, 1.0),
                  )!.withOpacity(_blastFlash.value * 0.98),
                ),
              ),
              ...List.generate(48, (i) {
                final angle  = (i / 48.0) * math.pi * 2;
                final prog   = (1 - _blastFlash.value).clamp(0.0, 1.0);
                final maxDst = (i % 5 == 0) ? size.height * 1.2
                    : (i % 5 == 1) ? size.height * 0.8
                    : (i % 5 == 2) ? size.height * 0.55
                    : (i % 5 == 3) ? size.height * 0.35
                    : size.height * 0.22;
                final dist   = prog * maxDst;
                final px     = cx + math.cos(angle) * dist;
                final py     = cy + math.sin(angle) * dist;
                final fade   = (1 - prog * 0.88).clamp(0.0, 1.0) * _blastFlash.value;
                final sz     = 5.0 + (i % 9) * 3.5;
                final c      = i % 6 == 0 ? Colors.white
                    : i % 6 == 1 ? const Color(0xFFCC00FF)
                    : _shipColors[i % 4];
                return Positioned(
                  left: px - sz / 2, top: py - sz / 2,
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Container(
                      width: sz, height: sz,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        boxShadow: [BoxShadow(color: c, blurRadius: sz * 1.3)],
                      ),
                    ),
                  ),
                );
              }),
            ],

            // ── 5. DARK PAUSE — energy building beneath surface ───────────
            if (_darkCtrl.value > 0.02 && _villainCtrl.value < 0.05)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(
                        (_darkFade.value).clamp(0.0, 1.0)),
                  ),
                ),
              ),

            // Energy orb at center during pause
            if (_darkCtrl.value > 0.35 && _villainCtrl.value < 0.05)
              Positioned(
                left: cx - 90, top: cy - 90,
                child: IgnorePointer(
                  child: Container(
                    width: 180, height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFCC00FF).withOpacity(
                            0.5 * _darkCtrl.value),
                        const Color(0xFFFF2266).withOpacity(
                            0.25 * _darkCtrl.value),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ),

            // ── 6. VILLAIN FULL-SCREEN REVEAL ─────────────────────────────
            if (rv > 0.01) ...[
              // Villain background aura (massive glow)
              if (rv < 0.82)
                Builder(builder: (_) {
                  final auraRadius = 180 + 60 * math.sin(rv * math.pi);
                  return Positioned(
                    left: cx - auraRadius,
                    top: size.height / 2 - auraRadius - 50,
                    child: IgnorePointer(
                      child: Container(
                        width: auraRadius * 2,
                        height: auraRadius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            const Color(0xFFCC00FF)
                                .withOpacity(0.40 * math.min(rv * 8, 1.0)),
                            const Color(0xFFFF2266)
                                .withOpacity(0.20 * math.min(rv * 8, 1.0)),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  );
                }),

              // ── Alien body with villain action sequence ──────────────
              Builder(builder: (_) {
                final finalY  = cy - 68.0;
                final centerY = size.height / 2 - 70.0;

                // Scale: 0→3.8 (0.00-0.13), hold (0.13-0.76), 3.8→1.0 (0.76-1.00)
                final growFrac   = _pv(rv, 0.00, 0.13);
                final shrinkFrac = _pv(rv, 0.76, 1.00);
                final overallScale = shrinkFrac > 0
                    ? 3.8 - 2.8 * Curves.easeIn.transform(shrinkFrac)
                    : 3.8 * Curves.easeOut.transform(growFrac);

                // Position: screen center → game position during shrink
                final posY = shrinkFrac > 0
                    ? centerY + (finalY - centerY)
                        * Curves.easeIn.transform(shrinkFrac)
                    : centerY;

                // Villain action params from timeline
                final eyePhase  = math.sin(math.pi * _pv(rv, 0.11, 0.42));
                final armPhase  = math.sin(math.pi * _pv(rv, 0.30, 0.56));
                final legPhase  = math.sin(math.pi * _pv(rv, 0.46, 0.64));
                final expl      = math.sin(math.pi * _pv(rv, 0.60, 0.80));
                final fadeIn    = _pv(rv, 0.00, 0.16).clamp(0.0, 1.0);

                return Positioned(
                  left: 0, right: 0,
                  top: posY,
                  child: Opacity(
                    opacity: fadeIn,
                    child: Transform.scale(
                      scale: overallScale.clamp(0.05, 4.2),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(150, 140),
                          painter: _AlienBodyPainter(
                            alienType: widget.controller.alienType,
                            isThrowing: false,
                            throwDirection: Offset.zero,
                            isHurt: false,
                            eyeBlinkValue: 0,
                            armSwingValue: 0,
                            villainEyeScale:  eyePhase,
                            villainArmSpread: armPhase,
                            villainLegSpread: legPhase,
                            villainExplode:   expl,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // ── Boss title (appears at end of villain sequence) ──────
              if (rv > 0.80)
                Builder(builder: (_) {
                  final finalY = cy - 68.0;
                  final titleAlpha = _pv(rv, 0.80, 1.0);
                  return Positioned(
                    top: finalY - 105,
                    left: 0, right: 0,
                    child: Opacity(
                      opacity: titleAlpha.clamp(0.0, 1.0),
                      child: Column(children: [
                        Text(
                          widget.controller.currentLevel == 33
                              ? '☠ BOSS ALIEN UNLEASHED ☠'
                              : widget.controller.alienType == AlienType.standing
                                  ? '👾 ALIEN BOSS ACTIVATED 👾'
                                  : '👾 ALIEN BOSS ONLINE 👾',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFF2266),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            shadows: [
                              Shadow(color: Color(0xFFFF2266), blurRadius: 24),
                              Shadow(color: Colors.white, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'MERGE TILES TO FIRE LASER  •  DESTROY THE ALIEN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ]),
                    ),
                  );
                }),
            ],
          ],
        );
      },
    );
  }
}

// ─── Booster Flame Painter ───────────────────────────────────────────────────
// Paints an engine exhaust cone behind a ship in direction [direction]
class _BoosterFlamePainter extends CustomPainter {
  final Color color;
  final Offset direction; // normalized unit vector pointing AWAY from target
  final double intensity; // 0..1

  const _BoosterFlamePainter(
      {required this.color, required this.direction, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity < 0.05) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Perpendicular to direction
    final perpX = -direction.dy;
    final perpY = direction.dx;
    final len = 22.0 * intensity;
    final wid = 10.0 * intensity;
    final tip = Offset(cx + direction.dx * len, cy + direction.dy * len);
    final l   = Offset(cx + perpX * wid, cy + perpY * wid);
    final r   = Offset(cx - perpX * wid, cy - perpY * wid);
    final path = Path()..moveTo(l.dx, l.dy)..lineTo(tip.dx, tip.dy)..lineTo(r.dx, r.dy)..close();
    // Outer flame: color-tinted
    canvas.drawPath(path,
        Paint()..shader = ui.Gradient.linear(
            Offset(cx, cy), tip,
            [color.withOpacity(0.9 * intensity), Colors.transparent]));
    // Inner core: white-hot
    final innerPath = Path()
      ..moveTo(cx + perpX * wid * 0.4, cy + perpY * wid * 0.4)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(cx - perpX * wid * 0.4, cy - perpY * wid * 0.4)
      ..close();
    canvas.drawPath(innerPath,
        Paint()..shader = ui.Gradient.linear(
            Offset(cx, cy), tip,
            [Colors.white.withOpacity(0.85 * intensity), Colors.transparent]));
  }

  @override
  bool shouldRepaint(_BoosterFlamePainter old) =>
      old.intensity != intensity || old.direction != direction;
}

// ─── Shockwave Rings Painter ─────────────────────────────────────────────────
// 4 expanding rings when ships converge
class _ShockwavePainter extends CustomPainter {
  final Offset center;
  final double progress; // 0..1

  const _ShockwavePainter({required this.center, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (int ring = 0; ring < 5; ring++) {
      final delay = ring * 0.14;
      final p = (progress - delay).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final radius  = p * 260;
      final opacity = (1.0 - p) * 0.85;
      final stroke  = (4.0 - ring * 0.5).clamp(1.0, 4.0);
      final ringColor = ring % 2 == 0
          ? const Color(0xFFCC00FF)
          : const Color(0xFFFF6600);
      canvas.drawCircle(center, radius,
          Paint()
            ..color = ringColor.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke);
    }
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALIEN ACTIVE WIDGET
// Alien body + health bar + meteor throws + laser missile
// ═══════════════════════════════════════════════════════════════════════════════

class _AlienActiveWidget extends StatefulWidget {
  final AlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  final Offset? Function() getSpawnerCenter;

  const _AlienActiveWidget({
    required this.controller,
    required this.getCellRect,
    required this.getSpawnerCenter,
  });

  @override
  State<_AlienActiveWidget> createState() => _AlienActiveWidgetState();
}

class _AlienActiveWidgetState extends State<_AlienActiveWidget>
    with TickerProviderStateMixin {
  late AnimationController _bodyBob;
  late AnimationController _eyeBlink;
  late AnimationController _hurtFlash;
  late Animation<double> _bobAnim;
  late Animation<double> _hurtAnim;

  // Particle system controller
  late AnimationController _particleCtrl;

  // Continuous idle animations
  late AnimationController _armSwing;
  late Animation<double> _armSwingAnim;

  // Active meteor animations
  final Map<double, AnimationController> _meteorControllers = {};
  final Map<double, Animation<double>> _meteorAnims = {};

  // Laser animation
  AnimationController? _laserCtrl;
  Animation<double>? _laserAnim;
  AlienLaserHit? _currentLaserHit;
  double _lastProcessedHitId = -1; // ← FIX: prevents re-trigger after completion

  // Throwing arm direction
  Offset _throwDir = Offset.zero;
  bool _isThrowing = false;
  Timer? _throwResetTimer;

  @override
  void initState() {
    super.initState();
    _bodyBob = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _armSwing = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _armSwingAnim = Tween<double>(begin: -1.0, end: 1.0)
        .animate(CurvedAnimation(parent: _armSwing, curve: Curves.easeInOut));
    _eyeBlink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _hurtFlash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bobAnim = Tween<double>(begin: -4.0, end: 4.0)
        .animate(CurvedAnimation(parent: _bodyBob, curve: Curves.easeInOut));
    _hurtAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_hurtFlash);
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _scheduleEyeBlink();
    widget.controller.addListener(_onControllerChanged);
  }

  void _scheduleEyeBlink() {
    Future.delayed(Duration(milliseconds: 900 + math.Random().nextInt(1200)),
        () {
      if (!mounted) return;
      _eyeBlink.forward().then((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 60), () {
          if (!mounted) return;
          _eyeBlink.reverse().then((_) { if (mounted) _scheduleEyeBlink(); });
        });
      });
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;

    // Handle new meteors
    for (final meteor in widget.controller.activeMeteors) {
      if (!_meteorControllers.containsKey(meteor.id)) {
        _addMeteorAnimation(meteor);
      }
    }

    // Handle laser hit — use id to prevent re-trigger after completion
    final hit = widget.controller.lastLaserHit;
    if (hit != null && hit.id != _lastProcessedHitId) {
      _lastProcessedHitId = hit.id;
      _currentLaserHit = hit;
      _triggerLaser(hit);
    }

    // Handle hurt flash when laser hits
    if (widget.controller.phase == AlienPhase.laserHit) {
      _hurtFlash.forward(from: 0.0);
    }

    setState(() {});
  }

  void _addMeteorAnimation(AlienMeteorThrow meteor) {
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeIn);

    _meteorControllers[meteor.id] = ctrl;
    _meteorAnims[meteor.id] = anim;

    // Update throw direction for arm animation
    final cellRect = widget.getCellRect(meteor.col, meteor.row);
    if (cellRect != null && mounted) {
      final firstCell = widget.getCellRect(0, 0);
      final size = MediaQuery.of(context).size;
      final gridTop = firstCell?.top ?? size.height * 0.38;
      final alienCenter = Offset(size.width / 2, gridTop - 30);
      final cellCenter = cellRect.center;
      final rawDir = cellCenter - alienCenter;
      final len = rawDir.distance;
      setState(() {
        _throwDir = len > 0 ? rawDir / len : const Offset(0, 1);
        _isThrowing = true;
      });
      _throwResetTimer?.cancel();
      _throwResetTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _isThrowing = false);
      });
    }

    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _meteorControllers.remove(meteor.id);
        _meteorAnims.remove(meteor.id);
        ctrl.dispose();
        if (mounted) setState(() {});
      }
    });
  }

  void _triggerLaser(AlienLaserHit hit) {
    _laserCtrl?.dispose();
    _laserCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _laserAnim =
        CurvedAnimation(parent: _laserCtrl!, curve: Curves.easeIn);
    if (mounted) setState(() {});
    _laserCtrl!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() { _currentLaserHit = null; });
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _bodyBob.dispose();
    _armSwing.dispose();
    _eyeBlink.dispose();
    _hurtFlash.dispose();
    _particleCtrl.dispose();
    _throwResetTimer?.cancel();
    _laserCtrl?.dispose();
    for (final ctrl in _meteorControllers.values) ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final firstCell = widget.getCellRect(0, 0);
    final gridTop = firstCell?.top ?? size.height * 0.45;
    // cy = gridTop - 10: head peeks just above game board top border,
    // body occupies the top strip of row 0. Board cells behind alien.
    final cy = gridTop - 10.0;
    final isHurt = widget.controller.phase == AlienPhase.laserHit;

    return AnimatedBuilder(
      animation: Listenable.merge([_bodyBob, _hurtFlash, _armSwing]),
      builder: (_, __) {
        final bobY = _bobAnim.value;
        final hurtT = _hurtAnim.value;
        final swing = _armSwingAnim.value;

        return Stack(
          children: [
            // ── Hurt flash — subtle green tint ONLY inside game board ──
            if (hurtT > 0)
              Positioned(
                top: gridTop, left: 0, right: 0, bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    color: const Color(0xFF00FFCC).withOpacity(hurtT * 0.18),
                  ),
                ),
              ),

            // ── HP bar — ABOVE alien head (so it's not covered by body) ───
            Positioned(
              // cy - 68 is alien body top; minus 26 for bar above head
              top: cy - 94 + bobY,
              left: 8, right: 8,
              child: _AlienHealthBar(
                health: widget.controller.alienHealth,
                mergesDone: widget.controller.mergesDone,
              ),
            ),

            // ── Alien ambient particle field (energy orbs + sparks) ────
            Positioned(
              top: cy - 130 + bobY,
              left: 0, right: 0,
              child: SizedBox(
                height: 220,
                child: AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _AlienParticlePainter(
                      progress: _particleCtrl.value,
                      alienHealth: widget.controller.alienHealth,
                      isHurt: isHurt,
                    ),
                  ),
                ),
              ),
            ),

            // ── Alien body — head above border, body in top of row 0 ───
            Positioned(
              top: cy - 68 + bobY + (isHurt ? hurtT * 3 : 0),
              left: 0, right: 0,
              child: Center(
                child: CustomPaint(
                  size: const Size(150, 140),
                  painter: _AlienBodyPainter(
                    alienType: widget.controller.alienType,
                    isThrowing: _isThrowing,
                    throwDirection: _throwDir,
                    isHurt: isHurt,
                    eyeBlinkValue: _eyeBlink.value,
                    armSwingValue: swing,
                  ),
                ),
              ),
            ),

            // ── Meteor projectiles ─────────────────────────────────────
            ...widget.controller.activeMeteors.map((meteor) {
              final anim = _meteorAnims[meteor.id];
              if (anim == null) return const SizedBox.shrink();
              final cellRect = widget.getCellRect(meteor.col, meteor.row);
              if (cellRect == null) return const SizedBox.shrink();
              return _MeteorProjectile(
                startX: size.width / 2,
                startY: cy + 40, // from alien arm tip
                targetRect: cellRect,
                progress: anim,
              );
            }),

            // ── Laser missile (spawner → alien) — only on merge hit ────
            if (_laserAnim != null && _currentLaserHit != null)
              AnimatedBuilder(
                animation: _laserAnim!,
                builder: (_, __) {
                  final spawnerCenter = widget.getSpawnerCenter();
                  if (spawnerCenter == null) return const SizedBox.shrink();
                  return _LaserMissile(
                    startOffset: spawnerCenter,
                    endOffset: Offset(size.width / 2, cy),
                    progress: _laserAnim!.value,
                    damage: _currentLaserHit!.damage,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALIEN BODY WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

// _AlienBodyWidget — used by ship entry animation (no health bar here)
class _AlienBodyWidget extends StatelessWidget {
  final AlienType alienType;
  final bool isThrowing;
  final Offset throwDirection;
  final bool isHurt;
  final double eyeBlinkValue;

  const _AlienBodyWidget({
    required this.alienType,
    this.isThrowing = false,
    this.throwDirection = Offset.zero,
    this.isHurt = false,
    this.eyeBlinkValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: const Size(150, 140),
        painter: _AlienBodyPainter(
          alienType: alienType,
          isThrowing: isThrowing,
          throwDirection: throwDirection,
          isHurt: isHurt,
          eyeBlinkValue: eyeBlinkValue,
        ),
      ),
    );
  }
}

// ─── Alien Body Painter ───────────────────────────────────────────────────────

class _AlienBodyPainter extends CustomPainter {
  final AlienType alienType;
  final bool isThrowing;
  final Offset throwDirection;
  final bool isHurt;
  final double eyeBlinkValue;
  final double armSwingValue;    // -1..1 continuous swing
  final double villainEyeScale;  // 0..1 → eyes bulge up to 3×
  final double villainArmSpread; // 0..1 → arms sweep dramatically wide
  final double villainLegSpread; // 0..1 → legs kick out wide
  final double villainExplode;   // 0..1 → body parts fly apart then rejoin

  const _AlienBodyPainter({
    required this.alienType,
    required this.isThrowing,
    required this.throwDirection,
    required this.isHurt,
    required this.eyeBlinkValue,
    this.armSwingValue    = 0.0,
    this.villainEyeScale  = 0.0,
    this.villainArmSpread = 0.0,
    this.villainLegSpread = 0.0,
    this.villainExplode   = 0.0,
  });

  // Canvas: 150 × 140
  // Layout (top→bottom): antenna(4), helmet(10-90), head(15-85),
  //   collar(84), torso(84-112), arms(88-116), legs(110-130), boots(128-140)

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;   // 75
    final h  = size.height;       // 140
    final ht = isHurt ? 0.6 : 0.0;

    final skinColor  = Color.lerp(const Color(0xFF7BC800), const Color(0xFF00FFCC), ht)!;
    final suitColor  = Color.lerp(const Color(0xFFFF6B00), const Color(0xFF00FFCC), ht)!;
    final darkSuit   = Color.lerp(const Color(0xFFCC4400), const Color(0xFF009988), ht)!;
    final legColor   = Color.lerp(const Color(0xFF2255CC), const Color(0xFF00DDAA), ht)!;
    final bootColor  = Color.lerp(const Color(0xFF111133), const Color(0xFF004466), ht)!;

    // ── Purple glow behind alien ─────────────────────────────────────────
    final glowR = villainEyeScale > 0.1
        ? const Color(0xFFFF1111) : const Color(0xFFCC00FF);
    canvas.drawCircle(Offset(cx, h * 0.52), 62 + villainExplode * 20,
        Paint()
          ..color = glowR.withOpacity(0.12 + villainEyeScale * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));

    // ── VILLAIN EXPLODE offsets for body sections ─────────────────────────
    // Each part flies away from the torso pivot when villainExplode > 0
    final exL = villainExplode;     // shorthand

    // ── LEGS ─────────────────────────────────────────────────────────────
    final legSwingL = armSwingValue * 0.28;
    final legSwingR = -armSwingValue * 0.28;
    // Villain kick: legs spread outward
    final villainKickL = -villainLegSpread * 0.75;
    final villainKickR =  villainLegSpread * 0.75;
    // Explode: legs fly down-outward
    final legExOffLX = exL * -38;
    final legExOffLY = exL * 48;
    final legExOffRX = exL *  38;
    final legExOffRY = exL * 48;

    canvas.save();
    canvas.translate(cx - 18 + legExOffLX, h * 0.78 + legExOffLY);
    canvas.rotate(legSwingL + villainKickL);
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, 0, 20, 22),
        const Radius.circular(10)), Paint()..color = legColor);
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, 18, 28, 14),
        const Radius.circular(7)), Paint()..color = bootColor);
    canvas.restore();

    canvas.save();
    canvas.translate(cx + 18 + legExOffRX, h * 0.78 + legExOffRY);
    canvas.rotate(legSwingR + villainKickR);
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, 0, 20, 22),
        const Radius.circular(10)), Paint()..color = legColor);
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, 18, 28, 14),
        const Radius.circular(7)), Paint()..color = bootColor);
    canvas.restore();

    // ── TORSO (stays as explode pivot) ───────────────────────────────────
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 32, h * 0.60, 64, h * 0.20),
        const Radius.circular(14)),
        Paint()..shader = ui.Gradient.linear(
          Offset(cx - 32, h * 0.60), Offset(cx + 32, h * 0.80),
          [suitColor, darkSuit]));

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 26, h * 0.595, 52, 9),
        const Radius.circular(5)),
        Paint()..color = Colors.white.withOpacity(0.55));

    canvas.drawCircle(Offset(cx, h * 0.69),
        8, Paint()..color = const Color(0xFF00FFCC).withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(cx, h * 0.69), 4, Paint()..color = Colors.white);

    // ── ARMS (with explode offsets) ───────────────────────────────────────
    _drawArms(canvas, cx, h, suitColor, skinColor, ht, exL);

    // ── HEAD (with explode offset: flies upward) ──────────────────────────
    final headExOff = exL * -45;
    canvas.save();
    canvas.translate(0, headExOff);

    canvas.drawCircle(Offset(cx, h * 0.37),
        38,
        Paint()..shader = ui.Gradient.radial(
          Offset(cx - 10, h * 0.28), 24,
          [skinColor, skinColor.withOpacity(0.75)]));

    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.36), width: 94, height: 96),
        Paint()..color = Colors.white.withOpacity(0.04));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.36), width: 94, height: 96),
        Paint()
          ..color = Colors.white.withOpacity(0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    final shinePath = Path()
      ..addArc(
          Rect.fromCenter(center: Offset(cx, h * 0.33), width: 70, height: 64),
          -2.4, 1.1);
    canvas.drawPath(shinePath,
        Paint()
          ..color = Colors.white.withOpacity(0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round);

    _drawEyes(canvas, cx, h, ht);

    // ── ANTENNA ──────────────────────────────────────────────────────────
    canvas.drawLine(Offset(cx, h * 0.09), Offset(cx, h * 0.01),
        Paint()
          ..color = Colors.white.withOpacity(0.75)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, h * 0.01), 5,
        Paint()..color = const Color(0xFFCC00FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(cx, h * 0.01), 3, Paint()..color = Colors.white);

    canvas.restore(); // end head explode group
  }

  void _drawArms(Canvas canvas, double cx, double h,
      Color suitColor, Color skinColor, double ht, [double exL = 0.0]) {
    final handColor = Color.lerp(skinColor, const Color(0xFF00FFCC), ht)!;
    final armPaint = Paint()..color = suitColor;

    // Villain arm spread: arms fly wide horizontally + explode offset
    final villainSpreadL = villainArmSpread * (-math.pi * 0.55);
    final villainSpreadR = villainArmSpread * (math.pi * 0.55);
    final armExOffLX = exL * -60;
    final armExOffRX = exL * 60;
    final armExOffY  = exL * -18;

    if (isThrowing) {
      canvas.save();
      canvas.translate(cx - 32 + armExOffLX, h * 0.62 + armExOffY);
      canvas.rotate(-0.18 + armSwingValue * 0.22 + villainSpreadL);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, 0, 18, 30), const Radius.circular(9)),
          armPaint);
      canvas.restore();

      final throwAngle = math.atan2(throwDirection.dy, throwDirection.dx);
      canvas.save();
      canvas.translate(cx + 32 + armExOffRX, h * 0.635 + armExOffY);
      canvas.rotate(throwAngle - math.pi / 6 + villainSpreadR);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, 0, 18, 40), const Radius.circular(9)),
          armPaint);
      canvas.drawCircle(const Offset(0, 42), 11,
          Paint()..color = const Color(0xFFCC00FF).withOpacity(0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawCircle(const Offset(0, 42), 7,
          Paint()..color = handColor);
      canvas.restore();

    } else if (alienType == AlienType.waving) {
      canvas.save();
      canvas.translate(cx - 32 + armExOffLX, h * 0.60 + armExOffY);
      canvas.rotate(-math.pi * 0.55 + armSwingValue * 0.18 + villainSpreadL);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, -38, 18, 40), const Radius.circular(9)),
          armPaint);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -40), width: 22, height: 16),
          Paint()..color = handColor);
      for (int fi = 0; fi < 3; fi++) {
        canvas.drawLine(Offset(-5.0 + fi * 5, -38), Offset(-5.0 + fi * 5, -48),
            Paint()..color = skinColor.withOpacity(0.65)
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round);
      }
      canvas.restore();
      canvas.save();
      canvas.translate(cx + 32 + armExOffRX, h * 0.62 + armExOffY);
      canvas.rotate(0.18 - armSwingValue * 0.22 + villainSpreadR);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 18, 30), const Radius.circular(9)),
          armPaint);
      canvas.restore();

    } else {
      canvas.save();
      canvas.translate(cx - 32 + armExOffLX, h * 0.62 + armExOffY);
      canvas.rotate(-0.18 + armSwingValue * 0.32 + villainSpreadL);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, 0, 18, 30), const Radius.circular(9)),
          armPaint);
      canvas.drawCircle(const Offset(-9, 31), 7,
          Paint()..color = handColor);
      canvas.restore();

      canvas.save();
      canvas.translate(cx + 32 + armExOffRX, h * 0.62 + armExOffY);
      canvas.rotate(0.18 - armSwingValue * 0.32 + villainSpreadR);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 18, 30), const Radius.circular(9)),
          armPaint);
      // Right hand
      canvas.drawCircle(const Offset(9, 31), 7,
          Paint()..color = handColor);
      canvas.restore();
    }
  }

  void _drawEyes(Canvas canvas, double cx, double h, double ht) {
    // Villain eye scale: normal (0) → 3× bulging red (1)
    final eyeBonus = 1.0 + villainEyeScale * 2.0;
    final eyeR  = 13.5 * eyeBonus;
    final eyeY  = h * 0.34;
    final eyeLX = cx - 19.0 * eyeBonus;
    final eyeRX = cx + 19.0 * eyeBonus;

    final blinkScale = (1.0 - eyeBlinkValue * 0.92).clamp(0.05, 1.0);
    final eyeH = eyeR * 2 * blinkScale;

    // Villain red glow behind each eye
    if (villainEyeScale > 0.05) {
      final glowRadius = eyeR * 2.2;
      for (final ex in [eyeLX, eyeRX]) {
        canvas.drawCircle(Offset(ex, eyeY), glowRadius,
            Paint()
              ..color = const Color(0xFFFF0000).withOpacity(0.45 * villainEyeScale)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      }
    }

    // Angry villain eyebrows (thick, angled inward)
    if (villainEyeScale > 0.15) {
      final browAngle = villainEyeScale * 0.4;
      final browPaint = Paint()
        ..color = const Color(0xFF2A1000).withOpacity(0.85 + villainEyeScale * 0.15)
        ..strokeWidth = 3.5 + villainEyeScale * 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      // Left brow: descends toward center (angry)
      canvas.drawLine(
          Offset(eyeLX - eyeR * 0.8, eyeY - eyeR - 4),
          Offset(eyeLX + eyeR * 0.5, eyeY - eyeR + 3 + browAngle * 8),
          browPaint);
      // Right brow: mirror
      canvas.drawLine(
          Offset(eyeRX + eyeR * 0.8, eyeY - eyeR - 4),
          Offset(eyeRX - eyeR * 0.5, eyeY - eyeR + 3 + browAngle * 8),
          browPaint);
    }

    // White sclera (enlarged during villain)
    final scleraColor = isHurt ? const Color(0xFFAAFFEE) : Colors.white;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(eyeLX, eyeY), width: eyeR * 2, height: eyeH),
        Paint()..color = scleraColor);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(eyeRX, eyeY), width: eyeR * 2, height: eyeH),
        Paint()..color = scleraColor);

    if (blinkScale > 0.15) {
      // Iris: villain red when eyeScale > 0, otherwise normal
      final irisColor = villainEyeScale > 0.1
          ? Color.lerp(const Color(0xFF4A2800), const Color(0xFFDD0000), villainEyeScale)!
          : isHurt ? const Color(0xFFCC00FF) : const Color(0xFF4A2800);
      final irisH = eyeH * 0.68;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeLX + (isHurt ? 2 : 0), eyeY),
              width: eyeR * 1.3, height: irisH),
          Paint()..color = irisColor);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeRX - (isHurt ? 2 : 0), eyeY),
              width: eyeR * 1.3, height: irisH),
          Paint()..color = irisColor);

      final pupilH = irisH * 0.55;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeLX, eyeY),
              width: eyeR * 0.7, height: pupilH),
          Paint()..color = Colors.black87);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeRX, eyeY),
              width: eyeR * 0.7, height: pupilH),
          Paint()..color = Colors.black87);

      if (blinkScale > 0.3) {
        canvas.drawCircle(
            Offset(eyeLX + eyeR * 0.35, eyeY - eyeH * 0.28), 2.5 * eyeBonus,
            Paint()..color = Colors.white.withOpacity(0.9));
        canvas.drawCircle(
            Offset(eyeRX + eyeR * 0.35, eyeY - eyeH * 0.28), 2.5 * eyeBonus,
            Paint()..color = Colors.white.withOpacity(0.9));
      }
    }

    // Eye glow when hurt or villain
    if (isHurt || villainEyeScale > 0.05) {
      final gc = villainEyeScale > 0.05
          ? Color.lerp(const Color(0xFFCC00FF), const Color(0xFFFF0000), villainEyeScale)!
          : const Color(0xFFCC00FF);
      for (final ex in [eyeLX, eyeRX]) {
        canvas.drawCircle(Offset(ex, eyeY), eyeR * 1.2,
            Paint()..color = gc.withOpacity(
                (isHurt ? 0.35 : 0) + villainEyeScale * 0.50)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }
    }

    // Mouth: villain scowl when eyeScale > 0, else normal
    final mouthY = h * 0.475;
    if (villainEyeScale > 0.2) {
      // Villain grimace (inverted smile — frown)
      final mp = Path()
        ..moveTo(cx - 14, mouthY + 6)
        ..quadraticBezierTo(cx, mouthY - 8, cx + 14, mouthY + 6);
      canvas.drawPath(mp,
          Paint()
            ..color = const Color(0xFF2A1000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round);
    } else if (alienType == AlienType.smiling || isHurt) {
      final mp = Path()
        ..moveTo(cx - 14, mouthY - 2)
        ..quadraticBezierTo(cx, mouthY + 10, cx + 14, mouthY - 2);
      canvas.drawPath(mp,
          Paint()
            ..color = const Color(0xFF2A1000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round);
    } else {
      canvas.drawLine(Offset(cx - 12, mouthY), Offset(cx + 12, mouthY),
          Paint()
            ..color = const Color(0xFF2A1000)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_AlienBodyPainter old) =>
      old.isThrowing       != isThrowing       ||
      old.isHurt           != isHurt            ||
      old.eyeBlinkValue    != eyeBlinkValue     ||
      old.throwDirection   != throwDirection    ||
      old.armSwingValue    != armSwingValue     ||
      old.villainEyeScale  != villainEyeScale   ||
      old.villainArmSpread != villainArmSpread  ||
      old.villainLegSpread != villainLegSpread  ||
      old.villainExplode   != villainExplode;
}

// ─── Alien Health Bar (Professional Boss-Style) ───────────────────────────────

class _AlienHealthBar extends StatefulWidget {
  final int health;
  final int mergesDone;
  const _AlienHealthBar({required this.health, required this.mergesDone});

  @override
  State<_AlienHealthBar> createState() => _AlienHealthBarState();
}

class _AlienHealthBarState extends State<_AlienHealthBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hpFrac = (widget.health / 100.0).clamp(0.0, 1.0);
    final isLowHp = hpFrac < 0.3;
    final isMidHp = hpFrac < 0.6;

    final Color barColorHigh = const Color(0xFF00FF88);
    final Color barColorMid  = const Color(0xFFFFD700);
    final Color barColorLow  = const Color(0xFFFF3344);
    final Color barColor = isLowHp
        ? barColorLow
        : isMidHp
            ? Color.lerp(barColorLow, barColorMid, (hpFrac - 0.3) / 0.3)!
            : Color.lerp(barColorMid, barColorHigh, (hpFrac - 0.6) / 0.4)!;

    const Color accentPurple = Color(0xFFCC00FF);
    const int segments = 10;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        final glowOpacity = isLowHp ? _pulseAnim.value : 0.55;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.black.withOpacity(0.72),
            border: Border.all(
              color: isLowHp
                  ? barColorLow.withOpacity(_pulseAnim.value)
                  : accentPurple.withOpacity(0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isLowHp ? barColorLow : accentPurple)
                    .withOpacity(glowOpacity * 0.6),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ────────────────────────────────────────────
              Row(
                children: [
                  // Boss icon with pulse glow
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentPurple.withOpacity(0.18),
                      border: Border.all(
                        color: accentPurple.withOpacity(0.7),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentPurple.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('👾', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALIEN BOSS',
                        style: TextStyle(
                          color: accentPurple,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                      Text(
                        'SPACE INVADER',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 6,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // HP numeric display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: barColor.withOpacity(0.15),
                      border: Border.all(
                        color: barColor.withOpacity(0.7),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${widget.health} / 100',
                      style: TextStyle(
                        color: barColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        shadows: [Shadow(color: barColor, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),

              // ── Segmented HP bar ──────────────────────────────────────
              LayoutBuilder(builder: (_, constraints) {
                final totalW = constraints.maxWidth;
                final gap = 2.0;
                final segW = (totalW - gap * (segments - 1)) / segments;
                final filledSegs = (hpFrac * segments).ceil();

                return Row(
                  children: List.generate(segments, (i) {
                    final filled = i < filledSegs;
                    final isLastFilled = i == filledSegs - 1;
                    final partialFill = isLastFilled
                        ? (hpFrac * segments) - i
                        : filled
                            ? 1.0
                            : 0.0;
                    final segColor = filled ? barColor : Colors.white12;
                    return Container(
                      width: segW,
                      height: 14,
                      margin: EdgeInsets.only(right: i < segments - 1 ? gap : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withOpacity(0.5),
                        border: Border.all(
                          color: filled
                              ? barColor.withOpacity(0.6)
                              : Colors.white12,
                          width: 0.8,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.5),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: partialFill.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    segColor.withOpacity(0.9),
                                    segColor,
                                  ],
                                ),
                                boxShadow: filled
                                    ? [BoxShadow(color: barColor.withOpacity(0.9), blurRadius: 6)]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),

              const SizedBox(height: 5),

              // ── Merge progress + warning label ────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.merge_type,
                          size: 9,
                          color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.mergesDone} / 22 MERGES',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 8,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  if (isLowHp)
                    Text(
                      '⚠ CRITICAL',
                      style: TextStyle(
                        color: barColorLow.withOpacity(_pulseAnim.value),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [Shadow(color: barColorLow, blurRadius: 6)],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Alien Particle Painter ────────────────────────────────────────────────────

class _AlienParticlePainter extends CustomPainter {
  final double progress;
  final int alienHealth;
  final bool isHurt;

  _AlienParticlePainter({
    required this.progress,
    required this.alienHealth,
    required this.isHurt,
  });

  static final _rng = math.Random(42);
  static final List<_AParticle> _particles = List.generate(28, (i) {
    return _AParticle(
      angle: _rng.nextDouble() * math.pi * 2,
      radius: 45 + _rng.nextDouble() * 60,
      speed: 0.12 + _rng.nextDouble() * 0.25,
      size: 1.5 + _rng.nextDouble() * 3.5,
      phase: _rng.nextDouble(),
      type: i % 4, // 0=orb, 1=spark, 2=ring, 3=dust
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.62;

    final hpFrac = (alienHealth / 100.0).clamp(0.0, 1.0);
    final Color baseColor = isHurt
        ? const Color(0xFF00FFCC)
        : hpFrac < 0.3
            ? const Color(0xFFFF3344)
            : hpFrac < 0.6
                ? const Color(0xFFFFD700)
                : const Color(0xFFCC00FF);

    for (final p in _particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final angle = p.angle + progress * p.speed * math.pi * 2;
      final r = p.radius * (0.7 + 0.3 * math.sin(t * math.pi * 2));
      final x = cx + math.cos(angle) * r;
      final y = cy + math.sin(angle) * r * 0.45; // flatten orbit slightly

      final alphaPulse = (math.sin(t * math.pi * 2 + p.phase * 6) + 1) / 2;
      final alpha = (0.25 + alphaPulse * 0.65).clamp(0.0, 1.0);

      if (p.type == 0) {
        // Glowing orb
        final paint = Paint()
          ..color = baseColor.withOpacity(alpha * 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(x, y), p.size, paint);
        final corePaint = Paint()
          ..color = Colors.white.withOpacity(alpha * 0.8);
        canvas.drawCircle(Offset(x, y), p.size * 0.4, corePaint);
      } else if (p.type == 1) {
        // Spark line
        final paint = Paint()
          ..color = baseColor.withOpacity(alpha * 0.7)
          ..strokeWidth = p.size * 0.4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        final dx = math.cos(angle + math.pi / 2) * p.size * 2;
        final dy = math.sin(angle + math.pi / 2) * p.size * 2;
        canvas.drawLine(
          Offset(x - dx, y - dy),
          Offset(x + dx, y + dy),
          paint,
        );
      } else if (p.type == 2) {
        // Energy ring
        final paint = Paint()
          ..color = baseColor.withOpacity(alpha * 0.4)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(x, y), p.size * 1.5, paint);
      } else {
        // Dust dot
        final paint = Paint()
          ..color = Colors.white.withOpacity(alpha * 0.35);
        canvas.drawCircle(Offset(x, y), p.size * 0.4, paint);
      }
    }

    // Central energy aura around alien
    if (!isHurt) {
      final auraPulse = (math.sin(progress * math.pi * 2) + 1) / 2;
      final auraPaint = Paint()
        ..color = baseColor.withOpacity(0.06 + auraPulse * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 + auraPulse * 15);
      canvas.drawCircle(Offset(cx, cy), 55 + auraPulse * 15, auraPaint);
    } else {
      // Hurt: white flash ring
      final hurtPaint = Paint()
        ..color = const Color(0xFF00FFCC).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset(cx, cy), 70, hurtPaint);
    }
  }

  @override
  bool shouldRepaint(_AlienParticlePainter old) =>
      old.progress != progress || old.isHurt != isHurt || old.alienHealth != alienHealth;
}

class _AParticle {
  final double angle;
  final double radius;
  final double speed;
  final double size;
  final double phase;
  final int type;
  const _AParticle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.phase,
    required this.type,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// METEOR PROJECTILE
// Travels from alien arm (top) → target grid cell (bottom)
// ═══════════════════════════════════════════════════════════════════════════════

class _MeteorProjectile extends StatelessWidget {
  final double startX;
  final double startY;
  final Rect targetRect;
  final Animation<double> progress;

  const _MeteorProjectile({
    required this.startX,
    required this.startY,
    required this.targetRect,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final endX = targetRect.center.dx;
    final endY = targetRect.center.dy;

    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        final t = progress.value;
        final x = startX + (endX - startX) * t;
        final y = startY + (endY - startY) * t;
        final isLanded = t >= 0.88;

        if (isLanded) {
          // Blast animation on landing
          return Stack(
            children: [
              // Shockwave ring
              Positioned(
                left: endX - 30 * (t - 0.88) / 0.12,
                top: endY - 30 * (t - 0.88) / 0.12,
                child: Opacity(
                  opacity: (1.0 - (t - 0.88) / 0.12).clamp(0.0, 1.0),
                  child: Container(
                    width: 60 * (t - 0.88) / 0.12,
                    height: 60 * (t - 0.88) / 0.12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFFF8800).withOpacity(0.8),
                          width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFF4400).withOpacity(0.5),
                            blurRadius: 12),
                      ],
                    ),
                  ),
                ),
              ),
              // Blast flash
              Positioned(
                left: endX - 16,
                top: endY - 16,
                child: Opacity(
                  opacity:
                      ((1.0 - (t - 0.88) / 0.12) * 0.8).clamp(0.0, 1.0),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6600).withOpacity(0.7),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFF4400),
                            blurRadius: 16),
                      ],
                    ),
                    child: const Center(
                      child: Text('💥', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Flying meteor
        final scale = 0.5 + t * 0.8;
        final opacity = (t < 0.1 ? t / 0.1 : 1.0).clamp(0.0, 1.0);
        return Positioned(
          left: x - 14 * scale,
          top: y - 14 * scale,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: t * math.pi * 3,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 28 * scale,
                    height: 28 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF6600),
                          const Color(0xFF9B00FF).withOpacity(0.8),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFCC00FF).withOpacity(0.7),
                            blurRadius: 8 * scale,
                            spreadRadius: 2),
                      ],
                    ),
                  ),
                  // Holographic grid lines on meteor
                  CustomPaint(
                    size: Size(28 * scale, 28 * scale),
                    painter: _MeteorFacePainter(t),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MeteorFacePainter extends CustomPainter {
  final double t;
  const _MeteorFacePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), paint);
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 6), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LASER MISSILE
// Travels from spawner (bottom) → alien (top)
// ═══════════════════════════════════════════════════════════════════════════════

class _LaserMissile extends StatelessWidget {
  final Offset startOffset;
  final Offset endOffset;
  final double progress;
  final int damage;

  const _LaserMissile({
    required this.startOffset,
    required this.endOffset,
    required this.progress,
    required this.damage,
  });

  @override
  Widget build(BuildContext context) {
    final t = progress;
    final x = startOffset.dx + (endOffset.dx - startOffset.dx) * t;
    final y = startOffset.dy + (endOffset.dy - startOffset.dy) * t;
    final isHitting = t >= 0.9;

    return Stack(
      children: [
        // ── Laser trail ──────────────────────────────────────────────
        CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _LaserTrailPainter(
            start: startOffset,
            current: Offset(x, y),
            progress: t,
          ),
        ),

        // ── Missile head ─────────────────────────────────────────────
        if (!isHitting)
          Positioned(
            left: x - 10,
            top: y - 20,
            child: Container(
              width: 20,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF00FFCC),
                    Color(0xFF0088FF),
                    Color(0xFF0044BB),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00FFCC).withOpacity(0.9),
                      blurRadius: 12,
                      spreadRadius: 2),
                ],
              ),
              child: const Center(
                child: Text('🔫', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),

        // ── Hit impact ───────────────────────────────────────────────
        if (isHitting) ...[
          Positioned(
            left: endOffset.dx - 30,
            top: endOffset.dy - 30,
            child: Opacity(
              opacity: (1.0 - (t - 0.9) / 0.1).clamp(0.0, 1.0),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00FFCC).withOpacity(0.6),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF00FFCC),
                        blurRadius: 24),
                  ],
                ),
              ),
            ),
          ),
          // Damage number
          Positioned(
            left: endOffset.dx - 30,
            top: endOffset.dy - 50 - 20 * (t - 0.9) / 0.1,
            child: Opacity(
              opacity: (1.0 - (t - 0.9) / 0.1).clamp(0.0, 1.0),
              child: Text(
                '-$damage HP',
                style: const TextStyle(
                  color: Color(0xFF00FFCC),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0xFF00FFCC), blurRadius: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LaserTrailPainter extends CustomPainter {
  final Offset start;
  final Offset current;
  final double progress;

  const _LaserTrailPainter({
    required this.start,
    required this.current,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.05) return;
    final fade = (1.0 - progress).clamp(0.0, 1.0);
    // Core beam
    canvas.drawLine(
      start,
      current,
      Paint()
        ..shader = ui.Gradient.linear(
          start, current,
          [
            const Color(0xFF0044BB).withOpacity(0.2 * fade),
            const Color(0xFF00FFCC).withOpacity(0.9 * fade),
          ],
        )
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    // Glow beam
    canvas.drawLine(
      start,
      current,
      Paint()
        ..shader = ui.Gradient.linear(
          start, current,
          [
            const Color(0xFF0044BB).withOpacity(0.05 * fade),
            const Color(0xFF00FFCC).withOpacity(0.35 * fade),
          ],
        )
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_LaserTrailPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// UFO SHIP PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _UfoPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;
  final double rotation; // 0..2π spinning lights

  const _UfoPainter({
    required this.color,
    required this.glowIntensity,
    this.rotation = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Canvas: 90 × 56. Disc centre at (45, 36), dome centre at (45, 18)
    final cx = size.width / 2;
    const discY = 36.0;
    const domeY = 18.0;
    final gi = glowIntensity.clamp(0.0, 1.0);

    // ── 1. Reactor glow pool beneath disc ────────────────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, discY + 8), width: 68, height: 16),
        Paint()
          ..color = color.withOpacity(0.45 * gi)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // ── 2. Tractor beam trapezoid ─────────────────────────────────────────
    if (gi > 0.1) {
      final beam = Path()
        ..moveTo(cx - 20, discY + 7)
        ..lineTo(cx + 20, discY + 7)
        ..lineTo(cx + 8, discY + 26)
        ..lineTo(cx - 8, discY + 26)
        ..close();
      canvas.drawPath(beam, Paint()..shader = ui.Gradient.linear(
          Offset(cx, discY + 7), Offset(cx, discY + 26),
          [color.withOpacity(0.55 * gi), Colors.transparent]));
    }

    // ── 3. Drop shadow under disc ─────────────────────────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, discY + 6), width: 90, height: 16),
        Paint()..color = Colors.black.withOpacity(0.50));

    // ── 4. Chrome metallic disc — 4-stop gradient ─────────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, discY), width: 90, height: 26),
        Paint()..shader = ui.Gradient.linear(
            Offset(cx, discY - 13), Offset(cx, discY + 13),
            [
              Colors.white.withOpacity(0.92),
              color.withOpacity(0.95),
              color.withOpacity(0.50),
              const Color(0xFF050505),
            ],
            [0.0, 0.20, 0.62, 1.0]));

    // ── 5. Outer disc rim highlight ───────────────────────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, discY), width: 90, height: 26),
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // ── 6. Inner ring panel line ──────────────────────────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, discY + 2), width: 58, height: 14),
        Paint()
          ..color = Colors.black.withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2);

    // ── 7. Porthole windows (visible front-arc only) ──────────────────────
    for (int i = 0; i < 5; i++) {
      final pAngle = -math.pi * 0.68 + (i / 4.0) * math.pi * 1.36;
      final px = cx + math.cos(pAngle) * 32;
      final py = discY + math.sin(pAngle) * 8;
      // dark surround
      canvas.drawCircle(Offset(px, py), 3.5,
          Paint()..color = Colors.black.withOpacity(0.7));
      // coloured glass
      canvas.drawCircle(Offset(px, py), 2.7,
          Paint()..color = color.withOpacity(gi));
      // tiny specular
      canvas.drawCircle(Offset(px - 0.8, py - 0.8), 1.0,
          Paint()..color = Colors.white.withOpacity(0.85));
    }

    // ── 8. Rotating rim lights (outer ring, upper hemisphere only) ────────
    for (int i = 0; i < 10; i++) {
      final a = rotation + (i / 10.0) * math.pi * 2;
      final lx = cx + math.cos(a) * 42;
      final ly = discY + math.sin(a) * 11;
      if (ly > discY + 10) continue; // skip bottom half (hidden behind disc)
      final lc = (i % 3 == 0) ? Colors.white
          : (i % 3 == 1) ? color : const Color(0xFFFFDD00);
      canvas.drawCircle(Offset(lx, ly), 2.6,
          Paint()
            ..color = lc.withOpacity(gi)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    // ── 9. Glass dome ─────────────────────────────────────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, domeY), width: 46, height: 36),
        Paint()..shader = ui.Gradient.radial(
            Offset(cx, domeY - 5), 20,
            [Colors.white.withOpacity(0.70), color.withOpacity(0.40), color.withOpacity(0.10)],
            [0.0, 0.55, 1.0]));
    // dome rim stroke
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, domeY), width: 46, height: 36),
        Paint()
          ..color = Colors.white.withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    // shine arc
    final shine = Path()..addArc(
        Rect.fromCenter(center: Offset(cx, domeY - 1), width: 34, height: 24),
        -2.5, 1.3);
    canvas.drawPath(shine, Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);

    // ── 10. Atmospheric halo (outermost subtle glow) ──────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, discY), width: 96, height: 34),
        Paint()
          ..color = color.withOpacity(0.15 * gi)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
  }

  @override
  bool shouldRepaint(_UfoPainter old) =>
      old.glowIntensity != glowIntensity ||
      old.rotation != rotation ||
      old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIN BLAST ANIMATION
// ═══════════════════════════════════════════════════════════════════════════════

class _AlienWinBlast extends StatefulWidget {
  final AlienController controller;
  const _AlienWinBlast({required this.controller});
  @override
  State<_AlienWinBlast> createState() => _AlienWinBlastState();
}

class _AlienWinBlastState extends State<_AlienWinBlast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shockwave1;
  late Animation<double> _shockwave2;
  late Animation<double> _flash;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..forward();

    _shockwave1 = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: const Interval(0.05, 0.55, curve: Curves.easeOut)));
    _shockwave2 = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: const Interval(0.15, 0.65, curve: Curves.easeOut)));
    _flash = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.9), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.0), weight: 20),
    ]).animate(_ctrl);
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: const Interval(0.45, 0.65, curve: Curves.easeOut)));
    _textSlide = Tween<double>(begin: 30.0, end: 0.0)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: const Interval(0.45, 0.65, curve: Curves.easeOut)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height * 0.38;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final partCount = 8;
        return Stack(
          children: [
            Container(
                color: Colors.black.withOpacity((t * 0.6).clamp(0.0, 0.6))),

            // Shockwave 1
            Center(
              child: Opacity(
                opacity: (1.0 - _shockwave1.value).clamp(0.0, 1.0),
                child: Container(
                  width: 30 + _shockwave1.value * size.width * 1.6,
                  height: 30 + _shockwave1.value * size.width * 1.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFCC00FF).withOpacity(0.9),
                        width: 5),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFCC00FF).withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
            // Shockwave 2
            Center(
              child: Opacity(
                opacity: (1.0 - _shockwave2.value * 0.8).clamp(0.0, 1.0),
                child: Container(
                  width: 20 + _shockwave2.value * size.width * 2.0,
                  height: 20 + _shockwave2.value * size.width * 2.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFFF4444).withOpacity(0.6),
                        width: 3),
                  ),
                ),
              ),
            ),

            // Flying alien parts
            ...List.generate(partCount, (i) {
              final angle = (i / partCount) * math.pi * 2;
              final fly = Curves.easeOut.transform(math.min(t * 2.0, 1.0));
              final dx = math.cos(angle) * fly * size.width * 0.55;
              final dy = math.sin(angle) * fly * size.height * 0.35;
              final pOp = (1.0 - ((t - 0.3) / 0.5)).clamp(0.0, 1.0);
              final spin = i * math.pi / 3 * fly * 2;
              return Positioned(
                left: cx + dx - 14,
                top: cy + dy - 14,
                child: Opacity(
                  opacity: pOp,
                  child: Transform.rotate(
                    angle: spin,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: i % 2 == 0
                            ? const Color(0xFF5ABE00)
                            : const Color(0xFFFF6B00),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFCC00FF).withOpacity(0.7),
                              blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Flash
            IgnorePointer(
              child: Container(
                  color: Colors.white.withOpacity(_flash.value)),
            ),

            // Victory text
            Opacity(
              opacity: _textOpacity.value,
              child: Transform.translate(
                offset: Offset(0, _textSlide.value),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '💥 ALIEN DESTROYED! 💥',
                        style: TextStyle(
                          color: const Color(0xFFCC00FF),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                                color: const Color(0xFFCC00FF),
                                blurRadius: 30),
                            Shadow(color: Colors.white, blurRadius: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'FLEET ANNIHILATED',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
