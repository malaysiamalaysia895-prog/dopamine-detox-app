// spaceship_boss_overlay.dart — Spaceship Alien Boss UI
// NEW: Dialogue bubble, HP pulse vignette, slow-mo flash,
//      L35 obstacle cell indicator, victory coin shower

import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/spaceship_boss_controller.dart';

class SpaceshipBossOverlay extends StatelessWidget {
  final SpaceshipBossController controller;
  final Rect? Function(int col, int row) getCellRect;
  final bool isDialogActive;
  const SpaceshipBossOverlay({
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
        final phase = controller.phase;
        if (phase == SpaceshipBossPhase.idle) return const SizedBox.shrink();
        if (isDialogActive) return const SizedBox.shrink();
        return Stack(children: [
          if (controller.isSlowMo)
            Positioned.fill(child: IgnorePointer(child: _SlowMoFlash(color: Colors.white))),
          if (phase == SpaceshipBossPhase.entry && !controller.entryComplete)
            _EntryAnimation(controller: controller, getCellRect: getCellRect),
          if (phase == SpaceshipBossPhase.active)
            _ActiveWidget(controller: controller, getCellRect: getCellRect),
          if (phase == SpaceshipBossPhase.active)
            _ThrowTimers(controller: controller, getCellRect: getCellRect),
          if (phase == SpaceshipBossPhase.active && controller.currentLevel == 35)
            _BlockedCells(controller: controller, getCellRect: getCellRect),
          if (controller.isLowHp && phase == SpaceshipBossPhase.active)
            const _LowHpVignette(),
          if (phase == SpaceshipBossPhase.winBlast)
            _WinBlast(level: controller.currentLevel),
        ]);
      },
    );
  }
}

// ── Slow-Mo Flash ──────────────────────────────────────────────────────────────

class _SlowMoFlash extends StatefulWidget {
  final Color color;
  const _SlowMoFlash({required this.color});
  @override State<_SlowMoFlash> createState() => _SlowMoFlashState();
}
class _SlowMoFlashState extends State<_SlowMoFlash> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => Container(color: widget.color.withOpacity((math.sin(_c.value * math.pi) * 0.6).clamp(0.0, 0.6))));
}

// ── Low HP Vignette ────────────────────────────────────────────────────────────

class _LowHpVignette extends StatefulWidget {
  const _LowHpVignette();
  @override State<_LowHpVignette> createState() => _LowHpVignetteState();
}
class _LowHpVignetteState extends State<_LowHpVignette> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
      center: Alignment.center, radius: 1.1,
      colors: [Colors.transparent, Colors.transparent,
        Colors.red.withOpacity(0.18 + _c.value * 0.18),
        Colors.red.withOpacity(0.40 + _c.value * 0.22)],
      stops: const [0.0, 0.45, 0.75, 1.0])))));
}

// ── Entry Animation ────────────────────────────────────────────────────────────

class _EntryAnimation extends StatefulWidget {
  final SpaceshipBossController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _EntryAnimation({required this.controller, required this.getCellRect});
  @override State<_EntryAnimation> createState() => _EntryAnimationState();
}
class _EntryAnimationState extends State<_EntryAnimation> with TickerProviderStateMixin {
  late AnimationController _main, _pulse, _particle, _rules, _land;
  late Animation<double> _scale;
  final _rng = Random();
  final List<_Ptcl> _pts = [];     // ambient trail particles
  final List<_Ptcl> _impactPts = []; // landing burst particles
  bool _landFired = false;

