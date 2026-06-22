// ============================================================
// robot_overlay.dart  —  AAA Robot Villain overlay
// Levels 13 / 15 / 17 / 20
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/robot_controller.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kSteel   = Color(0xFF546E7A);
const _kDark    = Color(0xFF263238);
const _kLight   = Color(0xFF90A4AE);
const _kCyan    = Color(0xFF00E5FF);
const _kRed     = Color(0xFFFF1744);
const _kOrange  = Color(0xFFFF6D00);
const _kYellow  = Color(0xFFFFD600);

// ── Public widget ────────────────────────────────────────────────────────────
class RobotOverlay extends StatelessWidget {
  final RobotController controller;
  const RobotOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        switch (controller.phase) {
          case RobotPhase.idle:         return const SizedBox.shrink();
          case RobotPhase.assemblyEntry:return _AssemblyEntryPhase(ctrl: controller);
          case RobotPhase.active:       return _ActivePhase(ctrl: controller);
          case RobotPhase.winDissolve:  return _WinDissolvePhase(ctrl: controller);
          case RobotPhase.winExplosion: return _WinExplosionPhase();
          case RobotPhase.loss:         return const _LossPhase();
        }
      },
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ROBOT BODY WIDGET  — composed of 6 metallic parts
// ════════════════════════════════════════════════════════════════════════════
const _kRW = 170.0; // robot total width
const _kRH = 215.0; // robot total height

class _RobotBody extends StatelessWidget {
  final double opacity;
  final double scale;
  final Widget? glowOverlay;
  final double armSwing;   // radians — arms pivot by this angle
  final double eyeOpen;    // 1.0 = fully open, 0.0 = blinked shut
  const _RobotBody({this.opacity = 1.0, this.scale = 1.0, this.glowOverlay,
      this.armSwing = 0.0, this.eyeOpen = 1.0});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity.clamp(0.0, 1.0),
    child: Transform.scale(
      scale: scale,
      child: SizedBox(
        width: _kRW, height: _kRH,
        child: Stack(clipBehavior: Clip.none, children: [
          // ── HEAD ────────────────────────────────────────────────────────
          Positioned(left: 55, top: 0, child: _metalBox(
            w: 62, h: 52, r: 10,
            color: _kSteel,
            child: Stack(alignment: Alignment.center, children: [
              // Visor
              Positioned(top: 10, left: 6, child: Container(
                width: 50, height: 22,
                decoration: BoxDecoration(
                  color: _kDark,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kCyan.withOpacity(0.6), width: 1),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _eyeLed(eyeOpen), _eyeLed(eyeOpen),
                  ],
                ),
              )),
              // Antenna
              Positioned(top: -12, left: 25, child: Container(
                width: 4, height: 14,
                decoration: BoxDecoration(color: _kLight, borderRadius: BorderRadius.circular(2)),
              )),
              Positioned(top: -16, left: 23, child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: _kCyan, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.8), blurRadius: 6)]),
              )),
            ]),
          )),

          // ── TORSO ───────────────────────────────────────────────────────
          Positioned(left: 30, top: 52, child: _metalBox(
            w: 110, h: 85, r: 8,
            color: _kSteel,
            child: Stack(children: [
              // Center reactor
              Center(child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kDark,
                  border: Border.all(color: _kCyan, width: 2),
                  boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.7), blurRadius: 14, spreadRadius: 2)],
                ),
                child: Center(child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kCyan,
                    boxShadow: [BoxShadow(color: _kCyan, blurRadius: 8)],
                  ),
                )),
              )),
              // Panel bolts
              Positioned(top: 6, left: 6,   child: _bolt()),
              Positioned(top: 6, right: 6,  child: _bolt()),
              Positioned(bottom: 6, left: 6,  child: _bolt()),
              Positioned(bottom: 6, right: 6, child: _bolt()),
              // Danger stripes
              Positioned(bottom: 0, left: 0, right: 0, child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _kDark,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(children: List.generate(6, (_) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                    decoration: BoxDecoration(
                      color: _.isEven ? _kOrange : Colors.transparent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ))),
              )),
            ]),
          )),

          // ── LEFT ARM ────────────────────────────────────────────────────
          Positioned(left: 0, top: 52, child: _arm(isLeft: true,  swing:  armSwing)),
          // ── RIGHT ARM ───────────────────────────────────────────────────
          Positioned(right: 0, top: 52, child: _arm(isLeft: false, swing: -armSwing)),

          // ── LEFT LEG ────────────────────────────────────────────────────
          Positioned(left: 34, top: 137, child: _leg(isLeft: true)),
          // ── RIGHT LEG ───────────────────────────────────────────────────
          Positioned(right: 34, top: 137, child: _leg(isLeft: false)),

          if (glowOverlay != null) glowOverlay!,
        ]),
      ),
    ),
  );

  static Widget _eyeLed([double eyeOpen = 1.0]) => Transform.scale(
    scaleY: eyeOpen.clamp(0.08, 1.0),
    child: Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: _kRed,
        boxShadow: [BoxShadow(color: _kRed.withOpacity(0.9 * eyeOpen), blurRadius: 8)],
      ),
    ),
  );

  static Widget _bolt() => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: _kLight),
  );

  static Widget _arm({required bool isLeft, double swing = 0.0}) =>
    Transform.rotate(
      angle: swing,
      alignment: Alignment.topCenter,
      child: _metalBox(
        w: 30, h: 82, r: 7,
        color: _kDark,
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Container(width: 18, height: 18, decoration: BoxDecoration(
            shape: BoxShape.circle, color: _kSteel,
            border: Border.all(color: _kLight, width: 1),
          )),
          Container(width: 22, height: 34, decoration: BoxDecoration(
            color: _kSteel, borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _kLight.withOpacity(0.4), width: 1),
          )),
          Container(width: 26, height: 18, decoration: BoxDecoration(
            color: _kLight, borderRadius: BorderRadius.circular(5),
          )),
        ]),
      ),
    );

  static Widget _leg({required bool isLeft}) => _metalBox(
    w: 34, h: 78, r: 6,
    color: _kDark,
    child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(height: 14, decoration: BoxDecoration(
        color: _kSteel, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      )),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(height: 36, decoration: BoxDecoration(
          color: _kSteel, borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _kLight.withOpacity(0.3), width: 1),
        )),
      ),
      Container(height: 16, decoration: BoxDecoration(
        color: _kLight, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        border: Border.all(color: _kCyan.withOpacity(0.5), width: 1),
      )),
    ]),
  );

  static Widget _metalBox({required double w, required double h, required double r,
      required Color color, required Widget child}) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: _kLight.withOpacity(0.35), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(2, 3)),
          BoxShadow(color: _kLight.withOpacity(0.08), blurRadius: 2, offset: const Offset(-1, -1)),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withOpacity(0.95), _kDark],
        ),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ASSEMBLY ENTRY — parts fly in from screen edges and snap together
