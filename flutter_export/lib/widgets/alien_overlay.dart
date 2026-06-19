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
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
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
  // ── Controllers ──────────────────────────────────────────────────────────────
  late AnimationController _shipCtrl;     // ships flying in (3800ms)
  late AnimationController _selfRotCtrl;  // each ship spins around itself (500ms repeat)
  late AnimationController _mergeCtrl;    // mega blast flash (1400ms)
  late AnimationController _vanishCtrl;   // ships fade out after blast (400ms)
  late AnimationController _revealCtrl;   // villain dramatic entrance (5000ms)
  late AnimationController _explodeCtrl;  // L33 ship explosion debris (1200ms)
  late AnimationController _shockCtrl;    // shockwave rings at convergence (1100ms)

  // ── Animations ───────────────────────────────────────────────────────────────
  late Animation<double> _shipProgress;
  late Animation<double> _mergeFlash;
  late Animation<double> _vanishAnim;  // 1.0→0.0: ships fade out after blast
  late Animation<double> _dimmer;

  bool _shipsArrived  = false;
  bool _shipsVanished = false;  // true after vanish completes

  static const List<Color> _shipColors = [
    Color(0xFF9B30FF), // purple
    Color(0xFFFF3030), // red
    Color(0xFF30AAFF), // blue
    Color(0xFFFF8800), // orange
  ];

  @override
  void initState() {
    super.initState();
    final isL33 = widget.controller.currentLevel == 33;

    _shipCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800));
    _selfRotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat();
    _mergeCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _vanishCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _revealCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000));
    _explodeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _shockCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

    _shipProgress = CurvedAnimation(parent: _shipCtrl, curve: Curves.easeOut);
    _mergeFlash   = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 85),
    ]).animate(_mergeCtrl);
    _vanishAnim  = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _vanishCtrl, curve: Curves.easeIn));
    _dimmer = Tween<double>(begin: 0.0, end: 0.85)
        .animate(CurvedAnimation(parent: _shipCtrl, curve: Curves.easeIn));

    _shipCtrl.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _shipsArrived = true);

      if (isL33) {
        // L33: ships explode → vanish → 1.5s gap → villain entrance
        _explodeCtrl.forward().then((_) {
          if (!mounted) return;
          _vanishCtrl.forward().then((_) {
            if (!mounted) return;
            setState(() => _shipsVanished = true);
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) { _revealCtrl.forward(); _scheduleVillainHaptics(); }
            });
          });
        });
      } else {
        // L31/L32: 500ms hover → shockwave → blast → ships VANISH → 1.5s gap → villain
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _shockCtrl.forward();
        });
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          _mergeCtrl.forward().then((_) {
            if (!mounted) return;
            _vanishCtrl.forward().then((_) {
              if (!mounted) return;
              setState(() => _shipsVanished = true);
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted) { _revealCtrl.forward(); _scheduleVillainHaptics(); }
              });
            });
          });
        });
      }
    });

    _shipCtrl.forward();
  }

  // ── Villain haptic sync: each phase gets its own vibration pattern ──────────
  // Phases (relative to _revealCtrl.forward() start):
  //  400ms  → Rise:      heavy rumble (alien erupts)
  //  1200ms → Eye Flash: rapid triple buzz (eyes open)
  //  1900ms → Arm Punch: two hard punches
  //  2600ms → Leg Stomp: stomp pattern
  //  3200ms → Explode:   long strong rumble (body shatters)
  //  3800ms → Rejoin:    rapid re-assembly buzz
  //  4400ms → Settle:    final heavy boss thud
  void _scheduleVillainHaptics() {
    final delays = const [
      (400,  [0, 200, 60, 300, 60, 200]),    // Rise — heavy 3-beat rumble
      (1200, [0, 50, 25, 50, 25, 50]),        // Eye flash — rapid triple buzz
      (1900, [0, 180, 50, 250]),              // Arm punch — double hard hit
      (2600, [0, 120, 30, 120]),              // Leg stomp — stomp-stomp
      (3200, [0, 400, 80, 300, 80, 150]),     // Body explodes — long shattering
      (3800, [0, 40, 15, 40, 15, 40, 15, 40]), // Reassemble — rapid light buzz
      (4400, [0, 350]),                        // Boss settle — final thud
    ];

    for (final (ms, pattern) in delays) {
      Future.delayed(Duration(milliseconds: ms), () async {
        if (!mounted) return;
        try {
          final has = await Vibration.hasVibrator() ?? false;
          if (!has) {
            HapticFeedback.heavyImpact();
            return;
          }
          await Vibration.vibrate(pattern: pattern);
        } catch (_) {
          try { HapticFeedback.heavyImpact(); } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    _shipCtrl.dispose();
    _selfRotCtrl.dispose();
    _mergeCtrl.dispose();
    _vanishCtrl.dispose();
    _revealCtrl.dispose();
    _explodeCtrl.dispose();
    _shockCtrl.dispose();
    super.dispose();
  }

  Offset _boosterDir(int i, Offset start, Offset target) {
    final dx = start.dx - target.dx;
    final dy = start.dy - target.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return Offset.zero;
    return Offset(dx / len, dy / len);
  }

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final cx      = size.width / 2;
    final firstCell = widget.getCellRect(0, 0);
    final gridTop = firstCell?.top ?? size.height * 0.45;
    final cy      = gridTop - 10.0;
    final isL33   = widget.controller.currentLevel == 33;
    final target  = Offset(cx, cy);

    final starts = [
      Offset(-80, -80),
      Offset(size.width + 80, -80),
      Offset(-80, size.height + 80),
      Offset(size.width + 80, size.height + 80),
    ];

    return AnimatedBuilder(
      animation: Listenable.merge([
        _shipCtrl, _selfRotCtrl, _mergeCtrl, _vanishCtrl,
        _revealCtrl, _explodeCtrl, _shockCtrl,
      ]),
      builder: (_, __) {
        final t       = _shipProgress.value;
        final selfRot = _selfRotCtrl.value * math.pi * 2; // full spin per 500ms

        return Stack(
          clipBehavior: Clip.none,
          children: [

            // ── 1. Cinematic black dimmer ─────────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(
                    _shipsVanished
                        ? (_revealCtrl.value < 0.08 ? 0.97 : 0.0)
                        : (_dimmer.value * 0.80),
                  ),
                ),
              ),
            ),

            // ── 2. SHIPS — SPINNING + real smoke + particle cloud ─────────
            if (!_shipsVanished)
              ...List.generate(4, (i) {
                final start   = starts[i];
                final prog    = _shipsArrived ? 1.0 : Curves.easeOut.transform(t);
                final shipX   = cx + (start.dx - cx) * (1 - prog);
                final shipY   = cy + (start.dy - cy) * (1 - prog);
                final booster = _boosterDir(i, start, target);
                final shipOp  = _shipsArrived ? _vanishAnim.value : 1.0;

                return Stack(clipBehavior: Clip.none, children: [

                  // ── Real smoke trail (dark gray, grows with age) ────────
                  if (!_shipsArrived)
                    ...List.generate(28, (lag) {
                      final lagT   = (t - lag * 0.022).clamp(0.0, 1.0);
                      if (lagT <= 0.01) return const SizedBox.shrink();
                      final lagP   = Curves.easeOut.transform(lagT);
                      final tx     = cx + (start.dx - cx) * (1 - lagP);
                      final ty     = cy + (start.dy - cy) * (1 - lagP);
                      final age    = lag / 28.0;
                      final puffSz = (10.0 + lag * 2.2).clamp(4.0, 65.0);
                      final op     = ((1 - age) * 0.65 * t).clamp(0.0, 1.0);
                      final drift  = (lag % 5 - 2.0) * 5.5;
                      final perpX  = -booster.dy * drift;
                      final perpY  =  booster.dx * drift;
                      // hot core → white steam → dark gray smoke
                      final Color puffColor = lag < 3
                          ? const Color(0xFFFF8800).withOpacity(op * 0.9)
                          : lag < 9
                              ? Colors.white.withOpacity(op * 0.7)
                              : Color.lerp(Colors.grey.shade600,
                                    Colors.grey.shade400, age)!.withOpacity(op * 0.55);
                      return Positioned(
                        left: tx + perpX - puffSz / 2,
                        top:  ty + perpY - puffSz / 2,
                        child: IgnorePointer(
                          child: Container(
                            width: puffSz, height: puffSz,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: puffColor,
                              boxShadow: lag < 5 ? [
                                BoxShadow(
                                  color: const Color(0xFFFF6600).withOpacity(op * 0.55),
                                  blurRadius: puffSz * 0.55,
                                ),
                              ] : null,
                            ),
                          ),
                        ),
                      );
                    }),

                  // ── Realistic smoke thruster (fire core → steam → dark smoke) ──
                  if (!_shipsArrived)
                    Positioned(
                      left: shipX + booster.dx * 26 - 22,
                      top:  shipY + booster.dy * 18 - 22,
                      child: IgnorePointer(
                        child: CustomPaint(
                          size: const Size(44, 44),
                          painter: _SmokeThrusterPainter(
                            direction: booster,
                            intensity: t,
                          ),
                        ),
                      ),
                    ),

                  // ── Orbiting particle cloud around ship ─────────────────
                  if (!_shipsArrived && t > 0.25)
                    ...List.generate(8, (pi) {
                      final pAngle = selfRot * 1.5 + (pi / 8.0) * math.pi * 2 + i * math.pi / 3;
                      final pr     = 34.0 + math.sin(selfRot * 4 + pi) * 10;
                      final px     = shipX + math.cos(pAngle) * pr;
                      final py     = shipY + math.sin(pAngle) * pr * 0.5;
                      final pfade  = ((t - 0.25) / 0.75 * 0.75).clamp(0.0, 0.75);
                      final pc     = _shipColors[i].withOpacity(pfade);
                      return Positioned(
                        left: px - 4, top: py - 4,
                        child: IgnorePointer(
                          child: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, color: pc,
                              boxShadow: [BoxShadow(color: pc, blurRadius: 8)],
                            ),
                          ),
                        ),
                      );
                    }),

                  // ── UFO — SELF-ROTATING as it flies (gol gol ghumna!) ───
                  Positioned(
                    left: shipX - 45,
                    top:  shipY - 28,
                    child: Opacity(
                      opacity: shipOp.clamp(0.0, 1.0),
                      child: Transform.rotate(
                        angle: selfRot + i * (math.pi / 2),
                        child: CustomPaint(
                          size: const Size(90, 56),
                          painter: _UfoPainter(
                            color: _shipColors[i],
                            glowIntensity: t,
                            rotation: selfRot,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]);
              }),

            // ── 3. Merged UFO hovering (before blast) ────────────────────
            if (_shipsArrived && !isL33 && _mergeFlash.value < 0.02 && !_shipsVanished)
              Positioned(
                left: cx - 45, top: cy - 28,
                child: Opacity(
                  opacity: _vanishAnim.value.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: selfRot,
                    child: CustomPaint(
                      size: const Size(90, 56),
                      painter: _UfoPainter(
                        color: const Color(0xFFCC00FF),
                        glowIntensity: 1.0,
                        rotation: selfRot,
                      ),
                    ),
                  ),
                ),
              ),

            // ── 4. Shockwave rings at convergence ────────────────────────
            if (_shockCtrl.value > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShockwavePainter(
                      center: target,
                      progress: _shockCtrl.value,
                    ),
                  ),
                ),
              ),

            // ── 5. L33 explosion debris ──────────────────────────────────
            if (isL33 && _shipsArrived && _explodeCtrl.value > 0)
              ...List.generate(24, (i) {
                final angle = (i / 24.0) * math.pi * 2;
                final dist  = _explodeCtrl.value * 200;
                final ex    = cx + math.cos(angle) * dist;
                final ey    = cy + math.sin(angle) * dist;
                final fade  = (1.0 - _explodeCtrl.value).clamp(0.0, 1.0) * _vanishAnim.value;
                final sz    = (12.0 + (i % 4) * 6).toDouble();
                return Positioned(
                  left: ex - sz / 2, top: ey - sz / 2,
                  child: Opacity(
                    opacity: fade,
                    child: Container(
                      width: sz, height: sz,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _shipColors[i % 4],
                        boxShadow: [BoxShadow(color: _shipColors[i % 4], blurRadius: 14)],
                      ),
                    ),
                  ),
                );
              }),

            // ── 6. MEGA BLAST — ships disappear IN the flash ─────────────
            if (!isL33 && _mergeFlash.value > 0) ...[
              IgnorePointer(
                child: Container(
                  color: Color.lerp(
                    Colors.white, const Color(0xFFCC00FF),
                    (1 - _mergeFlash.value).clamp(0.0, 1.0),
                  )!.withOpacity(_mergeFlash.value * 0.97),
                ),
              ),
              ...List.generate(44, (i) {
                final angle  = (i / 44.0) * math.pi * 2;
                final maxDst = (i % 3 == 0) ? size.height * 1.1
                    : (i % 3 == 1) ? size.height * 0.7 : size.height * 0.45;
                final prog   = (1 - _mergeFlash.value).clamp(0.0, 1.0);
                final dist   = prog * maxDst;
                final px     = cx + math.cos(angle) * dist;
                final py     = cy + math.sin(angle) * dist;
                final fade   = (1 - prog * 0.88).clamp(0.0, 1.0) * _mergeFlash.value;
                final sz     = (8.0 + (i % 8) * 4.0);
                final c      = _shipColors[i % 4];
                return Positioned(
                  left: px - sz / 2, top: py - sz / 2,
                  child: Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Container(
                      width: sz, height: sz,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i % 7 == 0 ? Colors.white : c,
                        boxShadow: [BoxShadow(color: c, blurRadius: sz)],
                      ),
                    ),
                  ),
                );
              }),
            ],

            // ── 7. VILLAIN DRAMATIC ENTRANCE ─────────────────────────────
            if (_revealCtrl.value > 0)
              _VillainEntranceWidget(
                progress: _revealCtrl.value,
                alienType: widget.controller.alienType,
                screenSize: size,
                finalY: cy - 68.0,
                isL33: isL33,
              ),
          ],
        );
      },
    );
  }
}

