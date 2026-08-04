// warp_sentinel_overlay.dart — WARP SENTINEL Visual Overlay v3
// Boss floats ABOVE the grid anchored to row-0; energy tether connects to active hole.
// Layered professional design: hex-armor torso, dual visor, arm cannons,
// shoulder spaulders, particle halo, flowing energy cape, wings during attack.
// Teleport: body pixelates → dots spiral INTO hole → reassemble from other hole.

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../controllers/warp_sentinel_controller.dart';

// ─── Shared colour tokens ─────────────────────────────────────────────────────
const _kPurple     = Color(0xFF9B30FF);
const _kPurpleDim  = Color(0xFF3D0080);
const _kCyan       = Color(0xFF00EEFF);
const _kArmor      = Color(0xFF0E0628);
const _kArmorMid   = Color(0xFF1C0A40);
const _kVisorGlow  = Color(0xFFCC66FF);
const _kStunBlue   = Color(0xFF22AAFF);
const _kWhite      = Color(0xFFFFFFFF);

// ─── Widget ───────────────────────────────────────────────────────────────────

class WarpSentinelOverlay extends StatefulWidget {
  final WarpSentinelController controller;
  final bool isDialogActive;
  final Rect? Function(int col, int row) getCellRect;

  const WarpSentinelOverlay({
    super.key,
    required this.controller,
    required this.isDialogActive,
    required this.getCellRect,
  });

  @override
  State<WarpSentinelOverlay> createState() => _WarpSentinelOverlayState();
}

class _WarpSentinelOverlayState extends State<WarpSentinelOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bob;
  late final AnimationController _holeSpin;
  late final AnimationController _corePulse;
  late final AnimationController _vortex;
  late final AnimationController _warnPulse;
  late final AnimationController _shake;
  late final AnimationController _glitch;
  late final AnimationController _entry;
  late final AnimationController _teleport;
  late final AnimationController _win;
  late final AnimationController _particle;
  // Drives the particle-streak animation when an item is siphoned into the hole
  late final AnimationController _siphonFlash;

  @override
  void initState() {
    super.initState();
    _bob        = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _holeSpin   = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    _corePulse  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _vortex     = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _warnPulse  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..repeat(reverse: true);
    _shake      = AnimationController(vsync: this, duration: const Duration(milliseconds: 55))..repeat();
    _glitch     = AnimationController(vsync: this, duration: const Duration(milliseconds: 75))..repeat();
    _entry      = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    _teleport   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _win        = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _particle   = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))..repeat();
    // Siphon streak: 1500ms one-shot — long enough for all simultaneous victims
    _siphonFlash = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(WarpSentinelOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (!mounted) return;
    final c = widget.controller;
    if (c.phase == WarpSentinelPhase.entry && !c.entryComplete) {
      _entry.forward(from: 0);
    }
    if (c.isTeleporting && _teleport.status != AnimationStatus.forward) {
      _teleport.forward(from: 0);
    } else if (!c.isTeleporting && _teleport.isCompleted) {
      _teleport.reset();
    }
    if (c.phase == WarpSentinelPhase.winBlast && !_win.isAnimating) {
      _win.forward(from: 0);
    }
    // Trigger siphon streak animation each time an item is newly siphoned
    if (c.recentSiphons.isNotEmpty && !_siphonFlash.isAnimating) {
      _siphonFlash.forward(from: 0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    for (final ac in [_bob, _holeSpin, _corePulse, _vortex, _warnPulse,
                      _shake, _glitch, _entry, _teleport, _win, _particle,
                      _siphonFlash]) {
      ac.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c.phase == WarpSentinelPhase.idle) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _bob, _holeSpin, _corePulse, _vortex, _warnPulse,
        _shake, _glitch, _entry, _teleport, _win, _particle, _siphonFlash,
      ]),
      builder: (_, __) {
        final shaking = widget.controller.isPulling;
        final shakeX  = shaking ? (Random(_shake.value.hashCode ^ 1).nextDouble() - .5) * 6 : 0.0;
        final shakeY  = shaking ? (Random(_shake.value.hashCode ^ 2).nextDouble() - .5) * 6 : 0.0;

        Widget scene = CustomPaint(
          painter: _WarpScenePainter(
            controller:    widget.controller,
            getCellRect:   widget.getCellRect,
            bobT:          _bob.value,
            holeSpinT:     _holeSpin.value,
            corePulseT:    _corePulse.value,
            vortexT:       _vortex.value,
            warnPulseT:    _warnPulse.value,
            shakeT:        _shake.value,
            glitchT:       _glitch.value,
            entryT:        _entry.value,
            teleportT:     _teleport.value,
            winT:          _win.value,
            particleT:     _particle.value,
            siphonFlashT:  _siphonFlash.value,
          ),
          child: _buildHUD(widget.controller),
        );
        if (shakeX != 0 || shakeY != 0) {
          scene = Transform.translate(offset: Offset(shakeX, shakeY), child: scene);
        }
        return scene;
      },
    );
  }

  Widget _buildHUD(WarpSentinelController c) => Stack(children: [
    if (c.dialogueText != null)
      Positioned(top: 8, left: 12, right: 12,
          child: _DialogueBubble(text: c.dialogueText!)),
    if (c.isStunned)
      Positioned(bottom: 80, left: 24, right: 24,
          child: _StunBar(secsLeft: c.stunSecsLeft)),
    if (c.isWarning)
      Positioned(top: 60, right: 16,
          child: _CountdownRing(secsLeft: c.warningSecsLeft, color: _kPurple, label: 'WARN')),
    if (c.isPulling)
      Positioned(top: 60, right: 16,
          child: _CountdownRing(secsLeft: c.pullSecsLeft, color: const Color(0xFFFF2222), label: 'PULL')),
    if (c.phase == WarpSentinelPhase.active && !c.isWarning && !c.isPulling)
      Positioned(bottom: 8, left: 12, right: 12,
          child: _HintStrip(hint: kWarpHints[c.hintIndex])),
  ]);
}

// ─── Main Painter ─────────────────────────────────────────────────────────────

class _WarpScenePainter extends CustomPainter {
  final WarpSentinelController controller;
  final Rect? Function(int col, int row) getCellRect;
  final double bobT, holeSpinT, corePulseT, vortexT, warnPulseT;
  final double shakeT, glitchT, entryT, teleportT, winT, particleT;
  final double siphonFlashT; // 0→1 one-shot per siphon event

