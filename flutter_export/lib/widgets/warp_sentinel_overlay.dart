// warp_sentinel_overlay.dart — WARP SENTINEL Visual Overlay (Level 41) v2
// Teleport: arm extend → liquid wireframe dissolve → suck into hole → exit → solidify
// Attack pose: both arms raised toward black hole
// 3×3 vortex spiral around black hole during attack
// Item shake during warning, screen-edge shake during pull
// Sacrifice overload flash, win blast

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../controllers/warp_sentinel_controller.dart';

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
  late final AnimationController _bob;        // hover bob
  late final AnimationController _holeSpin;   // black hole accretion spin
  late final AnimationController _corePulse;  // energy core pulse
  late final AnimationController _vortex;     // attack vortex spiral
  late final AnimationController _warnPulse;  // warning glow pulse
  late final AnimationController _shake;      // fast shake tick (pull phase)
  late final AnimationController _glitch;     // intro glitch
  late final AnimationController _entry;      // entry drop animation
  late final AnimationController _teleport;   // full teleport sequence 0→1
  late final AnimationController _win;        // win explosion

  @override
  void initState() {
    super.initState();
    _bob       = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _holeSpin  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    _corePulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _vortex    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _warnPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..repeat(reverse: true);
    _shake     = AnimationController(vsync: this, duration: const Duration(milliseconds: 60))..repeat();
    _glitch    = AnimationController(vsync: this, duration: const Duration(milliseconds: 80))..repeat();
    _entry     = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    _teleport  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _win       = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(WarpSentinelOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
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

    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    for (final c in [_bob, _holeSpin, _corePulse, _vortex, _warnPulse,
                     _shake, _glitch, _entry, _teleport, _win]) {
      c.dispose();
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
        _shake, _glitch, _entry, _teleport, _win,
      ]),
      builder: (context, _) => _buildScene(context, c),
    );
  }

  Widget _buildScene(BuildContext context, WarpSentinelController c) {
    // Screen-edge shake during pull phase
    final shakeOffset = c.isPulling
        ? Offset(
            (Random(_shake.value.hashCode ^ 1).nextDouble() - 0.5) * 5,
            (Random(_shake.value.hashCode ^ 2).nextDouble() - 0.5) * 5,
          )
        : Offset.zero;

    Widget scene = CustomPaint(
      painter: _WarpScenePainter(
        controller:   c,
        getCellRect:  widget.getCellRect,
        bobT:         _bob.value,
        holeSpinT:    _holeSpin.value,
        corePulseT:   _corePulse.value,
        vortexT:      _vortex.value,
        warnPulseT:   _warnPulse.value,
        shakeT:       _shake.value,
        glitchT:      _glitch.value,
        entryT:       _entry.value,
        teleportT:    _teleport.value,
        winT:         _win.value,
      ),
      child: _buildHUD(c),
    );

    if (shakeOffset != Offset.zero) {
      scene = Transform.translate(offset: shakeOffset, child: scene);
    }
    return scene;
  }

  Widget _buildHUD(WarpSentinelController c) {
    return Stack(
      children: [
        if (c.dialogueText != null)
          Positioned(top: 8, left: 12, right: 12,
              child: _DialogueBubble(text: c.dialogueText!)),

        if (c.isStunned)
          Positioned(bottom: 80, left: 24, right: 24,
              child: _StunBar(secsLeft: c.stunSecsLeft)),

        if (c.isWarning)
          Positioned(top: 60, right: 16,
              child: _CountdownRing(secsLeft: c.warningSecsLeft, color: const Color(0xFFAA00FF), label: 'WARN')),

        if (c.isPulling)
          Positioned(top: 60, right: 16,
              child: _CountdownRing(secsLeft: c.pullSecsLeft, color: const Color(0xFFFF2222), label: 'PULL')),

        if (c.phase == WarpSentinelPhase.active && !c.isWarning && !c.isPulling)
          Positioned(bottom: 8, left: 12, right: 12,
              child: _HintStrip(hint: kWarpHints[c.hintIndex])),
      ],
    );
  }
}

