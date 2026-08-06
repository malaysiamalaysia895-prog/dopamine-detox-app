// ============================================================
// terra_lich_overlay.dart  —  Terra-Lich Mech Boss  (v3 — AAA REWRITE)
// Level 42  ·  "Terraforming"  |  Masters of the Universe
//
// FIXES:
//   • IgnorePointer wraps overlay → game grid / 3D printer respond again
//   • Full visual rewrite: metallic gradient fills, per-part animation,
//     ambient particle orbit, 3-stream thruster, zigzag scanner laser,
//     branching EMP beam, cinematic boot sequence
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/terra_lich_controller.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kMetal     = Color(0xFF0D0D0D);
const _kMetalMid  = Color(0xFF1C1C1C);
const _kMetalHi   = Color(0xFF2A2A2A);
const _kMetalEdge = Color(0xFF3A3A3A);
const _kMetalShine= Color(0xFF4A4A4A);
const _kNeonGreen = Color(0xFF39FF14);
const _kGreenDim  = Color(0xFF1C7A00);
const _kGreenGlow = Color(0xFF00FF55);
const _kVisor     = Color(0xFFFF4500);
const _kOrange    = Color(0xFFFF6D00);
const _kRed       = Color(0xFFFF1744);
const _kAmber     = Color(0xFFFF8C00);
const _kFire1     = Color(0xFFFF3800);
const _kFire2     = Color(0xFFFF7200);
const _kScan      = Color(0xFFFF1744);
const _kWhite     = Color(0xFFFFFFFF);
const _kCyan      = Color(0xFF00FFFF);

// ── Entry point ───────────────────────────────────────────────────────────────

class TerraLichOverlay extends StatelessWidget {
  final TerraLichController controller;
  const TerraLichOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final p = controller.phase;
        if (p == TerraLichPhase.idle) return const SizedBox.shrink();
        // IgnorePointer: overlay must NEVER consume touch events from grid/printer
        if (p == TerraLichPhase.winBlast) {
          return IgnorePointer(child: _WinBlastPhase(controller: controller));
        }
        return IgnorePointer(child: _ActivePhase(controller: controller));
      },
    );
  }
}

// ── Active / Entry / Attack Phase ─────────────────────────────────────────────

class _ActivePhase extends StatefulWidget {
  final TerraLichController controller;
  const _ActivePhase({required this.controller});
  @override State<_ActivePhase> createState() => _ActivePhaseState();
}