  const _WarpScenePainter({
    required this.controller,
    required this.getCellRect,
    required this.bobT, required this.holeSpinT, required this.corePulseT,
    required this.vortexT, required this.warnPulseT, required this.shakeT,
    required this.glitchT, required this.entryT, required this.teleportT,
    required this.winT, required this.particleT, required this.siphonFlashT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    if (c.glitchActive) { _paintGlitch(canvas, size); return; }

    // Zone tiles
    if (c.isWarning || c.isPulling) {
      for (final cell in c.pullZoneCells) {
        final r = getCellRect(cell.$1, cell.$2);
        if (r != null) _paintZoneTile(canvas, r, warnPulseT, c.isPulling, shakeT);
      }
    }

    // Black holes
    for (int i = 0; i < c.blackHoles.length; i++) {
      final hr = getCellRect(c.blackHoles[i].$1, c.blackHoles[i].$2);
      if (hr == null) continue;
      _paintBlackHole(canvas, hr, holeSpinT,
          isActive:   i == c.bossHoleIndex,
          entryScale: c.phase == WarpSentinelPhase.entry ? entryT : 1.0,
          isFrom:     c.isTeleporting && i == c.fromHoleIndex,
          isDest:     c.isTeleporting && i == c.toHoleIndex);
    }

    // Attack vortex
    if ((c.isWarning || c.isPulling) && c.blackHoles.isNotEmpty) {
      final hr = getCellRect(c.blackHoles[c.bossHoleIndex].$1,
                             c.blackHoles[c.bossHoleIndex].$2);
      if (hr != null) _paintAttackVortex(canvas, hr.center, vortexT, c.isPulling);
    }

    // ── Siphon streak: item spiraling into the black hole ─────────────────────
    // Use OR so the streak keeps painting until the animation fully completes,
    // even if recentSiphons was cleared by its 850ms timer a frame earlier.
    if (c.recentSiphons.isNotEmpty || siphonFlashT > 0.01) {
      _paintSiphonStreaks(canvas, c);
    }

    // ── Targeting reticle: lock-on diamond on nearest item during pull ─────────
    if (c.isPulling && c.blackHoles.isNotEmpty && c.pullZoneCells.isNotEmpty) {
      _paintTargetingReticle(canvas, c);
    }

    // Overload flash
    if (c.overloadFlash) {
      canvas.drawRect(Offset.zero & const Size(9999, 9999),
          Paint()..color = const Color(0x99FFFFFF)
                 ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    }

    // Boss
    _paintBossDispatch(canvas, size, c);

    // Win blast
    if (c.phase == WarpSentinelPhase.winBlast && winT > 0) {
      _paintWinBlast(canvas, size, winT);
    }
  }

  // ── Boss dispatch ──────────────────────────────────────────────────────────

  void _paintBossDispatch(Canvas canvas, Size size, WarpSentinelController c) {
    if (c.blackHoles.isEmpty) return;

    final bossHole = c.blackHoles[c.bossHoleIndex];
    // Anchor: top of the boss column's row-0 → boss floats ABOVE the grid
    final topRect  = getCellRect(bossHole.$1, 0);
    final holeRect = getCellRect(bossHole.$1, bossHole.$2);
    if (topRect == null || holeRect == null) return;

    final bob        = sin(bobT * pi) * 7;
    final bossCenter = Offset(topRect.center.dx, topRect.top - 75 + bob);
    final tp         = c.teleportPhase;

    if (tp == WarpTeleportPhase.idle || tp == WarpTeleportPhase.arming) {
      _paintTether(canvas, bossCenter, holeRect.center, corePulseT, c.isAttackPoseActive || c.isPulling);

      if (c.phase == WarpSentinelPhase.entry) {
        // Professional glitch-materialize: boss coalesces from the black hole
        _paintBossGlitchEntry(canvas, bossCenter, holeRect.center, c.isStunned);
      } else {
        _paintBossEntity(canvas, bossCenter,
            opacity:     1.0,
            isStunned:   c.isStunned,
            armPose:     tp == WarpTeleportPhase.arming ? _ArmPose.teleportArm
                       : c.isAttackPoseActive            ? _ArmPose.attackBoth
                       :                                   _ArmPose.idle,
            isAttacking: c.isAttackPoseActive || c.isWarning || c.isPulling);
      }

    } else if (tp == WarpTeleportPhase.dissolving) {
      final fromRect  = getCellRect(c.blackHoles[c.fromHoleIndex].$1,
                                    c.blackHoles[c.fromHoleIndex].$2);
      if (fromRect == null) return;
      final dissolveT = ((teleportT - 0.30) / 0.37).clamp(0.0, 1.0);
      _paintTether(canvas, bossCenter, fromRect.center, corePulseT, true);
      _paintBossDissolveIntoHole(canvas, bossCenter, fromRect.center,
          dissolveT, c.isStunned);

    } else if (tp == WarpTeleportPhase.materializing) {
      final toHole   = c.blackHoles[c.toHoleIndex];
      final toRect   = getCellRect(toHole.$1, toHole.$2);
      final toTop    = getCellRect(toHole.$1, 0);
      if (toRect == null || toTop == null) return;
      final materT   = ((teleportT - 0.67) / 0.33).clamp(0.0, 1.0);
      final newCenter = Offset(toTop.center.dx, toTop.top - 75 + bob);
      _paintTether(canvas, newCenter, toRect.center, corePulseT, false);
      // Materialize = reverse dissolve (materT 0→1 means going from hole to solid)
      _paintBossDissolveIntoHole(canvas, newCenter, toRect.center,
          1.0 - materT, c.isStunned);
    }
  }

  // ── Energy tether boss→hole ────────────────────────────────────────────────

  void _paintTether(Canvas canvas, Offset from, Offset to,
      double pulseT, bool isAttacking) {
    final p      = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fromPt = Offset(from.dx, from.dy + 58); // boss bottom

    // Soft glow beam
    p
      ..color = (isAttacking ? const Color(0x55FF2244) : const Color(0x44AA33FF))
      ..strokeWidth = 9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawLine(fromPt, to, p);
    p.maskFilter = null;

    // Bright core line
    p
      ..color = isAttacking
          ? Color.fromARGB((155 + (pulseT * 80).toInt()), 255, 60, 100)
          : Color.fromARGB((110 + (pulseT * 90).toInt()), 170, 80, 255)
      ..strokeWidth = 2.0;
    canvas.drawLine(fromPt, to, p);

    // Energy nodes flowing downward along tether
    final dist  = (to - fromPt).distance.clamp(1.0, 9999.0);
    final dirN  = (to - fromPt) / dist;
    final dotP  = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (int i = 1; i <= 5; i++) {
      final t   = ((i / 6.0) + pulseT) % 1.0;
      final pos = fromPt + dirN * (dist * t);
      dotP.color = (isAttacking ? const Color(0xAAFF4466) : const Color(0xAA9944FF))
                       .withOpacity(sin(t * pi) * 0.8);
      canvas.drawCircle(pos, 2.5 - t * 1.5, dotP);
    }
    dotP.maskFilter = null;
  }

  // ── Full boss entity ───────────────────────────────────────────────────────

  void _paintBossEntity(Canvas canvas, Offset center, {
    required double opacity,
    required bool   isStunned,
    required _ArmPose armPose,
    required bool   isAttacking,
  }) {
    if (opacity < 0.02) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final oi   = (opacity * 255).clamp(0, 255).toInt();
    final ac   = isStunned ? _kStunBlue : _kPurple;

    // 0. Outer atmosphere halo
    _drawBlur(canvas, Offset.zero, 50,
        (isStunned ? _kStunBlue : _kPurple).withOpacity(opacity * (.10 + corePulseT * .07)),
        blurRadius: 40);

    // 1. Energy wings (attack mode)
    if (isAttacking) _paintWings(canvas, oi, isStunned);

    // 2. Flowing energy cape (below torso)
    _paintCape(canvas, oi, isStunned);

    // 3. Orbiting particle halo
    _paintHalo(canvas, oi, isStunned);

    // 4. Thruster base (floating bottom)
    _paintThruster(canvas, oi, isStunned);

    // 5. Hex torso
    _paintTorso(canvas, oi, isStunned);

    // 6. Chest core gem
    _paintCore(canvas, oi, isStunned);

    // 7. Shoulder pauldrons
    _paintShoulders(canvas, oi, isStunned);

    // 8. Arms + cannons
    _paintArms(canvas, oi, isStunned, armPose);

    // 9. Helmet + visor
    _paintHelmet(canvas, oi, isStunned);

    // 10. Stun sparks
    if (isStunned) _paintStunSparks(canvas, oi);

    canvas.restore();
  }

  // ── Wings ─────────────────────────────────────────────────────────────────

  void _paintWings(Canvas canvas, int oi, bool isStunned) {
    final ac     = isStunned ? _kStunBlue : _kPurple;
    final spread = 0.75 + corePulseT * 0.35;
    final p      = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    for (final side in [-1.0, 1.0]) {
      for (int w = 0; w < 4; w++) {
        final wt   = w / 4.0;
        final ex   = side * (58 + wt * 28) * spread;
        final ey   = -52 - wt * 18;
        final cpx  = side * (42 + wt * 12) * spread;
        const cpy  = -28.0;
        final path = Path()
          ..moveTo(side * 22, -15)
          ..quadraticBezierTo(cpx, cpy, ex, ey);
        final alpha = (oi / 255.0) * (0.55 - wt * 0.12);
        p
          ..color = ac.withOpacity(alpha)
          ..strokeWidth = 3.8 - wt * 1.2
          ..maskFilter  = w == 0 ? const MaskFilter.blur(BlurStyle.normal, 7) : null;
        canvas.drawPath(path, p);
        p.maskFilter = null;
      }
      // Wing root glow
      _drawBlur(canvas, Offset(side * 22, -15), 6,
          ac.withOpacity((oi / 255.0) * (.4 + corePulseT * .4)), blurRadius: 8);
    }
  }

  // ── Cape ──────────────────────────────────────────────────────────────────

  void _paintCape(Canvas canvas, int oi, bool isStunned) {
    final ac  = isStunned ? _kStunBlue : _kPurple;
    final wave = sin(particleT * 2 * pi);
    final p   = Paint();

    final capePath = Path()
      ..moveTo(-18, 20)
      ..cubicTo(-36, 38, -24 + wave * 4, 72, -8, 95 + wave * 6)
      ..lineTo(8, 95 + wave * 6)
      ..cubicTo(24 - wave * 4, 72, 36, 38, 18, 20)
      ..close();

    p
      ..shader = ui.Gradient.linear(const Offset(0, 20), const Offset(0, 95), [
        Color.fromARGB((oi * 0.65).toInt(), ac.red, ac.green, ac.blue),
        Color.fromARGB(0, ac.red, ac.green, ac.blue),
      ])
      ..style = PaintingStyle.fill;
    canvas.drawPath(capePath, p);
    p.shader = null;

    // Streaming cape particles
    final rng = Random(9001);
    p
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (int i = 0; i < 14; i++) {
      final ft = ((i / 14.0) + particleT) % 1.0;
      final cx = (rng.nextDouble() - .5) * 28 * (0.4 + ft * 0.6);
      final cy = 24 + ft * 70;
      final sz = 1.2 + rng.nextDouble() * 2.0;
      p.color  = ac.withOpacity((oi / 255.0) * (1 - ft) * 0.7);
      canvas.drawCircle(Offset(cx, cy), sz, p);
    }
    p.maskFilter = null;
  }

  // ── Halo ──────────────────────────────────────────────────────────────────

  void _paintHalo(Canvas canvas, int oi, bool isStunned) {
    final ac   = isStunned ? _kStunBlue : _kPurple;
    final p    = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    const n  = 12;
    const r  = 64.0;
    for (int i = 0; i < n; i++) {
      final angle = (i / n) * 2 * pi + particleT * 2 * pi;
      final ri    = r + sin(particleT * 2 * pi * 2 + i) * 8;
      final sz    = 1.8 + sin(particleT * 2 * pi + i * 0.7) * 1.1;
      p.color = ac.withOpacity((oi / 255.0) * 0.50);
      canvas.drawCircle(Offset(cos(angle) * ri, sin(angle) * ri * 0.4 - 5), sz, p);
    }
    p.maskFilter = null;
  }

  // ── Thruster base ──────────────────────────────────────────────────────────

  void _paintThruster(Canvas canvas, int oi, bool isStunned) {
    final ac = isStunned ? _kStunBlue : _kPurple;
    final p  = Paint();

    final path = Path()
      ..moveTo(0, 22)
      ..lineTo(-24, 16)
      ..lineTo(-17, 32)
      ..lineTo(17, 32)
      ..lineTo(24, 16)
      ..close();

    p
      ..shader = ui.Gradient.linear(const Offset(0, 16), const Offset(0, 32), [
        Color.fromARGB(oi, _kArmorMid.red, _kArmorMid.green, _kArmorMid.blue),
        Color.fromARGB(oi, _kArmor.red,    _kArmor.green,    _kArmor.blue),
      ])
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, p);
    p.shader = null;

    // Thruster glow nodes
    p
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    for (final dx in [-10.0, 0.0, 10.0]) {
      p.color = ac.withOpacity((oi / 255.0) * (.45 + corePulseT * .55));
      canvas.drawCircle(Offset(dx, 32), 3.0 + corePulseT * 1.5, p);
    }
    p.maskFilter = null;

    // Segment line
    p
      ..color = ac.withOpacity((oi / 255.0) * .38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(-16, 24), const Offset(16, 24), p);
  }

  // ── Hex torso ─────────────────────────────────────────────────────────────

  void _paintTorso(Canvas canvas, int oi, bool isStunned) {
    final ac = isStunned ? _kStunBlue : _kPurple;
    final p  = Paint();

    // Hexagonal torso outline
    final torso = Path()
      ..moveTo(0, -27)
      ..lineTo(22, -18)
      ..lineTo(24, 12)
      ..lineTo(15, 22)
      ..lineTo(-15, 22)
      ..lineTo(-24, 12)
      ..lineTo(-22, -18)
      ..close();

    // Gradient fill
    p
      ..shader = ui.Gradient.linear(const Offset(0, -27), const Offset(0, 22), [
        Color.fromARGB(oi, _kArmorMid.red, _kArmorMid.green, _kArmorMid.blue),
        Color.fromARGB(oi, _kArmor.red,    _kArmor.green,    _kArmor.blue),
      ])
      ..style = PaintingStyle.fill;
    canvas.drawPath(torso, p);
    p.shader = null;

    // Glowing armor seams
    p
      ..color = ac.withOpacity((oi / 255.0) * (.30 + corePulseT * .18))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    canvas.drawLine(const Offset(-8, -20), const Offset(-8, 16), p);
    canvas.drawLine(const Offset(8, -20),  const Offset(8, 16),  p);
    canvas.drawLine(const Offset(-20, 0),  const Offset(20, 0),  p);
    canvas.drawLine(const Offset(-16, -11), const Offset(16, -11), p);

    // Torso border glow
    p
      ..color = ac.withOpacity((oi / 255.0) * 0.65)
      ..strokeWidth = 1.4;
    canvas.drawPath(torso, p);

    // Side tech vents
    p
      ..strokeWidth = 0.8
      ..color = ac.withOpacity((oi / 255.0) * 0.45);
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(Offset(s * 20, 2),  Offset(s * 20, 9),  p);
      canvas.drawLine(Offset(s * 20, 13), Offset(s * 20, 19), p);
    }
    p.style = PaintingStyle.fill;
  }

