// ============================================================
// creature_overlay.dart  —  "Data Kraken" Silicon Valley Boss
// Levels 23 · 25 · 27 · 29  |  AAA-quality Flutter animation
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/creature_controller.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kCyan   = Color(0xFF00E5FF);
const _kPurple = Color(0xFF7C4DFF);
const _kNavy   = Color(0xFF0A1628);
const _kDanger = Color(0xFFFF1744);
const _kGreen  = Color(0xFF00E676);
const _kYellow = Color(0xFFFFD600);
const _kTeal   = Color(0xFF006064);

// ── Entry point ───────────────────────────────────────────────────────────────

class CreatureOverlay extends StatelessWidget {
  final CreatureController controller;
  const CreatureOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) => switch (controller.phase) {
        CreaturePhase.idle         => const SizedBox.shrink(),
        CreaturePhase.warningEntry => _WarningScreen(controller: controller),
        CreaturePhase.assemblyEntry => _AssemblyPhase(controller: controller),
        CreaturePhase.active       => _ActivePhase(controller: controller),
        CreaturePhase.winBlast     => _WinBlastPhase(controller: controller),
      },
    );
  }
}

// ── Phase 0: Level-23 Warning Screen ─────────────────────────────────────────

class _WarningScreen extends StatefulWidget {
  final CreatureController controller;
  const _WarningScreen({required this.controller});
  @override State<_WarningScreen> createState() => _WarningScreenState();
}