// ════════════════════════════════════════════════════════════════════════════
class _AssemblyEntryPhase extends StatefulWidget {
  final RobotController ctrl;
  const _AssemblyEntryPhase({required this.ctrl});
  @override State<_AssemblyEntryPhase> createState() => _AssemblyEntryPhaseState();
}

class _AssemblyEntryPhaseState extends State<_AssemblyEntryPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  // Per-part slide animations (fractional translation)
  late Animation<Offset> _headSlide;
  late Animation<Offset> _torsoSlide;
  late Animation<Offset> _lArmSlide;
  late Animation<Offset> _rArmSlide;
  late Animation<Offset> _lLegSlide;
  late Animation<Offset> _rLegSlide;

  // Per-part scale punch on landing
  late Animation<double> _headScale, _torsoScale, _lArmScale, _rArmScale, _lLegScale, _rLegScale;

  late Animation<double> _assemblyFlash;  // white flash when all parts land
  late Animation<double> _dimmerAlpha;    // background darkens as parts arrive
  late Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: kRobotAssemblyMs),
      vsync: this,
    )..forward();

    // ── Slides ──────────────────────────────────────────────────────────────
    _torsoSlide = Tween<Offset>(begin: const Offset(4, -4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0.00, 0.60, curve: Curves.easeOutExpo)));

    _lArmSlide = Tween<Offset>(begin: const Offset(-7, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0.08, 0.65, curve: Curves.easeOutBack)));

    _rArmSlide = Tween<Offset>(begin: const Offset(7, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0.08, 0.65, curve: Curves.easeOutBack)));

    _lLegSlide = Tween<Offset>(begin: const Offset(-4, 7), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0.15, 0.72, curve: Curves.easeOutCubic)));

    _rLegSlide = Tween<Offset>(begin: const Offset(4, 7), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0.15, 0.72, curve: Curves.easeOutCubic)));

    _headSlide = Tween<Offset>(begin: const Offset(0, -9), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0.28, 0.82, curve: Curves.easeOutBack)));

    // ── Scale punch (lands at 1.25 then springs to 1.0) ─────────────────────
    _torsoScale = _punchScale(0.00, 0.65);
    _lArmScale  = _punchScale(0.08, 0.70);
    _rArmScale  = _punchScale(0.08, 0.70);
    _lLegScale  = _punchScale(0.15, 0.75);
    _rLegScale  = _punchScale(0.15, 0.75);
    _headScale  = _punchScale(0.28, 0.85);

    // ── Assembly impact flash ─────────────────────────────────────────────
    _assemblyFlash = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.75), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 0.0), weight: 16),
    ]).animate(_c);

    _dimmerAlpha = Tween<double>(begin: 0.0, end: 0.70)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.4)));

    // "THREAT DETECTED" flashes at the very start, then fades before assembly
    _titleOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
    ]).animate(_c);
  }

  Animation<double> _punchScale(double start, double end) => TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.6), weight: start * 100),
    TweenSequenceItem(
      tween: Tween(begin: 0.6, end: 1.25).chain(CurveTween(curve: Curves.easeOut)),
      weight: (end - start) * 100,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: (1.0 - end) * 100 == 0 ? 0.1 : (1.0 - end) * 100,
    ),
  ]).animate(_c);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(children: [
        // Dark background
        Container(color: Colors.black.withOpacity(_dimmerAlpha.value * 0.7)),

        // Scan-lines for cyberpunk feel
        IgnorePointer(child: CustomPaint(
          size: sz,
          painter: _ScanLinePainter(progress: _c.value),
        )),

        // ── Body parts assembled at center ──────────────────────────────
        Center(child: SizedBox(
          width: _kRW, height: _kRH,
          child: Stack(clipBehavior: Clip.none, children: [
            // TORSO
            Positioned(left: 30, top: 52, child: FractionalTranslation(
              translation: _torsoSlide.value,
              child: Transform.scale(scale: _torsoScale.value, child: _RobotBody._metalBox(
                w: 110, h: 85, r: 8, color: _kSteel,
                child: Stack(children: [
                  Center(child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _kDark,
                      border: Border.all(color: _kCyan, width: 2),
                      boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.7), blurRadius: 14, spreadRadius: 2)],
                    ),
                    child: Center(child: Container(width: 16, height: 16,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _kCyan,
                        boxShadow: [BoxShadow(color: _kCyan, blurRadius: 8)]),
                    )),
                  )),
                  Positioned(top: 6,   left: 6,   child: _RobotBody._bolt()),
                  Positioned(top: 6,   right: 6,  child: _RobotBody._bolt()),
                  Positioned(bottom: 6, left: 6,  child: _RobotBody._bolt()),
                  Positioned(bottom: 6, right: 6, child: _RobotBody._bolt()),
                ]),
              )),
            )),
            // LEFT ARM
            Positioned(left: 0, top: 52, child: FractionalTranslation(
              translation: _lArmSlide.value,
              child: Transform.scale(scale: _lArmScale.value, child: _RobotBody._arm(isLeft: true)),
            )),
            // RIGHT ARM
            Positioned(right: 0, top: 52, child: FractionalTranslation(
              translation: _rArmSlide.value,
              child: Transform.scale(scale: _rArmScale.value, child: _RobotBody._arm(isLeft: false)),
            )),
            // LEFT LEG
            Positioned(left: 34, top: 137, child: FractionalTranslation(
              translation: _lLegSlide.value,
              child: Transform.scale(scale: _lLegScale.value, child: _RobotBody._leg(isLeft: true)),
            )),
            // RIGHT LEG
            Positioned(right: 34, top: 137, child: FractionalTranslation(
              translation: _rLegSlide.value,
              child: Transform.scale(scale: _rLegScale.value, child: _RobotBody._leg(isLeft: false)),
            )),
            // HEAD (last — most dramatic)
            Positioned(left: 55, top: 0, child: FractionalTranslation(
              translation: _headSlide.value,
              child: Transform.scale(scale: _headScale.value, child: _RobotBody._metalBox(
                w: 62, h: 52, r: 10, color: _kSteel,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned(top: 10, left: 6, child: Container(
                    width: 50, height: 22,
                    decoration: BoxDecoration(color: _kDark, borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _kCyan.withOpacity(0.6), width: 1)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [_RobotBody._eyeLed(), _RobotBody._eyeLed()]),
                  )),
                  Positioned(top: -12, left: 25, child: Container(width: 4, height: 14,
                    decoration: BoxDecoration(color: _kLight, borderRadius: BorderRadius.circular(2)))),
                  Positioned(top: -16, left: 23, child: Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: _kCyan, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.8), blurRadius: 6)]))),
                ]),
              )),
            )),
          ]),
        )),

        // Assembly FLASH
        IgnorePointer(child: Container(
          color: Colors.white.withOpacity(_assemblyFlash.value),
        )),

        // ── Intro text: "⚠ THREAT DETECTED" at start, "ROBOT ONLINE" at end ──
        Opacity(opacity: _titleOpacity.value, child: Center(child:
          _c.value < 0.80
          // Phase 1: THREAT DETECTED (start of animation)
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kRed, width: 2),
                  boxShadow: [BoxShadow(color: _kRed.withOpacity(0.6), blurRadius: 24)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('⚠  THREAT DETECTED  ⚠', style: TextStyle(
                    color: _kRed, fontSize: 18, fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    shadows: [Shadow(color: _kRed, blurRadius: 16)],
                  )),
                  const SizedBox(height: 6),
                  Text('ROBOT BOSS — LEVEL ${widget.ctrl.currentLevel}', style: const TextStyle(
                    color: Colors.white70, fontSize: 11, letterSpacing: 2.2,
                  )),
                  const SizedBox(height: 10),
                  Text(
                    'MERGE  ${widget.ctrl.mergesRequired}  ITEMS  TO  DEFEAT',
                    style: TextStyle(
                      color: _kYellow, fontSize: 13, fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      shadows: [Shadow(color: _kYellow, blurRadius: 10)],
                    ),
                  ),
                ]),
              ),
            ])
          // Phase 2: ROBOT ONLINE (end of animation)
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Text('ROBOT  ONLINE', style: TextStyle(
                color: _kCyan, fontSize: 22, fontWeight: FontWeight.w900,
                letterSpacing: 3.5,
                shadows: [Shadow(color: _kCyan, blurRadius: 20)],
              )),
              const SizedBox(height: 4),
              Text('WATCH THE TOP RIGHT →', style: TextStyle(
                color: Colors.white54, fontSize: 11, letterSpacing: 2,
              )),
            ]),
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ACTIVE PHASE — robot + countdown + challenge progress
// ════════════════════════════════════════════════════════════════════════════
class _ActivePhase extends StatefulWidget {
  final RobotController ctrl;
  const _ActivePhase({required this.ctrl});
  @override State<_ActivePhase> createState() => _ActivePhaseState();
}
class _ActivePhaseState extends State<_ActivePhase>
    with TickerProviderStateMixin {
  late AnimationController _idle;
  late AnimationController _armAnim;
  late AnimationController _blinkAnim;
  late AnimationController _hurtAnim;   // triggers on each merge hit
  int _prevMergesDone = 0;

  @override
  void initState() {
    super.initState();
    _idle      = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))
      ..repeat(reverse: true);
    _armAnim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1350))
      ..repeat(reverse: true);
    _blinkAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _hurtAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _scheduleBlink();
    widget.ctrl.addListener(_onCtrlChange);
  }

  void _onCtrlChange() {
    if (widget.ctrl.mergesDone > _prevMergesDone) {
      _prevMergesDone = widget.ctrl.mergesDone;
      _hurtAnim.forward(from: 0.0);
    }
  }

  void _scheduleBlink() {
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (!mounted) return;
      _blinkAnim.forward().then((_) {
        if (!mounted) return;
        _blinkAnim.reverse().then((_) { if (mounted) _scheduleBlink(); });
      });
    });
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChange);
    _idle.dispose(); _armAnim.dispose(); _blinkAnim.dispose(); _hurtAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    return AnimatedBuilder(
      animation: Listenable.merge([ctrl, _idle, _armAnim, _blinkAnim, _hurtAnim]),
      builder: (_, __) {
        final bobOffset = math.sin(_idle.value * math.pi) * 3.0;
        final armSwing  = math.sin(_armAnim.value * math.pi) * 0.18;
        final eyeOpen   = 1.0 - _blinkAnim.value;

        // Health colour: cyan (full HP) → yellow → red (almost dead)
        final hp = 1.0 - ctrl.mergeProgress;
        final hpColor = hp > 0.5
            ? Color.lerp(_kYellow, _kCyan, (hp - 0.5) * 2)!
            : Color.lerp(_kRed,    _kYellow, hp * 2)!;

        // Hurt flash: white burst then fades
        final hurtT = _hurtAnim.value;
        final hurtFlash = hurtT > 0
            ? (hurtT < 0.25 ? hurtT / 0.25 : (1.0 - hurtT) / 0.75).clamp(0.0, 1.0) * 0.55
            : 0.0;
        // Hurt shake: fast left-right
        final shakeX = hurtT > 0
            ? math.sin(hurtT * math.pi * 7) * 4.0 * (1 - hurtT)
            : 0.0;

        return Stack(children: [
          Positioned(
            top: 100, right: 4,
            child: Transform.translate(
              offset: Offset(shakeX, bobOffset),
              child: _BossHudPanel(
                ctrl:      ctrl,
                hpColor:   hpColor,
                hurtFlash: hurtFlash,
                armSwing:  armSwing,
                eyeOpen:   eyeOpen,
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ── Boss HUD Panel ────────────────────────────────────────────────────────────
// AAA-style: designed UI card, not a floating sticker
class _BossHudPanel extends StatelessWidget {
  final RobotController ctrl;
  final Color  hpColor;
  final double hurtFlash;
  final double armSwing;
  final double eyeOpen;
  const _BossHudPanel({
    required this.ctrl, required this.hpColor, required this.hurtFlash,
    required this.armSwing, required this.eyeOpen,
  });

  @override
  Widget build(BuildContext context) {
    const panelW = 112.0;
    final robotH  = _kRH * 0.54;   // robot display height inside panel
    final remaining = ctrl.mergesRequired - ctrl.mergesDone;

    return Container(
      width: panelW,
      decoration: BoxDecoration(
        color: const Color(0xFF08101C).withOpacity(0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hpColor.withOpacity(0.75), width: 1.5),
        boxShadow: [BoxShadow(color: hpColor.withOpacity(0.18), blurRadius: 10)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // ── Header bar ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(7, 5, 7, 4),
          decoration: BoxDecoration(
            color: hpColor.withOpacity(0.10),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            border: Border(bottom: BorderSide(color: hpColor.withOpacity(0.30), width: 1)),
          ),
          child: Row(children: [
            Text('⚡', style: TextStyle(fontSize: 9, color: hpColor)),
            const SizedBox(width: 3),
            Expanded(child: Text(
              'BOSS · L${ctrl.currentLevel}',
              style: TextStyle(color: hpColor, fontSize: 8,
                  fontWeight: FontWeight.w900, letterSpacing: 1.4),
            )),
            // Remaining merges counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: hpColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: hpColor.withOpacity(0.5), width: 0.8),
              ),
              child: Text(
                '$remaining left',
                style: TextStyle(color: hpColor, fontSize: 8, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
        ),

        // ── HP bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('HP', style: TextStyle(color: Colors.white38, fontSize: 7,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
              const Spacer(),
              Text('${ctrl.mergesDone}/${ctrl.mergesRequired}',
                style: TextStyle(color: hpColor, fontSize: 7, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (1.0 - ctrl.mergeProgress).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(hpColor),
              ),
            ),
          ]),
        ),

        // ── Robot body with hurt-flash overlay ──────────────────────────
        SizedBox(
          width: panelW,
          height: robotH,
          child: Stack(children: [
            // Corner targeting brackets (AAA HUD feel)
            Positioned(top: 4, left: 6, child: _bracket(hpColor, true,  true)),
            Positioned(top: 4, right: 6, child: _bracket(hpColor, true,  false)),
            Positioned(bottom: 4, left: 6, child: _bracket(hpColor, false, true)),
            Positioned(bottom: 4, right: 6, child: _bracket(hpColor, false, false)),

            // Robot
            Positioned.fill(child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _kRW, height: _kRH,
                child: _RobotBody(armSwing: armSwing, eyeOpen: eyeOpen),
              ),
            )),

            // Hurt white flash overlay
            if (hurtFlash > 0.01)
              Positioned.fill(child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(hurtFlash),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                ),
              )),
          ]),
        ),
      ]),
    );
  }

  // Corner bracket — mimics targeting reticle in AAA games
  static Widget _bracket(Color color, bool isTop, bool isLeft) {
    const len = 8.0; const thick = 1.5;
    return SizedBox(width: len + thick, height: len + thick,
      child: CustomPaint(painter: _BracketPainter(color, isTop, isLeft, len, thick)),
    );
  }
}

// Corner bracket painter — gives the boss panel an AAA targeting-reticle look
class _BracketPainter extends CustomPainter {
  final Color  color;
  final bool   isTop, isLeft;
  final double len, thick;
  const _BracketPainter(this.color, this.isTop, this.isLeft, this.len, this.thick);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thick..style = PaintingStyle.stroke;
    final x = isLeft  ? 0.0 : size.width;
    final y = isTop   ? 0.0 : size.height;
    final dx = isLeft ?  len : -len;
    final dy = isTop  ?  len : -len;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint); // horizontal
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint); // vertical
  }

  @override bool shouldRepaint(_BracketPainter o) => o.color != color;
}

