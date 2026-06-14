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
  Widget build(BuildContext context) => AnimatedBuilder(
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
  const _RobotBody({this.opacity = 1.0, this.scale = 1.0, this.glowOverlay});

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
                    _eyeLed(), _eyeLed(),
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
          Positioned(left: 0, top: 52, child: _arm(isLeft: true)),
          // ── RIGHT ARM ───────────────────────────────────────────────────
          Positioned(right: 0, top: 52, child: _arm(isLeft: false)),

          // ── LEFT LEG ────────────────────────────────────────────────────
          Positioned(left: 34, top: 137, child: _leg(isLeft: true)),
          // ── RIGHT LEG ───────────────────────────────────────────────────
          Positioned(right: 34, top: 137, child: _leg(isLeft: false)),

          if (glowOverlay != null) glowOverlay!,
        ]),
      ),
    ),
  );

  static Widget _eyeLed() => Container(
    width: 14, height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle, color: _kRed,
      boxShadow: [BoxShadow(color: _kRed.withOpacity(0.9), blurRadius: 8)],
    ),
  );

  static Widget _bolt() => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: _kLight),
  );

  static Widget _arm({required bool isLeft}) => _metalBox(
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

    _dimmerAlpha = Tween<double>(begin: 0.0, end: 0.55)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.5)));

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.88, 1.0)));
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

        // ONLINE title
        Opacity(opacity: _titleOpacity.value, child: Align(
          alignment: const Alignment(0, 0.68),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('ROBOT ONLINE', style: TextStyle(
              color: _kCyan, fontSize: 22, fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
              shadows: [Shadow(color: _kCyan, blurRadius: 20)],
            )),
            const SizedBox(height: 4),
            Text('LEVEL ${widget.ctrl.currentLevel} BOSS', style: const TextStyle(
              color: Colors.white60, fontSize: 12, letterSpacing: 2.5,
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
    with SingleTickerProviderStateMixin {
  late AnimationController _idle;
  @override
  void initState() {
    super.initState();
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }
  @override void dispose() { _idle.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final urgent = ctrl.secondsLeft <= 7;
    return AnimatedBuilder(
      animation: Listenable.merge([ctrl, _idle]),
      builder: (_, __) {
        final bobOffset = math.sin(_idle.value * math.pi) * 4.0;
        return Stack(children: [
          // Semi-dark overlay
          Container(color: Colors.black.withOpacity(0.38)),

          // ── Robot body (bobbing idle) ──
          Center(child: Transform.translate(
            offset: Offset(0, bobOffset - 20),
            child: _RobotBody(
              glowOverlay: urgent ? _UrgentGlow() : null,
            ),
          )),

          // ── Countdown badge ──
          Positioned(top: 54, right: 16, child: _CountdownBadge(ctrl: ctrl, urgent: urgent)),

          // ── Challenge bar ──
          Positioned(bottom: 90, left: 24, right: 24, child: _ChallengeMeter(ctrl: ctrl)),

          // ── Threat label ──
          Positioned(bottom: 60, left: 0, right: 0, child: Center(child: Text(
            'MERGE ${ctrl.mergesRequired - ctrl.mergesDone} MORE TO DEFEAT',
            style: TextStyle(
              color: urgent ? _kOrange : Colors.white70,
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.8,
              shadows: urgent ? [Shadow(color: _kOrange, blurRadius: 8)] : null,
            ),
          ))),
        ]);
      },
    );
  }
}

class _UrgentGlow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Positioned.fill(child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      boxShadow: [BoxShadow(color: _kRed.withOpacity(0.6), blurRadius: 30, spreadRadius: 8)],
    ),
  ));
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
// WIN EXPLOSION — L20 only: parts scatter dramatically
// ════════════════════════════════════════════════════════════════════════════
class _WinExplosionPhase extends StatefulWidget {
  @override State<_WinExplosionPhase> createState() => _WinExplosionPhaseState();
}
class _WinExplosionPhaseState extends State<_WinExplosionPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  final _rng = math.Random();

  // Each part gets a random exit velocity
  late final List<Offset> _velocities;
  late final List<double>  _rotations;

  late Animation<double> _flashOpacity;
  late Animation<double> _shockwave;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _velocities = List.generate(6, (_) => Offset(
      (_rng.nextDouble() - 0.5) * 14,
      (_rng.nextDouble() - 0.5) * 14 - 2,
    ));
    _rotations = List.generate(6, (_) => (_rng.nextDouble() - 0.5) * 8);

    _c = AnimationController(duration: const Duration(milliseconds: 2400), vsync: this)..forward();

    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 75),
    ]).animate(_c);

    _shockwave = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0.35, 0.6)));
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    const cx = 0.0; // center
    final partData = [
      // (name, startLeft, startTop, width, height)
      ('head',   55.0,  0.0,  62.0, 52.0),
      ('torso',  30.0, 52.0, 110.0, 85.0),
      ('larm',    0.0, 52.0,  30.0, 82.0),
      ('rarm',  140.0, 52.0,  30.0, 82.0),
      ('lleg',   34.0,137.0,  34.0, 78.0),
      ('rleg',  102.0,137.0,  34.0, 78.0),
    ];
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final partOpacity = (1.0 - ((t - 0.1) / 0.7)).clamp(0.0, 1.0);
        return Stack(children: [
          // Dark overlay
          Container(color: Colors.black.withOpacity((t * 0.7).clamp(0.0, 0.7))),

          // Shockwave ring
          Center(child: Opacity(
            opacity: (1.0 - _shockwave.value).clamp(0.0, 1.0),
            child: Container(
              width: 50 + _shockwave.value * sz.width,
              height: 50 + _shockwave.value * sz.width,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kOrange.withOpacity(0.8), width: 4),
                boxShadow: [BoxShadow(color: _kOrange.withOpacity(0.4), blurRadius: 30)],
              ),
            ),
          )),

          // Flying parts
          Center(child: Transform.translate(
            offset: Offset(0, 0),
            child: SizedBox(
              width: _kRW, height: _kRH,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(partData.length, (i) {
                  final p = partData[i];
                  final v = _velocities[i];
                  final fly = Curves.easeOut.transform(math.min(t * 2.5, 1.0));
                  return Positioned(
                    left: p.$2 + v.dx * fly * sz.width * 0.25,
                    top:  p.$3 + v.dy * fly * sz.height * 0.25,
                    child: Opacity(
                      opacity: partOpacity,
                      child: Transform.rotate(
                        angle: _rotations[i] * fly,
                        child: Container(
                          width: p.$4, height: p.$5,
                          decoration: BoxDecoration(
                            color: _kSteel,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kLight.withOpacity(0.4), width: 1),
                            boxShadow: [BoxShadow(color: _kOrange.withOpacity(0.6), blurRadius: 12)],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          )),

          // Flash
          IgnorePointer(child: Container(color: Colors.white.withOpacity(_flashOpacity.value))),

          // DESTROYED text
          Opacity(opacity: _textOpacity.value, child: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ROBOT DESTROYED!', style: TextStyle(
                color: _kOrange, fontSize: 28, fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [Shadow(color: _kOrange, blurRadius: 30), Shadow(color: Colors.red, blurRadius: 60)],
              )),
              const SizedBox(height: 8),
              Text('SYSTEM PERMANENTLY SECURED', style: const TextStyle(
                color: Colors.white54, fontSize: 11, letterSpacing: 3,
              )),
            ],
          ))),
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
