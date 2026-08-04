// nexus_core_overlay.dart — NEXUS CORE Boss UI (Level 40)
// Complete rewrite: proper dark-metal mechanical squid body, animated waving
// tentacles, organic professional eye blink, red laser beam from eye to
// targeted cell, hacked-cell sparks that follow item moves.

import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/nexus_core_controller.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBodyDark   = Color(0xFF0D1520);
const _kBodyMid    = Color(0xFF1A2540);
const _kBodyEdge   = Color(0xFF2E4060);
const _kPanelLine  = Color(0xFF3A5070);
const _kEyeRed     = Color(0xFFFF1800);
const _kEyeOrange  = Color(0xFFFF7000);
const _kTentBase   = Color(0xFF1E3050);
const _kTentTip    = Color(0xFF0A1525);
const _kGold       = Color(0xFFFFD700);
const _kEMP        = Color(0xFF44AAFF);
const _kHack       = Color(0xFFFF2020);

/// Y-offset of boss body center from top of screen (fraction of height).
double _bossCY(Size sz) => sz.height * 0.225;

// ── Root widget ───────────────────────────────────────────────────────────────

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
        if (isDialogActive)           return const SizedBox.shrink();
        return _NexusScene(controller: controller, getCellRect: getCellRect);
      },
    );
  }
}

// ── Main animated scene ───────────────────────────────────────────────────────

class _NexusScene extends StatefulWidget {
  final NexusCoreController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _NexusScene({required this.controller, required this.getCellRect});
  @override State<_NexusScene> createState() => _NexusSceneState();
}