class _UrgentGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Positioned.fill(child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(color: _kRed.withOpacity(0.28), blurRadius: 5, spreadRadius: 1),
        BoxShadow(color: _kOrange.withOpacity(0.12), blurRadius: 9),
      ],
    ),
  ));
}
class _RobotWarningBanner extends StatelessWidget {
  final RobotController ctrl;
  const _RobotWarningBanner({required this.ctrl});
  @override
  Widget build(BuildContext context) {
    final remaining = ctrl.mergesRequired - ctrl.mergesDone;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withOpacity(0.88),
        border: Border.all(color: _kRed.withOpacity(0.85), width: 1.5),
        boxShadow: [
          BoxShadow(color: _kRed.withOpacity(0.45), blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.18), shape: BoxShape.circle,
            border: Border.all(color: _kRed, width: 1.2),
          ),
          child: const Center(child: Text('⚡', style: TextStyle(fontSize: 14))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              remaining > 0 ? 'ROBOT THREAT — MERGE $remaining MORE TO DEFEAT' : 'ROBOT DEFEATED!',
              style: TextStyle(
                color: remaining > 0 ? Colors.white : Colors.greenAccent,
                fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ctrl.mergeProgress,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  ctrl.mergeProgress >= 1.0 ? Colors.greenAccent : _kRed,
                ),
              ),
            ),
          ],
        )),
        const SizedBox(width: 8),
        Text('${ctrl.mergesDone}/${ctrl.mergesRequired}',
          style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900,
          )),
      ]),
    );
  }
}