class _ActivePhaseState extends State<_ActivePhase>
    with TickerProviderStateMixin {

  late AnimationController _entry;     // 0→1 boss descends into position (3.8 s)
  late AnimationController _bob;       // 0→1→0 gentle hover loop (2.2 s)
  late AnimationController _thruster;  // 0→1 thruster flicker loop (0.42 s)
  late AnimationController _idle;      // 0→1 current idle animation (1.8 s)
  late AnimationController _charge;    // 0→1 charge-up (1.5 s)
  late AnimationController _beam;      // 0→1 EMP beam strike (0.8 s)
  // NEW controllers
  late AnimationController _ambient;   // 0→1 ambient particle orbit / arm oscillation (3.5 s)
  late AnimationController _pulse;     // 0→1 reactor + pipe brightness pulse (1.1 s)

  TerraLichPhase    _lastPhase    = TerraLichPhase.idle;
  TerraLichIdleAnim _lastIdleAnim = TerraLichIdleAnim.none;

  @override
  void initState() {
    super.initState();
    _entry    = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))..forward();
    _bob      = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _thruster = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..repeat(reverse: true);
    _idle     = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _charge   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _beam     = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ambient  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat();
    _pulse    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

    widget.controller.addListener(_onControllerChange);
    _lastPhase    = widget.controller.phase;
    _lastIdleAnim = widget.controller.idleAnim;
  }

  void _onControllerChange() {
    if (!mounted) return;
    final c = widget.controller;
    if (c.phase != _lastPhase) {
      if (c.phase == TerraLichPhase.chargingUp) { _charge.forward(from: 0); _beam.value = 0; }
      if (c.phase == TerraLichPhase.striking)  { _beam.forward(from: 0); }
      if (c.phase == TerraLichPhase.active && _lastPhase == TerraLichPhase.striking) {
        _charge.value = 0; _beam.value = 0;
      }
      _lastPhase = c.phase;
    }
    if (c.idleAnim != _lastIdleAnim) {
      if (c.idleAnim != TerraLichIdleAnim.none) { _idle.forward(from: 0); }
      else                                       { _idle.value = 0; }
      _lastIdleAnim = c.idleAnim;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _entry.dispose(); _bob.dispose(); _thruster.dispose();
    _idle.dispose();  _charge.dispose(); _beam.dispose();
    _ambient.dispose(); _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entry, _bob, _thruster, _idle, _charge, _beam, _ambient, _pulse]),
        builder: (ctx, _) {
          final c   = widget.controller;
          final raw = _entry.value.clamp(0.0, 1.0);
          final p1  = (raw / 0.30).clamp(0.0, 1.0);
          final p2  = ((raw - 0.30) / 0.25).clamp(0.0, 1.0);
          final p3  = ((raw - 0.55) / 0.45).clamp(0.0, 1.0);
          final eT  = raw < 0.30 ? Curves.easeIn.transform(p1) : 1.0;
          final bT  = raw >= 1.0 ? _bob.value : 0.0;

          return CustomPaint(
            painter: _TerraLichPainter(
              entryT:    eT,
              phase1T:   p1,
              phase2T:   p2,
              phase3T:   p3,
              bobT:      bT,
              thrusterT: _thruster.value,
              idleAnim:  c.idleAnim,
              idleT:     _idle.value,
              chargeT:   _charge.value,
              beamT:     _beam.value,
              ambientT:  _ambient.value,
              pulseT:    _pulse.value,
              phase:     c.phase,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

// ── Win Blast Phase ───────────────────────────────────────────────────────────

class _WinBlastPhase extends StatefulWidget {
  final TerraLichController controller;
  const _WinBlastPhase({required this.controller});
  @override State<_WinBlastPhase> createState() => _WinBlastPhaseState();
}

class _WinBlastPhaseState extends State<_WinBlastPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) => CustomPaint(
          painter: _WinBlastPainter(t: _ctrl.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Main Painter  ─────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _TerraLichPainter extends CustomPainter {
  final double entryT, phase1T, phase2T, phase3T;
  final double bobT, thrusterT;
  final TerraLichIdleAnim idleAnim;
  final double idleT, chargeT, beamT;
  final double ambientT, pulseT;   // NEW
  final TerraLichPhase phase;

  const _TerraLichPainter({
    required this.entryT,  required this.phase1T, required this.phase2T,
    required this.phase3T, required this.bobT,    required this.thrusterT,
    required this.idleAnim, required this.idleT,  required this.chargeT,
    required this.beamT,   required this.ambientT, required this.pulseT,
    required this.phase,
  });

  @override
  bool shouldRepaint(_TerraLichPainter o) =>
      o.entryT != entryT || o.phase1T != phase1T || o.phase2T != phase2T ||
      o.phase3T != phase3T || o.bobT != bobT || o.thrusterT != thrusterT ||
      o.idleAnim != idleAnim || o.idleT != idleT || o.chargeT != chargeT ||
      o.beamT != beamT || o.ambientT != ambientT || o.pulseT != pulseT ||
      o.phase != phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bobOffset  = math.sin(bobT * math.pi) * 5.0;
    const baseTop    = 32.0;
    final entrySlide = (1.0 - entryT) * -380.0;
    final ht = baseTop + entrySlide + bobOffset;

    final onlineT = phase3T <= 0.0 ? 0.0 : phase3T;
    final flexUp  = idleAnim == TerraLichIdleAnim.mechanicalFlex
        ? math.sin(idleT * math.pi) * 8.0 : 0.0;
    final chargeAngle = Curves.easeInOut.transform(chargeT);

    // Phase 2: screen shake
    if (phase2T > 0 && phase2T < 1.0) {
      final shakeFade = (1.0 - phase2T).clamp(0.0, 1.0);
      final shakeAmt  = 10.0 * shakeFade;
      canvas.save();
      canvas.translate(
        math.sin(phase2T * 55) * shakeAmt,
        math.cos(phase2T * 42) * shakeAmt * 0.6,
      );
    }

    // Draw order: atmosphere → thruster fire → body → arms → head → FX
    _drawBodyGlow(canvas, size, cx, ht, onlineT);
    if (phase2T > 0) _drawEntryBlast(canvas, size, cx, ht, phase2T);
    _drawThrusterFire(canvas, cx, ht, thrusterT,
        idleAnim == TerraLichIdleAnim.mechanicalFlex ? idleT : 0.0,
        phase2T, onlineT);
    _drawThruster(canvas, cx, ht);
    _drawChest(canvas, cx, ht, flexUp, chargeAngle, onlineT, pulseT);
    _drawEnergyPipes(canvas, cx, ht, flexUp,
        idleAnim == TerraLichIdleAnim.energyPulse ? idleT : 0.0,
        chargeAngle, onlineT, pulseT);
    _drawArms(canvas, cx, ht, flexUp, chargeAngle, onlineT, ambientT);
    _drawNeck(canvas, cx, ht, flexUp, onlineT, pulseT);
    _drawHelmet(canvas, cx, ht, flexUp, ambientT);
    _drawVisor(canvas, cx, ht, flexUp, onlineT, pulseT);
    if (onlineT >= 1.0) _drawAmbientParticles(canvas, cx, ht, ambientT, pulseT);

    if (phase3T > 0 && phase3T < 1.0) _drawBootSequence(canvas, size, cx, ht, phase3T);
    if (phase2T > 0 && phase2T < 1.0) canvas.restore();

    // Idle animation overlays
    if (idleAnim == TerraLichIdleAnim.scannerSweep && idleT > 0 && onlineT >= 1.0) {
      _drawScannerLaser(canvas, size, cx, ht, idleT);
    }
    if (chargeT > 0) _drawChargeEffect(canvas, cx, ht, chargeAngle, pulseT);
    if (beamT > 0)   _drawEmpBeam(canvas, size, cx, ht, beamT);
  }

  // ── Atmospheric body glow ──────────────────────────────────────────────────
  void _drawBodyGlow(Canvas canvas, Size size, double cx, double ht, double onlineT) {
    if (onlineT <= 0) return;
    final center = Offset(cx, ht + 130);
    canvas.drawCircle(center, 90,
      Paint()
        ..color = _kNeonGreen.withOpacity(0.04 * onlineT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    canvas.drawCircle(center, 50,
      Paint()
        ..color = _kOrange.withOpacity(0.03 * onlineT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25));
  }

  // ── Ambient orbiting particles ─────────────────────────────────────────────
  void _drawAmbientParticles(Canvas canvas, double cx, double ht,
      double ambientT, double pulseT) {
    final rng = math.Random(77);
    for (int i = 0; i < 12; i++) {
      final baseAngle = i * math.pi * 2 / 12;
      final speed     = 0.4 + rng.nextDouble() * 0.6;
      final radius    = 70.0 + rng.nextDouble() * 30.0;
      final angle     = baseAngle + ambientT * 2 * math.pi * speed;
      final vertBase  = ht + 130.0;
      final px = cx + math.cos(angle) * radius;
      final py = vertBase + math.sin(angle) * radius * 0.35; // ellipse orbit
      final pr = 1.5 + rng.nextDouble() * 2.0;
      final alpha = (0.5 + 0.5 * pulseT) * (0.4 + rng.nextDouble() * 0.4);
      final col = i % 3 == 0 ? _kNeonGreen : (i % 3 == 1 ? _kOrange : _kGreenGlow);
      canvas.drawCircle(Offset(px, py), pr,
        Paint()
          ..color = col.withOpacity(alpha.clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 1.2));
    }
  }

  // ── Helmet ────────────────────────────────────────────────────────────────
  void _drawHelmet(Canvas canvas, double cx, double ht, double flexUp, double ambientT) {
    final top = ht - flexUp;

    final helmetPath = Path()
      ..moveTo(cx - 20, top + 2)
      ..lineTo(cx + 20, top + 2)
      ..quadraticBezierTo(cx + 35, top + 4,  cx + 36, top + 18)
      ..lineTo(cx + 36, top + 40)
      ..quadraticBezierTo(cx + 34, top + 52, cx + 22, top + 54)
      ..lineTo(cx - 22, top + 54)
      ..quadraticBezierTo(cx - 34, top + 52, cx - 36, top + 40)
      ..lineTo(cx - 36, top + 18)
      ..quadraticBezierTo(cx - 35, top + 4,  cx - 20, top + 2)
      ..close();

    final helmetBounds = Rect.fromLTWH(cx - 36, top, 72, 54);

    // Metallic gradient fill — left-top bright, right-bottom dark
    canvas.drawPath(helmetPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kMetalHi, _kMetalMid, _kMetal, const Color(0xFF080808)],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(helmetBounds));

    // Panel edge highlight (top chamfer bright strip)
    canvas.drawPath(helmetPath, Paint()
      ..color = _kMetalShine.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    // Outer edge
    canvas.drawPath(helmetPath, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8);

    // Top ridge (crest)
    final ridgePath = Path()
      ..moveTo(cx - 14, top + 2)
      ..lineTo(cx + 14, top + 2)
      ..lineTo(cx + 10, top - 7)
      ..lineTo(cx,      top - 10)
      ..lineTo(cx - 10, top - 7)
      ..close();
    canvas.drawPath(ridgePath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_kMetalEdge, _kMetalMid],
      ).createShader(Rect.fromLTWH(cx - 14, top - 10, 28, 12)));
    canvas.drawPath(ridgePath, Paint()
      ..color = _kOrange.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Horizontal panel lines (internal detail)
    for (int li = 0; li < 3; li++) {
      final ly = top + 12 + li * 10.0;
      final lw = 18.0 - li * 3.0;
      canvas.drawLine(
        Offset(cx - lw, ly), Offset(cx + lw, ly),
        Paint()..color = _kMetalEdge.withOpacity(0.5)..strokeWidth = 0.8);
    }

    // Side ear-panels — metallic gradient
    for (final side in [-1, 1]) {
      final ex = cx + side * 36.0;
      final earPath = Path()
        ..moveTo(ex,             top + 16)
        ..lineTo(ex + side * 9, top + 20)
        ..lineTo(ex + side * 9, top + 38)
        ..lineTo(ex,             top + 42)
        ..close();
      final earBounds = side == -1
          ? Rect.fromLTWH(cx - 45, top + 16, 9, 26)
          : Rect.fromLTWH(cx + 36, top + 16, 9, 26);
      canvas.drawPath(earPath, Paint()
        ..shader = LinearGradient(
          begin: side == -1 ? Alignment.centerLeft : Alignment.centerRight,
          end: Alignment.center,
          colors: [_kMetalHi, _kMetalMid],
        ).createShader(earBounds));
      canvas.drawPath(earPath, Paint()
        ..color = _kOrange.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
      // Animated vent slots
      for (int v = 0; v < 3; v++) {
        final vy = top + 23 + v * 5.5;
        final glowA = 0.4 + 0.35 * math.sin(ambientT * 2 * math.pi + v * 0.8);
        canvas.drawLine(
          Offset(ex + side * 2, vy), Offset(ex + side * 8, vy),
          Paint()..color = _kNeonGreen.withOpacity(glowA)..strokeWidth = 1.2);
      }
    }

    // Antenna nubs — pulse
    for (final side in [-1.0, 1.0]) {
      final pulseScale = 0.8 + 0.5 * math.sin(ambientT * 4 * math.pi + side);
      canvas.drawCircle(Offset(cx + side * 8, top - 8), 5.0 * pulseScale,
        Paint()
          ..color = _kRed.withOpacity(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(Offset(cx + side * 8, top - 8), 2.2,
        Paint()..color = _kAmber);
    }
  }

  // ── Visor ─────────────────────────────────────────────────────────────────
  void _drawVisor(Canvas canvas, double cx, double ht, double flexUp,
      double onlineT, double pulseT) {
    final top = ht - flexUp;
    final visorPath = Path()
      ..moveTo(cx - 22, top + 14)
      ..lineTo(cx + 22, top + 14)
      ..lineTo(cx + 17, top + 42)
      ..lineTo(cx - 17, top + 42)
      ..close();
    final visorBounds = Rect.fromLTWH(cx - 22, top + 14, 44, 28);

    // Dark reflective glass with slight blue tint
    canvas.drawPath(visorPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF1A000D), const Color(0xFF0A001A), const Color(0xFF000005)],
      ).createShader(visorBounds));

    // Red danger glow over glass
    canvas.drawPath(visorPath, Paint()
      ..color = _kVisor.withOpacity(0.28 * onlineT)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Visor border
    canvas.drawPath(visorPath, Paint()
      ..color = _kVisor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Scanlines over visor glass
    for (int sl = 0; sl < 5; sl++) {
      final sy = top + 18 + sl * 5.0;
      canvas.drawLine(Offset(cx - 18, sy), Offset(cx + 18, sy),
        Paint()..color = _kVisor.withOpacity(0.12)..strokeWidth = 0.8);
    }

    // Top-left reflection streak
    canvas.drawLine(
      Offset(cx - 18, top + 16), Offset(cx - 6, top + 26),
      Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Central eye — multi-ring iris
    final eyeY  = top + 28.0;
    final eyeOn = ((onlineT - 0.80) / 0.20).clamp(0.0, 1.0);
    final pupilPulse = 0.85 + 0.15 * math.sin(pulseT * 2 * math.pi);

    // Outer glow halo
    canvas.drawCircle(Offset(cx, eyeY), 10 * pupilPulse,
      Paint()
        ..color = _kRed.withOpacity(0.35 * eyeOn)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    // Iris ring 1
    canvas.drawCircle(Offset(cx, eyeY), 7.5,
      Paint()
        ..color = _kVisor.withOpacity(0.8 * eyeOn)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    // Iris ring 2
    canvas.drawCircle(Offset(cx, eyeY), 5.0,
      Paint()
        ..color = _kAmber.withOpacity(0.9 * eyeOn)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
    // Pupil
    canvas.drawCircle(Offset(cx, eyeY), 3.0 * pupilPulse,
      Paint()..color = _kRed.withOpacity(eyeOn));
    // Bright core
    canvas.drawCircle(Offset(cx, eyeY), 1.4,
      Paint()..color = _kWhite.withOpacity(eyeOn));
  }

  // ── Neck ──────────────────────────────────────────────────────────────────
  void _drawNeck(Canvas canvas, double cx, double ht, double flexUp,
      double onlineT, double pulseT) {
    final neckTop  = ht + 54 - flexUp;
    final neckRect = Rect.fromLTWH(cx - 12, neckTop, 24, 20);

    canvas.drawRect(neckRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_kMetalHi, _kMetalMid],
      ).createShader(neckRect));

    // Glow
    canvas.drawRect(neckRect, Paint()
      ..color = _kNeonGreen.withOpacity((0.3 + 0.25 * pulseT) * onlineT)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Animated vertebrae grooves — brightness pulses
    for (int i = 1; i <= 4; i++) {
      final gy = neckTop + i * 3.8;
      final phaseOff = i * 0.2;
      final lineGlow = 0.5 + 0.45 * math.sin(pulseT * 2 * math.pi + phaseOff);
      canvas.drawLine(
        Offset(cx - 11, gy), Offset(cx + 11, gy),
        Paint()..color = _kNeonGreen.withOpacity(lineGlow * onlineT)..strokeWidth = 1.3);
    }

    canvas.drawRect(neckRect, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  // ── Chest / Torso ─────────────────────────────────────────────────────────
  void _drawChest(Canvas canvas, double cx, double ht, double flexUp,
      double chargeT, double onlineT, double pulseT) {
    final chestTop = ht + 74 - flexUp;
    final chestPath = Path()
      ..moveTo(cx - 46, chestTop)
      ..lineTo(cx + 46, chestTop)
      ..lineTo(cx + 37, chestTop + 83)
      ..lineTo(cx - 37, chestTop + 83)
      ..close();
    final chestBounds = Rect.fromLTWH(cx - 46, chestTop, 92, 83);

    // Metallic gradient fill
    canvas.drawPath(chestPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kMetalHi, _kMetalMid, _kMetal, const Color(0xFF080808)],
        stops: const [0.0, 0.3, 0.65, 1.0],
      ).createShader(chestBounds));

    // Edge
    canvas.drawPath(chestPath, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0);

    // Inner panel recess
    final innerPath = Path()
      ..moveTo(cx - 38, chestTop + 8)
      ..lineTo(cx + 38, chestTop + 8)
      ..lineTo(cx + 30, chestTop + 74)
      ..lineTo(cx - 30, chestTop + 74)
      ..close();
    canvas.drawPath(innerPath, Paint()
      ..color = const Color(0xFF0A0D1A)
      ..style = PaintingStyle.fill);

    // Shoulder armor caps
    for (final side in [-1.0, 1.0]) {
      final sx = cx + side * 46;
      final capPath = Path()
        ..moveTo(sx,              chestTop)
        ..lineTo(sx + side * 13, chestTop - 9)
        ..lineTo(sx + side * 15, chestTop + 15)
        ..lineTo(sx,              chestTop + 19)
        ..close();
      final capBounds = Rect.fromLTWH(side < 0 ? sx - 15 : sx, chestTop - 9, 15, 28);
      canvas.drawPath(capPath, Paint()
        ..shader = LinearGradient(
          begin: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
          end: Alignment.center,
          colors: [_kMetalShine, _kMetalMid],
        ).createShader(capBounds));
      canvas.drawPath(capPath, Paint()
        ..color = _kOrange.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3);

      // Corner bolt dots
      for (int b = 0; b < 2; b++) {
        canvas.drawCircle(
          Offset(sx + side * (4 + b * 5), chestTop + 8 + b * 5), 1.8,
          Paint()..color = _kMetalEdge);
      }
    }

    // Panel bolt screws (4 corners of inner panel)
    final boltPositions = [
      Offset(cx - 34, chestTop + 12), Offset(cx + 34, chestTop + 12),
      Offset(cx - 27, chestTop + 70), Offset(cx + 27, chestTop + 70),
    ];
    for (final bp in boltPositions) {
      canvas.drawCircle(bp, 2.5, Paint()..color = _kMetalEdge);
      canvas.drawCircle(bp, 1.0, Paint()..color = _kMetalShine);
    }

    // Reactor core — pulsing multi-ring
    final reactorCenter = Offset(cx, chestTop + 41);
    final reactorR = 14.0 + chargeT * 10.0;
    final reactorPulse = 0.9 + 0.1 * pulseT;

    // Outer charge aura
    if (chargeT > 0) {
      canvas.drawCircle(reactorCenter, reactorR + 12 * chargeT,
        Paint()
          ..color = _kAmber.withOpacity(0.18 * chargeT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    }

    // Reactor fill
    canvas.drawCircle(reactorCenter, reactorR * reactorPulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(_kOrange, _kAmber, chargeT)!.withOpacity(onlineT),
            _kMetal.withOpacity(0.9),
          ],
        ).createShader(Rect.fromCircle(center: reactorCenter, radius: reactorR)));

    // Reactor border
    canvas.drawCircle(reactorCenter, reactorR * reactorPulse,
      Paint()
        ..color = _kOrange.withOpacity((0.65 + 0.35 * chargeT) * onlineT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2);

    // Inner rings — 3 animated
    for (int ri = 1; ri <= 3; ri++) {
      final ringPhase = ri * 0.25;
      final ringBright = 0.25 + 0.35 * math.sin(pulseT * 2 * math.pi + ringPhase);
      canvas.drawCircle(reactorCenter, reactorR * (0.30 + ri * 0.22) * reactorPulse,
        Paint()
          ..color = _kOrange.withOpacity((ringBright + chargeT * 0.4) * onlineT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
    }

    // Energy veins radiating from reactor
    if (onlineT > 0.5) {
      final veinAlpha = ((onlineT - 0.5) / 0.5).clamp(0.0, 1.0);
      for (int vi = 0; vi < 6; vi++) {
        final angle = vi * math.pi / 3 + ambientT * math.pi * 0.2;
        final veinEnd = reactorCenter + Offset(
          math.cos(angle) * (20 + pulseT * 8),
          math.sin(angle) * (20 + pulseT * 8),
        );
        canvas.drawLine(reactorCenter, veinEnd,
          Paint()
            ..color = _kNeonGreen.withOpacity(0.35 * veinAlpha * (0.5 + 0.5 * pulseT))
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round);
      }
    }

    // Side vents — animated green slots
    for (final side in [-1.0, 1.0]) {
      for (int v = 0; v < 5; v++) {
        final vy = chestTop + 20 + v * 8.0;
        final ventGlow = 0.20 + 0.20 * math.sin(pulseT * 2 * math.pi + v * 0.4);
        canvas.drawLine(
          Offset(cx + side * 22, vy), Offset(cx + side * 36, vy),
          Paint()..color = _kNeonGreen.withOpacity(ventGlow)..strokeWidth = 1.2);
      }
    }
  }


  // ── Energy Pipes ──────────────────────────────────────────────────────────
  void _drawEnergyPipes(Canvas canvas, double cx, double ht, double flexUp,
      double pulseIdleT, double chargeT, double onlineT, double pulseLoopT) {
    final pipeTop = ht + 54 - flexUp;
    final pipeBot = ht + 157 - flexUp;
    final pipeXs  = [cx - 20.0, cx, cx + 20.0];

    for (int pi = 0; pi < 3; pi++) {
      final px = pipeXs[pi];
      // Base pipe
      canvas.drawLine(Offset(px, pipeTop), Offset(px, pipeBot),
        Paint()
          ..color = _kNeonGreen.withOpacity((0.20 + 0.15 * pulseLoopT) * onlineT)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round);

      // Bright node connectors along pipe
      for (int ni = 0; ni < 3; ni++) {
        final ny = pipeTop + (ni + 1) * (pipeBot - pipeTop) / 4;
        final nodeGlow = 0.3 + 0.4 * math.sin(pulseLoopT * 2 * math.pi + ni * 0.6 + pi * 0.3);
        canvas.drawCircle(Offset(px, ny), 2.5,
          Paint()
            ..color = _kNeonGreen.withOpacity(nodeGlow * onlineT)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }

      // Idle energy pulse — traveling bolt
      if (pulseIdleT > 0) {
        final delay  = pi * 0.12;
        final localT = ((pulseIdleT - delay) / 0.7).clamp(0.0, 1.0);
        if (localT > 0) {
          final pulseY  = pipeTop + localT * (pipeBot - pipeTop);
          const tailLen = 32.0;
          canvas.drawLine(
            Offset(px, pulseY - tailLen), Offset(px, pulseY),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kNeonGreen.withOpacity(0),
                  _kNeonGreen.withOpacity(0.90),
                  _kWhite.withOpacity(0.65),
                ],
              ).createShader(Rect.fromLTWH(px - 2, pulseY - tailLen, 4, tailLen))
              ..strokeWidth = 4.0
              ..strokeCap = StrokeCap.round);
          canvas.drawCircle(Offset(px, pulseY), 5.0,
            Paint()
              ..color = _kNeonGreen.withOpacity(0.7 * (1 - localT))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
        }
      }

      // Charge state: pipes flash amber
      if (chargeT > 0) {
        canvas.drawLine(
          Offset(px, pipeTop), Offset(px, pipeBot),
          Paint()
            ..color = _kAmber.withOpacity(0.55 * chargeT)
            ..strokeWidth = 6.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * chargeT));
      }
    }
  }

  // ── Arms ──────────────────────────────────────────────────────────────────
  void _drawArms(Canvas canvas, double cx, double ht, double flexUp,
      double chargeT, double onlineT, double ambientT) {
    final shoulderY = ht + 82 - flexUp;
    for (final side in [-1.0, 1.0]) {
      _drawArm(canvas, cx, shoulderY, side, chargeT, onlineT, ambientT);
    }
  }

  void _drawArm(Canvas canvas, double cx, double shoulderY,
      double side, double chargeT, double onlineT, double ambientT) {
    final chargeFrac = Curves.easeIn.transform(chargeT);

    // Ambient oscillation — arms gently breathe
    final oscillation = math.sin(ambientT * 2 * math.pi + side * 1.2) * 4.0;

    final shoulder    = Offset(cx + side * 47, shoulderY);
    final elbowNorm   = Offset(cx + side * 76, shoulderY + 36 + oscillation);
    final wristNorm   = Offset(cx + side * 66, shoulderY + 68 + oscillation * 0.5);
    final elbowCharge = Offset(cx + side * 56, shoulderY - 28);
    final wristCharge = Offset(cx + side * 30, shoulderY - 56);

    final elbow = Offset.lerp(elbowNorm, elbowCharge, chargeFrac)!;
    final wrist = Offset.lerp(wristNorm, wristCharge, chargeFrac)!;

    // Glow
    final glowColor = Color.lerp(_kNeonGreen, _kAmber, chargeFrac)!
        .withOpacity((0.28 + 0.50 * chargeFrac) * onlineT);
    final armGlow = Paint()
      ..color = glowColor
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    // Arm segment — 3 layers: glow, metal, edge
    canvas.drawLine(shoulder, elbow, armGlow);
    canvas.drawLine(shoulder, elbow, Paint()
      ..color = _kMetalMid..strokeWidth = 11.0..strokeCap = StrokeCap.round);
    canvas.drawLine(shoulder, elbow, Paint()
      ..color = _kMetalEdge..strokeWidth = 11.0..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);

    canvas.drawLine(elbow, wrist, armGlow);
    canvas.drawLine(elbow, wrist, Paint()
      ..color = _kMetalMid..strokeWidth = 9.0..strokeCap = StrokeCap.round);
    canvas.drawLine(elbow, wrist, Paint()
      ..color = _kMetalEdge..strokeWidth = 9.0..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);

    // Energy cable along arm — thin neon green line
    if (onlineT > 0) {
      canvas.drawLine(shoulder, wrist,
        Paint()
          ..color = _kNeonGreen.withOpacity(0.30 * onlineT)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
    }

    // Shoulder joint
    canvas.drawCircle(shoulder, 11,
      Paint()..shader = RadialGradient(
        colors: [_kMetalHi, _kMetal],
      ).createShader(Rect.fromCircle(center: shoulder, radius: 11)));
    canvas.drawCircle(shoulder, 11,
      Paint()..color = _kOrange.withOpacity(0.60)
        ..style = PaintingStyle.stroke..strokeWidth = 2.2);
    canvas.drawCircle(shoulder, 6,  Paint()..color = _kMetal);
    canvas.drawCircle(shoulder, 3.5,
      Paint()..color = _kNeonGreen.withOpacity(0.8 + 0.2 * chargeFrac));
    // Shoulder spark emission
    if (onlineT >= 1.0 && chargeFrac > 0) {
      for (int s = 0; s < 4; s++) {
        final sAngle = s * math.pi / 2 + chargeFrac * math.pi;
        final sPos = shoulder + Offset(
          math.cos(sAngle) * (12 + chargeFrac * 8),
          math.sin(sAngle) * (12 + chargeFrac * 8),
        );
        canvas.drawCircle(sPos, 1.5,
          Paint()..color = _kAmber.withOpacity(0.7 * chargeFrac)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }

    // Elbow joint
    canvas.drawCircle(elbow, 8,
      Paint()..shader = RadialGradient(
        colors: [_kMetalHi, _kMetal],
      ).createShader(Rect.fromCircle(center: elbow, radius: 8)));
    canvas.drawCircle(elbow, 8,
      Paint()..color = _kOrange.withOpacity(0.55)
        ..style = PaintingStyle.stroke..strokeWidth = 1.6);
    canvas.drawCircle(elbow, 3.5,
      Paint()..color = _kNeonGreen.withOpacity(0.75));

    // Wrist / hand
    final handPath = Path();
    handPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: wrist, width: 18, height: 11),
      const Radius.circular(3),
    ));
    canvas.drawPath(handPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_kMetalHi, _kMetalMid],
      ).createShader(Rect.fromCenter(center: wrist, width: 18, height: 11)));
    canvas.drawPath(handPath, Paint()
      ..color = Color.lerp(_kNeonGreen, _kAmber, chargeFrac)!
          .withOpacity(0.55 + 0.45 * chargeFrac)
      ..style = PaintingStyle.stroke..strokeWidth = 1.6);

    // Charge: crackle at wrists
    if (chargeFrac > 0.3) {
      canvas.drawCircle(wrist, 6 + 8 * chargeFrac,
        Paint()
          ..color = _kAmber.withOpacity(0.60 * chargeFrac)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * chargeFrac));
    }
  }

  // ── Thruster body ─────────────────────────────────────────────────────────
  void _drawThruster(Canvas canvas, double cx, double ht) {
    final thrTop = ht + 157;

    final waistPath = Path()
      ..moveTo(cx - 37, thrTop)
      ..lineTo(cx + 37, thrTop)
      ..lineTo(cx + 23, thrTop + 17)
      ..lineTo(cx - 23, thrTop + 17)
      ..close();
    canvas.drawPath(waistPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_kMetalHi, _kMetalMid],
      ).createShader(Rect.fromLTWH(cx - 37, thrTop, 74, 17)));
    canvas.drawPath(waistPath, Paint()
      ..color = _kMetalEdge..style = PaintingStyle.stroke..strokeWidth = 1.6);

    final bellPath = Path()
      ..moveTo(cx - 23, thrTop + 17)
      ..quadraticBezierTo(cx - 27, thrTop + 35, cx - 20, thrTop + 54)
      ..lineTo(cx - 15, thrTop + 58)
      ..lineTo(cx + 15, thrTop + 58)
      ..lineTo(cx + 20, thrTop + 54)
      ..quadraticBezierTo(cx + 27, thrTop + 35, cx + 23, thrTop + 17)
      ..close();
    canvas.drawPath(bellPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_kMetalMid, _kMetal, const Color(0xFF080808)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - 27, thrTop + 17, 54, 41)));
    canvas.drawPath(bellPath, Paint()
      ..color = _kMetalEdge..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // Ribs with gradient
    for (int rib = 1; rib <= 4; rib++) {
      final ry = thrTop + 20 + rib * 9.0;
      final rw = 14.0 + rib * 2.5;
      canvas.drawLine(Offset(cx - rw, ry), Offset(cx + rw, ry),
        Paint()..color = _kMetalEdge..strokeWidth = 1.0);
    }

    // Nozzle ring
    final nozzleCenter = Offset(cx, thrTop + 60);
    canvas.drawCircle(nozzleCenter, 19,
      Paint()..shader = RadialGradient(
        colors: [_kFire1.withOpacity(0.4), _kMetal],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: nozzleCenter, radius: 19)));
    canvas.drawCircle(nozzleCenter, 19,
      Paint()..color = _kOrange.withOpacity(0.85)..style = PaintingStyle.stroke..strokeWidth = 2.8);
    canvas.drawCircle(nozzleCenter, 12,
      Paint()..color = _kFire1.withOpacity(0.6));
    canvas.drawCircle(nozzleCenter, 12,
      Paint()..color = _kOrange..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Outer glow pulse
    canvas.drawCircle(nozzleCenter, 24,
      Paint()..color = _kOrange.withOpacity(0.22)..style = PaintingStyle.stroke
        ..strokeWidth = 4.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
  }

  // ── Thruster plasma fire (3-column, turbulent) ────────────────────────────
  void _drawThrusterFire(Canvas canvas, double cx, double ht,
      double thrusterT, double flexT, double brakeT, double onlineT) {
    if (onlineT <= 0 || brakeT > 0) return;
    final fireBase  = ht + 218;
    final extraBurst = flexT > 0 ? math.sin(flexT * math.pi) * 35.0 : 0.0;
    final fireLen    = 55.0 + thrusterT * 30.0 + extraBurst;

    // Draw 3 separate fire streams: L, center, R
    for (int stream = -1; stream <= 1; stream++) {
      final offX = stream * 5.0;
      final sLen = fireLen * (stream == 0 ? 1.0 : 0.72);
      final turbX = stream * 2.0 + math.sin(thrusterT * 3 + stream) * 2.0;
      final firePath = Path()
        ..moveTo(cx - 8 + offX,  fireBase)
        ..quadraticBezierTo(
            cx - 3 + offX + turbX,  fireBase + sLen * 0.45,
            cx + offX + turbX * 1.2, fireBase + sLen)
        ..quadraticBezierTo(
            cx + 3 + offX + turbX,  fireBase + sLen * 0.45,
            cx + 8 + offX,          fireBase)
        ..close();

      canvas.drawPath(firePath, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kFire2.withOpacity(stream == 0 ? 0.95 : 0.65),
            _kFire1.withOpacity(0.7),
            _kOrange.withOpacity(0.35),
            _kOrange.withOpacity(0),
          ],
          stops: const [0.0, 0.25, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(cx - 8 + offX, fireBase, 16, sLen)));

      // Outer glow per stream
      canvas.drawPath(firePath, Paint()
        ..color = _kFire1.withOpacity(stream == 0 ? 0.22 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    }

    // Scatter particles
    final rng = math.Random(42);
    for (int i = 0; i < 14; i++) {
      final frac = (i / 14.0 + thrusterT * 0.35) % 1.0;
      final py   = fireBase + frac * fireLen;
      final px   = cx + (rng.nextDouble() - 0.5) * 26 * frac;
      final pr   = (3.5 - frac * 3.0).clamp(0.5, 3.5);
      canvas.drawCircle(Offset(px, py), pr,
        Paint()
          ..color = _kAmber.withOpacity((1.0 - frac) * 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    if (extraBurst > 0) {
      canvas.drawCircle(Offset(cx, fireBase + 8), 20 + extraBurst * 0.6,
        Paint()
          ..color = _kAmber.withOpacity(0.20 * (extraBurst / 35.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }
  }

  // ── Scanner Laser (ZIGZAG + forks + sparks) ───────────────────────────────
  void _drawScannerLaser(Canvas canvas, Size size, double cx, double ht,
      double scanT) {
    final eyePos  = Offset(cx, ht + 28);
    final sweep   = Curves.easeInOut.transform(scanT);
    final targetX = -50.0 + sweep * (size.width + 100);

    canvas.save();
    final neckLean = (sweep - 0.5) * 0.09;
    canvas.transform((Matrix4.identity()
      ..translate(cx, ht + 54.0)
      ..rotateZ(neckLean)
      ..translate(-cx, -(ht + 54.0))).storage);

    // Build zigzag path
    final dx     = targetX - eyePos.dx;
    final dy     = 0.0;
    final segs   = 10;
    final zigPath = Path()..moveTo(eyePos.dx, eyePos.dy);
    for (int i = 1; i <= segs; i++) {
      final t1 = i / segs;
      final xp = eyePos.dx + t1 * dx;
      final yp = eyePos.dy + math.sin(i * 1.8 + scanT * 8) * 3.0;
      zigPath.lineTo(xp, yp);
    }

    // Outer glow
    canvas.drawPath(zigPath, Paint()
      ..color = _kScan.withOpacity(0.30)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Core beam
    canvas.drawPath(zigPath, Paint()
      ..color = _kScan.withOpacity(0.90)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // 2 ghost parallel beams
    for (final off in [-3.0, 3.0]) {
      canvas.drawLine(
        Offset(eyePos.dx, eyePos.dy + off),
        Offset(targetX,   eyePos.dy + off),
        Paint()
          ..color = _kScan.withOpacity(0.15)
          ..strokeWidth = 1.0);
    }

    // Scan point impact sparks
    final spPos = Offset(targetX, eyePos.dy);
    canvas.drawCircle(spPos, 6.0,
      Paint()..color = _kScan..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(spPos, 2.5, Paint()..color = _kWhite);
    final rng = math.Random((scanT * 60).toInt());
    for (int s = 0; s < 8; s++) {
      final sAngle = s * math.pi / 4 + rng.nextDouble() * 0.3;
      final sDist  = 6 + rng.nextDouble() * 10;
      final sPos   = spPos + Offset(math.cos(sAngle) * sDist, math.sin(sAngle) * sDist);
      canvas.drawCircle(sPos, 1.5 + rng.nextDouble(),
        Paint()..color = _kScan.withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }

    // Ground mark ring
    canvas.drawCircle(spPos, 12,
      Paint()
        ..color = _kScan.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.restore();
  }

  // ── Charge-up effect ──────────────────────────────────────────────────────
  void _drawChargeEffect(Canvas canvas, double cx, double ht,
      double chargeT, double pulseT) {
    final reactorCenter = Offset(cx, ht + 74 + 41);

    for (int ring = 0; ring < 4; ring++) {
      final rt    = (chargeT - ring * 0.18).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final r     = 14.0 + rt * 50;
      final alpha = (1.0 - rt) * 0.55;
      canvas.drawCircle(reactorCenter, r, Paint()
        ..color = _kAmber.withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }

    // Energy vortex particles
    for (int i = 0; i < 12; i++) {
      final angle  = i * math.pi * 2 / 12 + chargeT * math.pi * 4;
      final radius = 20.0 + chargeT * 18.0 + pulseT * 4.0;
      final pos    = reactorCenter + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawCircle(pos, 2.0 + chargeT * 2.0,
        Paint()
          ..color = _kAmber.withOpacity(0.8 * chargeT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  // ── EMP Beam (BRANCHING LIGHTNING + impact crater) ────────────────────────
  void _drawEmpBeam(Canvas canvas, Size size, double cx, double ht,
      double beamT) {
    final beamStart = Offset(cx, ht + 74 + 41);

    final alpha = beamT < 0.15
        ? beamT / 0.15
        : beamT > 0.75
            ? (1.0 - beamT) / 0.25
            : 1.0;
    final shakeX = math.sin(beamT * 30) * 5.0 * (1.0 - beamT);
    final beamEnd = Offset(cx + shakeX, size.height - 10);

    // Outer plasma cloud
    canvas.drawLine(beamStart, beamEnd, Paint()
      ..color = _kRed.withOpacity(0.15 * alpha)
      ..strokeWidth = 40.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    // Mid glow
    canvas.drawLine(beamStart, beamEnd, Paint()
      ..color = _kRed.withOpacity(0.55 * alpha)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round);
    // Core
    canvas.drawLine(beamStart, beamEnd, Paint()
      ..color = _kOrange.withOpacity(0.85 * alpha)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round);
    // White hot center
    canvas.drawLine(beamStart, beamEnd, Paint()
      ..color = _kWhite.withOpacity(0.95 * alpha)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Lightning branches — 6 forks off main beam
    final rng = math.Random(17 + (beamT * 20).toInt());
    for (int b = 0; b < 6; b++) {
      final branchFrac = 0.15 + rng.nextDouble() * 0.65;
      final branchX    = cx + branchFrac * shakeX;
      final branchY    = beamStart.dy + branchFrac * (beamEnd.dy - beamStart.dy);
      final branchDX   = (rng.nextDouble() - 0.5) * 60;
      final branchLen  = 25 + rng.nextDouble() * 45;
      canvas.drawLine(
        Offset(branchX, branchY),
        Offset(branchX + branchDX, branchY + branchLen),
        Paint()
          ..color = _kRed.withOpacity(0.50 * alpha)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      // Sub-branch
      if (rng.nextBool()) {
        canvas.drawLine(
          Offset(branchX + branchDX * 0.5, branchY + branchLen * 0.5),
          Offset(branchX + branchDX * 0.5 + (rng.nextDouble() - 0.5) * 30,
              branchY + branchLen * 0.5 + 20),
          Paint()
            ..color = _kOrange.withOpacity(0.35 * alpha)
            ..strokeWidth = 1.0);
      }
    }

    // Source flash (reactor)
    canvas.drawCircle(beamStart, 22 * alpha, Paint()
      ..color = _kAmber.withOpacity(0.65 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Impact crater at grid
    canvas.drawCircle(beamEnd, 24 * alpha, Paint()
      ..color = _kRed.withOpacity(0.70 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.drawCircle(beamEnd, 14 * alpha, Paint()
      ..color = _kOrange.withOpacity(0.85 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Impact debris sparks
    for (int d = 0; d < 10; d++) {
      final dAngle = d * math.pi / 5 + rng.nextDouble() * 0.3;
      final dDist  = (5 + rng.nextDouble() * 22) * alpha;
      final dPos   = beamEnd + Offset(math.cos(dAngle) * dDist, math.sin(dAngle) * dDist);
      canvas.drawCircle(dPos, 1.8 + rng.nextDouble() * 2,
        Paint()..color = _kAmber.withOpacity(0.75 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }
}

// ── Entry Blast (Phase 2) — Cinematic brake explosion ─────────────────────────

void _drawEntryBlast(Canvas canvas, Size size, double cx, double ht, double p2) {
  final nozzleCenter = Offset(cx, ht + 218);
  final blastAlpha   = p2 < 0.40
      ? p2 / 0.40
      : (1.0 - (p2 - 0.40) / 0.60).clamp(0.0, 1.0);

  // Massive expanding ring
  final blastR = 18.0 + p2 * 130.0;
  canvas.drawCircle(nozzleCenter, blastR, Paint()
    ..color = _kNeonGreen.withOpacity(0.16 * blastAlpha)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blastR * 0.45));
  canvas.drawCircle(nozzleCenter, blastR * 0.38, Paint()
    ..color = _kNeonGreen.withOpacity(0.60 * blastAlpha)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));

  // Shockwave rings — 3 waves
  for (int sw = 0; sw < 3; sw++) {
    final swP   = (p2 - sw * 0.12).clamp(0.0, 1.0);
    if (swP <= 0) continue;
    final swR   = 28.0 + swP * 95.0;
    final swAlpha = (1.0 - swP).clamp(0.0, 0.65) * blastAlpha;
    canvas.drawCircle(nozzleCenter, swR, Paint()
      ..color = (sw == 0 ? _kNeonGreen : (sw == 1 ? _kGreenGlow : _kWhite))
          .withOpacity(swAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 - sw * 0.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  // Downward plasma jet
  final jetLen  = 80.0 + p2 * 180.0;
  final jetPath = Path()
    ..moveTo(cx - 13 * (1 - p2 * 0.5), nozzleCenter.dy)
    ..quadraticBezierTo(cx, nozzleCenter.dy + jetLen * 0.6, cx - 3, nozzleCenter.dy + jetLen)
    ..quadraticBezierTo(cx, nozzleCenter.dy + jetLen * 0.6, cx + 13 * (1 - p2 * 0.5), nozzleCenter.dy)
    ..close();
  canvas.drawPath(jetPath, Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        _kNeonGreen.withOpacity(0.95 * blastAlpha),
        _kGreenGlow.withOpacity(0.55 * blastAlpha),
        _kNeonGreen.withOpacity(0),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(cx - 13, nozzleCenter.dy, 26, jetLen)));

  // 4 diagonal plasma jets
  for (int jet = 0; jet < 4; jet++) {
    final jAngle = (jet * math.pi / 2) + math.pi / 4;
    final jLen   = (50 + jet * 15.0) * p2;
    final jEnd   = nozzleCenter + Offset(math.cos(jAngle) * jLen, math.sin(jAngle) * jLen);
    canvas.drawLine(nozzleCenter, jEnd, Paint()
      ..color = _kNeonGreen.withOpacity(0.45 * (1 - p2) * blastAlpha)
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  // 32 radial debris particles
  final rng = math.Random(99);
  for (int i = 0; i < 32; i++) {
    final angle  = i * math.pi * 2 / 32 + rng.nextDouble() * 0.15;
    final speed  = 55.0 + rng.nextDouble() * 110.0;
    final dist   = p2 * speed;
    final pos    = nozzleCenter + Offset(
        math.cos(angle) * dist, math.sin(angle) * dist + dist * 0.55);
    final pa     = (1.0 - p2 * 1.05).clamp(0.0, 1.0) * blastAlpha;
    final pr     = (5.0 + rng.nextDouble() * 6.0) * (1.0 - p2 * 0.5);
    final col    = i % 3 == 0 ? _kGreenGlow : (i % 2 == 0 ? _kNeonGreen : _kWhite);
    canvas.drawCircle(pos, pr.clamp(0.5, 11.0), Paint()
      ..color = col.withOpacity(pa)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 0.5));
  }

  // Electric arc pre-impact
  if (p2 < 0.35) {
    final arcAlpha = (1.0 - p2 / 0.35) * blastAlpha;
    final arcRng   = math.Random(7);
    for (int a = 0; a < 5; a++) {
      final aAngle = arcRng.nextDouble() * math.pi * 2;
      final aDist  = 30 + arcRng.nextDouble() * 40;
      canvas.drawLine(
        nozzleCenter,
        nozzleCenter + Offset(math.cos(aAngle) * aDist, math.sin(aAngle) * aDist),
        Paint()
          ..color = _kCyan.withOpacity(0.5 * arcAlpha)
          ..strokeWidth = 1.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }
}

// ── Boot Sequence (Phase 3) — Dramatic sequential power-on ────────────────────

void _drawBootSequence(Canvas canvas, Size size, double cx, double ht, double p3) {
  // Scan-line sweep down body
  if (p3 < 0.65) {
    final scanFrac = (p3 / 0.65).clamp(0.0, 1.0);
    final scanY    = (ht - 10.0) + scanFrac * (ht + 235.0 - (ht - 10.0));
    // Bright sweep bar
    canvas.drawRect(
      Rect.fromLTWH(cx - 64, scanY - 3, 128, 6),
      Paint()
        ..color = _kNeonGreen.withOpacity(0.7 * (1.0 - scanFrac))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    // Trailing wake
    canvas.drawRect(
      Rect.fromLTWH(cx - 60, scanY - 12, 120, 12),
      Paint()
        ..color = _kNeonGreen.withOpacity(0.18 * (1.0 - scanFrac))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  // Pipe surge sequential flash
  final pipeXs = [cx - 20.0, cx, cx + 20.0];
  for (int pi = 0; pi < 3; pi++) {
    final delay  = pi * 0.14;
    final localT = ((p3 - delay) / 0.38).clamp(0.0, 1.0);
    if (localT <= 0) continue;
    final pipeTop = ht + 54;
    final pipeBot = ht + 157;
    final surgeY  = pipeTop + localT * (pipeBot - pipeTop);
    const tail    = 44.0;
    canvas.drawRect(
      Rect.fromLTWH(pipeXs[pi] - 4, surgeY - tail, 8, tail),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            _kNeonGreen.withOpacity(0),
            _kNeonGreen.withOpacity(0.95),
            _kWhite.withOpacity(0.55),
          ],
        ).createShader(Rect.fromLTWH(pipeXs[pi] - 4, surgeY - tail, 8, tail))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Node flash at top of surge
    canvas.drawCircle(Offset(pipeXs[pi], surgeY), 5.0,
      Paint()
        ..color = _kNeonGreen.withOpacity(0.7 * (1 - localT))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  // Chest reactor bloom
  if (p3 > 0.50) {
    final cFrac    = ((p3 - 0.50) / 0.28).clamp(0.0, 1.0);
    final chestTop = ht + 74;
    final chestPath = Path()
      ..moveTo(cx - 46, chestTop)
      ..lineTo(cx + 46, chestTop)
      ..lineTo(cx + 37, chestTop + 83)
      ..lineTo(cx - 37, chestTop + 83)
      ..close();
    canvas.drawPath(chestPath, Paint()
      ..color = _kNeonGreen.withOpacity(0.25 * cFrac * (1.0 - cFrac * 0.6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // Reactor ring expand
    canvas.drawCircle(Offset(cx, chestTop + 41), 20 + cFrac * 30,
      Paint()
        ..color = _kOrange.withOpacity(0.2 * cFrac * (1 - cFrac))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  // Eye flicker then snap on
  if (p3 > 0.78) {
    final eFrac   = ((p3 - 0.78) / 0.18).clamp(0.0, 1.0);
    final eyeY    = ht + 28.0;
    // Flicker: 3 quick blinks before full on
    final flickerPhase = (eFrac * 8).floor() % 2;
    final flickerAlpha = flickerPhase == 0 ? 0.0 : eFrac;
    canvas.drawCircle(Offset(cx, eyeY), 18 * (1.0 - eFrac),
      Paint()
        ..color = _kRed.withOpacity(0.90 * (1.0 - eFrac) + flickerAlpha * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * (1.0 - eFrac)));
  }

  // "ONLINE" text glitch flash at full boot
  if (p3 > 0.92) {
    final textFrac = ((p3 - 0.92) / 0.08).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: '[ TERRA-LICH ONLINE ]',
        style: TextStyle(
          fontFamily: 'Orbitron',
          color: _kNeonGreen.withOpacity(textFrac * (1.0 - textFrac * 0.8)),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(canvas,
      Offset((size.width - tp.width) / 2, ht + 270));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Win Blast Painter ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _WinBlastPainter extends CustomPainter {
  final double t;
  const _WinBlastPainter({required this.t});

  @override bool shouldRepaint(_WinBlastPainter o) => o.t != t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = 130.0;
    final c  = Offset(cx, cy);

    if (t < 0.20) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kWhite.withOpacity((t / 0.20).clamp(0.0, 1.0) * 0.85));
      return;
    }

    final pt = ((t - 0.20) / 0.80).clamp(0.0, 1.0);

    // 5 shockwave rings
    for (int ring = 0; ring < 5; ring++) {
      final rt    = (pt - ring * 0.08).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final r     = rt * (170 + ring * 30);
      final alpha = (1.0 - rt).clamp(0.0, 1.0) * 0.65;
      final cols  = [_kRed, _kOrange, _kAmber, _kFire1, _kNeonGreen];
      canvas.drawCircle(c, r, Paint()
        ..color = cols[ring % 5].withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (4.0 - ring * 0.5) * (1.0 - rt * 0.35));
    }

    // 24 metal shards
    final rng = math.Random(42);
    for (int i = 0; i < 24; i++) {
      final angle = i * math.pi * 2 / 24 + rng.nextDouble() * 0.3;
      final speed = 80.0 + rng.nextDouble() * 150;
      final dist  = pt * speed;
      final pos   = c + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final alpha = (1.0 - pt * 1.1).clamp(0.0, 1.0);
      final pr    = (5.0 + rng.nextDouble() * 7.0) * (1.0 - pt * 0.55);
      final col   = i % 3 == 0 ? _kRed : (i % 3 == 1 ? _kAmber : _kOrange);
      canvas.drawCircle(pos, pr.clamp(0.5, 14.0), Paint()
        ..color = col.withOpacity(alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 0.5));
    }

    // Core remnant
    if (pt < 0.55) {
      final bFrac = 1.0 - pt / 0.55;
      canvas.drawCircle(c, (1.0 + pt * 1.8) * 35 * bFrac, Paint()
        ..color = _kOrange.withOpacity(0.38 * bFrac)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }

    // Victory text
    if (pt > 0.42) {
      final textFrac = ((pt - 0.42) / 0.28).clamp(0.0, 1.0);
      final fadeOut  = pt > 0.82 ? (1.0 - (pt - 0.82) / 0.18).clamp(0.0, 1.0) : 1.0;
      final tAlpha   = textFrac * fadeOut;
      final tp = TextPainter(
        text: TextSpan(
          text: '⚡ TERRA-LICH DEFEATED! ⚡',
          style: TextStyle(
            fontFamily: 'Orbitron',
            color: _kAmber.withOpacity(tAlpha),
            fontSize: 15,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: _kAmber.withOpacity(tAlpha), blurRadius: 20),
              Shadow(color: _kRed.withOpacity(tAlpha * 0.6), blurRadius: 35),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.35));
    }
  }
}