class _NexusSceneState extends State<_NexusScene> with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _bob;        // continuous bob 0→1 cycle
  late final AnimationController _tentWave;  // tentacle wave 0→1 cycle
  late final AnimationController _eyePulse;  // eye glow pulse 0→1 cycle
  late final AnimationController _blinkCtrl; // eye blink sequence
  late final AnimationController _laserPulse;// laser flicker (fast)
  late final AnimationController _entryDrop; // entry drop-in (0→1 once)
  late final AnimationController _empRing;   // EMP ring on stun
  late final AnimationController _winLaser;  // win blast laser
  late final AnimationController _winExplode;
  late final AnimationController _laserBuildup; // beam buildup when new target acquired

  double _bobVal    = 0;
  double _tentVal   = 0;
  double _eyeVal    = 0;
  double _blinkVal  = 0; // 0=open, 1=fully closed
  double _laserVal  = 0;
  double _entryVal  = 0;
  double _empVal    = 0;
  double _winLVal   = 0;
  double _winEVal   = 0;
  double _laserBuildupVal = 0;  // 0→1 beam buildup when new target acquired

  // Blink scheduling
  bool _blinkScheduled = false;
  (int,int)? _prevTarget; // track target changes for buildup anim

  @override
  void initState() {
    super.initState();
    _bob       = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _tentWave  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _eyePulse  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _laserPulse= AnimationController(vsync: this, duration: const Duration(milliseconds: 180))..repeat(reverse: true);
    _entryDrop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _empRing   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
    _winLaser  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _winExplode= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _laserBuildup = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

    _bob.addListener(()         { if (mounted) setState(() => _bobVal         = _bob.value); });
    _tentWave.addListener(()    { if (mounted) setState(() => _tentVal        = _tentWave.value); });
    _eyePulse.addListener(()    { if (mounted) setState(() => _eyeVal         = _eyePulse.value); });
    _blinkCtrl.addListener(()   { if (mounted) setState(() => _blinkVal       = _blinkAnim()); });
    _laserPulse.addListener(()  { if (mounted) setState(() => _laserVal       = _laserPulse.value); });
    _entryDrop.addListener(()   { if (mounted) setState(() => _entryVal       = _entryDrop.value); });
    _empRing.addListener(()     { if (mounted) setState(() => _empVal         = _empRing.value); });
    _winLaser.addListener(()    { if (mounted) setState(() => _winLVal        = _winLaser.value); });
    _winExplode.addListener(()  { if (mounted) setState(() => _winEVal        = _winExplode.value); });
    _laserBuildup.addListener((){if (mounted) setState(() => _laserBuildupVal = _laserBuildup.value); });

    // Start blink loop
    _scheduleBlink();

    // Win sequence
    if (widget.controller.phase == NexusCorePhase.winBlast) {
      _winLaser.forward().then((_) => _winExplode.forward());
    } else if (widget.controller.phase == NexusCorePhase.entry) {
      _entryDrop.forward();
    } else {
      _entryVal = 1.0;
    }
  }

  void _scheduleBlink() {
    if (!mounted || _blinkScheduled) return;
    _blinkScheduled = true;
    final delay = 2800 + Random().nextInt(2200);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _blinkScheduled = false;
      if (widget.controller.phase == NexusCorePhase.stunned) { _scheduleBlink(); return; }
      _blinkCtrl.forward().then((_) {
        if (!mounted) return;
        _blinkCtrl.reverse().then((_) { if (mounted) _scheduleBlink(); });
      });
    });
  }

  // Blink: closes over 60% of anim then reopens — smooth, organic
  double _blinkAnim() {
    final t = _blinkCtrl.value;
    if (t <= 0.6) return Curves.easeIn.transform(t / 0.6);
    return Curves.easeOut.transform(1 - (t - 0.6) / 0.4);
  }

  @override
  void didUpdateWidget(_NexusScene old) {
    super.didUpdateWidget(old);
    if (widget.controller.phase == NexusCorePhase.entry && _entryVal == 0) {
      _entryDrop.forward();
    }
    if (widget.controller.phase == NexusCorePhase.winBlast && _winLVal == 0) {
      _winLaser.forward().then((_) { if (mounted) _winExplode.forward(); });
    }
    // Detect new target → trigger beam buildup animation
    final newTarget = widget.controller.targetedCell;
    if (newTarget != _prevTarget) {
      _prevTarget = newTarget;
      if (newTarget != null) {
        _laserBuildup.forward(from: 0);
      } else {
        _laserBuildup.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _bob.dispose(); _tentWave.dispose(); _eyePulse.dispose(); _blinkCtrl.dispose();
    _laserPulse.dispose(); _entryDrop.dispose(); _empRing.dispose();
    _winLaser.dispose(); _winExplode.dispose(); _laserBuildup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz  = MediaQuery.of(context).size;
    final p   = widget.controller.phase;
    final cy  = _bossCY(sz);

    // Compute entry Y offset
    final entryY = p == NexusCorePhase.entry
        ? -180.0 + Curves.easeOutBack.transform(_entryVal) * (cy + 180)
        : cy;

    // Stun: desaturate eye
    final isStunned = p == NexusCorePhase.stunned;
    final eyeColor  = isStunned ? const Color(0xFF444444)
        : Color.lerp(_kEyeRed, _kEyeOrange, _eyeVal * 0.4)!;
    final bodyBrightness = isStunned ? 0.5 : 1.0;

    // Targeted cell rect for laser
    final target    = widget.controller.targetedCell;
    final targetRect= target != null ? widget.getCellRect(target.$1, target.$2) : null;
    // Fallback cell position if getCellRect returns null (fixes first-item bug)
    final effectiveTargetRect = targetRect ?? (target != null ? _estimateCellRect(target.$1, target.$2, sz) : null);

    // Actual eye position on screen (accounts for bob offset)
    final eyeCenter = Offset(sz.width / 2, entryY + (_bobVal - 0.5) * 12.0);

    return Stack(children: [

      // ── Pre-attack charge vignette (eye charging up) ──────────────────────
      if (p == NexusCorePhase.active && widget.controller.isLaserCharging && effectiveTargetRect == null)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ChargeVignettePainter(
                eyeCenter: eyeCenter,
                chargeProgress: _eyeVal,
              ),
            ),
          ),
        ),

      // ── Laser beam from eye to targeted cell ─────────────────────────────
      if (p == NexusCorePhase.active && effectiveTargetRect != null)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _LaserBeamPainter(
                eyeCenter:      eyeCenter,
                toRect:         effectiveTargetRect,
                flickerVal:     _laserVal,
                buildupProgress: _laserBuildupVal,
                secsLeft:       widget.controller.targetSecondsLeft,
              ),
            ),
          ),
        ),

      // ── Boss body ────────────────────────────────────────────────────────
      Positioned(
        top: entryY - 60,
        left: 0, right: 0,
        child: Center(
          child: SizedBox(
            width: 160, height: 120,
            child: CustomPaint(
              painter: _NexusBodyPainter(
                bobOffset:        (_bobVal - 0.5) * 12,
                tentPhase:        _tentVal,
                eyeColor:         eyeColor,
                blinkT:           isStunned ? 0 : _blinkVal,
                bodyBrightness:   bodyBrightness,
                isTargeting:      p == NexusCorePhase.active && targetRect != null,
                eyePulse:         _eyeVal,
                glitchIntensity:  p == NexusCorePhase.entry ? (1 - _entryVal) * 0.8 : 0,
              ),
            ),
          ),
        ),
      ),

      // ── Hacked cell sparks ───────────────────────────────────────────────
      if (p == NexusCorePhase.active || p == NexusCorePhase.stunned)
        _HackedCells(controller: widget.controller, getCellRect: widget.getCellRect),

      // ── Crosshair on targeted cell ───────────────────────────────────────
      if (p == NexusCorePhase.active && target != null && targetRect != null)
        _CrosshairWidget(rect: targetRect, secsLeft: widget.controller.targetSecondsLeft, laserVal: _laserVal),

      // ── Stunned overlay ──────────────────────────────────────────────────
      if (isStunned)
        Positioned(
          top: entryY - 78,
          left: 0, right: 0,
          child: Center(
            child: CustomPaint(
              size: const Size(200, 160),
              painter: _EmpRingPainter(_empVal),
            ),
          ),
        ),
      if (isStunned)
        Positioned(
          top: entryY - 90,
          left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _kEMP.withOpacity(0.88),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: _kEMP.withOpacity(0.55), blurRadius: 10)],
              ),
              child: Text(
                'STUNNED  ${widget.controller.stunSecondsLeft}s',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w900, letterSpacing: 1.4),
              ),
            ),
          ),
        ),

      // ── Win blast ────────────────────────────────────────────────────────
      if (p == NexusCorePhase.winBlast)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _WinBlastPainter(
                bossCY:  cy,
                bossX:   sz.width / 2,
                quotaY:  sz.height * 0.72,
                laserT:  _winLVal,
                explodeT:_winEVal,
              ),
            ),
          ),
        ),
      if (p == NexusCorePhase.winBlast && _winEVal > 0.55)
        Positioned(
          top: sz.height * 0.38,
          left: 16, right: 16,
          child: Opacity(
            opacity: ((_winEVal - 0.55) / 0.45).clamp(0, 1),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kGold, width: 2.5),
                  boxShadow: [BoxShadow(color: _kGold.withOpacity(0.45), blurRadius: 28)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFFD700)],
                    ).createShader(b),
                    child: const Text('LEVEL 40 CLEARED',
                      style: TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                  ),
                  const SizedBox(height: 6),
                  const Text('NEXUS CORE DESTROYED',
                    style: TextStyle(color: Colors.white70, fontSize: 14,
                        fontWeight: FontWeight.w700, letterSpacing: 1.8)),
                  const SizedBox(height: 10),
                  const Text('🛸💥🤖', style: TextStyle(fontSize: 30)),
                ]),
              ),
            ),
          ),
        ),

      // ── Hint ticker ──────────────────────────────────────────────────────
      if (p == NexusCorePhase.active || isStunned)
        _HintBar(controller: widget.controller),

      // ── Dialogue bubble ──────────────────────────────────────────────────
      if (p == NexusCorePhase.active && widget.controller.dialogueText != null)
        _DialogueBubble(text: widget.controller.dialogueText!, bossCY: cy, screenW: sz.width),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEXUS CORE Body Painter — full mechanical squid drawn every frame
