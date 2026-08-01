// warp_sentinel_overlay.dart — WARP SENTINEL Visual Overlay (Level 41)
// Boss: Futuristic armored sentinel hovering above grid.
// Black holes: pulsing purple vortexes on grid tiles.
// Glitch intro, teleport dissolve, siphon tendrils, time-lock laser.

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
  // Bob / hover
  late final AnimationController _bob;
  // Black hole spin
  late final AnimationController _holeSpin;
  // Eye / core pulse
  late final AnimationController _corePulse;
  // Teleport dissolve
  late final AnimationController _teleport;
  // Siphon tendrils
  late final AnimationController _siphon;
  // Warning glow pulse
  late final AnimationController _warn;
  // Time-lock laser
  late final AnimationController _laser;
  // Glitch effect
  late final AnimationController _glitch;
  // Win explosion
  late final AnimationController _win;
  // Entry drop
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _bob      = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _holeSpin = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _corePulse= AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _teleport = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _siphon   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _warn     = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _laser    = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _glitch   = AnimationController(vsync: this, duration: const Duration(milliseconds: 80))..repeat();
    _win      = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _entry    = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

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

    // Trigger entry animation
    if (c.phase == WarpSentinelPhase.entry && !c.entryComplete) {
      _entry.forward(from: 0);
    }

    // Teleport animation
    if (c.isTeleporting && _teleport.status != AnimationStatus.forward) {
      _teleport.forward(from: 0).then((_) => _teleport.reverse());
    }

    // Win
    if (c.phase == WarpSentinelPhase.winBlast && !_win.isAnimating) {
      _win.forward(from: 0);
    }

    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _bob.dispose(); _holeSpin.dispose(); _corePulse.dispose();
    _teleport.dispose(); _siphon.dispose(); _warn.dispose();
    _laser.dispose(); _glitch.dispose(); _win.dispose(); _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c.phase == WarpSentinelPhase.idle) return const SizedBox.shrink();
    if (widget.isDialogActive && c.phase == WarpSentinelPhase.idle) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _bob, _holeSpin, _corePulse, _teleport,
        _siphon, _warn, _laser, _glitch, _win, _entry,
      ]),
      builder: (context, _) {
        return CustomPaint(
          painter: _WarpScenePainter(
            controller:  c,
            getCellRect: widget.getCellRect,
            bobT:        _bob.value,
            holeSpinT:   _holeSpin.value,
            corePulseT:  _corePulse.value,
            teleportT:   _teleport.value,
            siphonT:     _siphon.value,
            warnT:       _warn.value,
            laserT:      _laser.value,
            glitchT:     _glitch.value,
            winT:        _win.value,
            entryT:      _entry.value,
          ),
          child: _buildHUD(c),
        );
      },
    );
  }

  Widget _buildHUD(WarpSentinelController c) {
    if (c.phase == WarpSentinelPhase.idle) return const SizedBox.shrink();

    return Stack(
      children: [
        // Dialogue bubble at top
        if (c.dialogueText != null)
          Positioned(
            top: 8, left: 12, right: 12,
            child: _DialogueBubble(text: c.dialogueText!),
          ),

        // Stun bar
        if (c.isStunned)
          Positioned(
            bottom: 80, left: 24, right: 24,
            child: _StunBar(secsLeft: c.stunSecsLeft),
          ),

        // Hint strip at bottom
        if (c.phase == WarpSentinelPhase.active)
          Positioned(
            bottom: 8, left: 12, right: 12,
            child: _HintStrip(hint: kWarpHints[c.hintIndex]),
          ),

        // Siphon countdown
        if (c.currentAttack == WarpAttackType.warpSiphon && !c.siphonedCells.isEmpty)
          Positioned(
            top: 60, right: 16,
            child: _SiphonCountdown(secsLeft: c.siphonSecsLeft),
          ),
      ],
    );
  }
}

// ─── Main Scene Painter ───────────────────────────────────────────────────────

class _WarpScenePainter extends CustomPainter {
  final WarpSentinelController controller;
  final Rect? Function(int col, int row) getCellRect;
  final double bobT, holeSpinT, corePulseT, teleportT;
  final double siphonT, warnT, laserT, glitchT, winT, entryT;