class _WarningScreenState extends State<_WarningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (ctx, _) => GestureDetector(
          onTap: widget.controller.dismissWarning,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.black.withOpacity(0.90),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background creature silhouette (faded, eerie)
                Positioned(
                  right: -30, top: 60,
                  child: Opacity(
                    opacity: 0.10,
                    child: CustomPaint(
                      painter: _DataKrakenPainter(
                        entryT: 1.0, bobT: 0.5, swayT: 0.5,
                        throwT: 0, throwArmIdx: 0, blinkT: 0,
                        glowColor: _kDanger,
                      ),
                      size: const Size(320, 480),
                    ),
                  ),
                ),
                // Warning panel
                SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C1A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _kDanger.withOpacity(0.45 + 0.55 * _pulse.value),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kDanger.withOpacity(0.28 * _pulse.value),
                          blurRadius: 35, spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Warning emoji — pulsing size
                        Text(
                          '⚠',
                          style: TextStyle(
                            fontSize: 50 + 8 * _pulse.value,
                            shadows: [Shadow(color: _kDanger, blurRadius: 24)],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Title
                        Text(
                          'DATA KRAKEN\nDETECTED',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: _kDanger,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            letterSpacing: 1.8,
                            shadows: [Shadow(color: _kDanger, blurRadius: 16)],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'LEVEL 23 — SILICON VALLEY THREAT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            color: _kCyan.withOpacity(0.65),
                            fontSize: 10.5,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(height: 1, color: _kDanger.withOpacity(0.35)),
                        const SizedBox(height: 16),
                        // Ability list
                        ...[
                          ('🦑', 'Silicon Valley\'s deadliest tech predator'),
                          ('⚡', 'Throws corrupted data packets onto the board'),
                          ('⏰', 'You have 5 seconds to MERGE each packet'),
                          ('💀', 'Fail to merge → packet destroyed + energy lost'),
                          ('✅', 'Complete delivery quota to defeat the Kraken!'),
                        ].map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.$1, style: const TextStyle(fontSize: 19)),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  e.$2,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 22),
                        // CTA button
                        GestureDetector(
                          onTap: widget.controller.dismissWarning,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _kCyan.withOpacity(0.55 + 0.45 * _pulse.value),
                                width: 1.8,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _kCyan.withOpacity(0.15 * _pulse.value),
                                  blurRadius: 16, spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              '⚔  FACE THE KRAKEN',
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                color: _kCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Phase 1: Assembly Entry — FULL-SCREEN AAA Cinematic (4.2 s) ──────────────
//
//  t 0.00-0.30 : Eruption — creature bursts from screen center at 3.5× scale
//  t 0.30-0.62 : Presence — hovers at center, ink particles, tentacles flail
//  t 0.62-0.80 : ROAR     — title text + cyan screen flash
//  t 0.80-1.00 : Slide    — shrinks + flies to top-right corner

class _AssemblyPhase extends StatefulWidget {
  final CreatureController controller;
  const _AssemblyPhase({required this.controller});
  @override State<_AssemblyPhase> createState() => _AssemblyPhaseState();
}

class _AssemblyPhaseState extends State<_AssemblyPhase>
    with TickerProviderStateMixin {
  late AnimationController _main;   // 4200 ms master timeline
  late AnimationController _pulse;  // 500 ms glow pulse (repeating)

  @override
  void initState() {
    super.initState();
    _main  = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
      ..forward();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _main.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: Listenable.merge([_main, _pulse]),
      builder: (ctx, _) {
        final double t = _main.value;
        final double p = _pulse.value;

        // ── Phase fractions ──────────────────────────────────────────────────
        final double eruptT  = (t / 0.30).clamp(0.0, 1.0);
        final double centerT = ((t - 0.30) / 0.32).clamp(0.0, 1.0);
        final double roarT   = ((t - 0.62) / 0.18).clamp(0.0, 1.0);
        final double slideT  = ((t - 0.80) / 0.20).clamp(0.0, 1.0);

        // ── Scale: erupts huge, breathes at center, shrinks to corner ────────
        final double scale;
        if (t < 0.30) {
          scale = Curves.elasticOut.transform(eruptT) * 3.5;
        } else if (t < 0.62) {
          scale = 3.5 - centerT * 0.4 + math.sin(centerT * math.pi * 3.0) * 0.12;
        } else if (t < 0.80) {
          scale = 3.1 + math.sin(roarT * math.pi * 6.0) * 0.18;
        } else {
          scale = 3.1 - Curves.easeInBack.transform(slideT) * 2.1;
        }

        // ── Position: screen center → top-right corner ───────────────────────
        final double cornerLeft = sz.width - 130.0;
        final double cornerTop  = 110.0;
        final double centL      = sz.width * 0.5 - 65.0;
        final double centT2     = sz.height * 0.5 - 100.0;
        final double sp         = t < 0.80 ? 0.0 : Curves.easeInCubic.transform(slideT);
        final double leftPos    = centL + (cornerLeft - centL) * sp;
        final double topPos     = centT2 + (cornerTop - centT2) * sp;

        // ── Overlay darkness ─────────────────────────────────────────────────
        final double oa;
        if (t < 0.30) {
          oa = eruptT * 0.88;
        } else if (t < 0.80) {
          oa = 0.88 - ((t - 0.30) / 0.50) * 0.73;
        } else {
          oa = 0.15 * (1.0 - slideT);
        }

        // ── Painter entryT ───────────────────────────────────────────────────
        final double ep = t < 0.30 ? Curves.elasticOut.transform(eruptT) : 1.0;

        // ── Roar title opacity ───────────────────────────────────────────────
        final double roarAlpha = roarT < 0.45
            ? (roarT / 0.45).clamp(0.0, 1.0)
            : ((1.0 - roarT) / 0.55).clamp(0.0, 1.0);

        // ── Screen flash ─────────────────────────────────────────────────────
        final double flashA = t > 0.68 && t < 0.76
            ? math.sin(((t - 0.68) / 0.08) * math.pi) * 0.55
            : 0.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [

            // ── Dark overlay ─────────────────────────────────────────────────
            if (oa > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color.fromRGBO(0, 0, 0, oa.clamp(0.0, 1.0)),
                  ),
                ),
              ),

            // ── Ink particle burst ───────────────────────────────────────────
            if (t > 0.15 && t < 0.68)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _InkSplatterPainter(
                      progress: ((t - 0.15) / 0.53).clamp(0.0, 1.0),
                      center:   Offset(sz.width * 0.5, sz.height * 0.5),
                      pulseT:   p,
                    ),
                  ),
                ),
              ),

            // ── Creature (scaled + sliding) ──────────────────────────────────
            Positioned(
              left: leftPos,
              top:  topPos,
              child: Transform.scale(
                scale:     scale.clamp(0.05, 4.0),
                alignment: Alignment.topLeft,
                child: CustomPaint(
                  painter: _DataKrakenPainter(
                    entryT:      ep,
                    bobT:        t < 0.30 ? 0.0 : p * 0.4,
                    swayT:       t * 1.8,
                    throwT:      t > 0.50 && t < 0.60 ? (t - 0.50) / 0.10 : 0.0,
                    throwArmIdx: 2,
                    blinkT:      t > 0.58 && t < 0.64 ? (t - 0.58) / 0.06 : 0.0,
                    glowColor:   Color.lerp(
                      _kPurple, _kCyan,
                      (math.sin(t * math.pi * 4.0) * 0.5 + 0.5),
                    )!,
                  ),
                  size: const Size(130, 200),
                ),
              ),
            ),

            // ── ROAR title ───────────────────────────────────────────────────
            if (t > 0.62 && t < 0.80)
              Positioned(
                left: 0, right: 0,
                top: sz.height * 0.16,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: roarAlpha.clamp(0.0, 1.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🦑 DATA KRAKEN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 26.0 + roarT * 6.0,
                            fontWeight: FontWeight.bold,
                            color: _kCyan,
                            shadows: const [
                              Shadow(color: Color(0xFF00E5FF), blurRadius: 32),
                              Shadow(color: Color(0xFF7C4DFF), blurRadius: 64),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'HAS ARRIVED!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 18.0 + roarT * 4.0,
                            fontWeight: FontWeight.bold,
                            color: _kDanger,
                            letterSpacing: 3.0,
                            shadows: const [
                              Shadow(color: Color(0xFFFF1744), blurRadius: 24),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '⚠  MERGE ITEMS OR LOSE ENERGY  ⚠',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: _kYellow.withOpacity(0.9),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Screen flash at roar peak ─────────────────────────────────────
            if (flashA > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color.fromRGBO(0, 229, 255, flashA.clamp(0.0, 0.6)),
                  ),
                ),
              ),

            // ── Slide dust trail ─────────────────────────────────────────────
            if (slideT > 0.05)
              Positioned(
                left: leftPos + 55.0,
                top:  topPos  + 100.0,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SlideDustPainter(progress: slideT, pulseT: p),
                    size: const Size(20.0, 20.0),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Ink Splatter Painter ──────────────────────────────────────────────────────

class _InkSplatterPainter extends CustomPainter {
  final double progress;
  final Offset center;
  final double pulseT;
  const _InkSplatterPainter({
    required this.progress,
    required this.center,
    required this.pulseT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(99);
    for (int i = 0; i < 28; i++) {
      final double angle   = i * math.pi * 2.0 / 28.0 + rng.nextDouble() * 0.5;
      final double maxDist = 100.0 + rng.nextDouble() * 160.0;
      final double dist    = progress * maxDist;
      final double alpha   = (1.0 - progress * 1.15).clamp(0.0, 1.0) * (0.55 + pulseT * 0.3);
      final double r       = (10.0 + rng.nextDouble() * 14.0) * (1.0 - progress * 0.65);
      if (r < 0.5 || alpha < 0.02) continue;
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      final Color col = i % 3 == 0 ? _kCyan : (i % 3 == 1 ? _kPurple : const Color(0xFF004D40));
      canvas.drawCircle(pos, r.clamp(0.5, 24.0), Paint()
        ..color = col.withOpacity(alpha.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (r * 0.35).clamp(1.0, 8.0)));
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * dist * 0.35,
               center.dy + math.sin(angle) * dist * 0.35),
        pos,
        Paint()
          ..color = col.withOpacity((alpha * 0.5).clamp(0.0, 1.0))
          ..strokeWidth = (r * 0.3).clamp(0.5, 4.0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    final double ringR = 50.0 + progress * 90.0 + pulseT * 18.0;
    final double ringA = (1.0 - progress * 1.3).clamp(0.0, 0.35);
    if (ringA > 0.01) {
      canvas.drawCircle(center, ringR, Paint()
        ..color = _kCyan.withOpacity(ringA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    final double ring2R = 80.0 + pulseT * 30.0;
    final double ring2A = ((1.0 - progress * 1.5) * pulseT).clamp(0.0, 0.25);
    if (ring2A > 0.01) {
      canvas.drawCircle(center, ring2R, Paint()
        ..color = _kPurple.withOpacity(ring2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
  }

  @override
  bool shouldRepaint(_InkSplatterPainter o) =>
      o.progress != progress || o.pulseT != pulseT;
}

// ── Slide Dust Painter ────────────────────────────────────────────────────────

class _SlideDustPainter extends CustomPainter {
  final double progress;
  final double pulseT;
  const _SlideDustPainter({required this.progress, required this.pulseT});

  @override
  void paint(Canvas canvas, Size size) {
    final double alpha = (1.0 - progress).clamp(0.0, 0.6);
    if (alpha < 0.01) return;
    for (int i = 0; i < 5; i++) {
      final double t  = i / 5.0;
      final double r  = (6.0 - i) * (1.0 - progress * 0.8);
      if (r < 0.5) continue;
      canvas.drawCircle(
        Offset(size.width * 0.5 + (t - 0.5) * 14.0, size.height * 0.5 + t * 10.0),
        r.clamp(0.5, 10.0),
        Paint()
          ..color = _kCyan.withOpacity((alpha * (1.0 - t)).clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_SlideDustPainter o) =>
      o.progress != progress || o.pulseT != pulseT;
}

// ── Phase 2: Active (floating + throwing) ─────────────────────────────────────

class _ActivePhase extends StatefulWidget {
  final CreatureController controller;
  const _ActivePhase({required this.controller});
  @override State<_ActivePhase> createState() => _ActivePhaseState();
}

class _ActivePhaseState extends State<_ActivePhase>
    with TickerProviderStateMixin {
  late AnimationController _bob;    // idle vertical bob  (2 s loop)
  late AnimationController _sway;   // tentacle sway      (2.5 s loop)
  late AnimationController _throw;  // throw animation    (1.2 s, triggered)
  late AnimationController _blink;  // eye blink          (0.3 s, triggered)
  int _lastThrowCount = 0;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _bob   = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _sway  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _throw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    widget.controller.addListener(_onCtrlChange);
    _lastThrowCount = widget.controller.throwCount;
    _scheduleBlink();
  }

  void _onCtrlChange() {
    if (!mounted) return;
    if (widget.controller.throwCount != _lastThrowCount) {
      _lastThrowCount = widget.controller.throwCount;
      _throw.forward(from: 0);
    }
  }

  void _scheduleBlink() {
    Future.delayed(
      Duration(milliseconds: 2800 + _rng.nextInt(2500)),
      () {
        if (!mounted) return;
        _blink.forward(from: 0).whenComplete(() {
          if (mounted) _blink.reverse().whenComplete(() {
            if (mounted) _scheduleBlink();
          });
        });
      },
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCtrlChange);
    _bob.dispose();
    _sway.dispose();
    _throw.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _sway, _throw, _blink]),
      builder: (ctx, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          // Creature body (top-right corner)
          Positioned(
            top: 110, right: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  painter: _DataKrakenPainter(
                    entryT:      1.0,
                    bobT:        _bob.value,
                    swayT:       _sway.value,
                    throwT:      _throw.value,
                    throwArmIdx: widget.controller.throwArmIdx,
                    blinkT:      _blink.value,
                    glowColor:   _kCyan,
                  ),
                  size: const Size(130, 200),
                ),
                // HUD info panel (left of creature)
                Positioned(
                  left: -112, top: 6,
                  child: _KrakenHud(
                    level:      widget.controller.currentLevel,
                    throwCount: widget.controller.throwCount,
                  ),
                ),
              ],
            ),
          ),
          // Throw arc particle (flies from creature to grid)
          if (_throw.value > 0.25 && _throw.value < 0.75)
            _ThrowParticle(progress: (_throw.value - 0.25) / 0.50),
        ],
      ),
    );
  }
}

// ── Throw arc particle ────────────────────────────────────────────────────────

class _ThrowParticle extends StatelessWidget {
  final double progress; // 0→1
  const _ThrowParticle({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Arc from top-right (creature tip ~[screenW-40, 175]) to mid-left grid
    final sz = MediaQuery.of(context).size;
    final startX = sz.width - 42.0;
    final startY = 175.0;
    final endX   = sz.width * 0.28;
    final endY   = sz.height * 0.50;

    // Quadratic arc: control point is above-left of midpoint
    final t  = progress;
    final mt = 1 - t;
    final cx = startX + (endX - startX) * 0.5;
    final cy = math.min(startY, endY) - 60.0;

    // Bezier point: B(t) = mt²·P0 + 2·mt·t·P1 + t²·P2
    final bx = mt * mt * startX + 2 * mt * t * cx + t * t * endX;
    final by = mt * mt * startY + 2 * mt * t * cy + t * t * endY;

    return Positioned(
      left: bx - 14,
      top:  by - 14,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: _kNavy.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(color: _kCyan, width: 2),
          boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.7), blurRadius: 12, spreadRadius: 2)],
        ),
        child: const Center(child: Text('📦', style: TextStyle(fontSize: 14))),
      ),
    );
  }
}

// ── Kraken HUD panel ──────────────────────────────────────────────────────────

class _KrakenHud extends StatelessWidget {
  final int level, throwCount;
  const _KrakenHud({required this.level, required this.throwCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: _kNavy.withOpacity(0.93),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _kCyan.withOpacity(0.38), width: 1.2),
        boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.1), blurRadius: 12, spreadRadius: 1)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🦑', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              'DATA KRAKEN',
              style: TextStyle(
                fontFamily: 'Orbitron',
                color: _kCyan,
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.9,
                shadows: [Shadow(color: _kCyan, blurRadius: 6)],
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Text(
            'LEVEL $level',
            style: const TextStyle(
              fontFamily: 'Orbitron', color: Colors.white60, fontSize: 9, letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            const Text('🎯', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 3),
            Text(
              'THROWS: $throwCount',
              style: TextStyle(
                fontFamily: 'Orbitron', color: _kYellow, fontSize: 9, letterSpacing: 0.4,
                shadows: [Shadow(color: _kYellow, blurRadius: 5)],
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Container(height: 0.8, color: _kDanger.withOpacity(0.5)),
          const SizedBox(height: 4),
          Text(
            '⏱ Merge in 5s!',
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: _kDanger,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: _kDanger, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phase 3: Win Blast ────────────────────────────────────────────────────────

class _WinBlastPhase extends StatefulWidget {
  final CreatureController controller;
  const _WinBlastPhase({required this.controller});
  @override State<_WinBlastPhase> createState() => _WinBlastPhaseState();
}

class _WinBlastPhaseState extends State<_WinBlastPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Positioned.fill(
        child: CustomPaint(painter: _BlastPainter(t: _ctrl.value, screenSize: MediaQuery.of(ctx).size)),
      ),
    );
  }
}

// ── Data Kraken Painter ───────────────────────────────────────────────────────
// Draws the full Silicon Valley tech octopus using Canvas.

class _DataKrakenPainter extends CustomPainter {
  final double entryT;      // 0→1 how assembled the creature is
  final double bobT;        // 0→1→0 idle vertical bob
  final double swayT;       // 0→1→0 tentacle sway
  final double throwT;      // 0→1 throw arm animation
  final int    throwArmIdx; // which of the 8 arms throws
  final double blinkT;      // 0→1 eye-blink progress
  final Color  glowColor;

  const _DataKrakenPainter({
    required this.entryT,
    required this.bobT,
    required this.swayT,
    required this.throwT,
    required this.throwArmIdx,
    required this.blinkT,
    required this.glowColor,
  });

  @override
  bool shouldRepaint(_DataKrakenPainter o) =>
    o.entryT != entryT || o.bobT != bobT || o.swayT != swayT ||
    o.throwT != throwT || o.throwArmIdx != throwArmIdx || o.blinkT != blinkT;

  // Tentacle base angles (radians, from body edge outward)
  static const List<double> _angles = [
    -math.pi * 0.88,
    -math.pi * 0.67,
    -math.pi * 0.47,
    -math.pi * 0.27,
    -math.pi * 0.07,
     math.pi * 0.12,
     math.pi * 0.32,
     math.pi * 0.52,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (entryT <= 0) return;

    final bob    = math.sin(bobT * math.pi) * 5.0;
    final cx     = size.width * 0.58;
    final cy     = size.height * 0.36 + bob;
    final center = Offset(cx, cy);

    canvas.save();

    // Back tentacles (drawn behind body: indices 4-7)
    for (int i = 4; i < 8; i++) {
      _paintTentacle(canvas, center, i);
    }

    // Outer body glow
    _paintBodyGlow(canvas, center);

    // Body (head dome + body oval)
    _paintBody(canvas, center);

    // Eyes
    _paintEyes(canvas, center);

    // Circuit traces on body
    _paintCircuits(canvas, center);

    // Front tentacles (in front of body: indices 0-3)
    for (int i = 0; i < 4; i++) {
      _paintTentacle(canvas, center, i);
    }

    canvas.restore();
  }

  void _paintBodyGlow(Canvas canvas, Offset c) {
    final pulsed = 0.45 + 0.3 * math.sin(bobT * math.pi);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 100, height: 76),
      Paint()
        ..color = glowColor.withOpacity(pulsed * entryT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
  }

  void _paintBody(Canvas canvas, Offset c) {
    final headC = Offset(c.dx, c.dy - 22);
    const headR  = 29.0;
    const bodyW  = 76.0;
    const bodyH  = 54.0;
    final bodyR  = Rect.fromCenter(center: c, width: bodyW, height: bodyH);

    // Head dome fill
    canvas.drawCircle(headC, headR, Paint()
      ..color = const Color(0xFF0E2038).withOpacity(entryT));

    // Head rim
    canvas.drawCircle(headC, headR, Paint()
      ..color = glowColor.withOpacity(0.45 * entryT)
      ..style = PaintingStyle.stroke..strokeWidth = 1.6);

    // Head inner glow
    canvas.drawCircle(headC, headR * 0.7, Paint()
      ..color = const Color(0xFF112A50).withOpacity(0.5 * entryT)
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 6));

    // Body oval fill (radial gradient via layered circles)
    canvas.drawOval(bodyR, Paint()..color = const Color(0xFF0D2040).withOpacity(entryT));
    canvas.drawOval(bodyR, Paint()
      ..color = const Color(0xFF1A3A60).withOpacity(0.35 * entryT)
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 10));

    // Body outline
    canvas.drawOval(bodyR, Paint()
      ..color = glowColor.withOpacity(0.40 * entryT)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Mantle texture lines (horizontal organic curves)
    final linePaint = Paint()
      ..color = glowColor.withOpacity(0.08 * entryT)
      ..strokeWidth = 0.7;
    for (int i = -2; i <= 2; i++) {
      final y  = c.dy + i * 9.0;
      final hw = (bodyW / 2) * math.sqrt(1 - math.pow(i * 9.0 / (bodyH / 2), 2).clamp(0.0, 1.0));
      canvas.drawLine(Offset(c.dx - hw, y), Offset(c.dx + hw, y), linePaint);
    }
  }

  void _paintEyes(Canvas canvas, Offset c) {
    final eyeY   = c.dy - 23.0;
    final blinkH = (1.0 - blinkT * 0.88).clamp(0.0, 1.0);

    _paintSingleEye(canvas, Offset(c.dx - 12, eyeY), const Color(0xFF00E5FF), blinkH);
    _paintSingleEye(canvas, Offset(c.dx + 12, eyeY), const Color(0xFFFF1744),  blinkH);
  }

  void _paintSingleEye(Canvas canvas, Offset pos, Color col, double openFrac) {
    if (openFrac < 0.04) return;
    final eyeH = 10.0 * openFrac;
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: 11, height: eyeH),
      const Radius.circular(2.5),
    );
    // Fill
    canvas.drawRRect(rr, Paint()..color = col.withOpacity(0.14 * entryT));
    // Glow
    canvas.drawRRect(rr, Paint()
      ..color = col.withOpacity(0.55 * entryT)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5));
    // Outline
    canvas.drawRRect(rr, Paint()
      ..color = col.withOpacity(0.95 * entryT)
      ..style = PaintingStyle.stroke..strokeWidth = 1.4);
    // Scan line (animated vertical sweep)
    final scanY = pos.dy - eyeH / 2 + eyeH * ((bobT * 0.8 + 0.1) % 1.0);
    canvas.drawLine(
      Offset(pos.dx - 4.5, scanY),
      Offset(pos.dx + 4.5, scanY),
      Paint()..color = col.withOpacity(0.9 * entryT)..strokeWidth = 1.0,
    );
  }

  void _paintCircuits(Canvas canvas, Offset c) {
    final p = Paint()
      ..color = const Color(0xFF00BCD4).withOpacity(0.22 * entryT)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    // Horizontal traces
    for (int i = -2; i <= 2; i++) {
      final y  = c.dy + i * 8.5;
      final hw = (34 - i.abs() * 4).toDouble();
      canvas.drawLine(Offset(c.dx - hw, y), Offset(c.dx + hw, y), p);
    }
    // Vertical connectors
    for (int i = -2; i <= 2; i++) {
      final x = c.dx + i * 13.5;
      canvas.drawLine(Offset(x, c.dy - 22), Offset(x, c.dy + 22), p);
    }
    // Junction nodes
    final np = Paint()..color = _kCyan.withOpacity(0.55 * entryT);
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        canvas.drawCircle(Offset(c.dx + i * 13.5, c.dy + j * 8.5), 1.5, np);
      }
    }
  }

  void _paintTentacle(Canvas canvas, Offset center, int idx) {
    final baseAngle  = _angles[idx];
    final isThrowArm = idx == throwArmIdx;
    final sway       = math.sin(swayT * math.pi + idx * math.pi * 0.4) * 6.0;

    // Staggered entry per arm
    final entryScale = ((entryT - idx * 0.065)).clamp(0.0, 1.0);
    if (entryScale <= 0.01) return;

    // Throw arm extends then retracts
    final throwBonus  = isThrowArm ? throwT * 28 * math.sin(throwT * math.pi) : 0.0;
    final armLength   = (62.0 + throwBonus) * entryScale;
    if (armLength < 2) return;

    // Start at body edge
    final startX = center.dx + math.cos(baseAngle) * 31;
    final startY = center.dy + math.sin(baseAngle) * 26 + 10;
    final start  = Offset(startX, startY);

    final angle = baseAngle + sway * 0.07;
    final end   = start + Offset(math.cos(angle) * armLength, math.sin(angle) * armLength);

    final ctrl1 = start + Offset(
      math.cos(angle + 0.18) * armLength * 0.32,
      math.sin(angle + 0.10) * armLength * 0.42 + sway * 0.55,
    );
    final ctrl2 = end - Offset(
      math.cos(angle) * armLength * 0.18,
      math.sin(angle) * armLength * 0.18,
    ) + Offset(0, sway * 0.28);

    // Build bezier path and sample along it
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, end.dx, end.dy);

    final metric  = path.computeMetrics().first;
    final pathLen = metric.length;

    final baseColor = isThrowArm && throwT > 0
      ? Color.lerp(_kTeal, _kCyan, throwT * math.sin(throwT * math.pi))!
      : _kTeal;

    const kSteps = 24;
    for (int s = 0; s <= kSteps; s++) {
      final t    = s / kSteps;
      final tang = metric.getTangentForOffset(pathLen * t);
      if (tang == null) continue;
      final r = (6.8 - t * 4.6) * entryScale;
      if (r < 0.5) continue;
      canvas.drawCircle(
        tang.position,
        r,
        Paint()..color = baseColor.withOpacity((0.82 - t * 0.22) * entryScale),
      );
    }

    // Suction cups
    final suctPaint = Paint()
      ..color = const Color(0xFF80DEEA).withOpacity(0.52 * entryScale)
      ..style = PaintingStyle.stroke..strokeWidth = 0.9;
    for (int s = 3; s <= kSteps - 2; s += 4) {
      final tang = metric.getTangentForOffset(pathLen * s / kSteps);
      if (tang == null) continue;
      final r = (3.8 - s / kSteps * 2.2) * entryScale;
      if (r < 0.6) continue;
      canvas.drawCircle(tang.position, r * 0.72, suctPaint);
    }

    // Throw arm: item at tip
    if (isThrowArm && throwT > 0.18 && throwT < 0.82) {
      final tp = TextPainter(
        text: const TextSpan(text: '⚡', style: TextStyle(fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, end - Offset(tp.width / 2, tp.height / 2));
    }
  }
}

// ── Blast painter ─────────────────────────────────────────────────────────────

class _BlastPainter extends CustomPainter {
  final double t;
  final Size   screenSize;
  const _BlastPainter({required this.t, required this.screenSize});

  @override
  bool shouldRepaint(_BlastPainter o) => o.t != t;

  @override
  void paint(Canvas canvas, Size size) {
    // Creature was at top-right: ~(screenW-65, 188)
    final cx = size.width - 65.0;
    final cy = 188.0;
    final c  = Offset(cx, cy);

    // ── Phase 0 (0→0.25): White impact flash ─────────────────────────────────
    if (t < 0.25) {
      final a = (t / 0.25).clamp(0.0, 1.0) * 0.75;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withOpacity(a));
      return;
    }

    final pt = ((t - 0.25) / 0.75).clamp(0.0, 1.0);

    // ── Shockwave rings ───────────────────────────────────────────────────────
    for (int ring = 0; ring < 3; ring++) {
      final rt = (pt - ring * 0.12).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final r     = rt * (180 + ring * 40);
      final alpha = (1.0 - rt).clamp(0.0, 1.0) * 0.65;
      final colors = [_kCyan, _kPurple, _kGreen];
      canvas.drawCircle(c, r, Paint()
        ..color = colors[ring % 3].withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.0 - ring) * (1.0 - rt * 0.5));
    }

    // ── 16 shard particles ────────────────────────────────────────────────────
    final rng = math.Random(7); // deterministic seed
    for (int i = 0; i < 16; i++) {
      final angle    = i * math.pi * 2 / 16 + rng.nextDouble() * 0.35;
      final speed    = 70.0 + rng.nextDouble() * 120;
      final dist     = pt * speed;
      final pos      = c + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final alpha    = (1.0 - pt * 1.1).clamp(0.0, 1.0);
      final particleR = (4.0 + rng.nextDouble() * 5.0) * (1.0 - pt * 0.6);
      final col = i % 3 == 0 ? _kCyan : (i % 3 == 1 ? _kPurple : _kYellow);
      canvas.drawCircle(pos, particleR.clamp(0.5, 12.0), Paint()
        ..color = col.withOpacity(alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particleR * 0.5));
    }

    // ── Body remnant (expands + fades) ────────────────────────────────────────
    if (pt < 0.55) {
      final bFrac = 1.0 - pt / 0.55;
      canvas.drawCircle(c, (1.0 + pt * 1.2) * 38 * bFrac, Paint()
        ..color = _kCyan.withOpacity(0.35 * bFrac)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }

    // ── Victory text ──────────────────────────────────────────────────────────
    if (pt > 0.45) {
      final textFrac  = ((pt - 0.45) / 0.25).clamp(0.0, 1.0);
      final fadeOut   = pt > 0.85 ? (1.0 - (pt - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;
      final textAlpha = textFrac * fadeOut;
      final tp = TextPainter(
        text: TextSpan(
          text: '💥 KRAKEN DEFEATED! 💥',
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: _kYellow.withOpacity(textAlpha),
            fontSize: 15,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: _kYellow.withOpacity(textAlpha), blurRadius: 16),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.34));
    }
  }
}

// ── Creature throw countdown ring (shown on grid cells) ───────────────────────

class CreatureThrowCountdown extends StatefulWidget {
  final int secondsLeft; // 1–5
  const CreatureThrowCountdown({super.key, required this.secondsLeft});

  @override
  State<CreatureThrowCountdown> createState() => _CreatureThrowCountdownState();
}

class _CreatureThrowCountdownState extends State<CreatureThrowCountdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      value: 1.0,
    )..animateTo(0, curve: Curves.linear);
  }

  @override
  void didUpdateWidget(CreatureThrowCountdown old) {
    super.didUpdateWidget(old);
    if (old.secondsLeft != widget.secondsLeft) {
      _ring
        ..value = 1.0
        ..animateTo(0, duration: const Duration(seconds: 1), curve: Curves.linear);
    }
  }

  @override void dispose() { _ring.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final danger = widget.secondsLeft <= 2;
    final col    = danger ? _kDanger : _kCyan;
    return AnimatedBuilder(
      animation: _ring,
      builder: (ctx, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black.withOpacity(0.45),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Countdown ring
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CustomPaint(
                  painter: _RingPainter(progress: _ring.value, color: col),
                ),
              ),
            ),
            // Number
            Text(
              '${widget.secondsLeft}',
              style: TextStyle(
                fontFamily: 'Orbitron',
                color: col,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: col, blurRadius: 10)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _RingPainter({required this.progress, required this.color});

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.color != color;

  @override
  void paint(Canvas canvas, Size size) {
    final r  = math.min(size.width, size.height) / 2 - 2;
    final c  = Offset(size.width / 2, size.height / 2);
    // Background ring
    canvas.drawCircle(c, r, Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke..strokeWidth = 3);
    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      -2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }
}