// ─────────────────────────────────────────────────────────────────────────────

class _NexusBodyPainter extends CustomPainter {
  final double bobOffset;
  final double tentPhase;       // 0..1 continuous wave
  final Color  eyeColor;
  final double blinkT;          // 0=open, 1=closed
  final double bodyBrightness;  // 1.0 = normal, 0.5 = stunned grey
  final bool   isTargeting;
  final double eyePulse;
  final double glitchIntensity;

  const _NexusBodyPainter({
    required this.bobOffset,
    required this.tentPhase,
    required this.eyeColor,
    required this.blinkT,
    required this.bodyBrightness,
    required this.isTargeting,
    required this.eyePulse,
    required this.glitchIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2 + bobOffset;

    _drawTentacles(canvas, size, cx, cy);
    _drawBody(canvas, cx, cy);
    _drawEye(canvas, cx, cy);
    if (glitchIntensity > 0) _drawGlitch(canvas, size, cx, cy);
  }

  // ── Tentacles ─────────────────────────────────────────────────────────────

  void _drawTentacles(Canvas canvas, Size size, double cx, double cy) {
    const nArms = 8;
    // Spread evenly below the body (170° arc pointing downward)
    const spreadStart = math.pi * 0.28;  // ~50° from straight down
    const spreadTotal = math.pi * 0.44;  // full spread of 80° total
    const nSeg = 5;
    const segLen = 18.0;

    for (int a = 0; a < nArms; a++) {
      final frac     = nArms == 1 ? 0.5 : a / (nArms - 1).toDouble();
      final baseAngle= spreadStart + frac * spreadTotal - math.pi / 2; // start angle
      final phase    = tentPhase * math.pi * 2 + a * (math.pi / 4);

      final path = Path();
      double px = cx;
      double py = cy + 36; // attach to bottom of body
      path.moveTo(px, py);

      for (int s = 0; s < nSeg; s++) {
        final waveAmp  = 6.0 + s * 2.0; // grows toward tip
        final waveFreq = 1.5;
        final segAngle = baseAngle + math.sin(phase + s * 0.7) * waveAmp * 0.06;
        final nx       = px + math.cos(segAngle) * segLen;
        final ny       = py + math.sin(segAngle) * segLen;
        // Control point for smooth bezier
        final mx = (px + nx) / 2 + math.sin(phase + s * 1.2) * waveAmp * 0.5;
        final my = (py + ny) / 2;
        path.quadraticBezierTo(mx, my, nx, ny);
        px = nx; py = ny;
      }

      final strokeW = 3.5 - a.abs() * 0.1;
      final opacity = bodyBrightness * (0.55 + (1 - a / nArms) * 0.25);

      // Outer glow
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW + 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _kEyeRed.withOpacity(isTargeting ? opacity * 0.35 : 0.0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      // Core tentacle
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [
            Color.lerp(_kTentBase, Colors.grey, 1 - bodyBrightness)!.withOpacity(opacity),
            _kTentTip.withOpacity(opacity * 0.5),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, cy, size.width, size.height - cy)));

      // Joint dots
      final rng = Random(a);
      double jx = cx, jy = cy + 36;
      for (int s = 0; s < nSeg; s++) {
        final waveAmp  = 6.0 + s * 2.0;
        final segAngle = baseAngle + math.sin(phase + s * 0.7) * waveAmp * 0.06;
        jx += math.cos(segAngle) * segLen;
        jy += math.sin(segAngle) * segLen;
        canvas.drawCircle(Offset(jx, jy), 2.2,
          Paint()..color = _kBodyEdge.withOpacity(opacity * 0.8 * bodyBrightness));
      }
    }
  }