  const _WarpScenePainter({
    required this.controller,
    required this.getCellRect,
    required this.bobT,
    required this.holeSpinT,
    required this.corePulseT,
    required this.teleportT,
    required this.siphonT,
    required this.warnT,
    required this.laserT,
    required this.glitchT,
    required this.winT,
    required this.entryT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = controller;
    final rng = Random(42); // deterministic seed for glitch noise

    // ── 1. Glitch intro overlay ───────────────────────────────────────────────
    if (c.glitchActive) {
      _paintGlitch(canvas, size, rng);
      return; // glitch replaces everything during intro
    }

    // ── 2. Warning glow on tiles ──────────────────────────────────────────────
    for (final cell in c.warningCells) {
      final rect = getCellRect(cell.$1, cell.$2);
      if (rect == null) continue;
      _paintWarningGlow(canvas, rect, warnT,
          isTimeLock: c.currentAttack == WarpAttackType.timeLock);
    }

    // ── 3. Time-locked tiles ──────────────────────────────────────────────────
    for (final cell in c.timeLockCells) {
      final rect = getCellRect(cell.$1, cell.$2);
      if (rect == null) continue;
      _paintTimeLockOverlay(canvas, rect, laserT);
    }

    // ── 4. Siphoned cells: pulsing purple pull ────────────────────────────────
    for (final cell in c.siphonedCells) {
      final rect = getCellRect(cell.$1, cell.$2);
      if (rect == null) continue;
      _paintSiphonGlow(canvas, rect, siphonT);
    }

    // ── 5. Black holes on grid ────────────────────────────────────────────────
    for (int i = 0; i < c.blackHoles.length; i++) {
      final hole = c.blackHoles[i];
      final rect = getCellRect(hole.$1, hole.$2);
      if (rect == null) continue;
      final isActive = i == c.bossHoleIndex;
      _paintBlackHole(canvas, rect, holeSpinT, isActive,
          entryT: c.phase == WarpSentinelPhase.entry ? entryT : 1.0);
    }

    // ── 6. Siphon tendrils from boss hole to siphoned cells ───────────────────
    if (c.currentAttack == WarpAttackType.warpSiphon && c.blackHoles.isNotEmpty) {
      final hole = c.blackHoles[c.bossHoleIndex];
      final holeRect = getCellRect(hole.$1, hole.$2);
      if (holeRect != null) {
        for (final sc in c.siphonedCells) {
          final cellRect = getCellRect(sc.$1, sc.$2);
          if (cellRect != null) {
            _paintSiphonTendril(canvas, holeRect.center, cellRect.center, siphonT);
          }
        }
      }
    }

    // ── 7. Time-lock laser from boss to locked zone ───────────────────────────
    if (c.currentAttack == WarpAttackType.timeLock && c.blackHoles.isNotEmpty) {
      final boss = _getBossPosition(size);
      if (boss != null && c.timeLockCells.isNotEmpty) {
        final firstCell = c.timeLockCells.first;
        final lastCell  = c.timeLockCells.last;
        final r1 = getCellRect(firstCell.$1, firstCell.$2);
        final r2 = getCellRect(lastCell.$1, lastCell.$2);
        if (r1 != null && r2 != null) {
          final zoneCenter = Rect.fromPoints(r1.topLeft, r2.bottomRight).center;
          _paintTimeLockLaser(canvas, boss, zoneCenter, laserT);
        }
      }
    }

    // ── 8. Boss figure ────────────────────────────────────────────────────────
    final bossPos = _getBossPosition(size);
    if (bossPos != null) {
      final dissolveT = teleportT; // 0→1 = dissolving, 1→0 = re-materialising
      final opacity   = c.isStunned ? 0.55 : 1.0 - (sin(dissolveT * pi) * 0.9);
      _paintBoss(canvas, bossPos, bobT, corePulseT, opacity, c.isStunned, c.phase == WarpSentinelPhase.winBlast);
    }

    // ── 9. Win explosion ──────────────────────────────────────────────────────
    if (c.phase == WarpSentinelPhase.winBlast && winT > 0) {
      _paintWinBlast(canvas, size, winT);
    }
  }

  // ── Boss position ───────────────────────────────────────────────────────────

  Offset? _getBossPosition(Size size) {
    if (controller.blackHoles.isEmpty) return null;
    final hole = controller.blackHoles[controller.bossHoleIndex];
    final rect = getCellRect(hole.$1, hole.$2);
    if (rect == null) return null;
    // Boss hovers above and slightly left of its black hole
    final bobOffset = sin(bobT * pi) * 10;
    return Offset(rect.center.dx, rect.top - 80 + bobOffset);
  }

  // ── Glitch ─────────────────────────────────────────────────────────────────

  void _paintGlitch(Canvas canvas, Size size, Random rng) {
    final paint = Paint();
    // Dark base tint
    paint.color = const Color(0x66000000);
    canvas.drawRect(Offset.zero & size, paint);

    // Horizontal noise bars
    final barCount = 6 + rng.nextInt(8);
    for (int i = 0; i < barCount; i++) {
      final y = rng.nextDouble() * size.height;
      final h = 2.0 + rng.nextDouble() * 18;
      final col = [
        const Color(0xAA9B30FF),
        const Color(0xAA00FFEE),
        const Color(0xAAFF003C),
      ][rng.nextInt(3)];
      paint.color = col;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, h), paint);
    }