  @override
  void initState() {
    super.initState();
    // Main timeline: 3.8s cinematic
    _main     = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800));
    _pulse    = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _particle = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))..forward();
    _rules    = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    // Landing impact controller (fires once ship reaches grid)
    _land     = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));

    // Scale: fullscreen giant → dramatic shrink → settle at 1.0
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 4.6, end: 5.0), weight: 5),   // quick flash zoom-in
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 1.0), weight: 53),  // main descent shrink
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 8),  // bounce overshoot
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 34), // settle
    ]).animate(CurvedAnimation(parent: _main, curve: Curves.easeInOutCubic));

    // Trail particles — stream behind ship as it falls
    for (int i = 0; i < 80; i++) {
      _pts.add(_Ptcl(
        _rng.nextDouble() * math.pi * 2,
        0.10 + _rng.nextDouble() * 0.55,
        1.5 + _rng.nextDouble() * 5.5,
        [const Color(0xFFCC00FF), const Color(0xFF00DDFF), const Color(0xFFFF6600),
         const Color(0xFFFFEE00), const Color(0xFFFF00AA), Colors.white][_rng.nextInt(6)],
        _rng.nextDouble() * 0.45,
      ));
    }
    // Impact burst — explode outward from landing point
    for (int i = 0; i < 45; i++) {
      _impactPts.add(_Ptcl(
        _rng.nextDouble() * math.pi * 2,
        0.04 + _rng.nextDouble() * 0.28,
        2.5 + _rng.nextDouble() * 5,
        [const Color(0xFFCC00FF), const Color(0xFF00DDFF),
         Colors.white, const Color(0xFFFFEE00)][_rng.nextInt(4)],
        0.0,
      ));
    }

    // Trigger landing effects when ship reaches ~60% of descent
    _main.addListener(() {
      if (!_landFired && _main.value >= 0.58) {
        _landFired = true;
        _land.forward();
      }
    });
    _main.forward().then((_) { if (mounted) _rules.forward(); });
  }

  @override void dispose() {
    _main.dispose(); _pulse.dispose(); _particle.dispose();
    _rules.dispose(); _land.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz      = MediaQuery.of(context).size;
    final cellR   = widget.getCellRect(0, 0);
    final gridTop = cellR?.top ?? sz.height * 0.40;
    // Final resting position matches _ActiveWidget exactly (gridTop - 110)
    final targetY = (gridTop - 110).clamp(10.0, gridTop - 110);
    final cx      = sz.width / 2;
    const startY  = -200.0; // off-screen above

    return AnimatedBuilder(
      animation: Listenable.merge([_main, _pulse, _particle, _rules, _land]),
      builder: (_, __) {
        final t  = _main.value;
        final pt = _particle.value;
        final sc = _scale.value;

        // Smooth descent: 0→0.58 fall, 0.58→0.68 overshoot, 0.68→1.0 settle
        double by;
        if (t < 0.58) {
          by = startY + (targetY - startY) *
              Curves.easeOutCubic.transform(t / 0.58);
        } else if (t < 0.68) {
          by = targetY + 20.0 * ((t - 0.58) / 0.10); // bounce down
        } else {
          by = targetY + 20.0 *
              (1.0 - Curves.easeOut.transform((t - 0.68) / 0.32)); // settle
        }

        // "Kneeling" rotation: gentle sway during descent, rapid wobble on landing
        final wobble = _landFired
            ? (1.0 - _land.value) * math.sin(_land.value * math.pi * 5) * 0.22
            : math.sin(t * math.pi * 3) * 0.04 * (1.0 - t).clamp(0.0, 1.0);

        return Stack(children: [
          // Cinematic dark backdrop
          Positioned.fill(child: IgnorePointer(child: Container(
            color: Colors.black.withOpacity((t * 0.82).clamp(0.0, 0.82))))),

          // Phase-energy halo that tracks the ship during entry
          if (t < 0.62)
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, ((by / sz.height) * 2) - 1.0),
                radius: 0.45 + t * 0.35,
                colors: [
                  const Color(0xFFCC00FF).withOpacity(
                      (0.40 * (1.0 - t / 0.62)).clamp(0.0, 0.40)),
                  Colors.transparent,
                ],
              ))))),

          // Ambient trail particles streaming outward from ship path
          ..._pts.map((pk) {
            final pr = ((pt - pk.delay) / (1 - pk.delay)).clamp(0.0, 1.0);
            if (pr <= 0) return const SizedBox.shrink();
            final dx = cx + math.cos(pk.angle) * pr * sz.width  * 0.55 * pk.speed;
            final dy = by + math.sin(pk.angle) * pr * sz.height * 0.42 * pk.speed;
            final op = (1.0 - pr * pr).clamp(0.0, 1.0);
            return Positioned(left: dx - pk.size / 2, top: dy - pk.size / 2,
              child: IgnorePointer(child: Container(width: pk.size, height: pk.size,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: pk.color.withOpacity(op),
                  boxShadow: [BoxShadow(
                    color: pk.color.withOpacity(op * 0.6),
                    blurRadius: pk.size * 2.0)]))));
          }),

          // Landing shockwave ring — expands outward from grid landing point
          if (_landFired) (() {
            final lv  = _land.value;
            final rw  = 180.0 * lv;
            final rh  = 60.0  * lv;
            final op  = (1.0 - lv).clamp(0.0, 1.0);
            return Positioned(
              left: cx - rw / 2, top: targetY + 30 - rh / 2,
              child: IgnorePointer(child: Opacity(opacity: op,
                child: Container(width: rw, height: rh,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rh / 2),
                    border: Border.all(
                      color: const Color(0xFFCC00FF).withOpacity(op * 0.95),
                      width: 3))))));
          })(),

          // Impact burst particles exploding outward from landing spot
          if (_landFired)
            ..._impactPts.map((pk) {
              final lv = _land.value;
              final dx = cx + math.cos(pk.angle) * lv * 130 * pk.speed;
              final dy = targetY + 45 + math.sin(pk.angle) * lv * 55 * pk.speed;
              final op = (1.0 - lv).clamp(0.0, 1.0);
              return Positioned(left: dx - pk.size / 2, top: dy - pk.size / 2,
                child: IgnorePointer(child: Container(width: pk.size, height: pk.size,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: pk.color.withOpacity(op),
                    boxShadow: [BoxShadow(
                      color: pk.color.withOpacity(op * 0.55),
                      blurRadius: pk.size)]))));
            }),

          // The ship: rotates/"kneels" as it descends and touches down
          Positioned(left: cx - 55 * sc, top: by - 38 * sc,
            child: IgnorePointer(child:
              Transform.rotate(angle: wobble, alignment: Alignment.center,
                child: Transform.scale(scale: sc, alignment: Alignment.center,
                  child: _ShipWidget(
                    glow: 0.7 + _pulse.value * 0.3,
                    thruster: _pulse.value))))),

          // Rules card fades in once ship has landed
          if (_rules.value > 0.01)
            Positioned(bottom: sz.height * 0.08, left: 20, right: 20,
              child: FadeTransition(opacity: _rules,
                child: _RulesCard(level: widget.controller.currentLevel))),
        ]);
      },
    );
  }
}