// ─── Smoke Thruster Painter ───────────────────────────────────────────────────
// Realistic engine exhaust: hot core (white/orange) → steam → dark smoke cloud
class _SmokeThrusterPainter extends CustomPainter {
  final Offset direction; // normalized, pointing AWAY from target
  final double intensity; // 0..1

  const _SmokeThrusterPainter({required this.direction, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity < 0.05) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final perpX = -direction.dy;
    final perpY =  direction.dx;
    final len = 32.0 * intensity;
    final wid = 18.0 * intensity;
    final tip = Offset(cx + direction.dx * len, cy + direction.dy * len);
    final l   = Offset(cx + perpX * wid, cy + perpY * wid);
    final r   = Offset(cx - perpX * wid, cy - perpY * wid);

    // ── Outer smoke (dark gray, wide cone) ──────────────────────────────────
    final smokePath = Path()..moveTo(l.dx, l.dy)..lineTo(tip.dx, tip.dy)..lineTo(r.dx, r.dy)..close();
    canvas.drawPath(smokePath,
        Paint()..shader = ui.Gradient.linear(Offset(cx, cy), tip, [
          Colors.grey.shade800.withOpacity(0.85 * intensity),
          Colors.grey.shade600.withOpacity(0.45 * intensity),
          Colors.grey.shade400.withOpacity(0.12 * intensity),
          Colors.transparent,
        ], [0.0, 0.30, 0.60, 1.0]));

    // ── Middle steam layer (white-hot, narrower) ─────────────────────────────
    final iLen = len * 0.55; final iWid = wid * 0.42;
    final iTip = Offset(cx + direction.dx * iLen, cy + direction.dy * iLen);
    final il = Offset(cx + perpX * iWid, cy + perpY * iWid);
    final ir = Offset(cx - perpX * iWid, cy - perpY * iWid);
    final steamPath = Path()..moveTo(il.dx, il.dy)..lineTo(iTip.dx, iTip.dy)..lineTo(ir.dx, ir.dy)..close();
    canvas.drawPath(steamPath,
        Paint()..shader = ui.Gradient.linear(Offset(cx, cy), iTip, [
          Colors.white.withOpacity(0.90 * intensity),
          Colors.white.withOpacity(0.40 * intensity),
          Colors.transparent,
        ], [0.0, 0.55, 1.0]));

    // ── Hot core (white → yellow → orange, narrowest) ─────────────────────────
    final cLen = len * 0.28; final cWid = wid * 0.20;
    final cTip = Offset(cx + direction.dx * cLen, cy + direction.dy * cLen);
    final cl = Offset(cx + perpX * cWid, cy + perpY * cWid);
    final cr = Offset(cx - perpX * cWid, cy - perpY * cWid);
    final corePath = Path()..moveTo(cl.dx, cl.dy)..lineTo(cTip.dx, cTip.dy)..lineTo(cr.dx, cr.dy)..close();
    canvas.drawPath(corePath,
        Paint()..shader = ui.Gradient.linear(Offset(cx, cy), cTip, [
          Colors.white.withOpacity(intensity),
          const Color(0xFFFFDD44).withOpacity(0.90 * intensity),
          const Color(0xFFFF6600).withOpacity(0.60 * intensity),
          Colors.transparent,
        ], [0.0, 0.18, 0.55, 1.0]));
  }