    // Vertical chromatic shift strips
    for (int i = 0; i < 3; i++) {
      final x = rng.nextDouble() * size.width;
      final w = 4.0 + rng.nextDouble() * 20;
      paint.color = Color.fromARGB(
          80 + rng.nextInt(100),
          rng.nextInt(255), rng.nextInt(255), rng.nextInt(255));
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
    }

    // Center WARP SENTINEL text
    final tp = TextPainter(
      text: const TextSpan(
        text: 'WARP SENTINEL',
        style: TextStyle(
          color: Color(0xFFCE93FF),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          shadows: [Shadow(color: Color(0xCC9B30FF), blurRadius: 20)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, size.height / 2 - tp.height / 2));
  }

  // ── Black Hole ──────────────────────────────────────────────────────────────

  void _paintBlackHole(Canvas canvas, Rect rect, double spinT, bool isActive,
      {required double entryT}) {
    final center = rect.center;
    final scale  = isActive ? (0.85 + entryT * 0.15) : 0.75;
    final radius = rect.width * 0.44 * scale;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spinT * 2 * pi * (isActive ? 1.0 : -0.6));

    // Outer glow rings
    for (int r = 3; r >= 0; r--) {
      final ringR = radius + r * 8.0;
      final alpha = (0.15 - r * 0.03).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.fromARGB((alpha * 255).toInt(), 155, 48, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset.zero, ringR, paint);
    }

    // Dark core (the actual black hole)
    final corePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        radius,
        [const Color(0xFF000000), const Color(0xFF0D0020), const Color(0xFF1A0033)],
        [0.0, 0.6, 1.0],
      );
    canvas.drawCircle(Offset.zero, radius, corePaint);