// ── Active: Boss + HP bar + Dialogue ──────────────────────────────────────────

class _ActiveWidget extends StatefulWidget {
  final SpaceshipBossController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _ActiveWidget({required this.controller, required this.getCellRect});
  @override State<_ActiveWidget> createState() => _ActiveWidgetState();
}
class _ActiveWidgetState extends State<_ActiveWidget> with TickerProviderStateMixin {
  late AnimationController _pulse, _thruster, _orbit, _hpPulse, _dialogueAnim;
  String? _prevDialogue;
  @override
  void initState() {
    super.initState();
    _pulse       = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _thruster    = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..repeat(reverse: true);
    _orbit       = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _hpPulse     = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..repeat(reverse: true);
    _dialogueAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    widget.controller.addListener(_onChange);
  }
  void _onChange() {
    final d = widget.controller.dialogueText;
    if (d != _prevDialogue && d != null) { _prevDialogue = d; _dialogueAnim.forward(from: 0); }
  }
  @override void dispose() {
    widget.controller.removeListener(_onChange);
    _pulse.dispose(); _thruster.dispose(); _orbit.dispose(); _hpPulse.dispose(); _dialogueAnim.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final fc = widget.getCellRect(0, 0);
    final gridTop = fc?.top ?? sz.height * 0.40;
    final cx = sz.width / 2;
    final bossY = (gridTop - 110).clamp(10.0, gridTop - 110);
    final c = widget.controller;
    final isLow = c.isLowHp;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _thruster, _orbit, _hpPulse, _dialogueAnim]),
      builder: (_, __) {
        final orb = _orbit.value * math.pi * 2;
        final hpOp = isLow ? (0.5 + _hpPulse.value * 0.5) : 1.0;
        return Stack(children: [
          Positioned(left: 0, right: 0, top: bossY,
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [_ShipWidget(glow: 0.7 + _pulse.value * 0.3, thruster: _thruster.value)])),
          if (c.dialogueText != null)
            Positioned(top: bossY - 50, left: cx - 140, width: 280,
              child: ScaleTransition(scale: CurvedAnimation(parent: _dialogueAnim, curve: Curves.elasticOut),
                child: _DialogueBubble(text: c.dialogueText!, color: const Color(0xFFCC00FF)))),
          ...List.generate(8, (i) {
            final a = orb + i * math.pi / 4;
            return Positioned(left: cx + math.cos(a) * 52 - 4, top: bossY + 35 + math.sin(a) * 22 - 4,
              child: IgnorePointer(child: Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFCC00FF).withOpacity(0.7),
                  boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.5), blurRadius: 6)]))));
          }),
          Positioned(top: bossY + 78, left: 30, right: 30,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('🛸 ALIEN HP', style: TextStyle(
                  color: isLow ? Colors.red.withOpacity(hpOp) : const Color(0xFFCC00FF).withOpacity(0.9),
                  fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                Text('${c.mergesDone}/${c.mergesNeeded} MERGES',
                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: c.progressFraction, minHeight: isLow ? 10 : 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(isLow
                    ? Colors.red.withOpacity(hpOp)
                    : Color.lerp(const Color(0xFFFF0000), const Color(0xFF00FF88), c.progressFraction)!))),
              if (isLow)
                Padding(padding: const EdgeInsets.only(top: 2),
                  child: Text('⚠️ BOSS ENRAGED!', style: TextStyle(
                    color: Colors.red.withOpacity(hpOp), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
            ])),
        ]);
      },
    );
  }
}