  // ── Main Body ──────────────────────────────────────────────────────────────

  void _drawBody(Canvas canvas, double cx, double cy) {
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy), width: 140, height: 88);

    // Outer glow / aura
    canvas.drawOval(bodyRect.inflate(12), Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color = (isTargeting ? _kEyeRed : _kBodyMid)
          .withOpacity(bodyBrightness * (isTargeting ? 0.35 : 0.18)));

    // Shell base gradient
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(_kBodyMid, Colors.grey.shade800, 1 - bodyBrightness)!,
          Color.lerp(_kBodyDark, Colors.grey.shade900, 1 - bodyBrightness)!,
        ],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, bodyPaint);

    // Rim highlight (top edge bright)
    canvas.drawArc(bodyRect, math.pi, math.pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = _kBodyEdge.withOpacity(bodyBrightness * 0.7));

    // Panel lines
    final pLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _kPanelLine.withOpacity(bodyBrightness * 0.65);

    // Horizontal divider
    canvas.drawLine(Offset(cx - 55, cy), Offset(cx + 55, cy), pLine);
    // Vertical dividers
    canvas.drawLine(Offset(cx - 28, cy - 35), Offset(cx - 28, cy + 35), pLine);
    canvas.drawLine(Offset(cx + 28, cy - 35), Offset(cx + 28, cy + 35), pLine);
    // Diagonal reinforcement
    canvas.drawLine(Offset(cx - 52, cy - 14), Offset(cx - 28, cy - 30), pLine);
    canvas.drawLine(Offset(cx + 28, cy - 30), Offset(cx + 52, cy - 14), pLine);

    // Bolt circles (mechanical detail)
    final boltPaint = Paint()..color = _kPanelLine.withOpacity(bodyBrightness * 0.8);
    for (final pos in [
      Offset(cx - 52, cy - 8), Offset(cx + 52, cy - 8),
      Offset(cx - 52, cy + 8), Offset(cx + 52, cy + 8),
      Offset(cx - 20, cy - 32), Offset(cx + 20, cy - 32),
    ]) {
      canvas.drawCircle(pos, 3.0, boltPaint);
      canvas.drawCircle(pos, 3.0, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _kBodyEdge.withOpacity(bodyBrightness * 0.5));
    }

    // Vent slits on sides
    final ventPaint = Paint()..color = _kBodyDark.withOpacity(bodyBrightness * 0.9)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int v = 0; v < 3; v++) {
      final vy = cy - 8 + v * 8.0;
      canvas.drawLine(Offset(cx - 68, vy), Offset(cx - 58, vy), ventPaint);
      canvas.drawLine(Offset(cx + 58, vy), Offset(cx + 68, vy), ventPaint);
    }

    // Rim border
    canvas.drawOval(bodyRect, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = _kBodyEdge.withOpacity(bodyBrightness * 0.55));
  }

  // ── Eye ───────────────────────────────────────────────────────────────────

  void _drawEye(Canvas canvas, double cx, double cy) {
    const eyeR = 22.0; // full open radius

    // Outer glow
    canvas.drawCircle(Offset(cx, cy), eyeR + 10, Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = eyeColor.withOpacity(bodyBrightness * (0.4 + eyePulse * 0.35)));

    // Outer ring
    canvas.drawCircle(Offset(cx, cy), eyeR + 4, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = eyeColor.withOpacity(bodyBrightness * 0.3));

    // Dark lens housing
    canvas.drawCircle(Offset(cx, cy), eyeR + 2, Paint()
      ..color = _kBodyDark.withOpacity(0.6));

    // Lens glass gradient
    canvas.drawCircle(Offset(cx, cy), eyeR, Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(bodyBrightness * 0.85),
          eyeColor.withOpacity(bodyBrightness),
          eyeColor.withOpacity(bodyBrightness * 0.6),
          Colors.black.withOpacity(0.9),
        ],
        stops: const [0.0, 0.28, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: eyeR)));

    // Iris ring segments (6 segments, rotating slightly with eye pulse)
    final irisR = eyeR * 0.75;
    for (int i = 0; i < 6; i++) {
      final a1 = i * (math.pi / 3) + eyePulse * 0.15;
      final a2 = a1 + math.pi / 3 - 0.12;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: irisR),
        a1, a2 - a1, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = eyeColor.withOpacity(bodyBrightness * 0.5));
    }

    // Pupil
    canvas.drawCircle(Offset(cx + 1, cy), eyeR * 0.3, Paint()
      ..color = Colors.black.withOpacity(0.92));

    // Lens glint
    canvas.drawCircle(Offset(cx - 6, cy - 7), 4.5, Paint()
      ..color = Colors.white.withOpacity(bodyBrightness * 0.65));
    canvas.drawCircle(Offset(cx - 6, cy - 7), 2.0, Paint()
      ..color = Colors.white.withOpacity(bodyBrightness * 0.9));

    // Targeting charge ring
    if (isTargeting) {
      canvas.drawCircle(Offset(cx, cy), eyeR + 8, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _kEyeRed.withOpacity(0.8 + eyePulse * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }

    // ── Blink (eyelid plates sliding over eye) ────────────────────────────
    if (blinkT > 0.01) {
      final lidH  = (eyeR + 3) * blinkT; // how far lids have closed
      final lidR  = eyeR + 3;

      // Clip to circle so lids don't go outside eye housing
      canvas.save();
      final clipPath = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: lidR));
      canvas.clipPath(clipPath);

      // Top eyelid plate
      final topLid = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - lidR, cy - lidR, lidR * 2, lidH),
        topLeft:    const Radius.circular(3),
        topRight:   const Radius.circular(3),
      );
      canvas.drawRRect(topLid, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_kBodyMid, _kBodyDark],
        ).createShader(topLid.outerRect));

      // Bottom eyelid plate
      final botLid = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - lidR, cy + lidR - lidH, lidR * 2, lidH),
        bottomLeft:  const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      canvas.drawRRect(botLid, Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [_kBodyMid, _kBodyDark],
        ).createShader(botLid.outerRect));

      // Lid edge seam
      if (blinkT > 0.4) {
        final seamY = cy - lidR + lidH;
        canvas.drawLine(Offset(cx - lidR, seamY), Offset(cx + lidR, seamY),
          Paint()..color = _kEyeRed.withOpacity(0.5 * (blinkT - 0.4) / 0.6)..strokeWidth = 1.2);
      }

      canvas.restore();

      // Lid rim lines (panel bolts on eyelids)
      final boltC = Paint()..color = _kBodyEdge.withOpacity(blinkT * 0.7);
      canvas.drawCircle(Offset(cx - 12, cy - lidR + 4), 1.8, boltC);
      canvas.drawCircle(Offset(cx + 12, cy - lidR + 4), 1.8, boltC);
    }
  }

  // ── Entry Glitch ──────────────────────────────────────────────────────────

  void _drawGlitch(Canvas canvas, Size size, double cx, double cy) {
    if (glitchIntensity <= 0) return;
    final rng = Random((glitchIntensity * 100).toInt());
    final col = Color.lerp(const Color(0xFF00FF44), _kEyeRed, 1 - glitchIntensity)!;
    final p = Paint()..color = col.withOpacity(glitchIntensity * 0.4);
    for (int i = 0; i < 8; i++) {
      final gy = rng.nextDouble() * size.height;
      final gw = 20.0 + rng.nextDouble() * (size.width * 0.7);
      final gx = rng.nextDouble() * (size.width - gw);
      canvas.drawRect(Rect.fromLTWH(gx, gy, gw, 2.5 + rng.nextDouble() * 2), p);
    }
  }

  @override
  bool shouldRepaint(_NexusBodyPainter o) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: estimate cell rect if getCellRect returns null (first-item bug fix)