class _CountdownBadge extends StatelessWidget {
  final RobotController ctrl;
  final bool urgent;
  const _CountdownBadge({required this.ctrl, required this.urgent});
  @override
  Widget build(BuildContext context) => Container(
    width: 106, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _kDark.withOpacity(0.92),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: urgent ? _kRed : _kCyan, width: 1.8),
      boxShadow: [BoxShadow(color: (urgent ? _kRed : _kCyan).withOpacity(0.55), blurRadius: 18)],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${ctrl.secondsLeft}s', style: TextStyle(
        color: urgent ? _kRed : _kCyan, fontSize: 28, fontWeight: FontWeight.w900,
        shadows: [Shadow(color: urgent ? _kRed : _kCyan, blurRadius: 14)],
      )),
      Text('TIME LEFT', style: const TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 2)),
    ]),
  );
}

class _ChallengeMeter extends StatelessWidget {
  final RobotController ctrl;
  const _ChallengeMeter({required this.ctrl});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: ctrl.mergeProgress, minHeight: 14,
        backgroundColor: Colors.white.withOpacity(0.08),
        valueColor: AlwaysStoppedAnimation(
          ctrl.mergeProgress >= 1.0 ? Colors.greenAccent : _kCyan,
        ),
      ),
    ),
    const SizedBox(height: 5),
    Text('${ctrl.mergesDone} / ${ctrl.mergesRequired} MERGES', style: const TextStyle(
      color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4,
    )),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// WIN DISSOLVE — L13/15/17: robot shrinks and vanishes