// ── Throw Timers ───────────────────────────────────────────────────────────────

class _ThrowTimers extends StatefulWidget {
  final SpaceshipBossController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _ThrowTimers({required this.controller, required this.getCellRect});
  @override State<_ThrowTimers> createState() => _ThrowTimersState();
}
class _ThrowTimersState extends State<_ThrowTimers> with TickerProviderStateMixin {
  late AnimationController _flash, _spark;
  @override void initState() {
    super.initState();
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }
  @override void dispose() { _flash.dispose(); _spark.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: Listenable.merge([_flash, _spark]),
    builder: (_, __) => ListenableBuilder(listenable: widget.controller,
      builder: (_, __) => Stack(children: widget.controller.activeThrows.expand((t) {
        final r = widget.getCellRect(t.col, t.row);
        if (r == null) return const <Widget>[];
        final urgent = t.secondsLeft <= 3;
        final f = urgent ? _flash.value : 1.0;
        final c = urgent ? Colors.red : const Color(0xFFFF8800);
        return <Widget>[
          Positioned(left: r.left, top: r.top, width: r.width, height: r.height,
            child: IgnorePointer(child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.withOpacity(f * 0.9), width: 2.5),
                color: c.withOpacity(f * 0.18),
                boxShadow: [BoxShadow(color: c.withOpacity(f * 0.4), blurRadius: 10)]),
              child: Stack(alignment: Alignment.center, children: [
                const Positioned(top: 4, child: Text('🛸', style: TextStyle(fontSize: 16))),
                Positioned(bottom: 4, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                  child: Text('${t.secondsLeft}s', style: TextStyle(
                    color: urgent ? Colors.red : Colors.orange, fontSize: 10, fontWeight: FontWeight.w900)))),
              ])))),
          ..._crackleSparks(r.center, _spark.value, c, urgent),
        ];
      }).toList())));

  // Crackling energy sparks orbiting each threatened cell — makes the attack
  // feel more alive/dangerous, escalating as the timer runs out.
  List<Widget> _crackleSparks(Offset center, double t, Color color, bool urgent) {
    final count = urgent ? 6 : 4;
    final out = <Widget>[];
    for (int i = 0; i < count; i++) {
      final a = (i / count) * math.pi * 2 + t * math.pi * 2 * (urgent ? 1.6 : 1.0);
      final reach = 20 + math.sin(t * math.pi * 2 + i) * 6;
      final dx = center.dx + math.cos(a) * reach;
      final dy = center.dy + math.sin(a) * reach;
      const sz = 4.0;
      out.add(Positioned(left: dx - sz / 2, top: dy - sz / 2,
        child: IgnorePointer(child: Container(width: sz, height: sz,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.8),
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)])))));
    }
    return out;
  }
}