    // Swirling accretion rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 0; i < 4; i++) {
      final t = (spinT + i * 0.25) % 1.0;
      final ringR = radius * (0.5 + t * 0.55);
      final alpha = (1.0 - t) * 0.8;
      ringPaint.color = Color.fromARGB(
          (alpha * 200).toInt(),
          155 + (t * 60).toInt(),
          48,
          255);
      canvas.drawOval(Rect.fromCenter(
          center: Offset.zero,
          width: ringR * 2,
          height: ringR * 0.7), ringPaint);
    }

    // Active indicator glow
    if (isActive) {
      final glowPaint = Paint()
        ..color = const Color(0x559B30FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset.zero, radius * 1.4, glowPaint);
    }

    canvas.restore();
  }

  // ── Boss Body ───────────────────────────────────────────────────────────────

  void _paintBoss(Canvas canvas, Offset center, double bobT, double corePulseT,
      double opacity, bool isStunned, bool isWin) {
    if (opacity <= 0.01) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final paint = Paint();
    final o = (opacity * 255).toInt().clamp(0, 255);

    // Outer atmospheric glow
    paint
      ..color = isStunned
          ? Color.fromARGB((o * 0.25).toInt(), 100, 200, 255)
          : Color.fromARGB((o * 0.20).toInt(), 155, 48, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset.zero, 55, paint);
    paint.maskFilter = null;

    // ── Cloak / energy mantle (flowing triangular shape) ─────────────────────
    final cloakColor = isStunned ? const Color(0xFF4488FF) : const Color(0xFF7B20EE);
    final cloakPath = Path();
    const cw = 52.0;
    const ch = 75.0;
    final cloakFlare = sin(bobT * pi) * 5;
    cloakPath.moveTo(0, -ch * 0.3);
    cloakPath.cubicTo(-cw, -ch * 0.1, -cw - cloakFlare, ch * 0.6, -18, ch + 5);
    cloakPath.lineTo(18, ch + 5);
    cloakPath.cubicTo(cw + cloakFlare, ch * 0.6, cw, -ch * 0.1, 0, -ch * 0.3);
    cloakPath.close();

    paint.color = Color.fromARGB(o, cloakColor.red, cloakColor.green, cloakColor.blue);
    paint.style = PaintingStyle.fill;
    canvas.drawPath(cloakPath, paint);

    // Cloak inner gradient overlay
    final cloakShader = ui.Gradient.linear(
      const Offset(0, -50),
      const Offset(0, 60),
      [
        Color.fromARGB((o * 0.7).toInt(), 30, 0, 80),
        Color.fromARGB((o * 0.0).toInt(), 30, 0, 80),
      ],
    );
    paint.shader = cloakShader;
    canvas.drawPath(cloakPath, paint);
    paint.shader = null;

    // ── Armored torso ─────────────────────────────────────────────────────────
    final torsoRect = Rect.fromCenter(center: const Offset(0, 0), width: 38, height: 50);
    final torsoRR   = RRect.fromRectAndRadius(torsoRect, const Radius.circular(8));
    paint
      ..color = Color.fromARGB(o, 18, 12, 38)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(torsoRR, paint);

    // Torso panel lines
    paint
      ..color = Color.fromARGB((o * 0.5).toInt(), 155, 48, 255)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(-8, -18), const Offset(-8, 18), paint);
    canvas.drawLine(const Offset(8, -18), const Offset(8, 18), paint);
    canvas.drawLine(const Offset(-16, 0), const Offset(16, 0), paint);
    paint.style = PaintingStyle.fill;

    // ── Energy core (chest) ──────────────────────────────────────────────────
    final coreGlow = 0.4 + corePulseT * 0.6;
    final coreColor = isStunned
        ? Color.fromARGB(o, 100, 200, 255)
        : Color.fromARGB(o, 180 + (corePulseT * 75).toInt(), 48, 255);

    paint
      ..color = coreColor.withOpacity(coreGlow * 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 + corePulseT * 8);
    canvas.drawCircle(Offset.zero, 16, paint);
    paint.maskFilter = null;

    paint
      ..color = Color.fromARGB(o, 30, 0, 70)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 9, paint);

    paint.color = coreColor;
    canvas.drawCircle(Offset.zero, 5 + corePulseT * 2, paint);

    // Core sparkle cross
    paint
      ..color = Color.fromARGB((o * coreGlow).toInt(), 255, 220, 255)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cs = 6.0 + corePulseT * 3;
    canvas.drawLine(Offset(0, -cs), Offset(0, cs), paint);
    canvas.drawLine(Offset(-cs, 0), Offset(cs, 0), paint);
    paint.style = PaintingStyle.fill;

    // ── Head / visor ─────────────────────────────────────────────────────────
    const headY = -34.0;
    final headRect = Rect.fromCenter(center: const Offset(0, headY), width: 28, height: 24);
    final headRR   = RRect.fromRectAndRadius(headRect, const Radius.circular(6));
    paint.color = Color.fromARGB(o, 18, 12, 38);
    canvas.drawRRect(headRR, paint);

    // Visor bar
    final visorRect = Rect.fromCenter(
        center: Offset(0, headY), width: 22, height: 8);
    paint.shader = ui.Gradient.linear(
      Offset(-11, headY), Offset(11, headY),
      [
        const Color(0xFF9B30FF),
        const Color(0xFFDD88FF),
        const Color(0xFF9B30FF),
      ],
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(visorRect, const Radius.circular(3)), paint);
    paint.shader = null;

    // Visor glow
    paint
      ..color = Color.fromARGB(
          (o * 0.5 * (0.6 + corePulseT * 0.4)).toInt(), 200, 120, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(visorRect, const Radius.circular(3)), paint);
    paint.maskFilter = null;

    // ── Shoulder plates ───────────────────────────────────────────────────────
    for (final side in [-1, 1]) {
      final sx = side * 22.0;
      final shoulderRect = Rect.fromCenter(
          center: Offset(sx, -18), width: 10, height: 22);
      paint
        ..color = Color.fromARGB(o, 25, 10, 55)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
          RRect.fromRectAndRadius(shoulderRect, const Radius.circular(4)), paint);
      // Shoulder edge glow
      paint
        ..color = Color.fromARGB((o * 0.4).toInt(), 155, 48, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(
          RRect.fromRectAndRadius(shoulderRect, const Radius.circular(4)), paint);
      paint.style = PaintingStyle.fill;
    }

    // ── Stun sparks ───────────────────────────────────────────────────────────
    if (isStunned) {
      final r = Random(DateTime.now().millisecondsSinceEpoch ~/ 100);
      paint
        ..color = Color.fromARGB(o, 100, 220, 255)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 6; i++) {
        final angle = r.nextDouble() * 2 * pi;
        final dist  = 20 + r.nextDouble() * 30;
        final len   = 6 + r.nextDouble() * 10;
        final sx    = cos(angle) * dist;
        final sy    = sin(angle) * dist;
        canvas.drawLine(
          Offset(sx, sy),
          Offset(sx + cos(angle + pi * 0.3) * len,
                 sy + sin(angle + pi * 0.3) * len),
          paint,
        );
      }
      paint.style = PaintingStyle.fill;
    }

    canvas.restore();
  }

  // ── Warning Glow ────────────────────────────────────────────────────────────

  void _paintWarningGlow(Canvas canvas, Rect rect, double warnT,
      {required bool isTimeLock}) {
    final pulse  = 0.5 + warnT * 0.5;
    final color  = isTimeLock ? const Color(0xFF00AAFF) : const Color(0xFFAA00FF);
    final paint  = Paint()
      ..color = color.withOpacity(pulse * 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRect(rect.inflate(4), paint);

    paint
      ..color = color.withOpacity(pulse * 0.9)
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(rect.inflate(2), paint);
    paint.style = PaintingStyle.fill;
  }

  // ── Time-Lock overlay on a locked cell ──────────────────────────────────────

  void _paintTimeLockOverlay(Canvas canvas, Rect rect, double laserT) {
    // Cyan freeze tint
    final paint = Paint()
      ..color = Color.fromARGB((50 + laserT * 40).toInt(), 0, 200, 255)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);

    // Ice crystal grid lines
    paint
      ..color = const Color(0x8800EEFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const lines = 3;
    for (int i = 1; i < lines; i++) {
      final x = rect.left + (rect.width / lines) * i;
      final y = rect.top  + (rect.height / lines) * i;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
    // Diagonals
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
    paint.style = PaintingStyle.fill;
  }

  // ── Siphon Glow on a targeted cell ──────────────────────────────────────────

  void _paintSiphonGlow(Canvas canvas, Rect rect, double siphonT) {
    final pull   = (siphonT * 2 * pi);
    final scale  = 1.0 + sin(pull) * 0.08;
    final center = rect.center;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = const Color(0x88AA00FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset.zero, rect.width * 0.6, paint);
    paint
      ..color = const Color(0xAACC44FF)
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, rect.width * 0.42, paint);
    paint.style = PaintingStyle.fill;

    canvas.restore();
  }

  // ── Siphon Tendril ───────────────────────────────────────────────────────────

  void _paintSiphonTendril(
      Canvas canvas, Offset from, Offset to, double siphonT) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Animated dash along the path
    final dir    = to - from;
    final length = dir.distance;
    final norm   = dir / length;
    final perp   = Offset(-norm.dy, norm.dx);

    // Draw 3 tendril strands
    for (int s = 0; s < 3; s++) {
      final phase = siphonT + s * 0.33;
      final waveAmp = 6.0 - s * 1.5;
      final path = Path();
      path.moveTo(from.dx, from.dy);
      const steps = 20;
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final wave = sin((t * 4 + phase) * 2 * pi) * waveAmp * (1 - t * 0.6);
        final p = from + dir * t + perp * wave;
        if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
      }
      final alpha = (0.5 + (1 - s * 0.15) * 0.5);
      paint
        ..color = Color.fromARGB(
            (alpha * 200).toInt(), 180 + s * 20, 48, 255)
        ..strokeWidth = 2.5 - s * 0.5
        ..maskFilter = s == 0
            ? const MaskFilter.blur(BlurStyle.normal, 4)
            : null;
      canvas.drawPath(path, paint);
    }

    // Particles flowing toward target
    for (int p = 0; p < 5; p++) {
      final t = (siphonT + p * 0.2) % 1.0;
      final pt = from + dir * t;
      final wave = sin((t * 4 + siphonT) * 2 * pi) * 5;
      final pp = pt + perp * wave;
      final paintP = Paint()
        ..color = Color.fromARGB((255 * (1 - t) * 0.8).toInt(), 220, 120, 255)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(pp, 2.5, paintP);
    }
  }

  // ── Time-Lock Laser ──────────────────────────────────────────────────────────

  void _paintTimeLockLaser(
      Canvas canvas, Offset from, Offset to, double laserT) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Outer glow
    paint
      ..color = Color.fromARGB((80 + laserT * 60).toInt(), 0, 200, 255)
      ..strokeWidth = 16
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawLine(from, to, paint);

    // Mid beam
    paint
      ..color = Color.fromARGB((160 + laserT * 80).toInt(), 0, 220, 255)
      ..strokeWidth = 5
      ..maskFilter = null;
    canvas.drawLine(from, to, paint);

    // White core
    paint
      ..color = Color.fromARGB((200 + laserT * 55).toInt(), 200, 255, 255)
      ..strokeWidth = 2;
    canvas.drawLine(from, to, paint);

    // Impact circle at target
    final impPaint = Paint()
      ..color = Color.fromARGB((120 + laserT * 120).toInt(), 0, 255, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(to, 20 + laserT * 8, impPaint);
  }

  // ── Win Explosion ────────────────────────────────────────────────────────────

  void _paintWinBlast(Canvas canvas, Size size, double t) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint  = Paint()
      ..color = Color.fromARGB(
          (sin(t * pi) * 180).toInt().clamp(0, 255), 180, 80, 255)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(center, size.width * t * 0.8, paint);

    // Ring
    paint
      ..color = Color.fromARGB(
          (sin(t * pi) * 220).toInt().clamp(0, 255), 255, 200, 255)
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, size.width * t * 0.7, paint);
  }

  @override
  bool shouldRepaint(_WarpScenePainter old) => true;
}

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
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFDD99FF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚡ STUNNED ', style: TextStyle(color: Color(0xFF00DDFF), fontWeight: FontWeight.w800, fontSize: 11)),
            Text('${secsLeft}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          ],
        ),
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
        child: Text(
          hint,
          style: const TextStyle(color: Color(0xFFBB88EE), fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      );
}

class _SiphonCountdown extends StatelessWidget {
  final int secsLeft;
  const _SiphonCountdown({required this.secsLeft});

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xDD1A003A),
          border: Border.all(color: const Color(0xFFAA00FF), width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x88AA00FF), blurRadius: 12)],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$secsLeft', style: const TextStyle(
                  color: Color(0xFFFF66FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
              const Text('s', style: TextStyle(color: Color(0xFFAA88CC), fontSize: 9)),
            ],
          ),
        ),
      );
}
