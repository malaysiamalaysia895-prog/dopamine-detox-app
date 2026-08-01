// nexus_core_overlay.dart — NEXUS CORE Boss UI (Level 40: The Orbital Station)
// Dark-metal mechanical squid with glowing red eye, 8 thin tentacles floating
// in the background. Boss sits ABOVE the grid, never blocking playable cells.
// Entry → Active (hacking laser / crosshair / hacked sparks) → Stunned → WinBlast.

import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/nexus_core_controller.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kMetal     = Color(0xFF1C2233);
const _kMetalMid  = Color(0xFF2D3A52);
const _kEyeRed    = Color(0xFFFF1C1C);
const _kEyeGlow   = Color(0xFFFF6060);
const _kGold      = Color(0xFFFFD700);
const _kEMP       = Color(0xFF44AAFF);
const _kHackSpark = Color(0xFFFF3A3A);
const _kCrossRed  = Color(0xFFFF2020);

/// Boss resting Y position inside the overlay Stack (fraction of screen height).
/// Placed between quota panel and grid — roughly top 22% of screen.
double _bossRestY(Size sz) => sz.height * 0.205;

// ── Public Widget ─────────────────────────────────────────────────────────────

class NexusCoreOverlay extends StatelessWidget {
  final NexusCoreController controller;
  final Rect? Function(int col, int row) getCellRect;
  final bool isDialogActive;
  const NexusCoreOverlay({
    super.key,
    required this.controller,
    required this.getCellRect,
    this.isDialogActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final p = controller.phase;
        if (p == NexusCorePhase.idle) return const SizedBox.shrink();
        if (isDialogActive) return const SizedBox.shrink();
        return Stack(children: [
          // Boss body (entry / active / stunned / winBlast)
          if (p == NexusCorePhase.entry)   _EntryBoss(controller: controller),
          if (p == NexusCorePhase.active)  _ActiveBoss(controller: controller),
          if (p == NexusCorePhase.stunned) _StunnedBoss(controller: controller),
          if (p == NexusCorePhase.winBlast) _WinBlast(controller: controller),

          // Cell-level effects (active only)
          if (p == NexusCorePhase.active) ...[
            _CrosshairEffect(controller: controller, getCellRect: getCellRect),
            _HackedCellEffects(controller: controller, getCellRect: getCellRect),
          ],

          // Hint ticker (active + stunned)
          if (p == NexusCorePhase.active || p == NexusCorePhase.stunned)
            _HintTicker(controller: controller),

          // Dialogue bubble (active)
          if (p == NexusCorePhase.active && controller.dialogueText != null)
            _DialogueBubble(text: controller.dialogueText!),
        ]);
      },
    );
  }
}

// ── Entry Animation ───────────────────────────────────────────────────────────

class _EntryBoss extends StatefulWidget {
  final NexusCoreController controller;
  const _EntryBoss({required this.controller});
  @override State<_EntryBoss> createState() => _EntryBossState();
}
class _EntryBossState extends State<_EntryBoss> with TickerProviderStateMixin {
  late final AnimationController _drop;
  late final AnimationController _glitch;
  late final AnimationController _eyeFlash;
  late final Animation<double> _dropAnim;
  late final Animation<double> _glitchAnim;
  late final Animation<double> _eyeAnim;

  @override
  void initState() {
    super.initState();
    _drop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _glitch = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _eyeFlash = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);

    _dropAnim = CurvedAnimation(parent: _drop, curve: Curves.easeOutBack);
    _glitchAnim = _glitch;
    _eyeAnim = _eyeFlash;
    _drop.forward();
  }

  @override
  void dispose() {
    _drop.dispose(); _glitch.dispose(); _eyeFlash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final restY = _bossRestY(sz);
    return AnimatedBuilder(
      animation: Listenable.merge([_drop, _glitch, _eyeFlash]),
      builder: (_, __) {
        final y = -140.0 + (_dropAnim.value * (restY + 140.0));
        final glitchColor = Color.lerp(const Color(0xFF00FF44), _kEyeRed, _glitchAnim.value)!;
        return Positioned(
          top: y,
          left: 0, right: 0,
          child: Center(
            child: _NexusBody(
              eyeColor: Color.lerp(_kEyeGlow, _kEyeRed, _eyeAnim.value)!,
              bodyColor: _kMetal,
              tentacleOpacity: _dropAnim.value * 0.7,
              glitchColor: glitchColor,
              glitchOpacity: (1 - _dropAnim.value) * 0.6 + 0.2,
              scale: 1.0,
            ),
          ),
        );
      },
    );
  }
}