  // ── Chest core ────────────────────────────────────────────────────────────

  void _paintCore(Canvas canvas, int oi, bool isStunned) {
    final cColor = isStunned
        ? Color.fromARGB(oi, 60, 190, 255)
        : Color.fromARGB(oi, 185 + (corePulseT * 65).toInt(), 55, 255);
    final glow = .40 + corePulseT * .60;
    final p    = Paint();

    // Glow aura
    p
      ..color = cColor.withOpacity(glow * .38)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 + corePulseT * 8);
    canvas.drawCircle(Offset.zero, 15, p);
    p.maskFilter = null;

    // Ring
    p
      ..color = cColor.withOpacity(glow * .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, 11.5, p);
    p.style = PaintingStyle.fill;

    // Dark socket
    p.color = Color.fromARGB(oi, 8, 2, 22);
    canvas.drawCircle(Offset.zero, 9.5, p);

    // Radial gem
    p.shader = ui.Gradient.radial(Offset.zero, 8, [
      isStunned ? const Color(0xFFBBEEFF) : Color.fromARGB(255, 245, 185 + (corePulseT * 70).toInt(), 255),
      cColor,
      Color.fromARGB(oi, cColor.red ~/ 2, cColor.green ~/ 2, cColor.blue ~/ 2),
    ], [0.0, .55, 1.0]);
    canvas.drawCircle(Offset.zero, 8, p);
    p.shader = null;