// ─── Main Scene Painter ───────────────────────────────────────────────────────

class _WarpScenePainter extends CustomPainter {
  final WarpSentinelController controller;
  final Rect? Function(int col, int row) getCellRect;
  final double bobT, holeSpinT, corePulseT, vortexT, warnPulseT;
  final double shakeT, glitchT, entryT, teleportT, winT;

  const _WarpScenePainter({
    required this.controller,
    required this.getCellRect,
    required this.bobT, required this.holeSpinT, required this.corePulseT,
    required this.vortexT, required this.warnPulseT, required this.shakeT,
    required this.glitchT, required this.entryT, required this.teleportT,
    required this.winT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;

    // ── 1. Glitch intro (replaces all else during first 2s) ───────────────────
    if (c.glitchActive) {
      _paintGlitch(canvas, size);
      return;
    }

    // ── 2. 3×3 Warning glow on tiles ─────────────────────────────────────────
    if (c.isWarning || c.isPulling) {
      for (final cell in c.pullZoneCells) {
        final rect = getCellRect(cell.$1, cell.$2);
        if (rect == null) continue;
        final isPull = c.isPulling;
        _paintZoneTile(canvas, rect, warnPulseT, isPull, shakeT);
      }
    }

    // ── 3. Black holes ────────────────────────────────────────────────────────
    for (int i = 0; i < c.blackHoles.length; i++) {
      final hole = c.blackHoles[i];
      final rect = getCellRect(hole.$1, hole.$2);
      if (rect == null) continue;
      final isActive  = (i == c.bossHoleIndex);
      final isFrom    = c.isTeleporting && i == c.fromHoleIndex;
      final isTo      = c.isTeleporting && i == c.toHoleIndex;
      final entryScale = c.phase == WarpSentinelPhase.entry ? entryT : 1.0;
      _paintBlackHole(canvas, rect, holeSpinT, isActive, entryScale, isFrom, isTo);
    }

    // ── 4. Attack vortex (warning + pull phase) ───────────────────────────────
    if ((c.isWarning || c.isPulling) && c.blackHoles.isNotEmpty) {
      final hole = c.blackHoles[c.bossHoleIndex];
      final hRect = getCellRect(hole.$1, hole.$2);
      if (hRect != null) {
        _paintAttackVortex(canvas, hRect.center, vortexT, c.isPulling);
      }
    }

    // ── 5. Overload flash ─────────────────────────────────────────────────────
    if (c.overloadFlash) {
      final paint = Paint()
        ..color = const Color(0x88FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawRect(Offset.zero & const Size(9999, 9999), paint);
    }

    // ── 6. Boss figure ────────────────────────────────────────────────────────
    _paintBossAtCurrentPosition(canvas, size, c);

    // ── 7. Win blast ──────────────────────────────────────────────────────────
    if (c.phase == WarpSentinelPhase.winBlast && winT > 0) {
      _paintWinBlast(canvas, size, winT);
    }
  }

  // ── Boss position + dispatch ────────────────────────────────────────────────

  void _paintBossAtCurrentPosition(Canvas canvas, Size size, WarpSentinelController c) {
    if (c.blackHoles.isEmpty) return;

    final tp = c.teleportPhase;

    if (tp == WarpTeleportPhase.idle || tp == WarpTeleportPhase.arming) {
      // Normal / arm-raising pose
      final hole = c.blackHoles[c.bossHoleIndex];
      final rect = getCellRect(hole.$1, hole.$2);
      if (rect == null) return;
      final bob = sin(bobT * pi) * 10;
      final center = Offset(rect.center.dx, rect.top - 80 + bob);
      _paintBoss(canvas, center, corePulseT,
          opacity: 1.0,
          isStunned: c.isStunned,
          armPose: tp == WarpTeleportPhase.arming ? _ArmPose.teleportArm :
                   c.isAttackPoseActive          ? _ArmPose.attackBoth  : _ArmPose.idle,
          holeDir: _holeDirFromBoss(c.blackHoles[c.bossHoleIndex], c.blackHoles[c.bossHoleIndex]));
    } else if (tp == WarpTeleportPhase.dissolving) {
      // Boss dissolves into the FROM hole
      final fromHole = c.blackHoles[c.fromHoleIndex];
      final rect = getCellRect(fromHole.$1, fromHole.$2);
      if (rect == null) return;
      // teleportT goes from 0→1 over 1500ms; dissolving starts ~0.3
      final dissolveProgress = ((teleportT - 0.3) / 0.37).clamp(0.0, 1.0);
      final bob = sin(bobT * pi) * 10;
      // Boss shrinks and moves toward hole center as it dissolves
      final bossStart = Offset(rect.center.dx, rect.top - 80 + bob);
      final center = Offset.lerp(bossStart, rect.center, dissolveProgress)!;
      _paintBossWireframe(canvas, center, corePulseT, dissolveProgress, c.isStunned);
    } else if (tp == WarpTeleportPhase.materializing) {
      // Boss materializes from the TO hole
      final toHole = c.blackHoles[c.toHoleIndex];
      final rect = getCellRect(toHole.$1, toHole.$2);
      if (rect == null) return;
      // teleportT continues; materializing starts ~0.67
      final materProgress = ((teleportT - 0.67) / 0.33).clamp(0.0, 1.0);
      final bob = sin(bobT * pi) * 10;
      final bossEnd = Offset(rect.center.dx, rect.top - 80 + bob);
      final center = Offset.lerp(rect.center, bossEnd, materProgress)!;
      _paintBossWireframe(canvas, center, corePulseT, 1.0 - materProgress, c.isStunned);
    }
  }

  Offset _holeDirFromBoss((int, int) bossHole, (int, int) targetHole) {
    // Direction vector from boss hole toward the other hole (simplified)
    return const Offset(0, 1);
  }

  // ── Glitch ─────────────────────────────────────────────────────────────────

  void _paintGlitch(Canvas canvas, Size size) {
    final rng = Random(DateTime.now().millisecondsSinceEpoch ~/ 80);
    final paint = Paint();

    paint.color = const Color(0xBB000000);
    canvas.drawRect(Offset.zero & size, paint);

    for (int i = 0; i < 8 + rng.nextInt(6); i++) {
      final y = rng.nextDouble() * size.height;
      final h = 2.0 + rng.nextDouble() * 22;
      paint.color = [
        const Color(0xAA9B30FF),
        const Color(0xAA00FFEE),
        const Color(0xAAFF2266),
      ][rng.nextInt(3)];
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, h), paint);
    }
    for (int i = 0; i < 4; i++) {
      final x = rng.nextDouble() * size.width;
      final w = 3.0 + rng.nextDouble() * 18;
      paint.color = Color.fromARGB(70 + rng.nextInt(80),
          rng.nextInt(255), rng.nextInt(255), rng.nextInt(255));
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
    }

    final tp = TextPainter(
      text: const TextSpan(
        text: '⚡ WARP SENTINEL ⚡',
        style: TextStyle(
          color: Color(0xFFCE93FF),
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 5,
          shadows: [Shadow(color: Color(0xCC9B30FF), blurRadius: 24)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, size.height / 2 - tp.height / 2));
  }

  // ── Black Hole ──────────────────────────────────────────────────────────────

  void _paintBlackHole(Canvas canvas, Rect rect, double spinT,
      bool isActive, double entryScale, bool isFrom, bool isDest) {
    final center = rect.center;
    final scale  = entryScale * (isActive ? 1.0 : 0.75);
    final radius = rect.width * 0.44 * scale;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Suction distortion during dissolving (boss being pulled in)
    if (isFrom) {
      final suck = ((teleportT - 0.3) / 0.37).clamp(0.0, 1.0);
      canvas.scale(1.0 + suck * 0.3, 1.0 + suck * 0.3);
    }
    // Emission burst during materializing
    if (isDest) {
      final emit = ((teleportT - 0.67) / 0.33).clamp(0.0, 1.0);
      canvas.scale(1.0 + (1.0 - emit) * 0.25, 1.0 + (1.0 - emit) * 0.25);
    }

    canvas.rotate(spinT * 2 * pi * (isActive ? 1.0 : -0.5));

    // Outer glow rings
    for (int r = 3; r >= 0; r--) {
      final ringR = radius + r * 9.0;
      final alpha = (0.14 - r * 0.025).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.fromARGB((alpha * 255).toInt(), 155, 48, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(Offset.zero, ringR, paint);
    }

    // Dark void core
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero, radius,
        [const Color(0xFF000000), const Color(0xFF0D0020), const Color(0xFF1A0033)],
        [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(Offset.zero, radius, corePaint);

    // Accretion disk rings
    final ringPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4;
    for (int i = 0; i < 5; i++) {
      final t = (spinT + i * 0.2) % 1.0;
      final ringR = radius * (0.45 + t * 0.6);
      ringPaint.color = Color.fromARGB(
          ((1.0 - t) * 200).toInt(),
          150 + (t * 80).toInt(), 48, 255);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: ringR * 2, height: ringR * 0.65),
          ringPaint);
    }

    if (isActive) {
      final glow = Paint()
        ..color = const Color(0x449B30FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset.zero, radius * 1.5, glow);
    }

    canvas.restore();
  }

  // ── Attack Vortex (3×3 spiral around boss hole) ────────────────────────────

  void _paintAttackVortex(Canvas canvas, Offset center, double vortexT, bool isPull) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Outer vortex halo
    final halopaint = Paint()
      ..color = isPull
          ? const Color(0x66FF2222)
          : const Color(0x66AA00FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, 80, halopaint);

    // Spiral arms (4 arms, rotating)
    for (int arm = 0; arm < 4; arm++) {
      final path = Path();
      final armOffset = arm * pi / 2;
      bool first = true;
      for (int i = 0; i <= 60; i++) {
        final t = i / 60.0;
        final angle = armOffset + vortexT * 2 * pi + t * 3 * pi;
        final r = 10 + t * 75;
        final x = center.dx + cos(angle) * r;
        final y = center.dy + sin(angle) * r;
        if (first) { path.moveTo(x, y); first = false; } else { path.lineTo(x, y); }
      }
      final alpha = isPull ? 0.85 : 0.6;
      paint
        ..color = isPull
            ? Color.fromARGB((alpha * 220).toInt(), 255, 40, 40)
            : Color.fromARGB((alpha * 180).toInt(), 170, 0, 255)
        ..strokeWidth = isPull ? 2.0 : 1.5
        ..maskFilter = arm == 0
            ? const MaskFilter.blur(BlurStyle.normal, 3)
            : null;
      canvas.drawPath(path, paint);
    }

    // Center burst circle
    paint
      ..color = isPull
          ? const Color(0xAAFF3333)
          : const Color(0xAACC44FF)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 14 + sin(vortexT * 2 * pi) * 4, paint);
    paint.maskFilter = null;
  }