// ── L35 Blocked Cells ─────────────────────────────────────────────────────────

class _BlockedCells extends StatefulWidget {
  final SpaceshipBossController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _BlockedCells({required this.controller, required this.getCellRect});
  @override State<_BlockedCells> createState() => _BlockedCellsState();
}
class _BlockedCellsState extends State<_BlockedCells> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => ListenableBuilder(listenable: widget.controller,
      builder: (_, __) => Stack(children: widget.controller.blockedCells.map((b) {
        final r = widget.getCellRect(b.col, b.row);
        if (r == null) return const SizedBox.shrink();
        return Positioned(left: r.left, top: r.top, width: r.width, height: r.height,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF9B30FF).withOpacity(0.8 + _c.value * 0.2), width: 2.5),
              color: const Color(0xFF6600CC).withOpacity(0.22 + _c.value * 0.1),
              boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.4), blurRadius: 10)]),
            child: const Center(child: Text('🚫', style: TextStyle(fontSize: 20))))));
      }).toList())));
}

// ── Win Blast + Coin Shower ────────────────────────────────────────────────────

class _WinBlast extends StatefulWidget {
  final int level;
  const _WinBlast({required this.level});
  @override State<_WinBlast> createState() => _WinBlastState();
}
class _WinBlastState extends State<_WinBlast> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  final _rng = Random();
  final List<_Ptcl> _pts = [];
  final List<_Coin> _coins = [];
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))..forward();
    for (int i = 0; i < 70; i++) {
      _pts.add(_Ptcl(_rng.nextDouble() * math.pi * 2, 0.3 + _rng.nextDouble() * 0.7,
        3 + _rng.nextDouble() * 10,
        [const Color(0xFFFF4400), const Color(0xFFFF8800), const Color(0xFFFFEE00), const Color(0xFFCC00FF), Colors.white][_rng.nextInt(5)],
        _rng.nextDouble() * 0.3));
    }
    for (int i = 0; i < 55; i++) {
      _coins.add(_Coin(_rng.nextDouble(), 0.2 + _rng.nextDouble() * 0.6, 0.4 + _rng.nextDouble() * 0.6, 14 + _rng.nextDouble() * 10));
    }
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final cx = sz.width / 2; final cy = sz.height * 0.28;
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = _c.value;
      return Stack(children: [
        Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity((math.sin(t * math.pi) * 0.85).clamp(0.0, 0.85))))),
        if (t < 0.3) Positioned.fill(child: IgnorePointer(child: Container(color: Colors.white.withOpacity((1 - t / 0.3) * 0.7)))),
        ..._pts.map((p) {
          final pr = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final dx = cx + math.cos(p.angle) * pr * sz.width * 0.7 * p.speed;
          final dy = cy + math.sin(p.angle) * pr * sz.height * 0.9 * p.speed;
          final op = ((1 - pr) * (1 - pr)).clamp(0.0, 1.0);
          return Positioned(left: dx - p.size / 2, top: dy - p.size / 2,
            child: IgnorePointer(child: Container(width: p.size, height: p.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
                boxShadow: [BoxShadow(color: p.color.withOpacity(op * 0.5), blurRadius: p.size * 2)]))));
        }),
        ..._coins.map((c) {
          final pr = ((t - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final op = t > 0.85 ? ((1 - t) / 0.15).clamp(0.0, 1.0) : 1.0;
          return Positioned(left: c.x * sz.width - c.size / 2, top: pr * sz.height * 1.1 * c.speed - c.size / 2,
            child: IgnorePointer(child: Opacity(opacity: op, child: Text('💰', style: TextStyle(fontSize: c.size)))));
        }),
        if (t > 0.4)
          Positioned(top: sz.height * 0.38, left: 30, right: 30,
            child: Opacity(opacity: ((t - 0.4) / 0.4).clamp(0.0, 1.0),
              child: Column(children: [
                const Text('🛸 ALIEN DESTROYED! 💥', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFFFEE00), fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2,
                    shadows: [Shadow(color: Color(0xFFFF8800), blurRadius: 20)])),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6))),
                  child: const Text('+50 COINS BONUS! 💰',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900))),
              ]))),
      ]);
    });
  }
}