// ── Active Boss (floating bob) ────────────────────────────────────────────────

class _ActiveBoss extends StatefulWidget {
  final NexusCoreController controller;
  const _ActiveBoss({required this.controller});
  @override State<_ActiveBoss> createState() => _ActiveBossState();
}
class _ActiveBossState extends State<_ActiveBoss> with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _eyePulse;
  late final Animation<double> _bobAnim;
  late final Animation<double> _eyeAnim;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _eyePulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _bobAnim  = CurvedAnimation(parent: _bob, curve: Curves.easeInOut);
    _eyeAnim  = CurvedAnimation(parent: _eyePulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _bob.dispose(); _eyePulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final baseY = _bossRestY(sz);
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _eyePulse]),
      builder: (_, __) {
        final y = baseY + (_bobAnim.value - 0.5) * 10.0;
        final eyeC = Color.lerp(const Color(0xFFFF4040), const Color(0xFFFF0000), _eyeAnim.value)!;
        // Attack countdown laser charge effect
        final isTargeting = widget.controller.isTargeting;
        return Positioned(
          top: y,
          left: 0, right: 0,
          child: Center(
            child: _NexusBody(
              eyeColor: eyeC,
              bodyColor: _kMetal,
              tentacleOpacity: 0.65,
              glitchColor: _kEyeRed,
              glitchOpacity: isTargeting ? 0.7 : 0.0,
              scale: 1.0,
              laserCharging: isTargeting,
            ),
          ),
        );
      },
    );
  }
}

// ── Stunned Boss ──────────────────────────────────────────────────────────────