  // ── Zone Tile (warning + pull) ──────────────────────────────────────────────

  void _paintZoneTile(Canvas canvas, Rect rect, double warnT,
      bool isPull, double shakeT) {
    // Item shake (random offset based on tile position hash)
    final shakeAmt = isPull ? 3.5 : 1.5;
    final rng = Random(rect.center.dx.toInt() ^ rect.center.dy.toInt() ^
        (shakeT * 1000).toInt());
    final dx = (rng.nextDouble() - 0.5) * shakeAmt;
    final dy = (rng.nextDouble() - 0.5) * shakeAmt;
    final shiftedRect = rect.translate(dx, dy);

    final pulse = 0.5 + warnT * 0.5;
    final color  = isPull ? const Color(0xFFFF2222) : const Color(0xFFAA00FF);
    final paint  = Paint()
      ..color = color.withOpacity(pulse * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRect(shiftedRect.inflate(5), paint);

    paint
      ..color = color.withOpacity(pulse * 0.85)
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(shiftedRect.inflate(2), paint);
    paint.style = PaintingStyle.fill;

    // Corner brackets
    const bl = 8.0;
    paint
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final r = shiftedRect;
    for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final signX = (corner.dx == r.left) ? 1.0 : -1.0;
      final signY = (corner.dy == r.top)  ? 1.0 : -1.0;
      canvas.drawLine(corner, Offset(corner.dx + signX * bl, corner.dy), paint);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + signY * bl), paint);
    }
    paint.style = PaintingStyle.fill;
  }

  // ── Boss — Solid body ───────────────────────────────────────────────────────

  void _paintBoss(Canvas canvas, Offset center, double corePulseT, {
    required double opacity,
    required bool isStunned,
    required _ArmPose armPose,
    required Offset holeDir,
  }) {
    if (opacity <= 0.01) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final o = (opacity * 255).toInt().clamp(0, 255);
    final paint = Paint();

    // Atmospheric glow
    paint
      ..color = isStunned
          ? Color.fromARGB((o * 0.22).toInt(), 100, 200, 255)
          : Color.fromARGB((o * 0.18).toInt(), 155, 48, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawCircle(Offset.zero, 60, paint);
    paint.maskFilter = null;

    // Energy cloak
    final cloakColor = isStunned ? const Color(0xFF3388FF) : const Color(0xFF7B20EE);
    final cloakPath  = Path();
    const cw = 50.0; const ch = 72.0;
    cloakPath.moveTo(0, -ch * 0.28);
    cloakPath.cubicTo(-cw, -ch * 0.08, -cw - 5, ch * 0.58, -16, ch + 4);
    cloakPath.lineTo(16, ch + 4);
    cloakPath.cubicTo(cw + 5, ch * 0.58, cw, -ch * 0.08, 0, -ch * 0.28);
    cloakPath.close();

    paint
      ..color = Color.fromARGB(o, cloakColor.red, cloakColor.green, cloakColor.blue)
      ..style = PaintingStyle.fill;
    canvas.drawPath(cloakPath, paint);

    // Inner cloak gradient
    paint.shader = ui.Gradient.linear(const Offset(0, -50), const Offset(0, 60), [
      Color.fromARGB((o * 0.65).toInt(), 25, 0, 70),
      Color.fromARGB(0, 25, 0, 70),
    ]);
    canvas.drawPath(cloakPath, paint);
    paint.shader = null;

    // Torso
    final torsoRR = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 36, height: 48),
        const Radius.circular(8));
    paint
      ..color = Color.fromARGB(o, 18, 10, 36)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(torsoRR, paint);

    // Panel lines
    paint
      ..color = Color.fromARGB((o * 0.45).toInt(), 155, 48, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawLine(const Offset(-7, -16), const Offset(-7, 16), paint);
    canvas.drawLine(const Offset(7, -16), const Offset(7, 16), paint);
    canvas.drawLine(const Offset(-15, 0), const Offset(15, 0), paint);
    paint.style = PaintingStyle.fill;

    // Energy core
    final cGlow = 0.4 + corePulseT * 0.6;
    final cColor = isStunned
        ? Color.fromARGB(o, 80, 200, 255)
        : Color.fromARGB(o, 170 + (corePulseT * 85).toInt(), 44, 255);

    paint
      ..color = cColor.withOpacity(cGlow * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 + corePulseT * 8);
    canvas.drawCircle(Offset.zero, 16, paint);
    paint.maskFilter = null;

    paint.color = Color.fromARGB(o, 25, 0, 65);
    canvas.drawCircle(Offset.zero, 9, paint);
    paint.color = cColor;
    canvas.drawCircle(Offset.zero, 4.5 + corePulseT * 2, paint);

    // Core cross
    paint
      ..color = Color.fromARGB((o * cGlow).toInt(), 255, 220, 255)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final cs = 5.5 + corePulseT * 2.5;
    canvas.drawLine(Offset(0, -cs), Offset(0, cs), paint);
    canvas.drawLine(Offset(-cs, 0), Offset(cs, 0), paint);
    paint.style = PaintingStyle.fill;

    // Head
    const headY = -33.0;
    paint.color = Color.fromARGB(o, 18, 10, 36);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, headY), width: 27, height: 23),
            const Radius.circular(6)),
        paint);

    // Visor
    paint.shader = ui.Gradient.linear(
      const Offset(-10, -33), const Offset(10, -33),
      [const Color(0xFF9B30FF), const Color(0xFFDD88FF), const Color(0xFF9B30FF)]);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, headY), width: 21, height: 7),
            const Radius.circular(3)),
        paint);
    paint.shader = null;

    // Visor glow
    paint
      ..color = Color.fromARGB((o * 0.45 * (0.6 + corePulseT * 0.4)).toInt(), 200, 120, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, headY), width: 21, height: 7),
            const Radius.circular(3)),
        paint);
    paint.maskFilter = null;

    // Shoulders
    for (final side in [-1, 1]) {
      paint.color = Color.fromARGB(o, 22, 8, 52);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(side * 22.0, -17), width: 9, height: 21),
              const Radius.circular(4)),
          paint);
    }

    // Arms based on pose
    _paintArms(canvas, paint, armPose, o, corePulseT, isStunned);

    // Stun sparks
    if (isStunned) {
      final r = Random(DateTime.now().millisecondsSinceEpoch ~/ 100);
      paint
        ..color = Color.fromARGB(o, 80, 210, 255)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 7; i++) {
        final angle = r.nextDouble() * 2 * pi;
        final dist  = 18 + r.nextDouble() * 32;
        final len   = 5 + r.nextDouble() * 12;
        final sx = cos(angle) * dist;
        final sy = sin(angle) * dist;
        canvas.drawLine(Offset(sx, sy),
            Offset(sx + cos(angle + pi * 0.35) * len, sy + sin(angle + pi * 0.35) * len),
            paint);
      }
      paint.style = PaintingStyle.fill;
    }

    canvas.restore();
  }

  void _paintArms(Canvas canvas, Paint paint, _ArmPose pose, int o,
      double corePulseT, bool isStunned) {
    final armColor = isStunned ? Color.fromARGB(o, 22, 8, 52) : Color.fromARGB(o, 22, 8, 52);
    paint
      ..color = armColor
      ..style = PaintingStyle.fill;

    switch (pose) {
      case _ArmPose.idle:
        // Arms hang at sides
        for (final s in [-1, 1]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: Offset(s * 26.0, 8), width: 8, height: 24),
                  const Radius.circular(3)),
              paint);
        }

      case _ArmPose.attackBoth:
        // Both arms raised forward, pointing toward black hole below
        for (final s in [-1, 1]) {
          canvas.save();
          canvas.translate(s * 22.0, -8);
          canvas.rotate(s * -0.5); // angled outward-up
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: const Offset(0, 14), width: 7, height: 26),
                  const Radius.circular(3)),
              paint);
          // Energy at hand tip
          paint
            ..color = Color.fromARGB((o * 0.8 * (0.5 + corePulseT * 0.5)).toInt(), 200, 80, 255)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(const Offset(0, 27), 5, paint);
          paint.maskFilter = null;
          paint.color = armColor;
          canvas.restore();
        }

      case _ArmPose.teleportArm:
        // One arm extends forward dramatically
        for (final s in [-1, 1]) {
          canvas.save();
          canvas.translate(s * 22.0, -4);
          canvas.rotate(s == -1 ? 0.8 : -0.8); // one arm forward
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: const Offset(0, 16), width: 7, height: 30),
                  const Radius.circular(3)),
              paint);
          canvas.restore();
        }
    }
  }

  // ── Boss — Wireframe dissolve ────────────────────────────────────────────────

  void _paintBossWireframe(Canvas canvas, Offset center, double corePulseT,
      double dissolveT, bool isStunned) {
    // dissolveT: 0=fully solid wireframe, 1=fully dissolved (invisible)
    if (dissolveT >= 0.98) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final opacity = (1.0 - dissolveT).clamp(0.0, 1.0);
    final color = isStunned ? const Color(0xFF00AAFF) : const Color(0xFF9B30FF);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withOpacity(opacity);

    // Scale toward hole (shrink as it dissolves)
    final scale = 1.0 - dissolveT * 0.7;
    canvas.scale(scale, scale);

    // Draw wireframe body outline as connected dots
    final rng = Random(42);
    final bodyPoints = _generateBodyPoints();
    for (int i = 0; i < bodyPoints.length - 1; i++) {
      // Glitch: randomly skip some segments more as dissolveT increases
      if (rng.nextDouble() < dissolveT * 0.7) continue;
      paint.color = color.withOpacity(opacity * (0.6 + rng.nextDouble() * 0.4));
      canvas.drawLine(bodyPoints[i], bodyPoints[i + 1], paint);
    }

    // Pixel scatter: dots flying outward as boss dissolves
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (int d = 0; d < 20; d++) {
      final angle = rng.nextDouble() * 2 * pi;
      final dist  = dissolveT * (20 + rng.nextDouble() * 50);
      final dx    = cos(angle) * dist + (rng.nextDouble() - 0.5) * dissolveT * 20;
      final dy    = sin(angle) * dist + (rng.nextDouble() - 0.5) * dissolveT * 20;
      final sz    = 1.5 + rng.nextDouble() * 3;
      dotPaint.color = color.withOpacity(opacity * (1.0 - dissolveT * 0.7));
      canvas.drawCircle(Offset(dx, dy), sz, dotPaint);
    }

    canvas.restore();
  }

  List<Offset> _generateBodyPoints() => [
    const Offset(0, -50),  // head top
    const Offset(-13, -40), const Offset(13, -40), // head sides
    const Offset(-13, -27), const Offset(13, -27), // head bottom
    const Offset(-25, -22), const Offset(25, -22), // shoulders
    const Offset(-25, -5),  const Offset(25, -5),  // upper arm
    const Offset(-18, 24),  const Offset(18, 24),  // waist
    const Offset(-8, 60),   const Offset(8, 60),   // cloak bottom
    const Offset(0, -50),   // back to top
    const Offset(0, 0),     // core
    const Offset(-18, 0),   const Offset(18, 0),   // core sides
    const Offset(0, -22),   const Offset(0, 22),   // core vertical
  ];

  // ── Win Blast ────────────────────────────────────────────────────────────────

  void _paintWinBlast(Canvas canvas, Size size, double t) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint  = Paint()
      ..color = Color.fromARGB((sin(t * pi) * 180).toInt().clamp(0, 255), 180, 80, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawCircle(center, size.width * t * 0.85, paint);

    paint
      ..color = Color.fromARGB((sin(t * pi) * 220).toInt().clamp(0, 255), 255, 200, 255)
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawCircle(center, size.width * t * 0.72, paint);
  }

  @override
  bool shouldRepaint(_WarpScenePainter old) => true;
}

enum _ArmPose { idle, attackBoth, teleportArm }

// ─── HUD Widgets ─────────────────────────────────────────────────────────────

class _DialogueBubble extends StatelessWidget {
  final String text;
  const _DialogueBubble({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xEE0D0020),
          border: Border.all(color: const Color(0xFF9B30FF), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x669B30FF), blurRadius: 16)],
        ),
        child: Text(text,
            style: const TextStyle(color: Color(0xFFDD99FF), fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 0.4),
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
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12)],
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