// ─────────────────────────────────────────────────────────────────────────────

Rect _estimateCellRect(int col, int row, Size sz) {
  // Approximate grid layout based on common game layout proportions
  const gridMargin = 8.0;
  const gridCols   = 6;
  const gridRows   = 5;
  final gridTop    = sz.height * 0.40;
  final gridBottom = sz.height * 0.87;
  final cellW = (sz.width - gridMargin * 2) / gridCols;
  final cellH = (gridBottom - gridTop) / gridRows;
  final left  = gridMargin + col * cellW;
  final top   = gridTop   + row * cellH;
  return Rect.fromLTWH(left, top, cellW, cellH);
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-attack charge vignette — red glow emanating from eye before beam fires
// ─────────────────────────────────────────────────────────────────────────────

class _ChargeVignettePainter extends CustomPainter {
  final Offset eyeCenter;
  final double chargeProgress; // 0→1 (uses eyePulse for oscillation)
  const _ChargeVignettePainter({required this.eyeCenter, required this.chargeProgress});

  @override
  void paint(Canvas canvas, Size size) {
    // Expanding charge rings from the eye
    for (int r = 0; r < 4; r++) {
      final rPhase = ((chargeProgress + r * 0.25) % 1.0);
      final radius = 16.0 + rPhase * 48.0;
      final alpha  = (1.0 - rPhase) * 0.55;
      canvas.drawCircle(eyeCenter, radius, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 - rPhase * 1.5
        ..color = _kEyeRed.withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    // Core charge glow
    canvas.drawCircle(eyeCenter, 22 + chargeProgress * 10, Paint()
      ..color = _kEyeRed.withOpacity(0.18 + chargeProgress * 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
  }

  @override bool shouldRepaint(_ChargeVignettePainter o) =>
      o.chargeProgress != chargeProgress || o.eyeCenter != eyeCenter;
}

// ─────────────────────────────────────────────────────────────────────────────
// Laser Beam — boss eye to targeted cell  (professional multi-layer beam)
// ─────────────────────────────────────────────────────────────────────────────

class _LaserBeamPainter extends CustomPainter {
  final Offset eyeCenter;       // actual eye position on screen
  final Rect   toRect;          // targeted cell rect
  final double flickerVal;      // 0→1 fast oscillation for flicker
  final double buildupProgress; // 0→1 beam buildup animation
  final int    secsLeft;

  const _LaserBeamPainter({
    required this.eyeCenter,
    required this.toRect,
    required this.flickerVal,
    required this.buildupProgress,
    required this.secsLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellPos = toRect.center;

    // How far the beam has traveled (0=not fired, 1=full beam at target)
    final beamReach = buildupProgress < 0.35
        ? 0.0
        : Curves.easeOutCubic.transform((buildupProgress - 0.35) / 0.65);

    final dist = (cellPos - eyeCenter).distance;
    if (dist < 4) return;

    final beamEnd = Offset.lerp(eyeCenter, cellPos, beamReach)!;
    final beamDist = (beamEnd - eyeCenter).distance;

    // ── 1. Screen red vignette while beam is active ───────────────────────
    if (buildupProgress > 0.2) {
      final vAlpha = ((buildupProgress - 0.2) / 0.8).clamp(0.0, 1.0) * 0.07;
      final gradient = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.6,
        colors: [
          _kEyeRed.withOpacity(0),
          _kEyeRed.withOpacity(vAlpha),
        ],
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    // ── 2. Eye charge rings (before beam fully extends) ───────────────────
    if (buildupProgress < 0.6) {
      final chargeT = buildupProgress / 0.6;
      for (int r = 0; r < 3; r++) {
        final rProg = ((chargeT * 3.0) - r).clamp(0.0, 1.0);
        if (rProg <= 0.01) continue;
        final ringR  = 10.0 + rProg * 55.0 * (1.0 - chargeT);
        final alpha  = rProg * (1.0 - rProg) * 1.8 * 0.9;
        if (alpha < 0.01) continue;
        canvas.drawCircle(eyeCenter, ringR.clamp(2.0, 80.0), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 - r * 0.8
          ..color = _kEyeRed.withOpacity(alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      }
    }

    if (beamDist < 3) return; // beam hasn't started extending yet

    // ── 3. Outer atmospheric glow (very wide, very soft) ──────────────────
    canvas.drawLine(eyeCenter, beamEnd, Paint()
      ..color = _kEyeRed.withOpacity((0.12 + flickerVal * 0.06).clamp(0, 1))
      ..strokeWidth = 42
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));

    // ── 4. Mid glow beam ──────────────────────────────────────────────────
    canvas.drawLine(eyeCenter, beamEnd, Paint()
      ..color = _kEyeRed.withOpacity((0.52 + flickerVal * 0.18).clamp(0, 1))
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // ── 5. Core red beam ──────────────────────────────────────────────────
    canvas.drawLine(eyeCenter, beamEnd, Paint()
      ..color = _kEyeRed.withOpacity((0.88 + flickerVal * 0.12).clamp(0, 1))
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round);

    // ── 6. Orange-hot inner beam ──────────────────────────────────────────
    canvas.drawLine(eyeCenter, beamEnd, Paint()
      ..color = _kEyeOrange.withOpacity((0.75 + flickerVal * 0.25).clamp(0, 1))
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round);

    // ── 7. White-hot core ─────────────────────────────────────────────────
    canvas.drawLine(eyeCenter, beamEnd, Paint()
      ..color = Colors.white.withOpacity((0.70 + flickerVal * 0.30).clamp(0, 1))
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round);

    // ── 8. Plasma energy nodes flowing along beam ─────────────────────────
    if (beamReach > 0.12) {
      final rng = Random((flickerVal * 40).toInt());
      final stepCount = (beamDist / 28).clamp(3.0, 12.0).toInt();
      for (int i = 1; i <= stepCount; i++) {
        final t = i / (stepCount + 1).toDouble();
        if (t >= beamReach) break;
        final nodePos = Offset.lerp(eyeCenter, cellPos, t)!;
        // Random jitter perpendicular to beam
        final dx = -(cellPos.dy - eyeCenter.dy) / dist;
        final dy =  (cellPos.dx - eyeCenter.dx) / dist;
        final jitter = (rng.nextDouble() - 0.5) * 7.0;
        final jPos = nodePos + Offset(dx * jitter, dy * jitter);
        final nodeR = 3.0 + rng.nextDouble() * 4.0 + flickerVal * 2.0;
        // Node glow
        canvas.drawCircle(jPos, nodeR + 4, Paint()
          ..color = _kEyeRed.withOpacity(0.30 + flickerVal * 0.20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, nodeR * 0.8));
        // Node core
        canvas.drawCircle(jPos, nodeR, Paint()
          ..color = Colors.white.withOpacity(0.55 + flickerVal * 0.45));
        // Node inner
        canvas.drawCircle(jPos, nodeR * 0.45, Paint()
          ..color = _kEyeOrange.withOpacity(0.95));
      }
    }

    // ── 9. Impact zone at target ──────────────────────────────────────────
    if (beamReach > 0.80) {
      final impactFrac = ((beamReach - 0.80) / 0.20).clamp(0.0, 1.0);

      // Expanding shockwave rings
      for (int r = 0; r < 4; r++) {
        final rPhase = ((flickerVal * 2.0 + r * 0.25) % 1.0);
        final ringR  = (10.0 + rPhase * 30.0) * impactFrac;
        final ringA  = (1.0 - rPhase) * impactFrac * 0.9;
        if (ringA < 0.02) continue;
        canvas.drawCircle(cellPos, ringR, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.5 - rPhase * 1.5).clamp(0.5, 3.0)
          ..color = _kEyeRed.withOpacity(ringA.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }

      // Central impact glow
      canvas.drawCircle(cellPos, (22 + flickerVal * 10) * impactFrac, Paint()
        ..color = _kEyeRed.withOpacity(0.30 * impactFrac)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      canvas.drawCircle(cellPos, (8 + flickerVal * 4) * impactFrac, Paint()
        ..color = _kEyeOrange.withOpacity(0.85 * impactFrac)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(cellPos, 3.5 * impactFrac, Paint()
        ..color = Colors.white.withOpacity(0.95 * impactFrac));

      // Radial spark lines
      final rng2 = Random(77);
      for (int i = 0; i < 10; i++) {
        final angle   = i * (math.pi * 2 / 10) + flickerVal * math.pi * 0.5;
        final sparkLen = (12.0 + rng2.nextDouble() * 18.0 + flickerVal * 12.0) * impactFrac;
        final sparkEnd = cellPos + Offset(math.cos(angle) * sparkLen, math.sin(angle) * sparkLen);
        canvas.drawLine(cellPos, sparkEnd, Paint()
          ..color = (i.isEven ? _kEyeOrange : _kEyeRed).withOpacity(0.80 * impactFrac)
          ..strokeWidth = 1.8 + rng2.nextDouble() * 0.8
          ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override bool shouldRepaint(_LaserBeamPainter o) =>
      o.flickerVal != flickerVal || o.toRect != toRect || o.buildupProgress != buildupProgress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Crosshair widget on targeted cell
// ─────────────────────────────────────────────────────────────────────────────

class _CrosshairWidget extends StatelessWidget {
  final Rect   rect;
  final int    secsLeft;
  final double laserVal;
  const _CrosshairWidget({required this.rect, required this.secsLeft, required this.laserVal});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left:   rect.left  - 6,
      top:    rect.top   - 6,
      width:  rect.width + 12,
      height: rect.height + 12,
      child: IgnorePointer(
        child: Stack(alignment: Alignment.center, children: [
          // Pulsing red border + glow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _kEyeRed.withOpacity(0.6 + laserVal * 0.4), width: 2.5),
              boxShadow: [BoxShadow(
                color: _kEyeRed.withOpacity(0.4 + laserVal * 0.3),
                blurRadius: 14, spreadRadius: 2)],
            ),
          ),
          // Corner brackets
          CustomPaint(
            size: Size(rect.width + 12, rect.height + 12),
            painter: _CrosshairBracketPainter(0.6 + laserVal * 0.4),
          ),
        ]),
      ),
    );
  }
}

class _CrosshairBracketPainter extends CustomPainter {
  final double intensity;
  const _CrosshairBracketPainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 9.0;
    final cx = size.width / 2, cy = size.height / 2;
    final p  = Paint()..color = _kEyeRed.withOpacity(intensity)
      ..strokeWidth = 1.8..style = PaintingStyle.stroke;
    // Center cross
    canvas.drawLine(Offset(cx - 7, cy), Offset(cx + 7, cy), p);
    canvas.drawLine(Offset(cx, cy - 7), Offset(cx, cy + 7), p);
    // Corner L brackets
    for (final dx in [-1.0, 1.0]) {
      for (final dy in [-1.0, 1.0]) {
        final bx = cx + dx * (size.width / 2 - 4);
        final by = cy + dy * (size.height / 2 - 4);
        canvas.drawLine(Offset(bx, by), Offset(bx - dx * arm, by), p);
        canvas.drawLine(Offset(bx, by), Offset(bx, by - dy * arm), p);
      }
    }
  }

  @override bool shouldRepaint(_CrosshairBracketPainter o) => o.intensity != intensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hacked cell sparks
// ─────────────────────────────────────────────────────────────────────────────

class _HackedCells extends StatefulWidget {
  final NexusCoreController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _HackedCells({required this.controller, required this.getCellRect});
  @override State<_HackedCells> createState() => _HackedCellsState();
}
class _HackedCellsState extends State<_HackedCells> with SingleTickerProviderStateMixin {
  late final AnimationController _spark;
  @override void initState() {
    super.initState();
    _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..repeat();
    _spark.addListener(() { if (mounted) setState(() {}); });
  }
  @override void dispose() { _spark.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.hackedCells.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: widget.controller.hackedCells.map((cell) {
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
  }
}

class _HackSparkPainter extends CustomPainter {
  final double t;
  final int    seed;
  const _HackSparkPainter(this.t, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed + (t * 10).toInt());

    // Scanline glitches
    for (int i = 0; i < 5; i++) {
      final y  = rng.nextDouble() * size.height;
      final w  = 6 + rng.nextDouble() * (size.width - 10);
      final x  = rng.nextDouble() * (size.width - w);
      final op = 0.25 + rng.nextDouble() * 0.45;
      canvas.drawRect(Rect.fromLTWH(x, y, w, 2.2), Paint()
        ..color = _kHack.withOpacity(op));
    }
    // Spark dots
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        1.0 + rng.nextDouble() * 2.5,
        Paint()..color = _kEyeOrange.withOpacity(0.5 + rng.nextDouble() * 0.5));
    }
    // Red border flash
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = _kHack.withOpacity(0.4 + t * 0.4));
  }

  @override bool shouldRepaint(_HackSparkPainter o) => o.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// EMP Ring — stunned state
// ─────────────────────────────────────────────────────────────────────────────

class _EmpRingPainter extends CustomPainter {
  final double t;
  const _EmpRingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    for (int r = 0; r < 3; r++) {
      final rt  = ((t + r * 0.33) % 1.0);
      final rad = 55.0 + rt * 55.0;
      final op  = (1 - rt) * 0.55;
      canvas.drawCircle(Offset(cx, cy), rad, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 - rt * 1.5
        ..color = _kEMP.withOpacity(op)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
  }

  @override bool shouldRepaint(_EmpRingPainter o) => o.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Win Blast Painter
// ─────────────────────────────────────────────────────────────────────────────

class _WinBlastPainter extends CustomPainter {
  final double bossCY, bossX, quotaY, laserT, explodeT;
  const _WinBlastPainter({
    required this.bossCY, required this.bossX,
    required this.quotaY, required this.laserT, required this.explodeT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final from = Offset(bossX, quotaY);
    final to   = Offset(bossX, bossCY);

    // Golden laser (grows from quota toward boss)
    if (laserT > 0) {
      final end = Offset.lerp(from, to, Curves.easeIn.transform(laserT))!;
      canvas.drawLine(from, end, Paint()
        ..color = _kGold.withOpacity(0.3)
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawLine(from, end, Paint()
        ..color = _kGold
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round);
      canvas.drawLine(from, end, Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);
    }

    // Explosion burst
    if (explodeT > 0) {
      final rng = Random(99);
      final op  = (1 - explodeT).clamp(0.0, 1.0);
      for (int i = 0; i < 20; i++) {
        final a   = i * (math.pi * 2 / 20) + explodeT * 0.3;
        final len = 25 + explodeT * 70 + rng.nextDouble() * 20;
        canvas.drawLine(
          Offset(bossX + math.cos(a) * 8, bossCY + math.sin(a) * 8),
          Offset(bossX + math.cos(a) * len, bossCY + math.sin(a) * len),
          Paint()
            ..color = (i.isEven ? _kGold : Colors.orange).withOpacity(op)
            ..strokeWidth = 3.5 - explodeT * 2.5
            ..strokeCap = StrokeCap.round);
      }
      // Shockwave ring
      canvas.drawCircle(Offset(bossX, bossCY), 20 + explodeT * 90, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 - explodeT * 3
        ..color = Colors.white.withOpacity(op * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      // Flash
      canvas.drawCircle(Offset(bossX, bossCY), 50 * explodeT, Paint()
        ..color = Colors.white.withOpacity((1 - explodeT * 1.2).clamp(0, 0.8))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
      // Debris
      for (int i = 0; i < 14; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        final d = (20 + rng.nextDouble() * 60) * explodeT;
        canvas.drawCircle(
          Offset(bossX + math.cos(a) * d, bossCY + math.sin(a) * d),
          2 + rng.nextDouble() * 3.5,
          Paint()..color = (i.isEven ? Colors.orange : Colors.red).withOpacity(op));
      }
    }
  }

  @override bool shouldRepaint(_WinBlastPainter o) =>
      o.laserT != laserT || o.explodeT != explodeT;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hint Bar
// ─────────────────────────────────────────────────────────────────────────────

class _HintBar extends StatelessWidget {
  final NexusCoreController controller;
  const _HintBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final sz        = MediaQuery.of(context).size;
    final targeting = controller.isTargeting;
    final hint      = kNexusHints[controller.hintIndex % kNexusHints.length];
    return Positioned(
      top: sz.height * 0.097,
      left: 0, right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Container(
            key: ValueKey(targeting ? 'dodge' : controller.hintIndex),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: targeting
                  ? _kEyeRed.withOpacity(0.90)
                  : Colors.black.withOpacity(0.58),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: targeting ? _kEyeRed : Colors.white24, width: 1),
              boxShadow: targeting
                  ? [BoxShadow(color: _kEyeRed.withOpacity(0.4), blurRadius: 10)]
                  : [],
            ),
            child: Text(
              targeting ? '⚡ MERGE QUICK TO DODGE! ⚡' : '💡 $hint',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: targeting ? FontWeight.w900 : FontWeight.w500,
                letterSpacing: targeting ? 1.2 : 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _DialogueBubble extends StatelessWidget {
  final String text;
  final double bossCY;
  final double screenW;
  const _DialogueBubble({required this.text, required this.bossCY, required this.screenW});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top:   bossCY - 52,
      left:  screenW * 0.50,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(10),
            topRight:    Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border.all(color: _kEyeRed.withOpacity(0.65), width: 1),
          boxShadow: [BoxShadow(color: _kEyeRed.withOpacity(0.25), blurRadius: 8)],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 10,
              fontWeight: FontWeight.w600, letterSpacing: 0.4),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