    // Lens flare cross
    final cl = 5.5 + corePulseT * 3.0;
    p
      ..color = _kWhite.withOpacity((oi / 255.0) * glow * .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, -cl), Offset(0, cl), p);
    canvas.drawLine(Offset(-cl, 0), Offset(cl, 0), p);
    p.style = PaintingStyle.fill;

    // Diagonal ticks
    p
      ..color = _kWhite.withOpacity((oi / 255.0) * glow * .35)
      ..strokeWidth = 0.8;
    final cl2 = cl * 0.65;
    canvas.drawLine(Offset(-cl2, -cl2), Offset(cl2, cl2), p);
    canvas.drawLine(Offset(cl2, -cl2),  Offset(-cl2, cl2), p);
    p.style = PaintingStyle.fill;
  }

  // ── Shoulder pauldrons ────────────────────────────────────────────────────

  void _paintShoulders(Canvas canvas, int oi, bool isStunned) {
    final ac = isStunned ? _kStunBlue : _kPurple;
    final p  = Paint();

    for (final s in [-1.0, 1.0]) {
      final sp = Path()
        ..moveTo(s * 22, -25)
        ..lineTo(s * 34, -18)
        ..lineTo(s * 36, -2)
        ..lineTo(s * 27,  4)
        ..lineTo(s * 22, -2)
        ..close();

      p
        ..shader = ui.Gradient.linear(
          Offset(s * 22, -25), Offset(s * 36, 4),
          [Color.fromARGB(oi, _kArmorMid.red, _kArmorMid.green, _kArmorMid.blue),
           Color.fromARGB(oi, _kArmor.red,    _kArmor.green,    _kArmor.blue)])
        ..style = PaintingStyle.fill;
      canvas.drawPath(sp, p);
      p.shader = null;

      p
        ..color = ac.withOpacity((oi / 255.0) * .58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawPath(sp, p);

      // Shoulder gem
      _drawBlur(canvas, Offset(s * 28, -12), 3.5,
          ac.withOpacity((oi / 255.0) * (.45 + corePulseT * .45)), blurRadius: 5);
      p
        ..color = _kWhite.withOpacity((oi / 255.0) * .7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(s * 28, -12), 1.8, p);
    }
  }

  // ── Arms + cannons ────────────────────────────────────────────────────────

  void _paintArms(Canvas canvas, int oi, bool isStunned, _ArmPose pose) {
    final ac       = isStunned ? _kStunBlue : _kPurple;
    final armorFill = Color.fromARGB(oi, _kArmor.red, _kArmor.green, _kArmor.blue);
    final armorMid  = Color.fromARGB(oi, _kArmorMid.red, _kArmorMid.green, _kArmorMid.blue);
    final p        = Paint();

    for (final s in [-1.0, 1.0]) {
      canvas.save();
      // Pose-specific position & rotation
      double tx = s * 30, ty = -10.0, rot = 0.0;
      switch (pose) {
        case _ArmPose.idle:
          ty = -5; rot = s * 0.07;
        case _ArmPose.attackBoth:
          ty = -18; rot = s * -0.60;
        case _ArmPose.teleportArm:
          ty = -8; rot = (s == -1) ? 0.65 : -0.65;
      }
      canvas.translate(tx, ty);
      canvas.rotate(rot);

      // Upper arm
      p
        ..shader = ui.Gradient.linear(const Offset(-4, 0), const Offset(4, 20),
          [armorMid, armorFill])
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: const Offset(0, 9), width: 10, height: 19),
              const Radius.circular(3)), p);
      p.shader = null;

      // Elbow joint
      p
        ..color = armorMid
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(0, 18), 5.5, p);
      p
        ..color = ac.withOpacity((oi / 255.0) * .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(const Offset(0, 18), 5.5, p);
      p.style = PaintingStyle.fill;

      // Forearm (angular silhouette)
      final fa = Path()
        ..moveTo(-5.5, 17)
        ..lineTo(-6.5, 36)
        ..lineTo(-2.5, 44)
        ..lineTo(2.5, 44)
        ..lineTo(6.5, 36)
        ..lineTo(5.5, 17)
        ..close();
      p
        ..shader = ui.Gradient.linear(const Offset(0, 17), const Offset(0, 44),
          [armorMid, armorFill])
        ..style = PaintingStyle.fill;
      canvas.drawPath(fa, p);
      p.shader = null;
      p
        ..color = ac.withOpacity((oi / 255.0) * .40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawPath(fa, p);

      // Forearm detail seam
      p
        ..color = ac.withOpacity((oi / 255.0) * .32)
        ..strokeWidth = 0.7;
      canvas.drawLine(const Offset(0, 20), const Offset(0, 42), p);
      p.style = PaintingStyle.fill;

      // Cannon muzzle block
      p
        ..shader = ui.Gradient.radial(const Offset(0, 48), 7,
          [armorMid, armorFill])
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: const Offset(0, 49), width: 12, height: 11),
              const Radius.circular(2)), p);
      p.shader = null;

      // Muzzle ring detail
      p
        ..color = ac.withOpacity((oi / 255.0) * .50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 52), width: 8, height: 5), p);
      p.style = PaintingStyle.fill;

      // Muzzle energy glow (active when not idle)
      if (pose != _ArmPose.idle) {
        _drawBlur(canvas, const Offset(0, 55),
            7 + corePulseT * 3,
            ac.withOpacity((oi / 255.0) * (.55 + corePulseT * .40)),
            blurRadius: 12);
        p
          ..color = _kWhite.withOpacity((oi / 255.0) * .8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(0, 55), 2.8, p);
      }

      canvas.restore();
    }
  }

  // ── Helmet ────────────────────────────────────────────────────────────────

  void _paintHelmet(Canvas canvas, int oi, bool isStunned) {
    final ac       = isStunned ? _kStunBlue : _kPurple;
    final armorFill = Color.fromARGB(oi, _kArmor.red, _kArmor.green, _kArmor.blue);
    final armorMid  = Color.fromARGB(oi, _kArmorMid.red, _kArmorMid.green, _kArmorMid.blue);
    final p        = Paint();

    // Helmet shell
    final helm = Path()
      ..moveTo(0, -60)
      ..lineTo(-15, -55)
      ..lineTo(-17, -38)
      ..lineTo(-13, -27)
      ..lineTo(13, -27)
      ..lineTo(17, -38)
      ..lineTo(15, -55)
      ..close();
    p
      ..shader = ui.Gradient.linear(const Offset(0, -60), const Offset(0, -27), [
        armorMid, armorFill,
      ])
      ..style = PaintingStyle.fill;
    canvas.drawPath(helm, p);
    p.shader = null;
    p
      ..color = ac.withOpacity((oi / 255.0) * .68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(helm, p);
    p.style = PaintingStyle.fill;

    // Crown antenna
    p
      ..color = armorMid
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-2, -72, 4, 14), const Radius.circular(2)), p);
    _drawBlur(canvas, const Offset(0, -73), 4,
        ac.withOpacity((oi / 255.0) * (.55 + corePulseT * .45)), blurRadius: 7);
    p
      ..color = _kWhite.withOpacity((oi / 255.0) * .88)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -73), 2.0, p);

    // Side crest fins
    for (final s in [-1.0, 1.0]) {
      final crest = Path()
        ..moveTo(s * 14, -55)
        ..lineTo(s * 22, -50)
        ..lineTo(s * 20, -42)
        ..lineTo(s * 16, -40);
      p
        ..color = armorMid
        ..style = PaintingStyle.fill;
      canvas.drawPath(crest, p);
      p
        ..color = ac.withOpacity((oi / 255.0) * .50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      canvas.drawPath(crest, p);
      p.style = PaintingStyle.fill;
    }

    // Side tech vents
    p
      ..color = ac.withOpacity((oi / 255.0) * .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85;
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(Offset(s * 14.5, -50), Offset(s * 16.5, -44), p);
      canvas.drawLine(Offset(s * 14.5, -44), Offset(s * 16.5, -38), p);
    }

    // Dual visor lenses (two horizontal scanner slits)
    for (int vi = 0; vi < 2; vi++) {
      final vy = -47.0 + vi * 7.0;
      // Socket
      p
        ..color = Color.fromARGB(oi, 5, 0, 16)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(0, vy), width: 23, height: 5.5),
              const Radius.circular(2)), p);

      // Visor gradient sweep
      p.shader = ui.Gradient.linear(
        Offset(-11, vy), Offset(11, vy),
        isStunned
            ? [const Color(0xFF0055FF), _kCyan, const Color(0xFF0055FF)]
            : [const Color(0xFF5500BB), _kVisorGlow, const Color(0xFF5500BB)]);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(0, vy), width: 21, height: 4.0),
              const Radius.circular(1.5)), p);
      p.shader = null;

      // Visor glow
      _drawBlur(canvas, Offset(0, vy), 12,
          (isStunned ? _kCyan : _kVisorGlow)
              .withOpacity((oi / 255.0) * (.45 + corePulseT * .45)),
          blurRadius: 8);

      // Scanning cursor (moves left-right across visor)
      final scanX = sin(corePulseT * pi * 2 + (vi == 0 ? 0 : pi)) * 7.5;
      p
        ..color = _kWhite.withOpacity((oi / 255.0) * .9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(scanX, vy), 2.2, p);
      p.maskFilter = null;
    }

    // Neck collar
    p
      ..color = armorMid
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-8, -27, 16, 6), const Radius.circular(2)), p);
  }

  // ── Stun sparks ───────────────────────────────────────────────────────────

  void _paintStunSparks(Canvas canvas, int oi) {
    final rng = Random(DateTime.now().millisecondsSinceEpoch ~/ 80);
    final p   = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _kStunBlue.withOpacity((oi / 255.0) * .85);
    for (int i = 0; i < 12; i++) {
      final a  = rng.nextDouble() * 2 * pi;
      final d  = 20 + rng.nextDouble() * 42;
      final l  = 5 + rng.nextDouble() * 15;
      canvas.drawLine(
          Offset(cos(a) * d, sin(a) * d),
          Offset(cos(a + .45) * (d + l), sin(a + .45) * (d + l)), p);
    }
    p.style = PaintingStyle.fill;
  }

  // ── Entry: glitch-materialize — boss coalesces from the black hole ───────────
  // entryT 0→1 over 3.2 s:
  //   Phase A (0.00–0.90): 60 pixel-sparks shoot from holeCenter to bossCenter
  //   Phase B (0.25–1.00): boss body scan-wipes upward (bottom → top) with jitter
  //   Phase C (0.00–0.75): chromatic-aberration RGB ghosts fade away
  //   Edge glow:           bright scan-line at the materialization front

  void _paintBossGlitchEntry(
      Canvas canvas, Offset bossCenter, Offset holeCenter, bool isStunned) {
    final t  = entryT.clamp(0.0, 1.0);
    final ac = isStunned ? _kStunBlue : _kPurple;
    final p  = Paint()..style = PaintingStyle.fill;

    // ── A. Pixel sparks: 60 dots fly from holeCenter → bossCenter ────────────
    if (t < 0.90) {
      final dir   = bossCenter - holeCenter;
      final dist  = dir.distance.clamp(1.0, 9999.0);
      final dirNx = dir.dx / dist;
      final dirNy = dir.dy / dist;
      final rng   = Random(7777);

      p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      for (int d = 0; d < 60; d++) {
        final bodyAngle    = rng.nextDouble() * 2 * pi;
        final bodyR        = rng.nextDouble() * 52;
        final staggerStart = rng.nextDouble() * 0.50;
        if (t < staggerStart) continue;
        final rawProg = ((t - staggerStart) / (1.0 - staggerStart)).clamp(0.0, 1.0);
        final spiral  = cos(bodyAngle + rawProg * 3 * pi) * 12 * (1 - rawProg);

        final x = holeCenter.dx + dir.dx * rawProg
                  + cos(bodyAngle) * bodyR * rawProg
                  + spiral * dirNy;
        final y = holeCenter.dy + dir.dy * rawProg
                  + sin(bodyAngle) * bodyR * rawProg
                  - spiral * dirNx;
        final sz  = (0.8 + rawProg * 2.2).clamp(0.3, 3.0);
        final alp = (rawProg * 0.9 *
                     (1.0 - (rawProg - 0.75).clamp(0.0, 1.0) * 4))
                        .clamp(0.0, 1.0);
        p.color = ac.withOpacity(alp);
        canvas.drawCircle(Offset(x, y), sz, p);
      }
      p.maskFilter = null;
    }

    // ── B. Boss body: scan-wipe from bottom up, with horizontal jitter ───────
    final bodyProg = ((t - 0.25) * 1.35).clamp(0.0, 1.0);
    if (bodyProg > 0.01) {
      const bossBottom =  95.0; // px below bossCenter
      const bossTop    = -82.0; // px above bossCenter
      const totalH     = bossBottom - bossTop; // 177 px

      final wipeY = bossBottom - totalH * bodyProg;

      // Horizontal jitter strongest at low bodyProg, gone by ~0.7
      final jitterAmt = (1.0 - bodyProg * 1.45).clamp(0.0, 1.0);
      final jitterX   = jitterAmt > 0.02
          ? (Random(glitchT.hashCode ^ 0x1F3A).nextDouble() - 0.5) *
              10.0 * jitterAmt
          : 0.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
        bossCenter.dx - 130,
        bossCenter.dy + wipeY,
        bossCenter.dx + 130,
        bossCenter.dy + bossBottom,
      ));
      _paintBossEntity(
        canvas, Offset(bossCenter.dx + jitterX, bossCenter.dy),
        opacity:     bodyProg.clamp(0.0, 1.0),
        isStunned:   isStunned,
        armPose:     _ArmPose.idle,
        isAttacking: false,
      );
      canvas.restore();

      // Scan-line edge glow at the materialization front
      if (bodyProg < 0.97) {
        final edgeY = bossCenter.dy + wipeY;
        p
          ..color      = ac.withOpacity((1.0 - bodyProg * 0.65).clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawLine(
            Offset(bossCenter.dx - 75, edgeY),
            Offset(bossCenter.dx + 75, edgeY), p);
        p..maskFilter = null..style = PaintingStyle.fill;

        // Sparkles along the scan edge
        for (int i = 0; i < 5; i++) {
          final sx = bossCenter.dx + (i / 4.0 - 0.5) * 120.0;
          p.color = _kWhite.withOpacity(
              ((1.0 - bodyProg) * 0.65).clamp(0.0, 1.0));
          canvas.drawCircle(Offset(sx, edgeY), 1.5, p);
        }
      }
    }

    // ── C. Chromatic-aberration RGB ghosts — fade out by t ≈ 0.75 ────────────
    final aber = (1.0 - t * 1.35).clamp(0.0, 1.0);
    if (aber > 0.04 && bodyProg > 0.08) {
      final shift = aber * 10.0;
      for (final dx in [-shift, shift]) {
        _paintBossEntity(
          canvas, Offset(bossCenter.dx + dx, bossCenter.dy),
          opacity:     (aber * 0.40).clamp(0.0, 1.0),
          isStunned:   isStunned,
          armPose:     _ArmPose.idle,
          isAttacking: false,
        );
      }
    }
  }

  // ── Teleport: pixel-scatter dissolve ──────────────────────────────────────
  // dissolveT 0→1: solid body → scattered pixels drawn around center;
  //                each pixel spirals toward holeCenter.

  void _paintBossDissolveIntoHole(Canvas canvas, Offset center,
      Offset holeCenter, double dissolveT, bool isStunned) {
    if (dissolveT >= 0.98) return;
    final opacity = (1.0 - dissolveT).clamp(0.0, 1.0);
    final s       = 1.0 - dissolveT * 0.55; // boss shrinks toward hole

    // Draw solid boss, scaled around its center, fading out
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(s, s);
    _paintBossEntity(canvas, Offset.zero,
        opacity:     opacity,
        isStunned:   isStunned,
        armPose:     _ArmPose.teleportArm,
        isAttacking: true);
    canvas.restore();

    // Pixel scatter: 42 dots spiral from body toward hole
    final ac   = isStunned ? _kStunBlue : _kPurple;
    final dir  = holeCenter - center;
    final dist = dir.distance.clamp(1.0, 9999.0);
    final dirN = dir / dist;
    final rng  = Random(42);
    final p    = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int d = 0; d < 42; d++) {
      final bodyAngle = rng.nextDouble() * 2 * pi;
      final bodyR     = rng.nextDouble() * 46;
      // Stagger: each dot starts moving at a slightly different progress
      final prog = (dissolveT * 1.5 - rng.nextDouble() * 0.55).clamp(0.0, 1.0);
      // Spiral offset diminishes as dot approaches hole
      final spiral = cos(bodyAngle + prog * 4 * pi) * 10 * (1 - prog);

      final localX = cos(bodyAngle) * bodyR * (1 - prog * 0.8)
                     + dirN.dx * dist * prog * 0.80 + spiral * dirN.dy;
      final localY = sin(bodyAngle) * bodyR * (1 - prog * 0.8)
                     + dirN.dy * dist * prog * 0.80 - spiral * dirN.dx;
      final sz     = (3.0 - prog * 2.5).clamp(0.2, 3.0);

      p.color = ac.withOpacity((opacity * (1 - prog * 0.65)).clamp(0, 1));
      canvas.drawCircle(center + Offset(localX, localY), sz, p);
    }
    p.maskFilter = null;
  }

  // ── Glitch screen — PREMIUM boss entry ────────────────────────────────────

  void _paintGlitch(Canvas canvas, Size size) {
    final rng = Random(DateTime.now().millisecondsSinceEpoch ~/ 60);
    final p   = Paint();
    final cx  = size.width / 2;
    final cy  = size.height * 0.40;

    // ── Deep-space base gradient ──────────────────────────────────────────────
    p.shader = ui.Gradient.linear(
        Offset.zero, Offset(0, size.height),
        [const Color(0xFF000010), const Color(0xFF08001F), const Color(0xFF000010)]);
    canvas.drawRect(Offset.zero & size, p);
    p.shader = null;

    // ── CRT scanline grid (subtle horizontal bands) ───────────────────────────
    p.style = PaintingStyle.fill;
    for (int i = 0; i < size.height.toInt(); i += 3) {
      p.color = Colors.black.withOpacity(0.17);
      canvas.drawRect(Rect.fromLTWH(0, i.toDouble(), size.width, 1.2), p);
    }

    // ── Chromatic-aberration glitch bands ─────────────────────────────────────
    final numBands = 9 + rng.nextInt(9);
    for (int i = 0; i < numBands; i++) {
      final y     = rng.nextDouble() * size.height;
      final h     = 0.8 + rng.nextDouble() * 20;
      final shift = (rng.nextDouble() - 0.5) * 24;
      final cols  = [
        const Color(0xBB9B30FF), const Color(0xBB00FFEE),
        const Color(0xBBFF2266), const Color(0x66FFFFFF), const Color(0x99FF6600),
      ];
      p.color = cols[rng.nextInt(cols.length)];
      canvas.save();
      canvas.translate(shift, 0);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, h), p);
      canvas.restore();
    }

    // ── Vertical tear lines ───────────────────────────────────────────────────
    p..style = PaintingStyle.stroke..strokeWidth = 1.0;
    for (int i = 0; i < 4 + rng.nextInt(4); i++) {
      final x = rng.nextDouble() * size.width;
      p..color = const Color(0x449B30FF)
       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawLine(Offset(x, 0),
          Offset(x + (rng.nextDouble() - 0.5) * 18, size.height), p);
    }
    p..maskFilter = null..style = PaintingStyle.fill;

    // ── Matrix-style Katakana column rain ─────────────────────────────────────
    const colW = 18.0;
    final cols = (size.width / colW).ceil();
    for (int c = 0; c < cols; c++) {
      if (rng.nextDouble() > 0.28) continue; // ~28% of columns active
      final headY = rng.nextDouble() * size.height;
      for (int row = 0; row < 7; row++) {
        final y = headY - row * 14.0;
        if (y < 0 || y > size.height) continue;
        final alpha = ((1.0 - row / 7.0) * (row == 0 ? 1.0 : 0.65)).clamp(0.0, 1.0);
        final char  = String.fromCharCode(0x30A0 + rng.nextInt(96)); // Katakana
        final tp    = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              color: const Color(0xFF9B30FF).withOpacity(alpha),
              fontSize: 11, fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c * colW, y));
      }
    }

    // ── Central power-surge aura ──────────────────────────────────────────────
    for (final args in [
      (110.0, const Color(0x339B30FF), 36.0),
      (72.0,  const Color(0x559B30FF), 20.0),
      (42.0,  const Color(0x8800CCEE), 12.0),
    ]) {
      p
        ..color       = args.$2
        ..maskFilter  = MaskFilter.blur(BlurStyle.normal, args.$3);
      canvas.drawCircle(Offset(cx, cy), args.$1, p);
    }
    p.maskFilter = null;

    // Concentric ring decorations
    p..style = PaintingStyle.stroke..strokeWidth = 1.3;
    for (int r = 0; r < 6; r++) {
      p
        ..color      = const Color(0xFF9B30FF).withOpacity(0.22 - r * 0.03)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(cx, cy), 48 + r * 19.0, p);
      p.maskFilter = null;
    }
    p.style = PaintingStyle.fill;

    // ── Boss title — multi-layer glow ─────────────────────────────────────────
    // Phase tag (small, above title)
    final phaseTp = TextPainter(
      text: const TextSpan(text: '[ LEVEL 41 — MASTER OF THE UNIVERSE ]',
        style: TextStyle(
          color: Color(0xFF5533AA), fontSize: 9,
          fontWeight: FontWeight.w600, letterSpacing: 2.5,
        )),
      textDirection: TextDirection.ltr,
    )..layout();
    phaseTp.paint(canvas, Offset(cx - phaseTp.width / 2, cy - 48));

    // Outer glow layers (blurred, stacked for bloom effect)
    for (final blur in [32.0, 20.0, 10.0]) {
      final gtp = TextPainter(
        text: TextSpan(
          text: '⚡  WARP SENTINEL  ⚡',
          style: TextStyle(
            color: const Color(0xFF9B30FF).withOpacity(0.55),
            fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 5,
            shadows: [Shadow(color: const Color(0xFF9B30FF), blurRadius: blur)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      gtp.paint(canvas, Offset(cx - gtp.width / 2, cy - gtp.height / 2));
    }

    // Sharp foreground title
    final titleTp = TextPainter(
      text: const TextSpan(text: '⚡  WARP SENTINEL  ⚡',
        style: TextStyle(
          color: Color(0xFFEEAAFF),
          fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 5,
          shadows: [
            Shadow(color: Color(0xFF9B30FF), blurRadius: 24),
            Shadow(color: Color(0xFFCC66FF), blurRadius: 7),
          ],
        )),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(cx - titleTp.width / 2, cy - titleTp.height / 2));

    // Subtitle
    final subTp = TextPainter(
      text: const TextSpan(text: 'REALITY DISTORTION ONLINE',
        style: TextStyle(
          color: Color(0xFF7744BB), fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 4,
          shadows: [Shadow(color: Color(0xFF9B30FF), blurRadius: 12)],
        )),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset(cx - subTp.width / 2, cy + titleTp.height / 2 + 10));

    // ── Bottom warning bar ────────────────────────────────────────────────────
    final warnY = size.height * 0.82;
    p
      ..color = const Color(0x44FF2266)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, warnY, size.width, 28), p);
    p
      ..color       = const Color(0x88FF4488)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, warnY), Offset(size.width, warnY), p);
    canvas.drawLine(Offset(0, warnY + 28), Offset(size.width, warnY + 28), p);
    p.style = PaintingStyle.fill;
    final warnTp = TextPainter(
      text: const TextSpan(text: '⚠  GRAVITATIONAL ANOMALY DETECTED  ⚠',
        style: TextStyle(
          color: Color(0xFFFF6699), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 2,
        )),
      textDirection: TextDirection.ltr,
    )..layout();
    warnTp.paint(canvas, Offset(cx - warnTp.width / 2, warnY + 6));

    // ── Corner bracket decorations ────────────────────────────────────────────
    p
      ..color       = const Color(0xFF9B30FF).withOpacity(0.52)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    const bl = 26.0;
    const mg = 16.0;
    for (final corner in [
      (Offset(mg, mg),                                  1.0,  1.0),
      (Offset(size.width - mg, mg),                    -1.0,  1.0),
      (Offset(mg, size.height - mg),                    1.0, -1.0),
      (Offset(size.width - mg, size.height - mg),      -1.0, -1.0),
    ]) {
      canvas.drawLine(corner.$1, Offset(corner.$1.dx + corner.$2 * bl, corner.$1.dy), p);
      canvas.drawLine(corner.$1, Offset(corner.$1.dx, corner.$1.dy + corner.$3 * bl), p);
    }
    p.style = PaintingStyle.fill;
  }

  // ── Siphon streaks — ALL items spiraling into the black hole simultaneously ─

  void _paintSiphonStreaks(Canvas canvas, WarpSentinelController c) {
    if (c.blackHoles.isEmpty) return;
    if (c.recentSiphons.isEmpty && siphonFlashT < 0.01) return;
    final holeRect = getCellRect(
        c.blackHoles[c.bossHoleIndex].$1, c.blackHoles[c.bossHoleIndex].$2);
    if (holeRect == null) return;
    final holePt = holeRect.center;
    final t      = siphonFlashT; // 0 → 1 over 1500ms
    final total  = c.recentSiphons.length.clamp(1, 9);
    final p      = Paint();

    // ── Per-item streaks, staggered so they arrive in a wave ─────────────────
    for (int idx = 0; idx < c.recentSiphons.length; idx++) {
      final siphon   = c.recentSiphons[idx];
      final cellRect = getCellRect(siphon.$1, siphon.$2);
      if (cellRect == null) continue;
      final fromPt = cellRect.center;
      final dir    = holePt - fromPt;
      final dist   = dir.distance.clamp(1.0, 9999.0);
      final dirN   = dir / dist;
      final rng    = Random(siphon.$1 * 137 + siphon.$2 * 29);

      // Each item starts a little later: stagger spreads over first 28% of t
      final stagger = (idx / total) * 0.28;
      final rawT    = (t - stagger).clamp(0.0, 1.0);
      final span    = (1.0 - stagger).clamp(0.01, 1.0);
      final itemT   = rawT / span;

      if (itemT <= 0) continue;

      // ── Phase 1 (itemT 0→0.22): bright flash ring at source cell ──────────
      final flashA = (1.0 - itemT / 0.22).clamp(0.0, 1.0);
      if (flashA > 0) {
        p
          ..color       = const Color(0xFF9B30FF).withOpacity(flashA * 0.55)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 9);
        canvas.drawCircle(fromPt, cellRect.width * (0.50 + flashA * 0.28), p);
        p
          ..color      = const Color(0xFFFFFFFF).withOpacity(flashA * 0.72)
          ..style      = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
        canvas.drawCircle(fromPt, cellRect.width * (0.36 + flashA * 0.16), p);
        p.maskFilter = null;
      }

      // ── Phase 2 (itemT 0.10→0.90): particle spiral + triple-layer beam ─────
      final streamT = ((itemT - 0.10) / 0.80).clamp(0.0, 1.0);
      if (streamT > 0) {
        // Particles
        p..style = PaintingStyle.fill..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        for (int i = 0; i < 28; i++) {
          final prog = ((streamT * 1.4) - (i / 28.0) * 0.6).clamp(0.0, 1.0);
          if (prog <= 0) continue;
          final angle   = prog * pi * 6 + (i / 28.0) * 2 * pi + idx * 0.9;
          final spiralR = (1.0 - prog) * 16.0 * (rng.nextDouble() * 0.5 + 0.75);
          final along   = fromPt + dirN * (dist * prog);
          final pos     = Offset(along.dx + cos(angle) * spiralR,
                                 along.dy + sin(angle) * spiralR);
          final sz    = (5.0 * (1 - prog * 0.70)).clamp(0.8, 5.5);
          final alpha = ((1.0 - prog * 0.40) *
                         (rng.nextDouble() * 0.30 + 0.70)).clamp(0.0, 1.0);
          p.color = Color.lerp(const Color(0xFFFFFFFF),
                               const Color(0xFF9B30FF), prog)!.withOpacity(alpha);
          canvas.drawCircle(pos, sz, p);
        }
        p.maskFilter = null;

        // Triple-layer energy chord
        final boltA = (sin(streamT * pi) * 0.88).clamp(0.0, 1.0);
        p..style = PaintingStyle.stroke;
        // Outer glow
        p..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..color      = const Color(0xFF9B30FF).withOpacity(boltA * 0.45);
        canvas.drawLine(fromPt, holePt, p);
        // Mid glow
        p..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..color      = const Color(0xFFCC66FF).withOpacity(boltA * 0.72);
        canvas.drawLine(fromPt, holePt, p);
        // Sharp bright core
        p..strokeWidth = 1.4..maskFilter = null
          ..color = const Color(0xFFFFEEFF).withOpacity(boltA * 0.92);
        canvas.drawLine(fromPt, holePt, p);
        p.style = PaintingStyle.fill;
      }
    }

    // ── Big impact at hole when items arrive (t 0.62 → 1.0) ─────────────────
    final impactT = ((t - 0.62) / 0.38).clamp(0.0, 1.0);
    if (impactT > 0) {
      // 3 expanding shockwave rings
      for (int ring = 0; ring < 3; ring++) {
        final rT = (impactT - ring * 0.14).clamp(0.0, 1.0);
        if (rT <= 0) continue;
        p
          ..style       = PaintingStyle.stroke
          ..strokeWidth = (3.5 * (1 - rT * 0.75)).clamp(0.5, 3.5)
          ..color       = const Color(0xFF9B30FF).withOpacity((1.0 - rT) * 0.72)
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(holePt, holeRect.width * (0.5 + rT * 3.0), p);
        p.maskFilter = null;
      }
      // Central aura bloom
      p
        ..style      = PaintingStyle.fill
        ..color      = const Color(0xFFAA44FF).withOpacity(sin(impactT * pi) * 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(holePt, holeRect.width * (0.6 + impactT * 1.4), p);
      // White hotspot
      p
        ..color      = const Color(0xFFFFFFFF).withOpacity(sin(impactT * pi) * 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(holePt, holeRect.width * 0.38, p);
      p.maskFilter = null;
    }
  }

  // ── Targeting reticle — lock-on on EVERY item in zone + gravitational rings ─

  void _paintTargetingReticle(Canvas canvas, WarpSentinelController c) {
    if (c.blackHoles.isEmpty || c.pullZoneCells.isEmpty) return;
    final hole     = c.blackHoles[c.bossHoleIndex];
    final holeRect = getCellRect(hole.$1, hole.$2);
    if (holeRect == null) return;
    final holePt = holeRect.center;
    final pulse  = 0.55 + warnPulseT * 0.45;
    final p      = Paint();

    // ── Gravitational lens rings expanding from the black hole ───────────────
    // 4 rings at different phases so they continuously ripple outward
    for (int ring = 0; ring < 4; ring++) {
      final ringPhase = (warnPulseT + ring * 0.25) % 1.0;
      final ringR     = holeRect.width * (0.55 + ringPhase * 3.2);
      final ringA     = (1.0 - ringPhase) * 0.45;
      p
        ..style       = PaintingStyle.stroke
        ..strokeWidth = (2.0 * (1 - ringPhase * 0.65)).clamp(0.4, 2.0)
        ..color       = const Color(0xFF9B30FF).withOpacity(ringA)
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(holePt, ringR, p);
      p.maskFilter = null;
    }

    // ── Per-item: diamond reticle + corner brackets + tendril to hole ────────
    for (final cell in c.pullZoneCells) {
      final targetRect = getCellRect(cell.$1, cell.$2);
      if (targetRect == null) continue;
      final center = targetRect.center;
      final r      = targetRect.width * 0.44;

      // Lock-on diamond
      final diamond = Path()
        ..moveTo(center.dx,            center.dy - r * 1.45)
        ..lineTo(center.dx + r * 1.45, center.dy)
        ..lineTo(center.dx,            center.dy + r * 1.45)
        ..lineTo(center.dx - r * 1.45, center.dy)
        ..close();
      // Outer glow
      p
        ..color       = const Color(0xFFFF2244).withOpacity(pulse * 0.35)
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 4.5;
      canvas.drawPath(diamond, p);
      p.maskFilter = null;
      // Sharp edge
      p..color = const Color(0xFFFF3355).withOpacity(pulse * 0.92)
       ..strokeWidth = 1.8;
      canvas.drawPath(diamond, p);

      // HUD corner brackets
      final bl = r * 0.52;
      p..strokeWidth = 1.5..color = const Color(0xFFFF5577).withOpacity(pulse * 0.88);
      for (final corner in [
        (Offset(center.dx - r, center.dy - r),  1.0,  1.0),
        (Offset(center.dx + r, center.dy - r), -1.0,  1.0),
        (Offset(center.dx - r, center.dy + r),  1.0, -1.0),
        (Offset(center.dx + r, center.dy + r), -1.0, -1.0),
      ]) {
        canvas.drawLine(
            corner.$1, Offset(corner.$1.dx + corner.$2 * bl, corner.$1.dy), p);
        canvas.drawLine(
            corner.$1, Offset(corner.$1.dx, corner.$1.dy + corner.$3 * bl), p);
      }

      // Center dot
      p
        ..style      = PaintingStyle.fill
        ..color      = const Color(0xFFFF2244).withOpacity(pulse * 0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(center, 4.5, p);
      p.maskFilter = null;
      p.color = const Color(0xFFFFFFFF).withOpacity(pulse * 0.88);
      canvas.drawCircle(center, 2.0, p);

      // Energy tendril: item → black hole
      final tDist = (holePt - center).distance;
      if (tDist < 4) continue;
      final normD = (holePt - center) / tDist;

      // Glow tendril
      p
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color       = const Color(0xFFFF2244).withOpacity(pulse * 0.30)
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawLine(center, holePt, p);
      p.maskFilter = null;
      // Bright core
      p..strokeWidth = 0.8
       ..color = const Color(0xFFFF8899).withOpacity(pulse * 0.68);
      canvas.drawLine(center, holePt, p);

      // Arrowhead pointing toward hole
      final arrowTip = holePt - normD * (holeRect.width * 0.52);
      final perp     = Offset(-normD.dy, normD.dx) * 5.0;
      final arrowPath = Path()
        ..moveTo(arrowTip.dx, arrowTip.dy)
        ..lineTo((arrowTip - normD * 9 + perp).dx,
                 (arrowTip - normD * 9 + perp).dy)
        ..lineTo((arrowTip - normD * 9 - perp).dx,
                 (arrowTip - normD * 9 - perp).dy)
        ..close();
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF4466).withOpacity(pulse * 0.82);
      canvas.drawPath(arrowPath, p);
    }

    p.style = PaintingStyle.fill;
  }

  // ── Black hole ────────────────────────────────────────────────────────────

  void _paintBlackHole(Canvas canvas, Rect rect, double spinT, {
    required bool   isActive,
    required double entryScale,
    required bool   isFrom,
    required bool   isDest,
  }) {
    final center = rect.center;
    final scale  = entryScale * (isActive ? 1.0 : 0.72);
    final radius = rect.width * 0.46 * scale;
    final p      = Paint();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (isFrom) {
      final suck = ((teleportT - 0.30) / 0.37).clamp(0.0, 1.0);
      canvas.scale(1 + suck * 0.35, 1 + suck * 0.35);
    }
    if (isDest) {
      final emit = ((teleportT - 0.67) / 0.33).clamp(0.0, 1.0);
      canvas.scale(1 + (1 - emit) * 0.30, 1 + (1 - emit) * 0.30);
    }
    canvas.rotate(spinT * 2 * pi * (isActive ? 1.0 : -0.6));

    // Outer glow rings
    p..style = PaintingStyle.stroke..strokeWidth = 2.0;
    for (int r = 4; r >= 0; r--) {
      p
        ..color = Color.fromARGB(((0.12 - r * 0.02).clamp(0, 1) * 255).toInt(), 155, 48, 255)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawCircle(Offset.zero, radius + r * 8.0, p);
    }
    p.maskFilter = null;

    // Void core
    p
      ..shader = ui.Gradient.radial(Offset.zero, radius,
          [const Color(0xFF000000), const Color(0xFF07001A), const Color(0xFF180032)],
          [0.0, 0.58, 1.0])
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, p);
    p.shader = null;

    // Accretion disk
    p..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (int i = 0; i < 6; i++) {
      final t    = (spinT + i * 0.165) % 1.0;
      final diskR = radius * (0.38 + t * 0.68);
      p.color = Color.fromARGB(((1 - t) * 210).toInt(), 140 + (t * 100).toInt(), 40, 255);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: diskR * 2, height: diskR * .58), p);
    }

    if (isActive) {
      p
        ..color = const Color(0x55AA44FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, radius * 1.65, p);
      p.maskFilter = null;
    }
    canvas.restore();
  }

  // ── Attack vortex ─────────────────────────────────────────────────────────

  void _paintAttackVortex(Canvas canvas, Offset center, double vt, bool isPull) {
    final p = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    p
      ..color = isPull ? const Color(0x66FF2222) : const Color(0x66AA00FF)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawCircle(center, 88, p);
    p.maskFilter = null;
    p.style = PaintingStyle.stroke;

    for (int arm = 0; arm < 4; arm++) {
      final path = Path();
      bool first = true;
      for (int i = 0; i <= 64; i++) {
        final t = i / 64.0;
        final a = arm * pi / 2 + vt * 2 * pi + t * 3.2 * pi;
        final r = 8 + t * 82;
        final x = center.dx + cos(a) * r;
        final y = center.dy + sin(a) * r;
        if (first) { path.moveTo(x, y); first = false; } else { path.lineTo(x, y); }
      }
      p
        ..color = isPull
            ? Color.fromARGB((200 * (1 - arm * 0.14)).toInt(), 255, 45, 45)
            : Color.fromARGB((175 * (1 - arm * 0.14)).toInt(), 170, 0, 255)
        ..strokeWidth = isPull ? 2.2 - arm * 0.3 : 1.8 - arm * 0.3
        ..maskFilter = arm == 0 ? const MaskFilter.blur(BlurStyle.normal, 3) : null;
      canvas.drawPath(path, p);
      p.maskFilter = null;
    }
    p
      ..color = isPull ? const Color(0xBBFF4444) : const Color(0xBBDD55FF)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawCircle(center, 13 + sin(vt * 2 * pi) * 5, p);
    p.maskFilter = null;
  }

  // ── Zone tile ─────────────────────────────────────────────────────────────

  void _paintZoneTile(Canvas canvas, Rect rect, double warnT,
      bool isPull, double shakeT) {
    final shakeAmt = isPull ? 4.0 : 1.8;
    final rng      = Random(rect.center.dx.toInt() ^ rect.center.dy.toInt() ^
                            (shakeT * 1000).toInt());
    final shifted  = rect.translate((rng.nextDouble() - .5) * shakeAmt,
                                    (rng.nextDouble() - .5) * shakeAmt);
    final pulse    = 0.5 + warnT * 0.5;
    final color    = isPull ? const Color(0xFFFF2222) : const Color(0xFFAA00FF);
    final p        = Paint();

    p
      ..color = color.withOpacity(pulse * 0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRect(shifted.inflate(5), p);
    p.maskFilter = null;

    p
      ..color = color.withOpacity(pulse * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawRect(shifted.inflate(2), p);

    const bl = 9.0;
    p..color = color.withOpacity(.96)..strokeWidth = 1.7;
    final r = shifted;
    for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final sx = (corner.dx == r.left) ? 1.0 : -1.0;
      final sy = (corner.dy == r.top)  ? 1.0 : -1.0;
      canvas.drawLine(corner, Offset(corner.dx + sx * bl, corner.dy), p);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + sy * bl), p);
    }
    p.style = PaintingStyle.fill;
  }

  // ── Win blast ─────────────────────────────────────────────────────────────

  void _paintWinBlast(Canvas canvas, Size size, double t) {
    final c = Offset(size.width / 2, size.height / 2);
    final p = Paint();
    p
      ..color = Color.fromARGB((sin(t * pi) * 185).toInt().clamp(0, 255), 180, 60, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 52);
    canvas.drawCircle(c, size.width * t * .92, p);
    p
      ..color = Color.fromARGB((sin(t * pi) * 230).toInt().clamp(0, 255), 255, 210, 255)
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(c, size.width * t * .76, p);
    p..strokeWidth = 3..color = Color.fromARGB(
        (sin(t * pi) * 160).toInt().clamp(0, 255), 220, 180, 255);
    canvas.drawCircle(c, size.width * t * .55, p);
  }

  // ── Helper: draw a soft glow circle ───────────────────────────────────────

  void _drawBlur(Canvas canvas, Offset center, double radius, Color color,
      {double blurRadius = 10}) {
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius),
    );
  }

  @override
  bool shouldRepaint(_WarpScenePainter o) => true;
}

