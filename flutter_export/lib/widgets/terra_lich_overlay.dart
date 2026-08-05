// ============================================================
// terra_lich_overlay.dart  —  Terra-Lich Mech Boss
// Level 42  ·  "Terraforming"  |  AAA-quality Flutter animation
//
// Body design:
//   • Metallic helmet head + glowing neck → chest
//   • Broad armor chest with energy-flow pipes
//   • Jointed arms: shoulder → elbow → wrist (lineTo / arc)
//   • Lower body: single thruster engine + plasma fire stream
//
// Idle anims (every 5–10 s):
//   • Energy Pulse  — light races through body pipes
//   • Mechanical Flex — shoulders jerk up, extra exhaust burst
//   • Scanner Sweep — eye laser sweeps grid left → right
//
// Attack:
//   • Charge Up  — arms raise, chest reactor opens (orange energy)
//   • Strike     — Red EMP Beam fires from chest to printer
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/terra_lich_controller.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
// Body  : Heavy Matte Black / Dark Metal
// Pipes : Toxic Neon Green  (Terraforming / Hacking vibe)
// Eye + Thruster + Attacks : Bright Red / Orange  (danger contrast)

const _kMetal    = Color(0xFF0D0D0D);   // heavy matte black body
const _kMetalHi  = Color(0xFF1A1A1A);   // dark panel face
const _kMetalEdge= Color(0xFF2E2E2E);   // subtle edge highlight
const _kNeonGreen= Color(0xFF39FF14);   // TOXIC NEON GREEN — pipes & energy flow
const _kGreenDim = Color(0xFF1C7A00);   // dimmer green — pipe base / unlit channel
const _kVisor    = Color(0xFFFF4500);   // MAIN EYE — danger red-orange
const _kOrange   = Color(0xFFFF6D00);   // THRUSTER + ATTACK — danger orange
const _kRed      = Color(0xFFFF1744);   // ATTACK BEAM + SCANNER — bright danger red
const _kAmber    = Color(0xFFFF8C00);   // charge-up glow — deep orange
const _kFire1    = Color(0xFFFF3800);   // THRUSTER FIRE outer — danger red
const _kFire2    = Color(0xFFFF7200);   // THRUSTER FIRE inner core — danger orange
const _kGlow     = Color(0xFFFF5500);   // thruster nozzle glow
const _kScan     = Color(0xFFFF1744);   // SCANNER LASER — danger red (keep)
const _kWhite    = Color(0xFFFFFFFF);   // EMP beam core — bright white

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
        if (p == TerraLichPhase.winBlast) {
          return _WinBlastPhase(controller: controller);
        }
        // entry, active, chargingUp, striking all use the same widget
        return _ActivePhase(controller: controller);
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

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _entry;     // 0→1 boss descends into position
  late AnimationController _bob;       // 0→1→0 gentle hover loop
  late AnimationController _thruster;  // 0→1 thruster fire flicker loop
  late AnimationController _idle;      // 0→1 current idle animation
  late AnimationController _charge;    // 0→1 charge-up (1.5 s)
  late AnimationController _beam;      // 0→1 EMP beam strike (0.8 s)

  TerraLichPhase    _lastPhase    = TerraLichPhase.idle;
  TerraLichIdleAnim _lastIdleAnim = TerraLichIdleAnim.none;

  @override
  void initState() {
    super.initState();

    _entry    = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))
      ..forward();
    _bob      = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _thruster = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
      ..repeat(reverse: true);
    _idle     = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _charge   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _beam     = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    widget.controller.addListener(_onControllerChange);
    _lastPhase    = widget.controller.phase;
    _lastIdleAnim = widget.controller.idleAnim;
  }

  void _onControllerChange() {
    if (!mounted) return;

    final c = widget.controller;

    // ── Phase transitions ─────────────────────────────────────────────────
    if (c.phase != _lastPhase) {
      if (c.phase == TerraLichPhase.chargingUp) {
        _charge.forward(from: 0);
        _beam.value = 0;
      }
      if (c.phase == TerraLichPhase.striking) {
        _beam.forward(from: 0);
      }
      if (c.phase == TerraLichPhase.active && _lastPhase == TerraLichPhase.striking) {
        _charge.value = 0;
        _beam.value   = 0;
      }
      _lastPhase = c.phase;
    }

    // ── Idle animation transitions ────────────────────────────────────────
    if (c.idleAnim != _lastIdleAnim) {
      if (c.idleAnim != TerraLichIdleAnim.none) {
        _idle.forward(from: 0);
      } else {
        _idle.value = 0;
      }
      _lastIdleAnim = c.idleAnim;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _entry.dispose();
    _bob.dispose();
    _thruster.dispose();
    _idle.dispose();
    _charge.dispose();
    _beam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entry, _bob, _thruster, _idle, _charge, _beam]),
        builder: (ctx, _) {
          final c   = widget.controller;
          // ── 3-phase entry timeline ─────────────────────────────────
          final raw = _entry.value.clamp(0.0, 1.0);
          // Phase 1 (0.00→0.30): Power Dive — body offline, falls from top
          final p1 = (raw / 0.30).clamp(0.0, 1.0);
          // Phase 2 (0.30→0.55): Thruster Brake — hard stop + blast + shake
          final p2 = ((raw - 0.30) / 0.25).clamp(0.0, 1.0);
          // Phase 3 (0.55→1.00): System Boot — pipes→chest→eye light up
          final p3 = ((raw - 0.55) / 0.45).clamp(0.0, 1.0);
          // Position: use phase1 for descent (easeIn = acceleration = heavy boulder)
          final eT = raw < 0.30
              ? Curves.easeIn.transform(p1)
              : 1.0;
          final bT  = raw >= 1.0 ? _bob.value : 0.0; // bob only after full entry
          final fT  = _thruster.value;
          final iT  = _idle.value;
          final cT  = _charge.value;
          final bmT = _beam.value;

          return CustomPaint(
            painter: _TerraLichPainter(
              entryT:    eT,
              phase1T:   p1,
              phase2T:   p2,
              phase3T:   p3,
              bobT:      bT,
              thrusterT: fT,
              idleAnim:  c.idleAnim,
              idleT:     iT,
              chargeT:   cT,
              beamT:     bmT,
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
      ..forward();
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
// ── Main Painter ──────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _TerraLichPainter extends CustomPainter {
  final double          entryT;     // 0→1 positional — boss reaches hover pos
  final double          phase1T;    // 0→1 power dive progress
  final double          phase2T;    // 0→1 brake+blast+shake progress
  final double          phase3T;    // 0→1 system boot-up progress
  final double          bobT;       // 0→1 idle hover bob
  final double          thrusterT;  // 0→1 thruster flicker
  final TerraLichIdleAnim idleAnim;
  final double          idleT;      // 0→1 current idle anim progress
  final double          chargeT;    // 0→1 charge-up progress
  final double          beamT;      // 0→1 EMP beam progress
  final TerraLichPhase  phase;

  const _TerraLichPainter({
    required this.entryT,
    required this.phase1T,
    required this.phase2T,
    required this.phase3T,
    required this.bobT,
    required this.thrusterT,
    required this.idleAnim,
    required this.idleT,
    required this.chargeT,
    required this.beamT,
    required this.phase,
  });

  @override
  bool shouldRepaint(_TerraLichPainter o) =>
      o.entryT != entryT || o.phase1T != phase1T || o.phase2T != phase2T ||
      o.phase3T != phase3T || o.bobT != bobT || o.thrusterT != thrusterT ||
      o.idleAnim != idleAnim || o.idleT != idleT ||
      o.chargeT != chargeT || o.beamT != beamT || o.phase != phase;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Anchor position ────────────────────────────────────────────────────
    final cx = size.width / 2;

    // Phase 1: boss dives from -380px above screen to hover position.
    // entryT drives position (0 = off-screen top, 1 = in place).
    final bobOffset  = math.sin(bobT * math.pi) * 4.0;
    const baseTop    = 32.0;
    final entrySlide = (1.0 - entryT) * -380.0;
    final ht = baseTop + entrySlide + bobOffset;

    // Offline = body dark (Phase 1 + Phase 2 = before boot-up)
    final isOffline  = phase3T <= 0.0;

    // Boot-up progressive online factor (0 = fully offline, 1 = fully online)
    final onlineT    = isOffline ? 0.0 : phase3T;

    // ── Phase 2: Screen shake ─────────────────────────────────────────────
    if (phase2T > 0 && phase2T < 1.0) {
      final shakeFade   = (1.0 - phase2T).clamp(0.0, 1.0);
      final shakeAmt    = 8.0 * shakeFade;
      final shakeX      = math.sin(phase2T * 55) * shakeAmt;
      final shakeY      = math.cos(phase2T * 42) * shakeAmt * 0.6;
      canvas.save();
      canvas.translate(shakeX, shakeY);
    }

    // ── Flex animation ────────────────────────────────────────────────────
    final flexUp = idleAnim == TerraLichIdleAnim.mechanicalFlex
        ? math.sin(idleT * math.pi) * 8.0
        : 0.0;

    // ── Charge: arms raise angle ──────────────────────────────────────────
    final chargeAngle = Curves.easeInOut.transform(chargeT);

    // ── Draw order: thruster fire → body → arms → head → overlays ────────

    // Phase 2: massive entry brake blast (green plasma explosion)
    if (phase2T > 0) {
      _drawEntryBlast(canvas, size, cx, ht, phase2T);
    }

    _drawThrusterFire(canvas, cx, ht, thrusterT,
        idleAnim == TerraLichIdleAnim.mechanicalFlex ? idleT : 0.0,
        phase2T, onlineT);
    _drawThruster(canvas, cx, ht);
    _drawChest(canvas, cx, ht, flexUp, chargeAngle, onlineT);
    _drawEnergyPipes(canvas, cx, ht, flexUp,
        idleAnim == TerraLichIdleAnim.energyPulse ? idleT : 0.0,
        chargeAngle, onlineT);
    _drawArms(canvas, cx, ht, flexUp, chargeAngle, onlineT);
    _drawNeck(canvas, cx, ht, flexUp, onlineT);
    _drawHelmet(canvas, cx, ht, flexUp);
    _drawVisor(canvas, cx, ht, flexUp, onlineT);

    // Phase 3: boot-up visual sequence overlay
    if (phase3T > 0 && phase3T < 1.0) {
      _drawBootSequence(canvas, size, cx, ht, phase3T);
    }

    // Restore shake translate
    if (phase2T > 0 && phase2T < 1.0) canvas.restore();

    // ── Idle animation overlays ───────────────────────────────────────────
    if (idleAnim == TerraLichIdleAnim.scannerSweep && idleT > 0 && onlineT >= 1.0) {
      _drawScannerLaser(canvas, size, cx, ht, idleT);
    }

    // ── Charge glow / reactor open ────────────────────────────────────────
    if (chargeT > 0) {
      _drawChargeEffect(canvas, cx, ht, chargeAngle);
    }

    // ── EMP Beam ──────────────────────────────────────────────────────────
    if (beamT > 0) {
      _drawEmpBeam(canvas, size, cx, ht, beamT);
    }
  }

  // ── Helmet ────────────────────────────────────────────────────────────────

  void _drawHelmet(Canvas canvas, double cx, double ht, double flexUp) {
    final top = ht - flexUp;

    // Outer helmet shell
    final helmetPath = Path()
      ..moveTo(cx - 20, top + 2)
      ..lineTo(cx + 20, top + 2)
      ..quadraticBezierTo(cx + 35, top + 4, cx + 36, top + 18)
      ..lineTo(cx + 36, top + 40)
      ..quadraticBezierTo(cx + 34, top + 52, cx + 22, top + 54)
      ..lineTo(cx - 22, top + 54)
      ..quadraticBezierTo(cx - 34, top + 52, cx - 36, top + 40)
      ..lineTo(cx - 36, top + 18)
      ..quadraticBezierTo(cx - 35, top + 4, cx - 20, top + 2)
      ..close();

    // Base metal fill
    canvas.drawPath(helmetPath, Paint()
      ..color = _kMetal
      ..style = PaintingStyle.fill);

    // Top ridge
    final ridgePath = Path()
      ..moveTo(cx - 14, top + 2)
      ..lineTo(cx + 14, top + 2)
      ..lineTo(cx + 10, top - 6)
      ..lineTo(cx,      top - 9)
      ..lineTo(cx - 10, top - 6)
      ..close();
    canvas.drawPath(ridgePath, Paint()
      ..color = _kMetalHi
      ..style = PaintingStyle.fill);
    canvas.drawPath(ridgePath, Paint()
      ..color = _kOrange.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Helmet edge highlight
    canvas.drawPath(helmetPath, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8);

    // Side ear-panels
    for (final side in [-1, 1]) {
      final ex = cx + side * 36.0;
      final earPath = Path()
        ..moveTo(ex,            top + 16)
        ..lineTo(ex + side * 8, top + 20)
        ..lineTo(ex + side * 8, top + 38)
        ..lineTo(ex,            top + 42)
        ..close();
      canvas.drawPath(earPath, Paint()
        ..color = _kMetalHi
        ..style = PaintingStyle.fill);
      canvas.drawPath(earPath, Paint()
        ..color = _kOrange.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
      // Vent lines on ear panel
      for (int v = 0; v < 3; v++) {
        final vy = top + 24 + v * 5.0;
        canvas.drawLine(
          Offset(ex + side * 2, vy),
          Offset(ex + side * 7, vy),
          Paint()..color = _kNeonGreen.withOpacity(0.55)..strokeWidth = 1.0,
        );
      }
    }

    // Top antenna nubs
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(cx + side * 8, top - 8),
        3.5,
        Paint()
          ..color = _kRed
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(Offset(cx + side * 8, top - 8), 2.0,
        Paint()..color = _kAmber);
    }
  }

  // ── Visor ─────────────────────────────────────────────────────────────────

  void _drawVisor(Canvas canvas, double cx, double ht, double flexUp, double onlineT) {
    final top = ht - flexUp;
    // Visor trapezoid
    final visorPath = Path()
      ..moveTo(cx - 22, top + 14)
      ..lineTo(cx + 22, top + 14)
      ..lineTo(cx + 17, top + 42)
      ..lineTo(cx - 17, top + 42)
      ..close();

    // Dark glass
    canvas.drawPath(visorPath, Paint()
      ..color = const Color(0xFF1A0008)
      ..style = PaintingStyle.fill);

    // Visor glow
    canvas.drawPath(visorPath, Paint()
      ..color = _kVisor.withOpacity(0.35)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Visor border
    canvas.drawPath(visorPath, Paint()
      ..color = _kVisor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Central eye — glowing circle
    final eyeY = top + 27.0;
    // Eye lights up during boot Phase 3 (after 80% of boot)
    final eyeOnT = ((onlineT - 0.80) / 0.20).clamp(0.0, 1.0);
    canvas.drawCircle(Offset(cx, eyeY), 6,
      Paint()
        ..color = _kRed.withOpacity(0.9 * eyeOnT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    if (eyeOnT > 0) {
      canvas.drawCircle(Offset(cx, eyeY), 3.5,
        Paint()..color = _kAmber.withOpacity(eyeOnT));
      canvas.drawCircle(Offset(cx, eyeY), 1.5,
        Paint()..color = _kWhite.withOpacity(eyeOnT));
    }

    // Visor scan-line effect
    final slPaint = Paint()
      ..color = _kVisor.withOpacity(0.18)
      ..strokeWidth = 1.0;
    for (int sl = 0; sl < 4; sl++) {
      final sy = top + 17 + sl * 6.0;
      canvas.drawLine(Offset(cx - 20, sy), Offset(cx + 20, sy), slPaint);
    }
  }

  // ── Neck ──────────────────────────────────────────────────────────────────

  void _drawNeck(Canvas canvas, double cx, double ht, double flexUp, double onlineT) {
    final neckTop = ht + 54 - flexUp;
    final neckRect = Rect.fromLTWH(cx - 11, neckTop, 22, 20);

    // Base
    canvas.drawRect(neckRect, Paint()..color = _kMetalHi);

    // Glow
    canvas.drawRect(neckRect, Paint()
      ..color = _kNeonGreen.withOpacity(0.35 * onlineT)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Horizontal vertebrae grooves
    for (int i = 1; i <= 3; i++) {
      final gy = neckTop + i * 4.5;
      canvas.drawLine(
        Offset(cx - 10, gy), Offset(cx + 10, gy),
        Paint()..color = _kNeonGreen.withOpacity(0.70 * onlineT)..strokeWidth = 1.2,
      );
    }

    // Border
    canvas.drawRect(neckRect, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  // ── Chest / Torso ─────────────────────────────────────────────────────────

  void _drawChest(Canvas canvas, double cx, double ht, double flexUp, double chargeT, double onlineT) {
    final chestTop = ht + 74 - flexUp;
    // Trapezoid: wider at top (92px) narrows to 74px at bottom
    final chestPath = Path()
      ..moveTo(cx - 46, chestTop)
      ..lineTo(cx + 46, chestTop)
      ..lineTo(cx + 37, chestTop + 83)
      ..lineTo(cx - 37, chestTop + 83)
      ..close();

    // Metal fill
    canvas.drawPath(chestPath, Paint()
      ..color = _kMetal
      ..style = PaintingStyle.fill);

    // Edge highlight
    canvas.drawPath(chestPath, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8);

    // Inner panel recess
    final innerPath = Path()
      ..moveTo(cx - 38, chestTop + 8)
      ..lineTo(cx + 38, chestTop + 8)
      ..lineTo(cx + 30, chestTop + 74)
      ..lineTo(cx - 30, chestTop + 74)
      ..close();
    canvas.drawPath(innerPath, Paint()
      ..color = const Color(0xFF1A1A28)
      ..style = PaintingStyle.fill);

    // Shoulder armor caps (top of chest)
    for (final side in [-1.0, 1.0]) {
      final sx = cx + side * 46;
      final capPath = Path()
        ..moveTo(sx,              chestTop)
        ..lineTo(sx + side * 12, chestTop - 8)
        ..lineTo(sx + side * 14, chestTop + 14)
        ..lineTo(sx,              chestTop + 18)
        ..close();
      canvas.drawPath(capPath, Paint()
        ..color = _kMetalHi
        ..style = PaintingStyle.fill);
      canvas.drawPath(capPath, Paint()
        ..color = _kOrange.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
    }

    // Reactor core circle (center chest)
    final reactorCenter = Offset(cx, chestTop + 41);
    final reactorR = 14.0 + chargeT * 10.0;

    if (chargeT > 0) {
      // Charge glow expanding
      canvas.drawCircle(reactorCenter, reactorR + 8,
        Paint()
          ..color = _kAmber.withOpacity(0.15 * chargeT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }

    canvas.drawCircle(reactorCenter, reactorR,
      Paint()
        ..color = Color.lerp(_kMetal, _kAmber, chargeT * onlineT)!
        ..style = PaintingStyle.fill);
    canvas.drawCircle(reactorCenter, reactorR,
      Paint()
        ..color = _kOrange.withOpacity((0.6 + 0.4 * chargeT) * onlineT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0);

    // Inner reactor rings
    for (int ri = 1; ri <= 2; ri++) {
      canvas.drawCircle(reactorCenter, reactorR * (0.35 + ri * 0.25),
        Paint()
          ..color = _kOrange.withOpacity((0.3 + chargeT * 0.5) * onlineT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
    }

    // Side vents (horizontal lines)
    for (final side in [-1.0, 1.0]) {
      for (int v = 0; v < 4; v++) {
        final vy = chestTop + 22 + v * 8.0;
        canvas.drawLine(
          Offset(cx + side * 22, vy),
          Offset(cx + side * 35, vy),
          Paint()..color = _kNeonGreen.withOpacity(0.30)..strokeWidth = 1.2,
        );
      }
    }
  }

  // ── Energy Pipes ──────────────────────────────────────────────────────────

  void _drawEnergyPipes(Canvas canvas, double cx, double ht, double flexUp,
      double pulseT, double chargeT, double onlineT) {
    final pipeTop = ht + 54 - flexUp;   // starts at neck
    final pipeBot = ht + 157 - flexUp;  // ends at thruster

    // 3 vertical pipes: left, center, right
    final pipeXs = [cx - 18.0, cx, cx + 18.0];

    for (int pi = 0; pi < 3; pi++) {
      final px = pipeXs[pi];
      final basePaint = Paint()
        ..color = _kNeonGreen.withOpacity(0.25)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      basePaint.color = _kNeonGreen.withOpacity(0.25 * onlineT);
      canvas.drawLine(Offset(px, pipeTop), Offset(px, pipeBot), basePaint);

      // Energy pulse: bright flash races from head (pipeTop) to hand area
      if (pulseT > 0) {
        final delay = pi * 0.12; // stagger across 3 pipes
        final localT = ((pulseT - delay) / 0.7).clamp(0.0, 1.0);
        if (localT > 0) {
          final pulseY   = pipeTop + localT * (pipeBot - pipeTop);
          final tailLen  = 28.0;
          final gradPaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _kNeonGreen.withOpacity(0),
                _kNeonGreen.withOpacity(0.85),
                _kWhite.withOpacity(0.6),
              ],
            ).createShader(Rect.fromLTWH(px - 2, pulseY - tailLen, 4, tailLen))
            ..strokeWidth = 4.0
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(px, pulseY - tailLen), Offset(px, pulseY), gradPaint);

          // Glow at head
          canvas.drawCircle(Offset(px, pulseY), 4.0,
            Paint()
              ..color = _kNeonGreen.withOpacity(0.65 * (1 - localT))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        }
      }

      // Charge state: pipes glow bright
      if (chargeT > 0) {
        canvas.drawLine(
          Offset(px, pipeTop), Offset(px, pipeBot),
          Paint()
            ..color = _kAmber.withOpacity(0.5 * chargeT)
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * chargeT),
        );
      }
    }
  }

  // ── Arms ─────────────────────────────────────────────────────────────────

  void _drawArms(Canvas canvas, double cx, double ht, double flexUp, double chargeT) {
    final shoulderY = ht + 82 - flexUp;

    for (final side in [-1.0, 1.0]) {
      _drawArm(canvas, cx, shoulderY, side, chargeT, onlineT);
    }
  }

  void _drawArm(Canvas canvas, double cx, double shoulderY,
      double side, double chargeT, double onlineT) {

    // ── Joint positions: normal vs charge ─────────────────────────────────
    // Normal: arm hangs at ~40° outward + downward
    // Charge: arm raises to ~50° above horizontal, both converge upward
    // Strike: arms snap down toward center-bottom

    final chargeFrac = Curves.easeIn.transform(chargeT);

    // Shoulder (fixed to body)
    final shoulder = Offset(cx + side * 47, shoulderY);

    // Normal positions (charge=0)
    final elbowNorm = Offset(cx + side * 74, shoulderY + 36);
    final wristNorm = Offset(cx + side * 64, shoulderY + 66);

    // Charge positions (charge=1): arms raise above body
    final elbowCharge = Offset(cx + side * 56, shoulderY - 28);
    final wristCharge = Offset(cx + side * 30, shoulderY - 55);

    final elbow = Offset.lerp(elbowNorm, elbowCharge, chargeFrac)!;
    final wrist = Offset.lerp(wristNorm, wristCharge, chargeFrac)!;

    // ── Arm segment paint ─────────────────────────────────────────────────
    final armPaint = Paint()
      ..color = _kMetalHi
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    final armEdge = Paint()
      ..color = _kMetalEdge
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final armGlowPaint = Paint()
      ..color = Color.lerp(_kNeonGreen, _kAmber, chargeFrac)!.withOpacity((0.30 + 0.50 * chargeFrac) * onlineT)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Draw upper arm
    canvas.drawLine(shoulder, elbow, armGlowPaint);
    canvas.drawLine(shoulder, elbow, armPaint);
    canvas.drawLine(shoulder, elbow, armEdge);

    // Draw lower arm
    canvas.drawLine(elbow, wrist, armGlowPaint);
    canvas.drawLine(elbow, wrist, armPaint);
    canvas.drawLine(elbow, wrist, armEdge);

    // ── Shoulder joint ────────────────────────────────────────────────────
    canvas.drawCircle(shoulder, 9,
      Paint()..color = _kMetalHi..style = PaintingStyle.fill);
    canvas.drawCircle(shoulder, 9,
      Paint()..color = _kOrange.withOpacity(0.55)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(shoulder, 5,
      Paint()..color = _kMetal);
    canvas.drawCircle(shoulder, 3,
      Paint()..color = _kNeonGreen.withOpacity(0.9));

    // ── Elbow joint ───────────────────────────────────────────────────────
    canvas.drawCircle(elbow, 7,
      Paint()..color = _kMetalHi..style = PaintingStyle.fill);
    canvas.drawCircle(elbow, 7,
      Paint()..color = _kOrange.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(elbow, 3,
      Paint()..color = _kNeonGreen.withOpacity(0.8));

    // ── Wrist / hand ──────────────────────────────────────────────────────
    final handPath = Path();
    final hSize = 9.0;
    handPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: wrist, width: hSize * 1.8, height: hSize),
      const Radius.circular(3),
    ));
    canvas.drawPath(handPath, Paint()..color = _kMetalHi);
    canvas.drawPath(handPath, Paint()
      ..color = Color.lerp(_kNeonGreen, _kAmber, chargeFrac)!.withOpacity(0.50 + 0.50 * chargeFrac)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Charge: energy crackle at wrists
    if (chargeFrac > 0.3) {
      canvas.drawCircle(wrist, 5 + 6 * chargeFrac,
        Paint()
          ..color = _kAmber.withOpacity(0.55 * chargeFrac)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * chargeFrac));
    }
  }

  // ── Thruster body ─────────────────────────────────────────────────────────

  void _drawThruster(Canvas canvas, double cx, double ht) {
    final thrTop = ht + 157;

    // Waist connector (narrows)
    final waistPath = Path()
      ..moveTo(cx - 37, thrTop)
      ..lineTo(cx + 37, thrTop)
      ..lineTo(cx + 22, thrTop + 16)
      ..lineTo(cx - 22, thrTop + 16)
      ..close();
    canvas.drawPath(waistPath, Paint()..color = _kMetalHi);
    canvas.drawPath(waistPath, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Thruster bell
    final bellPath = Path()
      ..moveTo(cx - 22, thrTop + 16)
      ..quadraticBezierTo(cx - 26, thrTop + 34, cx - 20, thrTop + 52)
      ..lineTo(cx - 15, thrTop + 56)
      ..lineTo(cx + 15, thrTop + 56)
      ..lineTo(cx + 20, thrTop + 52)
      ..quadraticBezierTo(cx + 26, thrTop + 34, cx + 22, thrTop + 16)
      ..close();

    canvas.drawPath(bellPath, Paint()..color = _kMetal);
    canvas.drawPath(bellPath, Paint()
      ..color = _kMetalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8);

    // Internal ribs on bell
    for (int rib = 1; rib <= 3; rib++) {
      final ry  = thrTop + 20 + rib * 10.0;
      final rw  = 16.0 + rib * 2.0;
      canvas.drawLine(
        Offset(cx - rw, ry),
        Offset(cx + rw, ry),
        Paint()..color = _kMetalEdge..strokeWidth = 1.0,
      );
    }

    // Engine nozzle ring
    final nozzleCenter = Offset(cx, thrTop + 58);
    canvas.drawCircle(nozzleCenter, 18,
      Paint()..color = _kMetal..style = PaintingStyle.fill);
    canvas.drawCircle(nozzleCenter, 18,
      Paint()
        ..color = _kOrange.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
    canvas.drawCircle(nozzleCenter, 12,
      Paint()
        ..color = _kFire1.withOpacity(0.5)
        ..style = PaintingStyle.fill);
    canvas.drawCircle(nozzleCenter, 12,
      Paint()
        ..color = _kOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

    // Outer glow ring
    canvas.drawCircle(nozzleCenter, 22,
      Paint()
        ..color = _kOrange.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  // ── Thruster plasma fire ──────────────────────────────────────────────────

  void _drawThrusterFire(Canvas canvas, double cx, double ht,
      double thrusterT, double flexT, double brakeT, double onlineT) {
    // Normal idle fire only when online (brake blast drawn separately)
    if (onlineT <= 0 || brakeT > 0) return;
    final fireBase = ht + 216;  // just below nozzle
    final extraBurst = flexT > 0 ? math.sin(flexT * math.pi) * 30.0 : 0.0;
    final fireLen   = 60.0 + thrusterT * 28.0 + extraBurst;
    final corePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _kFire2.withOpacity(0.95),
          _kFire1.withOpacity(0.75),
          _kOrange.withOpacity(0.4),
          _kOrange.withOpacity(0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(cx - 8, fireBase, 16, fireLen));

    // Core fire stream
    final firePath = Path()
      ..moveTo(cx - 10, fireBase)
      ..quadraticBezierTo(cx - 4, fireBase + fireLen * 0.5, cx, fireBase + fireLen)
      ..quadraticBezierTo(cx + 4, fireBase + fireLen * 0.5, cx + 10, fireBase)
      ..close();
    canvas.drawPath(firePath, corePaint);

    // Outer glow
    canvas.drawPath(firePath, Paint()
      ..color = _kFire1.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Scatter particles (deterministic)
    final rng = math.Random(42);
    for (int i = 0; i < 10; i++) {
      final frac   = (i / 10.0 + thrusterT * 0.3) % 1.0;
      final py     = fireBase + frac * fireLen;
      final px     = cx + (rng.nextDouble() - 0.5) * 22 * frac;
      final pr     = (3.0 - frac * 2.5).clamp(0.5, 3.0);
      final alpha  = (1.0 - frac) * 0.7;
      canvas.drawCircle(Offset(px, py), pr, Paint()
        ..color = _kAmber.withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // Mechanical flex: extra burst halo
    if (extraBurst > 0) {
      canvas.drawCircle(
        Offset(cx, fireBase + 8),
        18 + extraBurst * 0.5,
        Paint()
          ..color = _kAmber.withOpacity(0.18 * (extraBurst / 30.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
  }

  // ── Scanner laser ─────────────────────────────────────────────────────────

  void _drawScannerLaser(Canvas canvas, Size size, double cx, double ht,
      double scanT) {
    // Eye position
    final eyePos = Offset(cx, ht + 27);

    // Sweep progress: 0→1 goes left-edge → right-edge with slight overshoot
    final sweep = Curves.easeInOut.transform(scanT);
    final targetX = -40.0 + sweep * (size.width + 80);

    // Neck rotate illusion: slight canvas skew on head
    canvas.save();
    final neckLean = (sweep - 0.5) * 0.08; // tiny tilt
    canvas.transform(Matrix4.identity()
      ..translate(cx, ht + 54.0)
      ..rotateZ(neckLean)
      ..translate(-cx, -(ht + 54.0))
      .storage);

    // Draw laser beam from eye to scan target
    final beamPaint = Paint()
      ..color = _kScan.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(eyePos, Offset(targetX, eyePos.dy), beamPaint);

    // Bright dot at scan point
    canvas.drawCircle(Offset(targetX, eyePos.dy), 4.5,
      Paint()
        ..color = _kScan
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    canvas.restore();
  }

  // ── Charge-up effect ──────────────────────────────────────────────────────

  void _drawChargeEffect(Canvas canvas, double cx, double ht, double chargeT) {
    final reactorCenter = Offset(cx, ht + 74 + 41);

    // Expanding ring waves
    for (int ring = 0; ring < 3; ring++) {
      final rt = (chargeT - ring * 0.2).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final r     = 14.0 + rt * 40;
      final alpha = (1.0 - rt) * 0.5;
      canvas.drawCircle(reactorCenter, r, Paint()
        ..color = _kAmber.withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // Orange energy swirl particles
    final rng = math.Random(7);
    for (int i = 0; i < 8; i++) {
      final angle  = i * math.pi * 2 / 8 + chargeT * math.pi * 3;
      final radius = 22.0 + chargeT * 14.0;
      final pos    = reactorCenter + Offset(
        math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawCircle(pos, 2.5 + rng.nextDouble() * 2,
        Paint()
          ..color = _kAmber.withOpacity(0.7 * chargeT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  // ── EMP Beam ──────────────────────────────────────────────────────────────

  void _drawEmpBeam(Canvas canvas, Size size, double cx, double ht,
      double beamT) {
    final beamStart = Offset(cx, ht + 74 + 41); // reactor center

    // Beam fades in fast, holds, then fades out at the end
    final alpha = beamT < 0.15
        ? beamT / 0.15
        : beamT > 0.75
            ? (1.0 - beamT) / 0.25
            : 1.0;

    // Screen shake: offset the beam end slightly
    final shakeX = math.sin(beamT * 28) * 4.0 * (1.0 - beamT);

    final beamEnd = Offset(cx + shakeX, size.height);

    // Outer glow
    canvas.drawLine(beamStart, beamEnd,
      Paint()
        ..color = _kRed.withOpacity(0.25 * alpha)
        ..strokeWidth = 28.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Mid glow
    canvas.drawLine(beamStart, beamEnd,
      Paint()
        ..color = _kRed.withOpacity(0.65 * alpha)
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round);

    // Core beam
    canvas.drawLine(beamStart, beamEnd,
      Paint()
        ..color = _kWhite.withOpacity(0.9 * alpha)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round);

    // Impact flash at start (chest opening)
    canvas.drawCircle(beamStart, 20 * alpha,
      Paint()
        ..color = _kAmber.withOpacity(0.6 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Impact flash at bottom (on grid)
    canvas.drawCircle(beamEnd, 18 * alpha,
      Paint()
        ..color = _kRed.withOpacity(0.75 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  }
}


  // ── Entry Blast (Phase 2) — Massive green plasma explosion on brake ─────────

  void _drawEntryBlast(Canvas canvas, Size size, double cx, double ht, double p2) {
    final nozzleCenter = Offset(cx, ht + 216); // nozzle position

    // Blast fade: rises fast (0→0.4) then fades out (0.4→1.0)
    final blastAlpha = p2 < 0.40
        ? p2 / 0.40
        : (1.0 - (p2 - 0.40) / 0.60).clamp(0.0, 1.0);

    // Core blast: massive green expanding circle
    final blastR = 20.0 + p2 * 110.0;
    canvas.drawCircle(nozzleCenter, blastR,
      Paint()
        ..color = _kNeonGreen.withOpacity(0.18 * blastAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blastR * 0.5));

    // Tight inner glow
    canvas.drawCircle(nozzleCenter, blastR * 0.4,
      Paint()
        ..color = _kNeonGreen.withOpacity(0.55 * blastAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

    // Downward plasma jet: long thick stream straight down
    final jetLen  = 80.0 + p2 * 160.0;
    final jetPath = Path()
      ..moveTo(cx - 12 * (1 - p2 * 0.5), nozzleCenter.dy)
      ..quadraticBezierTo(cx, nozzleCenter.dy + jetLen * 0.6,
           cx - 3, nozzleCenter.dy + jetLen)
      ..quadraticBezierTo(cx, nozzleCenter.dy + jetLen * 0.6,
           cx + 12 * (1 - p2 * 0.5), nozzleCenter.dy)
      ..close();

    canvas.drawPath(jetPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _kNeonGreen.withOpacity(0.90 * blastAlpha),
          _kNeonGreen.withOpacity(0.40 * blastAlpha),
          _kNeonGreen.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(cx - 12, nozzleCenter.dy, 24, jetLen)));

    // 24 radial particle shards
    final rng = math.Random(99);
    for (int i = 0; i < 24; i++) {
      final angle   = i * math.pi * 2 / 24 + rng.nextDouble() * 0.2;
      final speed   = 60.0 + rng.nextDouble() * 90.0;
      final dist    = p2 * speed;
      final pos     = nozzleCenter + Offset(math.cos(angle) * dist,
          math.sin(angle) * dist + dist * 0.6); // bias downward
      final alpha   = (1.0 - p2 * 1.1).clamp(0.0, 1.0) * blastAlpha;
      final pr      = (4.0 + rng.nextDouble() * 5.0) * (1.0 - p2 * 0.55);
      canvas.drawCircle(pos, pr.clamp(0.5, 10.0), Paint()
        ..color = _kNeonGreen.withOpacity(alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 0.5));
    }

    // Shockwave ring
    final swR  = 30.0 + p2 * 80.0;
    final swA  = (1.0 - p2).clamp(0.0, 0.6) * blastAlpha;
    canvas.drawCircle(nozzleCenter, swR, Paint()
      ..color = _kNeonGreen.withOpacity(swA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  // ── Boot Sequence Overlay (Phase 3) — pipes → chest → eye ─────────────────

  void _drawBootSequence(Canvas canvas, Size size, double cx, double ht, double p3) {
    // Scan-line effect: a bright horizontal sweep that moves down the boss body
    // during early boot (0→0.55)
    if (p3 < 0.60) {
      final scanFrac  = (p3 / 0.60).clamp(0.0, 1.0);
      final scanTop   = ht - 10.0;
      final scanBot   = ht + 230.0;
      final scanY     = scanTop + scanFrac * (scanBot - scanTop);

      // Scan glow line
      canvas.drawRect(
        Rect.fromLTWH(cx - 60, scanY - 2, 120, 4),
        Paint()
          ..color = _kNeonGreen.withOpacity(0.65 * (1.0 - scanFrac))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Pipe surge: sequential flash along each pipe channel
    final pipeXs = [cx - 18.0, cx, cx + 18.0];
    for (int pi = 0; pi < 3; pi++) {
      final delay  = pi * 0.14;
      final localT = ((p3 - delay) / 0.35).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final pipeTop = ht + 54;
      final pipeBot = ht + 157;
      final surgeY  = pipeTop + localT * (pipeBot - pipeTop);
      final tailLen = 40.0;
      canvas.drawRect(
        Rect.fromLTWH(pipeXs[pi] - 3, surgeY - tailLen, 6, tailLen),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _kNeonGreen.withOpacity(0),
              _kNeonGreen.withOpacity(0.95),
              _kWhite.withOpacity(0.5),
            ],
          ).createShader(Rect.fromLTWH(
              pipeXs[pi] - 3, surgeY - tailLen, 6, tailLen))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Chest armor glow flash (after 50%)
    if (p3 > 0.50) {
      final cFrac   = ((p3 - 0.50) / 0.25).clamp(0.0, 1.0);
      final chestTop = ht + 74;
      final chestPath = Path()
        ..moveTo(cx - 46, chestTop)
        ..lineTo(cx + 46, chestTop)
        ..lineTo(cx + 37, chestTop + 83)
        ..lineTo(cx - 37, chestTop + 83)
        ..close();
      canvas.drawPath(chestPath, Paint()
        ..color = _kNeonGreen.withOpacity(0.22 * cFrac * (1.0 - cFrac * 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }

    // Eye snap-on flash (after 80%)
    if (p3 > 0.80) {
      final eFrac = ((p3 - 0.80) / 0.15).clamp(0.0, 1.0);
      final eyeY  = ht + 27.0;
      // Bright flash
      canvas.drawCircle(Offset(cx, eyeY), 16 * (1.0 - eFrac),
        Paint()
          ..color = _kRed.withOpacity(0.85 * (1.0 - eFrac))
          ..maskFilter = MaskFilter.blur(
              BlurStyle.normal, 18 * (1.0 - eFrac)));
    }
  }

// ═══════════════════════════════════════════════════════════════════════════════
// ── Win Blast Painter ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _WinBlastPainter extends CustomPainter {
  final double t; // 0→1
  const _WinBlastPainter({required this.t});

  @override
  bool shouldRepaint(_WinBlastPainter o) => o.t != t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width / 2;
    final cy  = 130.0; // boss center y
    final c   = Offset(cx, cy);

    // Phase 0 (0→0.2): White EMP flash
    if (t < 0.20) {
      final a = (t / 0.20).clamp(0.0, 1.0) * 0.82;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kWhite.withOpacity(a),
      );
      return;
    }

    final pt = ((t - 0.20) / 0.80).clamp(0.0, 1.0);

    // Shockwave rings
    for (int ring = 0; ring < 4; ring++) {
      final rt     = (pt - ring * 0.10).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final r      = rt * (160 + ring * 35);
      final alpha  = (1.0 - rt).clamp(0.0, 1.0) * 0.60;
      final colors = [_kRed, _kOrange, _kAmber, _kFire1];
      canvas.drawCircle(c, r, Paint()
        ..color = colors[ring % 4].withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3.5 - ring * 0.5) * (1.0 - rt * 0.4));
    }

    // 20 metal shard particles
    final rng = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final angle  = i * math.pi * 2 / 20 + rng.nextDouble() * 0.3;
      final speed  = 80.0 + rng.nextDouble() * 130;
      final dist   = pt * speed;
      final pos    = c + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final alpha  = (1.0 - pt * 1.1).clamp(0.0, 1.0);
      final pr     = (5.0 + rng.nextDouble() * 6.0) * (1.0 - pt * 0.6);
      final col    = i % 3 == 0 ? _kRed : (i % 3 == 1 ? _kAmber : _kOrange);
      canvas.drawCircle(pos, pr.clamp(0.5, 12.0), Paint()
        ..color = col.withOpacity(alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pr * 0.5));
    }

    // Core remnant (expands + fades)
    if (pt < 0.5) {
      final bFrac = 1.0 - pt / 0.5;
      canvas.drawCircle(c, (1.0 + pt * 1.5) * 32 * bFrac, Paint()
        ..color = _kOrange.withOpacity(0.35 * bFrac)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }

    // Victory text
    if (pt > 0.40) {
      final textFrac = ((pt - 0.40) / 0.30).clamp(0.0, 1.0);
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
              Shadow(color: _kAmber.withOpacity(tAlpha), blurRadius: 18),
              Shadow(color: _kRed.withOpacity(tAlpha * 0.5), blurRadius: 30),
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