// ════════════════════════════════════════════════════════════════════════════
class _WinDissolvePhase extends StatefulWidget {
  final RobotController ctrl;
  const _WinDissolvePhase({required this.ctrl});
  @override State<_WinDissolvePhase> createState() => _WinDissolvePhaseState();
}
class _WinDissolvePhaseState extends State<_WinDissolvePhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale, _opacity, _textOpacity;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this)..forward();
    _scale   = Tween<double>(begin: 1.0, end: 0.05)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.85, curve: Curves.easeInBack)));
    _opacity = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.6, 1.0)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.3, 0.7)));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Stack(children: [
      Container(color: Colors.black.withOpacity(0.35 * (1 - _c.value))),
      Center(child: _RobotBody(scale: _scale.value, opacity: _opacity.value)),
      Center(child: Opacity(opacity: _textOpacity.value, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 230),
          Text('SYSTEM DEFEATED', style: TextStyle(
            color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            shadows: [Shadow(color: Colors.greenAccent, blurRadius: 20)],
          )),
          const Text('ROBOT NEUTRALISED', style: TextStyle(
            color: Colors.white54, fontSize: 11, letterSpacing: 3,
          )),
        ],
      ))),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// WIN EXPLOSION — L20 only: AAA-style parts scatter in fixed dramatic directions