class _StunnedBoss extends StatefulWidget {
  final NexusCoreController controller;
  const _StunnedBoss({required this.controller});
  @override State<_StunnedBoss> createState() => _StunnedBossState();
}
class _StunnedBossState extends State<_StunnedBoss> with TickerProviderStateMixin {
  late final AnimationController _empRing;
  @override void initState() {
    super.initState();
    _empRing = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }
  @override void dispose() { _empRing.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final y  = _bossRestY(sz);
    return AnimatedBuilder(
      animation: _empRing,
      builder: (_, __) {
        return Positioned(
          top: y - 10,
          left: 0, right: 0,
          child: Center(
            child: SizedBox(
              width: 160, height: 130,
              child: Stack(alignment: Alignment.center, children: [
                // EMP ring
                CustomPaint(
                  size: const Size(160, 130),
                  painter: _EmpRingPainter(_empRing.value),
                ),
                // Grey body
                _NexusBody(
                  eyeColor: Colors.transparent,
                  bodyColor: const Color(0xFF3A3A3A),
                  tentacleOpacity: 0.3,
                  glitchColor: Colors.transparent,
                  glitchOpacity: 0,
                  scale: 1.0,
                ),
                // STUNNED label
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kEMP.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: _kEMP.withOpacity(0.5), blurRadius: 8)],
                    ),
                    child: Text(
                      'STUNNED ${widget.controller.stunSecondsLeft}s',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Win Blast ─────────────────────────────────────────────────────────────────

class _WinBlast extends StatefulWidget {
  final NexusCoreController controller;
  const _WinBlast({required this.controller});
  @override State<_WinBlast> createState() => _WinBlastState();
}
class _WinBlastState extends State<_WinBlast> with TickerProviderStateMixin {
  late final AnimationController _laser;
  late final AnimationController _shake;
  late final AnimationController _explode;
  late final AnimationController _text;

  @override
  void initState() {
    super.initState();
    _laser   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _shake   = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _explode = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _text    = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _laser.addStatusListener((s) { if (s == AnimationStatus.completed) { _explode.forward(); _text.forward(); } });
  }

  @override
  void dispose() { _laser.dispose(); _shake.dispose(); _explode.dispose(); _text.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final bossY = _bossRestY(sz);
    final bossCX = sz.width / 2;
    final bossCY = bossY + 40.0;
    // Laser fires from bottom-center (quota area approx 72% height)
    final quotaY = sz.height * 0.72;

    return AnimatedBuilder(
      animation: Listenable.merge([_laser, _shake, _explode, _text]),
      builder: (_, __) {
        final shakeX = _shake.isAnimating ? (math.sin(_shake.value * math.pi * 18) * 6 * (1 - _shake.value)) : 0.0;
        return Stack(children: [
          // Golden laser beam
          if (_laser.value > 0 && _explode.value < 1)
            Positioned.fill(
              child: CustomPaint(
                painter: _GoldenLaserPainter(
                  from: Offset(bossCX, quotaY),
                  to: Offset(bossCX + shakeX, bossCY),
                  progress: _laser.value,
                ),
              ),
            ),

          // Boss — shaking then exploding
          Positioned(
            top: bossY + shakeX * 0.5,
            left: 0, right: 0,
            child: Center(
              child: _explode.value < 0.3
                ? _NexusBody(
                    eyeColor: _kGold,
                    bodyColor: Color.lerp(_kMetal, Colors.orange.shade900, _explode.value * 3)!,
                    tentacleOpacity: 1 - _explode.value * 3,
                    glitchColor: _kGold,
                    glitchOpacity: _laser.value,
                    scale: 1.0 + _explode.value * 0.5,
                  )
                : const SizedBox.shrink(),
            ),
          ),

          // Explosion burst
          if (_explode.value > 0.1)
            Positioned(
              top: bossCY - 60,
              left: bossCX - 60,
              child: CustomPaint(
                size: const Size(120, 120),
                painter: _ExplosionPainter(_explode.value),
              ),
            ),

          // SYSTEM OVERLOAD text
          if (_explode.value > 0.15 && _explode.value < 0.7)
            Positioned(
              top: bossCY - 20,
              left: 0, right: 0,
              child: Center(
                child: Text(
                  'SYSTEM OVERLOAD ⚠️',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.orange, blurRadius: 12)],
                  ),
                ),
              ),
            ),

          // Victory text
          if (_text.value > 0.5)
            Positioned(
              top: sz.height * 0.38,
              left: 16, right: 16,
              child: Opacity(
                opacity: (_text.value - 0.5) * 2,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.82),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kGold, width: 2),
                      boxShadow: [BoxShadow(color: _kGold.withOpacity(0.4), blurRadius: 24)],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('LEVEL 40 CLEARED', style: TextStyle(color: _kGold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: _kGold, blurRadius: 10)])),
                      const SizedBox(height: 4),
                      const Text('NEXUS CORE DESTROYED', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      const Text('🛸💥🤖', style: TextStyle(fontSize: 28)),
                    ]),
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

// ── Crosshair on Targeted Cell ────────────────────────────────────────────────

class _CrosshairEffect extends StatefulWidget {
  final NexusCoreController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _CrosshairEffect({required this.controller, required this.getCellRect});
  @override State<_CrosshairEffect> createState() => _CrosshairEffectState();
}
class _CrosshairEffectState extends State<_CrosshairEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  @override void initState() { super.initState(); _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true); }
  @override void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final target = widget.controller.targetedCell;
    if (target == null) return const SizedBox.shrink();
    final rect = widget.getCellRect(target.$1, target.$2);
    if (rect == null) return const SizedBox.shrink();
    final secsLeft = widget.controller.targetSecondsLeft;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final glow = 0.6 + _pulse.value * 0.4;
        return Positioned(
          left: rect.left - 6, top: rect.top - 6,
          width: rect.width + 12, height: rect.height + 12,
          child: Stack(alignment: Alignment.center, children: [
            // Pulsing red border
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kCrossRed.withOpacity(glow), width: 2.5),
                boxShadow: [BoxShadow(color: _kCrossRed.withOpacity(glow * 0.5), blurRadius: 10, spreadRadius: 2)],
              ),
            ),
            // Crosshair lines
            CustomPaint(
              size: Size(rect.width + 12, rect.height + 12),
              painter: _CrosshairPainter(glow),
            ),
            // Countdown
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: _kCrossRed.withOpacity(0.85), borderRadius: BorderRadius.circular(4)),
                child: Text('${secsLeft}s', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Hacked Cell Sparks ────────────────────────────────────────────────────────

class _HackedCellEffects extends StatefulWidget {
  final NexusCoreController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _HackedCellEffects({required this.controller, required this.getCellRect});
  @override State<_HackedCellEffects> createState() => _HackedCellEffectsState();
}
class _HackedCellEffectsState extends State<_HackedCellEffects> with SingleTickerProviderStateMixin {
  late final AnimationController _spark;
  @override void initState() { super.initState(); _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..repeat(); }
  @override void dispose() { _spark.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.hackedCells.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _spark,
      builder: (_, __) {
        final cells = widget.controller.hackedCells.toList();
        return Stack(
          children: cells.map((cell) {
            final rect = widget.getCellRect(cell.$1, cell.$2);
            if (rect == null) return const SizedBox.shrink();
            return Positioned(
              left: rect.left, top: rect.top,
              width: rect.width, height: rect.height,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _HackSparkPainter(_spark.value, cell.hashCode),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Hint Ticker ───────────────────────────────────────────────────────────────

class _HintTicker extends StatelessWidget {
  final NexusCoreController controller;
  const _HintTicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final hint = kNexusHints[controller.hintIndex % kNexusHints.length];
    final isTargeting = controller.isTargeting;
    return Positioned(
      top: sz.height * 0.098,  // just below energy bar
      left: 0, right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Container(
            key: ValueKey(isTargeting ? 'dodge' : controller.hintIndex),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isTargeting ? _kCrossRed.withOpacity(0.88) : Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isTargeting ? _kCrossRed : Colors.white24, width: 1),
            ),
            child: Text(
              isTargeting ? '⚡ MERGE QUICK TO DODGE! ⚡' : '💡 $hint',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: isTargeting ? FontWeight.w900 : FontWeight.w500,
                letterSpacing: isTargeting ? 1.2 : 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dialogue Bubble ───────────────────────────────────────────────────────────

class _DialogueBubble extends StatelessWidget {
  final String text;
  const _DialogueBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return Positioned(
      top: _bossRestY(sz) - 42,
      left: sz.width * 0.52,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.82),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(color: _kEyeRed.withOpacity(0.7), width: 1),
          boxShadow: [BoxShadow(color: _kEyeRed.withOpacity(0.3), blurRadius: 8)],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Boss Body Widget ──────────────────────────────────────────────────────────

class _NexusBody extends StatelessWidget {
  final Color eyeColor;
  final Color bodyColor;
  final double tentacleOpacity;
  final Color glitchColor;
  final double glitchOpacity;
  final double scale;
  final bool laserCharging;
  const _NexusBody({
    required this.eyeColor,
    required this.bodyColor,
    required this.tentacleOpacity,
    required this.glitchColor,
    required this.glitchOpacity,
    required this.scale,
    this.laserCharging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 120, height: 100,
        child: CustomPaint(
          painter: _NexusBodyPainter(
            eyeColor: eyeColor,
            bodyColor: bodyColor,
            tentacleOpacity: tentacleOpacity,
            glitchColor: glitchColor,
            glitchOpacity: glitchOpacity,
            laserCharging: laserCharging,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

class _NexusBodyPainter extends CustomPainter {
  final Color eyeColor, bodyColor, glitchColor;
  final double tentacleOpacity, glitchOpacity;
  final bool laserCharging;
  const _NexusBodyPainter({
    required this.eyeColor, required this.bodyColor,
    required this.tentacleOpacity, required this.glitchColor,
    required this.glitchOpacity, required this.laserCharging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;

    // ── Tentacles (8 thin mechanical arms radiating downward) ──
    if (tentacleOpacity > 0) {
      final tPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = _kMetalMid.withOpacity(tentacleOpacity);
      final angles = List.generate(8, (i) => (math.pi * 0.15) + i * (math.pi * 0.85 / 7));
      for (int i = 0; i < 8; i++) {
        final a = angles[i];
        final len = 38.0 + (i % 3) * 12.0;
        final mx = cx + math.cos(a - math.pi / 2) * (len * 0.55);
        final my = cy + math.sin(a - math.pi / 2) * (len * 0.55) + 26;
        final ex = cx + math.cos(a - math.pi / 2) * len;
        final ey = cy + math.sin(a - math.pi / 2) * len + 26;
        final path = Path()
          ..moveTo(cx + math.cos(a - math.pi / 2) * 28, cy + math.sin(a - math.pi / 2) * 28 + 20)
          ..quadraticBezierTo(mx + (i.isEven ? 8 : -8), my, ex, ey);
        canvas.drawPath(path, tPaint);
        // Joint dot
        canvas.drawCircle(Offset(ex, ey), 2.0,
          Paint()..color = _kMetalMid.withOpacity(tentacleOpacity * 0.8));
      }
    }

    // ── Body outer glow ──
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = bodyColor.withOpacity(0.55);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 86, height: 60), glowPaint);

    // ── Body dark shell ──
    final bodyPaint = Paint()
      ..shader = RadialGradient(colors: [_kMetalMid, bodyColor]).createShader(
          Rect.fromCenter(center: Offset(cx, cy), width: 82, height: 58));
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 82, height: 58), bodyPaint);

    // ── Body rim (metallic edge) ──
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 82, height: 58),
      Paint()..style = PaintingStyle.stroke..color = const Color(0xFF4A5A7A)..strokeWidth = 1.5,
    );

    // ── Panel lines (mechanical detail) ──
    final linePaint = Paint()..color = const Color(0xFF3A4A60)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 16, cy - 14), Offset(cx - 16, cy + 14), linePaint);
    canvas.drawLine(Offset(cx + 16, cy - 14), Offset(cx + 16, cy + 14), linePaint);
    canvas.drawLine(Offset(cx - 34, cy), Offset(cx + 34, cy), linePaint);

    // ── Eye lens (glowing red circle) ──
    if (eyeColor != Colors.transparent) {
      // Outer glow
      canvas.drawCircle(Offset(cx, cy), 18,
        Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
               ..color = eyeColor.withOpacity(0.6));
      // Mid ring
      canvas.drawCircle(Offset(cx, cy), 16,
        Paint()..color = eyeColor.withOpacity(0.2));
      // Core lens gradient
      canvas.drawCircle(Offset(cx, cy), 13,
        Paint()..shader = RadialGradient(
          colors: [Colors.white.withOpacity(0.9), eyeColor, eyeColor.withOpacity(0.4)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 13)));
      // Pupil
      canvas.drawCircle(Offset(cx + 2, cy - 2), 4,
        Paint()..color = Colors.black.withOpacity(0.8));
      // Lens glint
      canvas.drawCircle(Offset(cx - 4, cy - 5), 2.5,
        Paint()..color = Colors.white.withOpacity(0.7));

      // Laser charge ring
      if (laserCharging) {
        canvas.drawCircle(Offset(cx, cy), 22,
          Paint()..style = PaintingStyle.stroke
                 ..color = _kEyeRed.withOpacity(0.9)
                 ..strokeWidth = 2.5
                 ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }

    // ── Glitch overlay ──
    if (glitchOpacity > 0 && glitchColor != Colors.transparent) {
      final rng = Random(42);
      final gPaint = Paint()..color = glitchColor.withOpacity(glitchOpacity * 0.4);
      for (int i = 0; i < 5; i++) {
        final y = cy - 25 + rng.nextDouble() * 50;
        final w = 10.0 + rng.nextDouble() * 35;
        final x = cx - 40 + rng.nextDouble() * 60;
        canvas.drawRect(Rect.fromLTWH(x, y, w, 2.5), gPaint);
      }
    }
  }

  @override bool shouldRepaint(_NexusBodyPainter old) => true;
}

// ── Crosshair Painter ────────────────────────────────────────────────────────

class _CrosshairPainter extends CustomPainter {
  final double intensity;
  const _CrosshairPainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final p = Paint()
      ..color = _kCrossRed.withOpacity(intensity)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const armLen = 10.0;
    // Crosshair arms
    canvas.drawLine(Offset(cx - armLen, cy), Offset(cx + armLen, cy), p);
    canvas.drawLine(Offset(cx, cy - armLen), Offset(cx, cy + armLen), p);
    // Corner brackets
    final c = Paint()..color = _kCrossRed.withOpacity(intensity * 0.7)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    const b = 7.0;
    for (final dx in [-1.0, 1.0]) {
      for (final dy in [-1.0, 1.0]) {
        canvas.drawLine(Offset(cx + dx * (size.width/2 - 4), cy + dy * (size.height/2 - 4)),
                        Offset(cx + dx * (size.width/2 - 4 - b * dx.abs()), cy + dy * (size.height/2 - 4)), c);
        canvas.drawLine(Offset(cx + dx * (size.width/2 - 4), cy + dy * (size.height/2 - 4)),
                        Offset(cx + dx * (size.width/2 - 4), cy + dy * (size.height/2 - 4 - b * dy.abs())), c);
      }
    }
  }

  @override bool shouldRepaint(_CrosshairPainter old) => old.intensity != intensity;
}

// ── Hack Spark Painter ────────────────────────────────────────────────────────

class _HackSparkPainter extends CustomPainter {
  final double t;
  final int seed;
  const _HackSparkPainter(this.t, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed + (t * 8).toInt());
    final p = Paint()..style = PaintingStyle.fill;
    // Red glitch scanlines
    for (int i = 0; i < 4; i++) {
      final y = rng.nextDouble() * size.height;
      final w = 4 + rng.nextDouble() * (size.width - 8);
      p.color = _kHackSpark.withOpacity(0.3 + rng.nextDouble() * 0.4);
      canvas.drawRect(Rect.fromLTWH(rng.nextDouble() * 6, y, w, 2), p);
    }
    // Corner sparks
    p.color = _kHackSpark.withOpacity(0.6 + rng.nextDouble() * 0.4);
    for (int i = 0; i < 3; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(sx, sy), 1.2 + rng.nextDouble() * 2, p);
    }
    // Red border flash
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..style = PaintingStyle.stroke..color = _kHackSpark.withOpacity(0.5 + 0.3 * t)..strokeWidth = 2,
    );
  }

  @override bool shouldRepaint(_HackSparkPainter old) => old.t != t;
}

// ── EMP Ring Painter ──────────────────────────────────────────────────────────

class _EmpRingPainter extends CustomPainter {
  final double t;
  const _EmpRingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = 55.0 + t * 30.0;
    canvas.drawCircle(Offset(cx, cy), r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _kEMP.withOpacity((1 - t) * 0.7)
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  @override bool shouldRepaint(_EmpRingPainter old) => old.t != t;
}

// ── Golden Laser Painter ──────────────────────────────────────────────────────

class _GoldenLaserPainter extends CustomPainter {
  final Offset from, to;
  final double progress;
  const _GoldenLaserPainter({required this.from, required this.to, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final end = Offset.lerp(from, to, progress)!;
    // Core beam
    canvas.drawLine(from, end, Paint()
      ..color = _kGold
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // Outer glow
    canvas.drawLine(from, end, Paint()
      ..color = _kGold.withOpacity(0.35)
      ..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // White hot core
    canvas.drawLine(from, end, Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2);
  }

  @override bool shouldRepaint(_GoldenLaserPainter old) =>
    old.progress != progress || old.from != from || old.to != to;
}

// ── Explosion Painter ─────────────────────────────────────────────────────────

class _ExplosionPainter extends CustomPainter {
  final double t;
  const _ExplosionPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final rng = Random(77);
    // Radial burst rays
    for (int i = 0; i < 16; i++) {
      final a = i * (math.pi * 2 / 16);
      final len = 20 + t * 50 + rng.nextDouble() * 15;
      final opacity = (1 - t).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(cx + math.cos(a) * 8, cy + math.sin(a) * 8),
        Offset(cx + math.cos(a) * len, cy + math.sin(a) * len),
        Paint()
          ..color = (i.isEven ? _kGold : Colors.orange).withOpacity(opacity)
          ..strokeWidth = 3 - t * 2,
      );
    }
    // Center flash
    canvas.drawCircle(Offset(cx, cy), 20 * t,
      Paint()..color = Colors.white.withOpacity((1 - t * 1.5).clamp(0, 1))
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Debris particles
    for (int i = 0; i < 12; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = 10 + rng.nextDouble() * 40 * t;
      canvas.drawCircle(
        Offset(cx + math.cos(a) * d, cy + math.sin(a) * d),
        2 + rng.nextDouble() * 3,
        Paint()..color = (i.isEven ? Colors.orange : Colors.red).withOpacity((1 - t).clamp(0, 1)),
      );
    }
  }

  @override bool shouldRepaint(_ExplosionPainter old) => old.t != t;
}