  @override
  bool shouldRepaint(_SmokeThrusterPainter old) =>
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
// VILLAIN DRAMATIC ENTRANCE
// 5-second cinematic villain intro after ships vanish:
// gap → rise → eye flash → arm punch → leg stomp → body explode → rejoin → settle
// ═══════════════════════════════════════════════════════════════════════════════

class _VillainEntranceWidget extends StatelessWidget {
  final double    progress;   // 0..1 over 5000ms
  final AlienType alienType;
  final Size      screenSize;
  final double    finalY;     // alien final resting Y
  final bool      isL33;

  const _VillainEntranceWidget({
    required this.progress,
    required this.alienType,
    required this.screenSize,
    required this.finalY,
    required this.isL33,
  });

  double _phase(double from, double to) =>
      ((progress - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final p  = progress;
    final cx = screenSize.width / 2;
    final sh = screenSize.height;

    // ── Phase map ─────────────────────────────────────────────────────────────
    // 0.00-0.08 : afterglow gap (ember sparks)
    // 0.08-0.24 : alien ERUPTS huge from center (scale 4.5→3.0)
    // 0.24-0.38 : eyes FLASH open wide (angry purple glow pulses)
    // 0.38-0.52 : both arms PUNCH dramatically outward
    // 0.52-0.64 : legs STOMP / body bounces
    // 0.64-0.76 : body EXPLODES into 8 chunks flying out
    // 0.76-0.88 : chunks REASSEMBLE; alien fades back in
    // 0.88-1.00 : scale 3.0→1.0, slide to final position + boss title

    final inRise    = p >= 0.08 && p < 0.24;
    final inEyes    = p >= 0.24 && p < 0.38;
    final inArms    = p >= 0.38 && p < 0.52;
    final inLegs    = p >= 0.52 && p < 0.64;
    final inExplode = p >= 0.64 && p < 0.76;
    final inRejoin  = p >= 0.76 && p < 0.88;
    final inSettle  = p >= 0.88;

    double bodyScale   = 4.5;
    double bodyY       = sh;
    double bodyOpacity = 0.0;
    double eyeGlow     = 0.0;
    double armExtend   = 0.0;
    double legBounce   = 0.0;
    double explodeT    = 0.0;
    bool   bodyHidden  = false;

    if (p < 0.08) {
      bodyOpacity = 0.0;
      bodyY = sh;
    } else if (inRise) {
      final t = Curves.easeOut.transform(_phase(0.08, 0.24));
      bodyOpacity = t;
      bodyScale   = 4.5 - t * 1.5;
      bodyY       = sh * 0.5 + (1 - t) * sh * 0.35;
    } else if (inEyes) {
      bodyOpacity = 1.0; bodyScale = 3.0; bodyY = sh * 0.5;
      eyeGlow     = 0.45 + 0.55 * math.sin(_phase(0.24, 0.38) * math.pi * 5);
    } else if (inArms) {
      bodyOpacity = 1.0; bodyScale = 3.0; bodyY = sh * 0.5; eyeGlow = 0.3;
      armExtend   = math.sin(_phase(0.38, 0.52) * math.pi);
    } else if (inLegs) {
      bodyOpacity = 1.0; bodyScale = 3.0; bodyY = sh * 0.5;
      legBounce   = math.sin(_phase(0.52, 0.64) * math.pi * 3) * 0.5;
    } else if (inExplode) {
      bodyHidden  = true;
      explodeT    = _phase(0.64, 0.76);
      bodyScale   = 3.0; bodyY = sh * 0.5;
    } else if (inRejoin) {
      final t    = _phase(0.76, 0.88);
      bodyHidden  = t < 0.5;
      explodeT    = 1.0 - t;
      bodyOpacity = t < 0.5 ? 0.0 : (t - 0.5) * 2;
      bodyScale   = 3.0; bodyY = sh * 0.5;
    } else {
      // inSettle
      bodyOpacity = 1.0;
      final t   = Curves.easeInOut.transform(_phase(0.88, 1.0));
      bodyScale  = 3.0 - t * 2.0;
      bodyY      = sh * 0.5 + t * (finalY + 60 - sh * 0.5);
    }

    final auraOp = ((bodyScale - 1.0) / 3.0 * 0.40).clamp(0.0, 0.40);

    return Stack(
      children: [
        // ── Ember afterglow sparks (gap phase) ──────────────────────────────
        if (p < 0.22)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _EmberAfterglowPainter(
                  center: Offset(cx, sh * 0.42),
                  intensity: (1 - p / 0.22).clamp(0.0, 1.0),
                ),
              ),
            ),
          ),

        // ── Purple atmospheric aura when alien is giant ──────────────────────
        if (auraOp > 0 && bodyOpacity > 0.05)
          Positioned(
            left: cx - 200, top: bodyY - 180,
            child: IgnorePointer(
              child: Container(
                width: 400, height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFCC00FF).withOpacity(auraOp),
                    const Color(0xFFFF2266).withOpacity(auraOp * 0.35),
                    Colors.transparent,
                  ], stops: const [0.0, 0.5, 1.0]),
                ),
              ),
            ),
          ),

        // ── Explosion chunks flying out / reassembling ──────────────────────
        if (inExplode || inRejoin)
          ...List.generate(8, (i) {
            const chunkColors = [
              Color(0xFF7BC800), Color(0xFFFF6B00),
              Color(0xFF2255CC), Color(0xFF111133),
              Color(0xFF7BC800), Color(0xFFFF6B00),
              Color(0xFF2255CC), Color(0xFF111133),
            ];
            final angle   = (i / 8.0) * math.pi * 2;
            final dist    = (inExplode ? explodeT : (1 - explodeT)) * 150 * bodyScale / 3.0;
            final chunkX  = cx + math.cos(angle) * dist;
            final chunkY  = bodyY + 55 + math.sin(angle) * dist;
            final chunkOp = inExplode
                ? (1 - explodeT * 0.35).clamp(0.0, 1.0)
                : explodeT.clamp(0.0, 1.0);
            final chunkSz = (30.0 + (i % 3) * 12.0) * bodyScale / 3.0;
            return Positioned(
              left: chunkX - chunkSz / 2,
              top:  chunkY - chunkSz / 2,
              child: Opacity(
                opacity: chunkOp,
                child: Transform.rotate(
                  angle: angle * explodeT * 2.5,
                  child: Container(
                    width: chunkSz, height: chunkSz,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(chunkSz * 0.28),
                      color: chunkColors[i],
                      boxShadow: [BoxShadow(color: chunkColors[i].withOpacity(0.65), blurRadius: 14)],
                    ),
                  ),
                ),
              ),
            );
          }),

        // ── Giant alien body ─────────────────────────────────────────────────
        if (!bodyHidden && bodyOpacity > 0.01)
          Positioned(
            top:  bodyY - 70.0 * bodyScale / 3.0 + legBounce * 22,
            left: 0, right: 0,
            child: Center(
              child: Opacity(
                opacity: bodyOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: bodyScale.clamp(1.0, 4.5),
                  child: SizedBox(
                    width: 150, height: 140,
                    child: Stack(children: [
                      // Eye glow overlay
                      if (eyeGlow > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _EyeGlowPainter(intensity: eyeGlow)),
                          ),
                        ),
                      // Alien body
                      CustomPaint(
                        size: const Size(150, 140),
                        painter: _AlienBodyPainter(
                          alienType: alienType,
                          isThrowing: armExtend > 0.1,
                          throwDirection: const Offset(1, 0.15),
                          isHurt: false,
                          eyeBlinkValue: 0.0,
                          armSwingValue: armExtend + legBounce,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),

        // ── Boss title (settle phase) ─────────────────────────────────────────
        if (inSettle)
          Positioned(
            top:  bodyY - 115.0 * bodyScale / 3.0,
            left: 0, right: 0,
            child: Opacity(
              opacity: _phase(0.88, 0.97).clamp(0.0, 1.0),
              child: Column(children: [
                Text(
                  isL33 ? '☠  BOSS ALIEN UNLEASHED  ☠'
                      : alienType == AlienType.standing
                          ? '👾  ALIEN BOSS ACTIVATED  👾'
                          : '👾  ALIEN BOSS ONLINE  👾',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF2266), fontSize: 22,
                    fontWeight: FontWeight.w900, letterSpacing: 2.5,
                    shadows: [
                      Shadow(color: Color(0xFFFF2266), blurRadius: 28),
                      Shadow(color: Colors.white, blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'MERGE TILES TO FIRE LASER  •  DESTROY THE ALIEN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 10.5, letterSpacing: 1.5,
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

// ─── Ember Afterglow Painter ──────────────────────────────────────────────────
// Random colored ember sparks that appear after ships vanish (gap phase)
class _EmberAfterglowPainter extends CustomPainter {
  final Offset center;
  final double intensity;
  const _EmberAfterglowPainter({required this.center, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final rng = math.Random(42);
    const colors = [
      Color(0xFFCC00FF), Color(0xFFFF8800), Color(0xFF00FFCC), Colors.white,
    ];
    for (int i = 0; i < 32; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist  = rng.nextDouble() * 130 * intensity;
      final x     = center.dx + math.cos(angle) * dist;
      final y     = center.dy + math.sin(angle) * dist;
      final sz    = rng.nextDouble() * 7 + 2;
      final op    = rng.nextDouble() * intensity * 0.75;
      canvas.drawCircle(
        Offset(x, y), sz,
        Paint()
          ..color = colors[i % colors.length].withOpacity(op)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(_EmberAfterglowPainter old) => old.intensity != intensity;
}

// ─── Eye Glow Painter ─────────────────────────────────────────────────────────
// Overlaid on alien body during villain eye-flash phase
class _EyeGlowPainter extends CustomPainter {
  final double intensity;
  const _EyeGlowPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final cx   = size.width / 2;
    final eyeY = size.height * 0.34;
    for (final ex in [cx - 19.0, cx + 19.0]) {
      canvas.drawCircle(Offset(ex, eyeY), 24 * intensity,
          Paint()
            ..color = const Color(0xFFCC00FF).withOpacity(intensity * 0.65)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      canvas.drawCircle(Offset(ex, eyeY), 9 * intensity,
          Paint()
            ..color = Colors.white.withOpacity(intensity * 0.88)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
  }

  @override
  bool shouldRepaint(_EyeGlowPainter old) => old.intensity != intensity;
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

  // Continuous idle animations
  late AnimationController _armSwing;
  late Animation<double> _armSwingAnim;
  late AnimationController _orbitCtrl;

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
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat();
    _eyeBlink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _hurtFlash = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bobAnim = Tween<double>(begin: -4.0, end: 4.0)
        .animate(CurvedAnimation(parent: _bodyBob, curve: Curves.easeInOut));
    _hurtAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_hurtFlash);
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
    _orbitCtrl.dispose();
    _eyeBlink.dispose();
    _hurtFlash.dispose();
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
      animation: Listenable.merge([_bodyBob, _hurtFlash, _armSwing, _orbitCtrl]),
      builder: (_, __) {
        final bobY = _bobAnim.value;
        final hurtT = _hurtAnim.value;
        final swing = _armSwingAnim.value;
        final orbitAngle = _orbitCtrl.value * math.pi * 2;

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

            // ── Elliptical orbit particle ring around alien ───────────
            ...List.generate(10, (i) {
              final angle = orbitAngle + (i / 10.0) * math.pi * 2;
              const orbitRX = 92.0;
              const orbitRY = 48.0;
              final alienCenterX = size.width / 2;
              final alienCenterY = cy + 2 + bobY;
              final px = alienCenterX + math.cos(angle) * orbitRX;
              final py = alienCenterY + math.sin(angle) * orbitRY;
              const particleColors = [
                Color(0xFFCC00FF), Color(0xFF00FFCC), Color(0xFFFF4444),
                Color(0xFFFFAA00), Color(0xFF4488FF), Color(0xFF00FF88),
                Color(0xFFFF00AA), Color(0xFFFFFF44), Color(0xFF44FFFF),
                Color(0xFFFF6600),
              ];
              final c = particleColors[i % particleColors.length];
              final pSz = (i % 3 == 0) ? 9.0 : (i % 3 == 1) ? 6.0 : 7.0;
              return Positioned(
                left: px - pSz / 2,
                top: py - pSz / 2,
                child: IgnorePointer(
                  child: Container(
                    width: pSz, height: pSz,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      boxShadow: [BoxShadow(color: c, blurRadius: 9, spreadRadius: 1)],
                    ),
                  ),
                ),
              );
            }),

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

            // ── HP bar — BELOW alien feet (professional design) ───────
            Positioned(
              top: cy + 78 + bobY,
              left: 16, right: 16,
              child: _AlienHealthBar(
                health: widget.controller.alienHealth,
                mergesDone: widget.controller.mergesDone,
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
  final double armSwingValue; // -1..1 continuous swing

  const _AlienBodyPainter({
    required this.alienType,
    required this.isThrowing,
    required this.throwDirection,
    required this.isHurt,
    required this.eyeBlinkValue,
    this.armSwingValue = 0.0,
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
    canvas.drawCircle(Offset(cx, h * 0.52), 62,
        Paint()
          ..color = const Color(0xFFCC00FF).withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));

    // ── LEGS (animated swing — opposite phases like walking) ─────────────
    final legSwingL = armSwingValue * 0.28; // left leg forward when arm back
    final legSwingR = -armSwingValue * 0.28;

    // Left leg
    canvas.save();
    canvas.translate(cx - 18, h * 0.78);
    canvas.rotate(legSwingL);
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, 0, 20, 22),
        const Radius.circular(10)), Paint()..color = legColor);
    // Left boot
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, 18, 28, 14),
        const Radius.circular(7)), Paint()..color = bootColor);
    canvas.restore();

    // Right leg
    canvas.save();
    canvas.translate(cx + 18, h * 0.78);
    canvas.rotate(legSwingR);
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, 0, 20, 22),
        const Radius.circular(10)), Paint()..color = legColor);
    // Right boot
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, 18, 28, 14),
        const Radius.circular(7)), Paint()..color = bootColor);
    canvas.restore();

    // ── TORSO (orange, wide, rounded) ───────────────────────────────────
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 32, h * 0.60, 64, h * 0.20),
        const Radius.circular(14)),
        Paint()..shader = ui.Gradient.linear(
          Offset(cx - 32, h * 0.60), Offset(cx + 32, h * 0.80),
          [suitColor, darkSuit]));

    // Suit collar ring (white band at neck)
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 26, h * 0.595, 52, 9),
        const Radius.circular(5)),
        Paint()..color = Colors.white.withOpacity(0.55));

    // Chest panel light
    canvas.drawCircle(Offset(cx, h * 0.69),
        8, Paint()..color = const Color(0xFF00FFCC).withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(cx, h * 0.69), 4, Paint()..color = Colors.white);

    // ── ARMS ─────────────────────────────────────────────────────────────
    _drawArms(canvas, cx, h, suitColor, skinColor, ht);

    // ── HEAD (big round green face) ──────────────────────────────────────
    canvas.drawCircle(Offset(cx, h * 0.37),
        38,
        Paint()..shader = ui.Gradient.radial(
          Offset(cx - 10, h * 0.28), 24,
          [skinColor, skinColor.withOpacity(0.75)]));

    // ── HELMET DOME (subtle glass — NO harsh white ring) ────────────────
    // Barely-there fill
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.36), width: 94, height: 96),
        Paint()..color = Colors.white.withOpacity(0.04));
    // Thin, very faint rim — just enough for shape definition
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.36), width: 94, height: 96),
        Paint()
          ..color = Colors.white.withOpacity(0.13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    // Subtle shine arc (top-left only)
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

    // ── BIG CARTOON EYES ─────────────────────────────────────────────────
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
  }

  void _drawArms(Canvas canvas, double cx, double h,
      Color suitColor, Color skinColor, double ht) {
    final handColor = Color.lerp(skinColor, const Color(0xFF00FFCC), ht)!;
    final armPaint = Paint()..color = suitColor;

    if (isThrowing) {
      // Left arm: idle swing while right arm throws
      canvas.save();
      canvas.translate(cx - 32, h * 0.62);
      canvas.rotate(-0.18 + armSwingValue * 0.22);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, 0, 18, 30), const Radius.circular(9)),
          armPaint);
      canvas.restore();

      // Right arm: throws toward target
      final throwAngle = math.atan2(throwDirection.dy, throwDirection.dx);
      canvas.save();
      canvas.translate(cx + 32, h * 0.635);
      canvas.rotate(throwAngle - math.pi / 6);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, 0, 18, 40), const Radius.circular(9)),
          armPaint);
      // Glowing purple energy orb at arm tip
      canvas.drawCircle(const Offset(0, 42), 11,
          Paint()..color = const Color(0xFFCC00FF).withOpacity(0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawCircle(const Offset(0, 42), 7,
          Paint()..color = handColor);
      canvas.restore();

    } else if (alienType == AlienType.waving) {
      // Left arm: raised and waving, with armSwing for wave motion
      canvas.save();
      canvas.translate(cx - 32, h * 0.60);
      canvas.rotate(-math.pi * 0.55 + armSwingValue * 0.18);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, -38, 18, 40), const Radius.circular(9)),
          armPaint);
      // Hand
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, -40), width: 22, height: 16),
          Paint()..color = handColor);
      // Finger hints
      for (int fi = 0; fi < 3; fi++) {
        canvas.drawLine(Offset(-5.0 + fi * 5, -38), Offset(-5.0 + fi * 5, -48),
            Paint()..color = skinColor.withOpacity(0.65)
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round);
      }
      canvas.restore();
      // Right arm: gentle swing
      canvas.save();
      canvas.translate(cx + 32, h * 0.62);
      canvas.rotate(0.18 - armSwingValue * 0.22);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 18, 30), const Radius.circular(9)),
          armPaint);
      canvas.restore();

    } else {
      // Idle: both arms swing naturally in opposite phases (walking cycle look)
      canvas.save();
      canvas.translate(cx - 32, h * 0.62);
      // Left arm swings forward when armSwingValue > 0
      canvas.rotate(-0.18 + armSwingValue * 0.32);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, 0, 18, 30), const Radius.circular(9)),
          armPaint);
      // Left hand
      canvas.drawCircle(const Offset(-9, 31), 7,
          Paint()..color = handColor);
      canvas.restore();

      canvas.save();
      canvas.translate(cx + 32, h * 0.62);
      // Right arm swings backward (opposite phase)
      canvas.rotate(0.18 - armSwingValue * 0.32);
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
    // BIG cartoon eyes — the dominant feature matching reference aliens
    final eyeR  = 13.5; // large eye radius
    final eyeY  = h * 0.34;
    final eyeLX = cx - 19.0;
    final eyeRX = cx + 19.0;

    // Blink: scale eye height down to near 0
    final blinkScale = (1.0 - eyeBlinkValue * 0.92).clamp(0.05, 1.0);
    final eyeH = eyeR * 2 * blinkScale;

    // White sclera
    final scleraColor = isHurt ? const Color(0xFFAAFFEE) : Colors.white;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(eyeLX, eyeY), width: eyeR * 2, height: eyeH),
        Paint()..color = scleraColor);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(eyeRX, eyeY), width: eyeR * 2, height: eyeH),
        Paint()..color = scleraColor);

    if (blinkScale > 0.15) {
      // Iris (large, colourful)
      final irisColor = isHurt ? const Color(0xFFCC00FF) : const Color(0xFF4A2800);
      final irisH = eyeH * 0.68;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeLX + (isHurt ? 2 : 0), eyeY),
              width: eyeR * 1.3, height: irisH),
          Paint()..color = irisColor);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeRX - (isHurt ? 2 : 0), eyeY),
              width: eyeR * 1.3, height: irisH),
          Paint()..color = irisColor);

      // Pupil
      final pupilH = irisH * 0.55;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeLX, eyeY),
              width: eyeR * 0.7, height: pupilH),
          Paint()..color = Colors.black87);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeRX, eyeY),
              width: eyeR * 0.7, height: pupilH),
          Paint()..color = Colors.black87);

      // Cute highlight dot (top-right of each eye)
      if (blinkScale > 0.3) {
        canvas.drawCircle(
            Offset(eyeLX + eyeR * 0.35, eyeY - eyeH * 0.28), 2.5,
            Paint()..color = Colors.white.withOpacity(0.9));
        canvas.drawCircle(
            Offset(eyeRX + eyeR * 0.35, eyeY - eyeH * 0.28), 2.5,
            Paint()..color = Colors.white.withOpacity(0.9));
      }
    }

    // Eye glow when hurt
    if (isHurt) {
      for (final ex in [eyeLX, eyeRX]) {
        canvas.drawCircle(Offset(ex, eyeY), 16,
            Paint()..color = const Color(0xFFCC00FF).withOpacity(0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
    }

    // Mouth
    final mouthY = h * 0.475;
    if (alienType == AlienType.smiling || isHurt) {
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
      old.isThrowing != isThrowing ||
      old.isHurt != isHurt ||
      old.eyeBlinkValue != eyeBlinkValue ||
      old.throwDirection != throwDirection ||
      old.armSwingValue != armSwingValue;
}

// ─── Alien Health Bar — Professional Segmented Design ─────────────────────────

class _AlienHealthBar extends StatelessWidget {
  final int health;
  final int mergesDone;
  final bool compact;
  const _AlienHealthBar({
    required this.health,
    required this.mergesDone,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hpFrac = (health / 100.0).clamp(0.0, 1.0);
    final isLow  = hpFrac < 0.33;
    final isMid  = hpFrac < 0.66;
    final barColor = isLow
        ? const Color(0xFFFF2244)
        : isMid ? const Color(0xFFFFAA00) : const Color(0xFF00E676);
    final glowColor = isLow
        ? const Color(0xFFFF2244)
        : isMid ? const Color(0xFFFF8800) : const Color(0xFF00CC66);

    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(6, 4, 6, 4)
          : const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF08000E).withOpacity(0.94),
        border: Border.all(
          color: const Color(0xFFCC00FF).withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(isLow ? 0.60 : 0.22),
            blurRadius: isLow ? 16 : 8,
            spreadRadius: isLow ? 2 : 0,
          ),
          BoxShadow(
            color: const Color(0xFFCC00FF).withOpacity(0.20),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                // Status dot
                Container(
                  width: compact ? 5 : 7,
                  height: compact ? 5 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor,
                    boxShadow: [BoxShadow(color: glowColor, blurRadius: 8)],
                  ),
                ),
                SizedBox(width: compact ? 4 : 5),
                Text(
                  'ALIEN HP',
                  style: TextStyle(
                    color: const Color(0xFFCC00FF).withOpacity(0.95),
                    fontSize: compact ? 7 : 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (isLow && !compact)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '⚠ CRITICAL',
                      style: TextStyle(
                        color: const Color(0xFFFF2244),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: [Shadow(color: const Color(0xFFFF2244), blurRadius: 8)],
                      ),
                    ),
                  ),
                Text(
                  '$health%',
                  style: TextStyle(
                    color: barColor,
                    fontSize: compact ? 8 : 11,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: barColor, blurRadius: 10)],
                  ),
                ),
              ]),
            ],
          ),
          SizedBox(height: compact ? 4 : 5),

          // ── Segmented HP bar ──────────────────────────────────────────
          SizedBox(
            height: compact ? 7 : 11,
            child: LayoutBuilder(builder: (ctx, constraints) {
              const segments = 10;
              final totalW = constraints.maxWidth;
              final gap = compact ? 1.5 : 2.0;
              final segW = (totalW - (segments - 1) * gap) / segments;
              final filled = (hpFrac * segments);
              return Row(
                children: List.generate(segments, (i) {
                  final isFilled = i < filled;
                  final isPartialSeg = i == filled.floor() && filled % 1 > 0;
                  final partialFrac = isPartialSeg ? (filled % 1) : 0.0;
                  // Color progression: left=green → mid=orange → right=red
                  final segPct = i / (segments - 1);
                  final segColor = segPct < 0.34
                      ? const Color(0xFF00E676)
                      : segPct < 0.67
                          ? const Color(0xFFFFAA00)
                          : const Color(0xFFFF3344);
                  return Padding(
                    padding: EdgeInsets.only(right: i < segments - 1 ? gap : 0),
                    child: Container(
                      width: segW,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: isFilled || isPartialSeg
                              ? segColor.withOpacity(0.45)
                              : Colors.white.withOpacity(0.07),
                          width: 0.5,
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: (isFilled || isPartialSeg)
                          ? FractionallySizedBox(
                              widthFactor: isFilled ? 1.0 : partialFrac,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      segColor,
                                      segColor.withOpacity(0.65),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: segColor.withOpacity(0.75),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                }),
              );
            }),
          ),

          if (!compact) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⚡ $mergesDone / 22 merges to destroy',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 7.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Mini merge progress dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final done = mergesDone >= ((i + 1) * 22 / 5).ceil();
                    return Container(
                      margin: const EdgeInsets.only(left: 3),
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? const Color(0xFF00E676)
                            : Colors.white.withOpacity(0.15),
                        boxShadow: done
                            ? [const BoxShadow(color: Color(0xFF00E676), blurRadius: 6)]
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ALIEN DELIVERY WIDGET
// Compact animated alien portrait shown in the Delivery Zone right panel
// Levels 31 / 32 / 33 — shows alien + orbiting particles + mini HP bar
// ═══════════════════════════════════════════════════════════════════════════════

class AlienDeliveryWidget extends StatefulWidget {
  final AlienController controller;
  const AlienDeliveryWidget({super.key, required this.controller});
  @override
  State<AlienDeliveryWidget> createState() => _AlienDeliveryWidgetState();
}

class _AlienDeliveryWidgetState extends State<AlienDeliveryWidget>
    with TickerProviderStateMixin {
  late AnimationController _bob;
  late AnimationController _orbit;
  late AnimationController _armSwing;
  late AnimationController _hurtFlash;
  late AnimationController _eyeBlinkCtrl;
  late Animation<double> _bobAnim;
  late Animation<double> _armSwingAnim;
  late Animation<double> _hurtAnim;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _armSwing = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _hurtFlash = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _eyeBlinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _bobAnim = Tween<double>(begin: -3.0, end: 3.0)
        .animate(CurvedAnimation(parent: _bob, curve: Curves.easeInOut));
    _armSwingAnim = Tween<double>(begin: -1.0, end: 1.0)
        .animate(CurvedAnimation(parent: _armSwing, curve: Curves.easeInOut));
    _hurtAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_hurtFlash);
    _scheduleEyeBlink();
    widget.controller.addListener(_onUpdate);
  }

  void _scheduleEyeBlink() {
    Future.delayed(Duration(milliseconds: 1200 + math.Random().nextInt(1500)), () {
      if (!mounted) return;
      _eyeBlinkCtrl.forward().then((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 60), () {
          if (!mounted) return;
          _eyeBlinkCtrl.reverse().then((_) { if (mounted) _scheduleEyeBlink(); });
        });
      });
    });
  }

  void _onUpdate() {
    if (!mounted) return;
    if (widget.controller.phase == AlienPhase.laserHit) _hurtFlash.forward(from: 0.0);
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    _bob.dispose();
    _orbit.dispose();
    _armSwing.dispose();
    _hurtFlash.dispose();
    _eyeBlinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHurt = widget.controller.phase == AlienPhase.laserHit;

    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _orbit, _armSwing, _hurtFlash, _eyeBlinkCtrl]),
      builder: (_, __) {
        final bob = _bobAnim.value;
        final orbitAngle = _orbit.value * math.pi * 2;
        final swing = _armSwingAnim.value;

        const w = 88.0;
        const alienW = 76.0;
        const alienH = 72.0;
        const centerX = w / 2;
        const centerY = 44.0;
        const orbitRX = 38.0;
        const orbitRY = 22.0;

        const particleColors = [
          Color(0xFFCC00FF), Color(0xFF00FFCC), Color(0xFFFF4444),
          Color(0xFFFFAA00), Color(0xFF4488FF), Color(0xFF00FF88),
        ];

        return SizedBox(
          width: w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Alien body + orbit particles ─────────────────────────
              SizedBox(
                width: w,
                height: 88,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Purple aura glow behind alien
                    Positioned(
                      left: centerX - 36,
                      top: centerY - 32 + bob,
                      child: IgnorePointer(
                        child: Container(
                          width: 72,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFCC00FF).withOpacity(
                              isHurt ? 0.28 : 0.10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFCC00FF).withOpacity(
                                  isHurt ? 0.50 : 0.22),
                                blurRadius: isHurt ? 24 : 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Orbit particles
                    ...List.generate(6, (i) {
                      final angle = orbitAngle + (i / 6.0) * math.pi * 2;
                      final px = centerX + math.cos(angle) * orbitRX;
                      final py = centerY + math.sin(angle) * orbitRY + bob;
                      final c = particleColors[i % particleColors.length];
                      final sz = i % 2 == 0 ? 7.0 : 5.0;
                      return Positioned(
                        left: px - sz / 2, top: py - sz / 2,
                        child: IgnorePointer(
                          child: Container(
                            width: sz, height: sz,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              boxShadow: [BoxShadow(color: c, blurRadius: 8, spreadRadius: 1)],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Alien body
                    Positioned(
                      left: centerX - alienW / 2,
                      top: centerY - alienH / 2 + bob,
                      child: CustomPaint(
                        size: const Size(alienW, alienH),
                        painter: _AlienBodyPainter(
                          alienType: widget.controller.alienType,
                          isThrowing: false,
                          throwDirection: Offset.zero,
                          isHurt: isHurt,
                          eyeBlinkValue: _eyeBlinkCtrl.value,
                          armSwingValue: swing,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // ── Compact professional HP bar ───────────────────────────
              _AlienHealthBar(
                health: widget.controller.alienHealth,
                mergesDone: widget.controller.mergesDone,
                compact: true,
              ),
            ],
          ),
        );
      },
    );
  }
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