// Head flies UP-LEFT, Torso DOWN, Arms LEFT/RIGHT, Legs diagonal outward
// ════════════════════════════════════════════════════════════════════════════
class _WinExplosionPhase extends StatefulWidget {
  @override State<_WinExplosionPhase> createState() => _WinExplosionPhaseState();
}
class _WinExplosionPhaseState extends State<_WinExplosionPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  // Fixed dramatic exit directions for each part (dx, dy) — normalized
  static const _dirs = [
    Offset(-0.55, -1.0),  // head    → shoots UP-LEFT
    Offset( 0.10, -0.30), // torso   → arcs slightly UP then DOWN
    Offset(-1.00,  0.20), // l-arm   → FAR LEFT
    Offset( 1.00,  0.20), // r-arm   → FAR RIGHT
    Offset(-0.55,  1.00), // l-leg   → DOWN-LEFT
    Offset( 0.55,  1.00), // r-leg   → DOWN-RIGHT
  ];
  // Spin multipliers for each part
  static const _spins = [-3.2, 1.8, -2.5, 2.5, 1.4, -1.4];

  late Animation<double> _flash1, _flash2, _shockwave1, _shockwave2, _textOpacity, _textSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 3000), vsync: this)..forward();

    _flash1 = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 84),
    ]).animate(_c);

    _flash2 = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.60), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 0.60, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 77),
    ]).animate(_c);

    _shockwave1 = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.30, curve: Curves.easeOut)));

    _shockwave2 = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.08, 0.45, curve: Curves.easeOut)));

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.35, 0.55)));

    _textSlide = Tween<double>(begin: 30.0, end: 0.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.35, 0.55, curve: Curves.easeOut)));
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    // part: (startLeft, startTop, width, height, color)
    final parts = [
      (_kSteel,  55.0,   0.0, 62.0, 52.0),  // head
      (_kSteel,  30.0,  52.0, 110.0, 85.0), // torso
      (_kDark,    0.0,  52.0,  30.0, 82.0), // l-arm
      (_kDark,  140.0,  52.0,  30.0, 82.0), // r-arm
      (_kSteel,  34.0, 137.0,  34.0, 78.0), // l-leg
      (_kSteel, 102.0, 137.0,  34.0, 78.0), // r-leg
    ];

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t     = _c.value;
        // Parts fade out between 30%-90% of animation
        final pOp   = (1.0 - ((t - 0.30) / 0.60)).clamp(0.0, 1.0);
        // Fly progress: easeOut so parts shoot fast then decelerate
        final fly   = Curves.easeOut.transform(math.min(t * 2.2, 1.0));

        return Stack(children: [
          // ── Background darkens as explosion fades ──
          Container(color: Colors.black.withOpacity((t * 0.65).clamp(0.0, 0.65))),

          // ── Shockwave ring 1 (orange) ──
          Center(child: Opacity(
            opacity: (1.0 - _shockwave1.value).clamp(0.0, 1.0),
            child: Container(
              width:  40 + _shockwave1.value * sz.width * 1.4,
              height: 40 + _shockwave1.value * sz.width * 1.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kOrange.withOpacity(0.85), width: 5),
                boxShadow: [
                  BoxShadow(color: _kOrange.withOpacity(0.50), blurRadius: 40, spreadRadius: 10),
                ],
              ),
            ),
          )),

          // ── Shockwave ring 2 (red, slightly delayed, larger) ──
          Center(child: Opacity(
            opacity: (1.0 - _shockwave2.value).clamp(0.0, 1.0),
            child: Container(
              width:  20 + _shockwave2.value * sz.width * 1.8,
              height: 20 + _shockwave2.value * sz.width * 1.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kRed.withOpacity(0.65), width: 3),
                boxShadow: [
                  BoxShadow(color: _kRed.withOpacity(0.30), blurRadius: 50, spreadRadius: 8),
                ],
              ),
            ),
          )),

          // ── Flying parts (each with fixed direction + spin) ──
          Center(child: SizedBox(
            width: _kRW, height: _kRH,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(parts.length, (i) {
                final p  = parts[i];
                final d  = _dirs[i];
                final dx = d.dx * fly * sz.width  * 0.70;
                final dy = d.dy * fly * sz.height * 0.55;
                final angle = _spins[i] * fly;
                return Positioned(
                  left: p.$2 + dx,
                  top:  p.$3 + dy,
                  child: Opacity(
                    opacity: pOp,
                    child: Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: p.$4, height: p.$5,
                        decoration: BoxDecoration(
                          color: p.$1,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kLight.withOpacity(0.35), width: 1),
                          boxShadow: [
                            BoxShadow(color: _kOrange.withOpacity(0.70), blurRadius: 18, spreadRadius: 2),
                            BoxShadow(color: _kRed.withOpacity(0.40),    blurRadius: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          )),

          // ── White blast flash ──
          IgnorePointer(child: Container(
            color: Colors.white.withOpacity(_flash1.value),
          )),

          // ── Red secondary flash ──
          IgnorePointer(child: Container(
            color: _kRed.withOpacity(_flash2.value),
          )),

          // ── ROBOT DESTROYED text (slides up) ──
          Opacity(
            opacity: _textOpacity.value,
            child: Transform.translate(
              offset: Offset(0, _textSlide.value),
              child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💥 ROBOT OBLITERATED! 💥', style: TextStyle(
                    color: _kOrange,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    shadows: [
                      Shadow(color: _kOrange, blurRadius: 30),
                      Shadow(color: Colors.red, blurRadius: 60),
                      Shadow(color: Colors.yellow, blurRadius: 10),
                    ],
                  )),
                  const SizedBox(height: 10),
                  Text('SYSTEM PERMANENTLY DESTROYED', style: const TextStyle(
                    color: Colors.white70, fontSize: 11, letterSpacing: 3,
                  )),
                ],
              )),
            ),
          ),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOSS PHASE
// ════════════════════════════════════════════════════════════════════════════
class _LossPhase extends StatefulWidget {
  const _LossPhase();
  @override State<_LossPhase> createState() => _LossPhaseState();
}
class _LossPhaseState extends State<_LossPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _opacity;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 400), vsync: this)..forward();
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_c);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity,
    child: Container(
      color: Colors.red.withOpacity(0.72),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('⚡', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 12),
        const Text('SYSTEM BREACHED!', style: TextStyle(
          color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2,
          shadows: [Shadow(color: Colors.red, blurRadius: 24)],
        )),
        const SizedBox(height: 6),
        const Text('Robot overwhelmed the grid.', style: TextStyle(color: Colors.white70, fontSize: 15)),
      ])),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SCAN LINES PAINTER (cyberpunk background effect during entry)
// ════════════════════════════════════════════════════════════════════════════
class _ScanLinePainter extends CustomPainter {
  final double progress;
  const _ScanLinePainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _kCyan.withOpacity(0.04);
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), p);
    }
    // Moving bright scan line
    final scanY = (progress * size.height * 1.6 - size.height * 0.3).clamp(0.0, size.height);
    final scanPaint = Paint()
      ..color = _kCyan.withOpacity(0.18 * (1 - progress))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(Rect.fromLTWH(0, scanY - 3, size.width, 6), scanPaint);
  }
  @override bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}