enum _ArmPose { idle, attackBoth, teleportArm }

// ─── HUD widgets ─────────────────────────────────────────────────────────────

class _DialogueBubble extends StatelessWidget {
  final String text;
  const _DialogueBubble({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xEE0D0020),
      border: Border.all(color: _kPurple, width: 1.5),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [BoxShadow(color: Color(0x669B30FF), blurRadius: 16)],
    ),
    child: Text(text,
        style: const TextStyle(color: Color(0xFFDD99FF), fontSize: 12,
            fontWeight: FontWeight.w700, letterSpacing: .4),
        textAlign: TextAlign.center),
  );
}

class _StunBar extends StatelessWidget {
  final int secsLeft;
  const _StunBar({required this.secsLeft});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xDD001020),
      border: Border.all(color: const Color(0xFF00BBFF), width: 1.5),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [BoxShadow(color: Color(0x4400BBFF), blurRadius: 14)],
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('⚡ STUNNED ', style: TextStyle(color: Color(0xFF00DDFF),
          fontWeight: FontWeight.w800, fontSize: 11)),
      Text('${secsLeft}s', style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w900, fontSize: 13)),
    ]),
  );
}

class _CountdownRing extends StatelessWidget {
  final int secsLeft;
  final Color color;
  final String label;
  const _CountdownRing({required this.secsLeft, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    width: 54, height: 54,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xDD0A0018),
      border: Border.all(color: color, width: 2.5),
      boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 12)],
    ),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$secsLeft', style: TextStyle(color: color, fontSize: 20,
          fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Color(0xFFAA88CC), fontSize: 8)),
    ])),
  );
}

class _HintStrip extends StatelessWidget {
  final String hint;
  const _HintStrip({required this.hint});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xCC0D0020),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF6622AA), width: 1),
    ),
    child: Text(hint,
        style: const TextStyle(color: Color(0xFFBB88EE), fontSize: 10,
            fontWeight: FontWeight.w600),
        textAlign: TextAlign.center),
  );
}