// ── Rules Card ─────────────────────────────────────────────────────────────────

class _RulesCard extends StatelessWidget {
  final int level;
  const _RulesCard({required this.level});
  @override
  Widget build(BuildContext context) {
    final n = kSpaceshipBossLevels[level] ?? 20;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A001A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.8), width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.4), blurRadius: 20)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🛸 LEVEL $level — SPACESHIP ALIEN', style: const TextStyle(color: Color(0xFFCC00FF),
          fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        _r('🛸', 'Every 10s: 5 mini-ships land on cells with 10s timers'),
        _r('🔧', 'Merge items → neutralize ships → earn +15 💰 each!'),
        _r('❌', 'Timer expires → item destroyed + −25 HP'),
        _r('🎯', 'Merge $n items total → Alien obliterated!'),
        if (level == 35) ...[
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.4))),
            child: const Text('⚠️ L35: Boss blocks 2 cells every 30s for 15s!',
              style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center)),
        ],
      ]));
  }
  Widget _r(String i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [Text(i, style: const TextStyle(fontSize: 14)), const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)))]));
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _DialogueBubble extends StatelessWidget {
  final String text; final Color color;
  const _DialogueBubble({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF0A0010).withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.9), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 16)]),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
    Positioned(bottom: -10, left: 0, right: 0,
      child: Center(child: CustomPaint(size: const Size(16, 10), painter: _TailPainter(color: color)))),
  ]);
}

class _TailPainter extends CustomPainter {
  final Color color; const _TailPainter({required this.color});
  @override void paint(Canvas canvas, Size size) {
    canvas.drawPath(Path()..moveTo(0,0)..lineTo(size.width,0)..lineTo(size.width/2,size.height)..close(),
      Paint()..color = color.withOpacity(0.9));
  }
  @override bool shouldRepaint(_) => false;
}

class _ShipWidget extends StatelessWidget {
  final double glow, thruster;
  const _ShipWidget({required this.glow, required this.thruster});
  @override
  Widget build(BuildContext context) => SizedBox(width: 110, height: 70,
    child: Stack(alignment: Alignment.center, children: [
      Container(width: 100, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(colors: [const Color(0xFF9B30FF).withOpacity(glow*0.8),
          const Color(0xFF3300AA).withOpacity(glow*0.5), Colors.transparent]),
        boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(glow*0.7), blurRadius: 24, spreadRadius: 4)])),
      Positioned(top: 2, child: Container(width: 48, height: 30,
        decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF00DDFF).withOpacity(0.9), const Color(0xFF0044AA).withOpacity(0.6)]),
          border: Border.all(color: const Color(0xFF00FFFF).withOpacity(0.8), width: 1.5)),
        child: const Center(child: Text('👾', style: TextStyle(fontSize: 18))))),
      Positioned(bottom: 8, child: Container(width: 90, height: 22,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(colors: [Color(0xFF6600CC), Color(0xFF9B30FF), Color(0xFF6600CC)]),
          border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.8), width: 1)))),
      Positioned(bottom: 0, child: Row(children: List.generate(3, (_) => Container(
        width: 14, height: 10 + thruster * 8, margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFFFF8800).withOpacity(0.9), const Color(0xFFFF4400).withOpacity(0.6), Colors.transparent])))))),
    ]));
}

class _Ptcl { final double angle, speed, size, delay; final Color color;
  const _Ptcl(this.angle, this.speed, this.size, this.color, this.delay); }
class _Coin { final double x, delay, speed, size;
  const _Coin(this.x, this.delay, this.speed, this.size); }
