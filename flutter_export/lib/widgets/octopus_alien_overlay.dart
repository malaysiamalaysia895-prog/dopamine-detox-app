// octopus_alien_overlay.dart — Octopus-Alien Hybrid Boss UI
// Level 36 — NEW: Dialogue bubble, shield golden aura,
// HP pulse vignette, slow-mo flash, victory coin shower

import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/octopus_alien_controller.dart';

class OctopusAlienOverlay extends StatelessWidget {
  final OctopusAlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  final bool isDialogActive;
  const OctopusAlienOverlay({super.key, required this.controller, required this.getCellRect, this.isDialogActive = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final p = controller.phase;
      if (p == OctopusAlienPhase.idle) return const SizedBox.shrink();
      if (isDialogActive) return const SizedBox.shrink();
      return Stack(children: [
        if (controller.isSlowMo) Positioned.fill(child: IgnorePointer(child: _Flash(color: const Color(0xFF00FF88)))),
        if (p == OctopusAlienPhase.alienEntry) _AlienEntry(controller: controller, getCellRect: getCellRect),
        if (p == OctopusAlienPhase.tentacleJoin) _TentacleJoin(controller: controller, getCellRect: getCellRect),
        if (p == OctopusAlienPhase.active) _ActivePhase(controller: controller, getCellRect: getCellRect),
        if (controller.isLowHp && p == OctopusAlienPhase.active) const _LowHpVignette(),
        if (p == OctopusAlienPhase.winBlast) const _WinBlast(),
      ]);
    });
  }
}

// ── Flash ──────────────────────────────────────────────────────────────────────
class _Flash extends StatefulWidget {
  final Color color; const _Flash({required this.color});
  @override State<_Flash> createState() => _FlashState();
}
class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => Container(color: widget.color.withOpacity((math.sin(_c.value * math.pi) * 0.5).clamp(0.0, 0.5))));
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
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
      center: Alignment.center, radius: 1.1,
      colors: [Colors.transparent, Colors.transparent, Colors.red.withOpacity(0.15 + _c.value * 0.15), Colors.red.withOpacity(0.38 + _c.value * 0.2)],
      stops: const [0.0, 0.45, 0.75, 1.0])))));
}

// ── Alien Body Entry ──────────────────────────────────────────────────────────
class _AlienEntry extends StatefulWidget {
  final OctopusAlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _AlienEntry({required this.controller, required this.getCellRect});
  @override State<_AlienEntry> createState() => _AlienEntryState();
}
class _AlienEntryState extends State<_AlienEntry> with TickerProviderStateMixin {
  late AnimationController _main, _pulse, _ptcl, _land;
  late Animation<double> _scale;
  final _rng = Random();
  final List<_P> _ps = [];
  final List<_P> _impactPs = [];
  bool _landFired = false;

  @override void initState() {
    super.initState();
    _main  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _ptcl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))..forward();
    _land  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    // Scale: giant fullscreen alien → elastic bounce settle
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 3.8, end: 4.2), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 4.2, end: 1.0), weight: 52),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 32),
    ]).animate(CurvedAnimation(parent: _main, curve: Curves.easeInOutCubic));

    for (int i = 0; i < 70; i++) {
      _ps.add(_P(_rng.nextDouble()*math.pi*2, 0.12+_rng.nextDouble()*0.52, 1.5+_rng.nextDouble()*6,
        [const Color(0xFF00FF88), const Color(0xFFCC00FF), const Color(0xFF00CCFF),
         Colors.white, const Color(0xFFFF8800), const Color(0xFF00FFCC)][_rng.nextInt(6)],
        _rng.nextDouble()*0.42));
    }
    for (int i = 0; i < 40; i++) {
      _impactPs.add(_P(_rng.nextDouble()*math.pi*2, 0.05+_rng.nextDouble()*0.25, 2+_rng.nextDouble()*5,
        [const Color(0xFF00FF88), const Color(0xFF00CCFF), Colors.white][_rng.nextInt(3)],
        0.0));
    }
    _main.addListener(() {
      if (!_landFired && _main.value >= 0.56) {
        _landFired = true;
        _land.forward();
      }
    });
    _main.forward();
  }
  @override void dispose() { _main.dispose(); _pulse.dispose(); _ptcl.dispose(); _land.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz      = MediaQuery.of(context).size;
    final cellR   = widget.getCellRect(0, 0);
    final gridTop = cellR?.top ?? sz.height * 0.40;
    final targetY = (gridTop - 130).clamp(8.0, gridTop - 130);
    final cx      = sz.width / 2;
    const startY  = -180.0;

    return AnimatedBuilder(animation: Listenable.merge([_main,_pulse,_ptcl,_land]), builder: (_, __) {
      final t  = _main.value;
      final pt = _ptcl.value;
      final sc = _scale.value;

      double by;
      if (t < 0.56) {
        by = startY + (targetY - startY) * Curves.easeOutCubic.transform(t / 0.56);
      } else if (t < 0.67) {
        by = targetY + 18.0 * ((t - 0.56) / 0.11);
      } else {
        by = targetY + 18.0 * (1.0 - Curves.easeOut.transform((t - 0.67) / 0.33));
      }

      // Elastic wobble on landing — alien "plops" into position
      final wobble = _landFired
          ? (1.0 - _land.value) * math.sin(_land.value * math.pi * 4) * 0.18
          : 0.0;

      return Stack(children: [
        Positioned.fill(child: IgnorePointer(child: Container(
          color: Colors.black.withOpacity((t*0.78).clamp(0.0,0.78))))),
        // Green energy aura around alien during approach
        if (t < 0.60)
          Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, ((by / sz.height) * 2) - 1.0),
              radius: 0.50 + t * 0.30,
              colors: [
                const Color(0xFF00FF88).withOpacity((0.30*(1.0-t/0.60)).clamp(0.0,0.30)),
                Colors.transparent]))))),
        // Ambient particles streaming from alien path
        ..._ps.map((p) {
          final pr = ((pt - p.delay)/(1-p.delay)).clamp(0.0,1.0); if (pr<=0) return const SizedBox.shrink();
          final dx = cx + math.cos(p.angle)*pr*sz.width*0.52*p.speed;
          final dy = by + math.sin(p.angle)*pr*sz.height*0.40*p.speed;
          final op = (1-pr*0.95).clamp(0.0,1.0);
          return Positioned(left: dx-p.size/2, top: dy-p.size/2, child: IgnorePointer(child: Container(width: p.size, height: p.size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
              boxShadow: [BoxShadow(color: p.color.withOpacity(op*0.55), blurRadius: p.size*1.8)]))));
        }),
        // Landing shockwave ring
        if (_landFired) (() {
          final lv = _land.value;
          final rw = 160.0 * lv; final rh = 50.0 * lv;
          final op = (1.0 - lv).clamp(0.0, 1.0);
          return Positioned(left: cx - rw/2, top: targetY + 40 - rh/2,
            child: IgnorePointer(child: Opacity(opacity: op, child: Container(width: rw, height: rh,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rh/2),
                border: Border.all(
                  color: const Color(0xFF00FF88).withOpacity(op*0.9), width: 3))))));
        })(),
        // Impact burst particles
        if (_landFired)
          ..._impactPs.map((p) {
            final lv = _land.value;
            final dx = cx + math.cos(p.angle)*lv*120*p.speed;
            final dy = targetY+48 + math.sin(p.angle)*lv*48*p.speed;
            final op = (1.0-lv).clamp(0.0,1.0);
            return Positioned(left: dx-p.size/2, top: dy-p.size/2, child: IgnorePointer(child: Container(width: p.size, height: p.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
                boxShadow: [BoxShadow(color: p.color.withOpacity(op*0.5), blurRadius: p.size)]))));
          }),
        // Alien body — rotates slightly on landing (wobble/plopping feel)
        Positioned(left: cx-55, top: by-50, child: IgnorePointer(child:
          Transform.rotate(angle: wobble, alignment: Alignment.center,
            child: Transform.scale(scale: sc, alignment: Alignment.center,
              child: _OctBody(glow: 0.7+_pulse.value*0.3, tentacles: false, wave: 0, shielded: false))))),
        if (t > 0.72)
          Positioned(bottom: 60, left: 20, right: 20, child: Opacity(opacity: ((t-0.72)/0.28).clamp(0.0,1.0),
            child: const _RulesCard())),
      ]);
    });
  }
}

// ── Tentacle Join ─────────────────────────────────────────────────────────────
class _TentacleJoin extends StatefulWidget {
  final OctopusAlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  const _TentacleJoin({required this.controller, required this.getCellRect});
  @override State<_TentacleJoin> createState() => _TentacleJoinState();
}
class _TentacleJoinState extends State<_TentacleJoin> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz      = MediaQuery.of(context).size;
    final cellR   = widget.getCellRect(0, 0);
    final gridTop = cellR?.top ?? sz.height * 0.40;
    // Must match _ActivePhase's by = (gridTop-130) for seamless phase transition
    final by      = (gridTop - 130).clamp(8.0, gridTop - 130);
    final cx      = sz.width/2;
    return AnimatedBuilder(animation: _c, builder: (_, __) => Stack(children: [
      Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity(0.65)))),
      Positioned(left: cx-55, top: by-50, child: IgnorePointer(child:
        _OctBody(glow: 0.8+_c.value*0.2, tentacles: true, wave: _c.value, shielded: false))),
      ...List.generate(8, (i) {
        final a = i*math.pi/4; final len = _c.value*90;
        return Positioned(left: cx+math.cos(a)*len-3, top: by+40+math.sin(a)*len-3,
          child: IgnorePointer(child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF00FF88).withOpacity(_c.value),
            boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.7), blurRadius: 10)]))));
      }),
    ]));
  }
}

// ── Active Phase ──────────────────────────────────────────────────────────────
class _ActivePhase extends StatefulWidget {
  final OctopusAlienController controller; final Rect? Function(int,int) getCellRect;
  const _ActivePhase({required this.controller, required this.getCellRect});
  @override State<_ActivePhase> createState() => _ActivePhaseState();
}
class _ActivePhaseState extends State<_ActivePhase> with TickerProviderStateMixin {
  late AnimationController _pulse, _wave, _tent, _hpP, _shld, _dlg;
  String? _prevDlg;
  @override void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _wave  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _tent  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _hpP   = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..repeat(reverse: true);
    _shld  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _dlg   = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    widget.controller.addListener(_onChange);
  }
  void _onChange() { final d = widget.controller.dialogueText; if (d != _prevDlg && d != null) { _prevDlg = d; _dlg.forward(from: 0); } }
  @override void dispose() { widget.controller.removeListener(_onChange); _pulse.dispose(); _wave.dispose(); _tent.dispose(); _hpP.dispose(); _shld.dispose(); _dlg.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final fc = widget.getCellRect(0,0); final gt = fc?.top ?? sz.height*0.40;
    final cx = sz.width/2; final by = (gt-130).clamp(8.0, gt-130);
    final c = widget.controller;
    final shielded = c.isShielded; final isLow = c.isLowHp;
    final glowCol = shielded ? const Color(0xFFFFD700) : const Color(0xFF00FF88);
    final strikes = c.activeTentacleStrikes;
    final isAttacking = strikes.isNotEmpty;

    return AnimatedBuilder(animation: Listenable.merge([_pulse,_wave,_tent,_hpP,_shld,_dlg]), builder: (_, __) {
      final hpOp = isLow ? (0.5 + _hpP.value * 0.5) : 1.0;
      final attackGlow = isAttacking ? (0.85 + _tent.value * 0.15) : (0.7 + _pulse.value * 0.3);
      return Stack(children: [
        Positioned(left: cx-55, top: by, child: IgnorePointer(child: _OctBody(glow: attackGlow, tentacles: true, wave: _wave.value, shielded: shielded, enraged: isAttacking))),
        // Shield aura
        if (shielded)
          Positioned(left: cx-75, top: by-20, child: IgnorePointer(child: Container(width: 150, height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6+_shld.value*0.4), width: 3),
              gradient: RadialGradient(colors: [Colors.transparent,
                const Color(0xFFFFD700).withOpacity(0.08+_shld.value*0.08),
                const Color(0xFFFFAA00).withOpacity(0.15+_shld.value*0.1)]),
              boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.35+_shld.value*0.25), blurRadius: 30, spreadRadius: 8)])))),
        // Dialogue bubble
        if (c.dialogueText != null)
          Positioned(top: by-50, left: cx-145, width: 290,
            child: ScaleTransition(scale: CurvedAnimation(parent: _dlg, curve: Curves.elasticOut),
              child: _DialogueBubble(text: c.dialogueText!, color: shielded ? const Color(0xFFFFD700) : const Color(0xFF00FF88)))),
        // HP bar
        Positioned(top: by+128, left: 30, right: 30, child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text('🐙 HP', style: TextStyle(color: isLow ? Colors.red.withOpacity(hpOp) : glowColor(shielded, isLow).withOpacity(0.9),
                fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              if (shielded) Container(margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.7))),
                child: const Text('🛡️ SHIELDED', style: TextStyle(color: Color(0xFFFFD700), fontSize: 8, fontWeight: FontWeight.w900))),
            ]),
            Text('${c.mergesDone}/${OctopusAlienController.mergesNeeded}',
              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 3),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: c.progressFraction, minHeight: isLow ? 10 : 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(isLow ? Colors.red.withOpacity(hpOp)
                : Color.lerp(glowCol, const Color(0xFFFF4400), 1 - c.progressFraction)!))),
        ])),
        // Tentacle strikes — one line + target box + spark burst per active target
        for (final s in strikes) ...() {
          final sr = widget.getCellRect(s.col, s.row);
          if (sr == null) return <Widget>[];
          return [
            ..._tentacleLine(Offset(cx, by+70), Offset(sr.center.dx, sr.center.dy), _tent.value),
            Positioned(left: sr.left, top: sr.top, width: sr.width, height: sr.height,
              child: IgnorePointer(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.9), width: 3),
                color: const Color(0xFF00FF44).withOpacity(0.2),
                boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.5), blurRadius: 12)])))),
            ..._impactSparks(sr.center, _tent.value),
          ];
        }(),
      ]);
    });
  }

  // Radiating spark particles around a strike's impact point — makes each
  // tentacle hit feel more dangerous/electric.
  List<Widget> _impactSparks(Offset center, double t) {
    const sparkCount = 6;
    final out = <Widget>[];
    for (int i = 0; i < sparkCount; i++) {
      final a = (i / sparkCount) * math.pi * 2 + t * math.pi * 2;
      final reach = 14 + t * 22;
      final dx = center.dx + math.cos(a) * reach;
      final dy = center.dy + math.sin(a) * reach;
      final op = (1 - ((t + i / sparkCount) % 1.0)).clamp(0.0, 1.0);
      const sz = 5.0;
      out.add(Positioned(left: dx - sz / 2, top: dy - sz / 2,
        child: IgnorePointer(child: Container(width: sz, height: sz,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF00FFAA).withOpacity(op * 0.9),
            boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withOpacity(op * 0.7), blurRadius: 8)])))));
    }
    return out;
  }

  Color glowColor(bool shielded, bool isLow) {
    if (isLow) return Colors.red;
    return shielded ? const Color(0xFFFFD700) : const Color(0xFF00FF88);
  }

  List<Widget> _tentacleLine(Offset start, Offset end, double progress) {
    if (progress < 0.05) return [];
    final segs = 14; final rng = Random(42); final out = <Widget>[];
    for (int i = 0; i < segs; i++) {
      final t0 = i/segs; final t1 = (i+1)/segs;
      if (t0 > progress) break;
      final p0 = Offset.lerp(start, end, t0)!; final p1 = Offset.lerp(start, end, t1.clamp(0.0, progress))!;
      final w = (rng.nextDouble()-0.5)*22*math.sin(t0*math.pi);
      final perp = Offset(-(end.dy-start.dy), end.dx-start.dx); final pLen = perp.distance;
      final pn = pLen > 0 ? Offset(perp.dx/pLen, perp.dy/pLen) : Offset.zero;
      final wp0 = Offset(p0.dx+pn.dx*w, p0.dy+pn.dy*w); final wp1 = Offset(p1.dx+pn.dx*w, p1.dy+pn.dy*w);
      // Thicker at base, tapering to tip
      final th = 11.0*(1-t0*0.65); final mid = Offset((wp0.dx+wp1.dx)/2,(wp0.dy+wp1.dy)/2);
      final len = (wp1-wp0).distance; final angle = math.atan2(wp1.dy-wp0.dy, wp1.dx-wp0.dx);
      out.add(Positioned(left: mid.dx-len/2, top: mid.dy-th/2, child: IgnorePointer(child: Transform.rotate(angle: angle,
        child: Container(width: len, height: th, decoration: BoxDecoration(borderRadius: BorderRadius.circular(th/2),
          gradient: const LinearGradient(colors: [Color(0xFF00FF88), Color(0xFF009955)]),
          boxShadow: [BoxShadow(color: const Color(0xFF00FF44).withOpacity(0.65), blurRadius: 10, spreadRadius: 1)]))))));
    }
    return out;
  }
}

// ── Win Blast + Coin Shower ────────────────────────────────────────────────────
class _WinBlast extends StatefulWidget {
  const _WinBlast();
  @override State<_WinBlast> createState() => _WinBlastState();
}
class _WinBlastState extends State<_WinBlast> with SingleTickerProviderStateMixin {
  late AnimationController _c; final _rng = Random(); final List<_P> _ps = []; final List<_Coin> _cs = [];
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))..forward();
    for (int i = 0; i < 70; i++) {
      _ps.add(_P(_rng.nextDouble()*math.pi*2, 0.3+_rng.nextDouble()*0.7, 4+_rng.nextDouble()*12,
        [const Color(0xFF00FF88), const Color(0xFFCC00FF), const Color(0xFFFF8800), const Color(0xFFFFEE00), Colors.white][_rng.nextInt(5)],
        _rng.nextDouble()*0.3));
    }
    for (int i = 0; i < 55; i++) { _cs.add(_Coin(_rng.nextDouble(), 0.25+_rng.nextDouble()*0.5, 0.4+_rng.nextDouble()*0.6, 14+_rng.nextDouble()*10)); }
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size; final cx = sz.width/2; final cy = sz.height*0.28;
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = _c.value;
      return Stack(children: [
        Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity((math.sin(t*math.pi)*0.85).clamp(0.0,0.85))))),
        if (t < 0.25) Positioned.fill(child: IgnorePointer(child: Container(color: const Color(0xFF00FF88).withOpacity((1-t/0.25)*0.6)))),
        ..._ps.map((p) { final pr = ((t-p.delay)/(1-p.delay)).clamp(0.0,1.0); if (pr<=0) return const SizedBox.shrink();
          final dx = cx+math.cos(p.angle)*pr*sz.width*0.7*p.speed; final dy = cy+math.sin(p.angle)*pr*sz.height*0.9*p.speed;
          final op = ((1-pr)*(1-pr)).clamp(0.0,1.0);
          return Positioned(left: dx-p.size/2, top: dy-p.size/2, child: IgnorePointer(child: Container(width: p.size, height: p.size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
              boxShadow: [BoxShadow(color: p.color.withOpacity(op*0.5), blurRadius: p.size*2)]))));
        }),
        ..._cs.map((c) { final pr = ((t-c.delay)/(1-c.delay)).clamp(0.0,1.0); if (pr<=0) return const SizedBox.shrink();
          final op = t > 0.85 ? ((1-t)/0.15).clamp(0.0,1.0) : 1.0;
          return Positioned(left: c.x*sz.width-c.size/2, top: pr*sz.height*1.1*c.speed-c.size/2,
            child: IgnorePointer(child: Opacity(opacity: op, child: Text('💰', style: TextStyle(fontSize: c.size)))));
        }),
        if (t > 0.4)
          Positioned(top: sz.height*0.4, left: 30, right: 30,
            child: Opacity(opacity: ((t-0.4)/0.4).clamp(0.0,1.0),
              child: Column(children: [
                const Text('🐙 OCTOPUS ALIEN DEFEATED! 💥', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF00FF88), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2,
                    shadows: [Shadow(color: Color(0xFF00FF44), blurRadius: 20)])),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6))),
                  child: const Text('+50 COINS BONUS! 💰', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900))),
              ]))),
      ]);
    });
  }
}

// ── Octopus Body ──────────────────────────────────────────────────────────────
class _OctBody extends StatelessWidget {
  final double glow, wave; final bool tentacles, shielded; final bool enraged;
  const _OctBody({required this.glow, required this.tentacles, required this.wave, required this.shielded, this.enraged = false});
  @override
  Widget build(BuildContext context) {
    final gc = shielded ? const Color(0xFFFFD700) : (enraged ? const Color(0xFFFF3300) : const Color(0xFF00FF88));
    return SizedBox(width: 110, height: tentacles ? 120 : 80, child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
      Positioned(top: 0, left: 5, child: Container(width: 100, height: 80, decoration: BoxDecoration(shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: gc.withOpacity(glow*0.5), blurRadius: 30, spreadRadius: 8)]))),
      Positioned(top: 0, left: 15, child: Container(width: 80, height: 70,
        decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(40), bottom: Radius.circular(20)),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: enraged
              ? [const Color(0xFF6E1A1A).withOpacity(0.9), const Color(0xFF3A0A0A).withOpacity(0.85)]
              : [const Color(0xFF2D8E4E).withOpacity(0.9), const Color(0xFF1A5C30).withOpacity(0.8)]),
          border: Border.all(color: gc.withOpacity(glow*0.8), width: enraged ? 2.5 : 2)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_Eye(glow: glow, c: gc), _Eye(glow: glow, c: gc)]),
          const SizedBox(height: 6),
          Container(width: 30, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
            color: const Color(0xFF004422).withOpacity(0.8), border: Border.all(color: gc.withOpacity(0.5), width: 1))),
        ]))),
      if (tentacles)
        ...List.generate(8, (i) {
          final ba = (i/8)*math.pi*2 + math.pi*0.5;
          final wo = math.sin(wave*math.pi*2 + i*math.pi/4)*16;
          final len = 54+wo;
          final tc = shielded ? const Color(0xFFFFAA00) : const Color(0xFF00CC66);
          return Positioned(left: 0, top: 0, right: 0, bottom: 0, child: IgnorePointer(child: CustomPaint(
            painter: _TentP(start: Offset(55+math.cos(ba)*30, 55+math.sin(ba)*30),
              end: Offset(55+math.cos(ba)*len, 70+math.sin(ba)*len+wo*0.5),
              color: tc, thickness: 11.0-i*0.7, glow: glow))));
        }),
      const Positioned(top: 20, left: 35, child: Text('👾', style: TextStyle(fontSize: 20))),
    ]));
  }
}

class _Eye extends StatelessWidget {
  final double glow; final Color c; const _Eye({required this.glow, required this.c});
  @override Widget build(BuildContext context) => Container(width: 16, height: 16,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(glow),
      boxShadow: [BoxShadow(color: c.withOpacity(glow*0.8), blurRadius: 8)]),
    child: Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black))));
}

class _TentP extends CustomPainter {
  final Offset start, end; final Color color; final double thickness, glow;
  const _TentP({required this.start, required this.end, required this.color, required this.thickness, required this.glow});

  Offset _qBez(Offset p0, Offset p1, Offset p2, double t) {
    final mt = 1 - t;
    return Offset(mt*mt*p0.dx + 2*mt*t*p1.dx + t*t*p2.dx,
                  mt*mt*p0.dy + 2*mt*t*p1.dy + t*t*p2.dy);
  }

  @override void paint(Canvas canvas, Size size) {
    final mid = Offset((start.dx+end.dx)/2+(end.dy-start.dy)*0.28,
                       (start.dy+end.dy)/2+(start.dx-end.dx)*0.28);
    final path = Path()..moveTo(start.dx,start.dy)..quadraticBezierTo(mid.dx,mid.dy,end.dx,end.dy);
    // Wide outer glow
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.38*glow)..strokeWidth = thickness+10..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)..style = PaintingStyle.stroke);
    // Mid glow layer
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.55*glow)..strokeWidth = thickness+4..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);
    // Solid tentacle body
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.92)..strokeWidth = thickness..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    // Sucker dots evenly along the tentacle
    final suckerCount = (thickness / 3).round().clamp(2, 5);
    for (int s = 1; s <= suckerCount; s++) {
      final t = s / (suckerCount + 1);
      final sp = _qBez(start, mid, end, t);
      canvas.drawCircle(sp, thickness * 0.42, Paint()..color = Colors.black.withOpacity(0.65)..style = PaintingStyle.fill);
      canvas.drawCircle(sp, thickness * 0.28, Paint()..color = color.withOpacity(0.75)..style = PaintingStyle.fill);
    }
  }
  @override bool shouldRepaint(_TentP o) => true;
}

// ── Rules Card ─────────────────────────────────────────────────────────────────
class _RulesCard extends StatelessWidget {
  const _RulesCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF001A08).withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.8), width: 2),
      boxShadow: [BoxShadow(color: const Color(0xFF00FF44).withOpacity(0.3), blurRadius: 20)]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🐙 LEVEL 36 — OCTOPUS ALIEN BOSS', style: TextStyle(color: Color(0xFF00FF88),
        fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFF00FF44).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5))),
        child: const Text('🎯 WIN: Merge 30 items total (watch X/30 on screen!)',
          style: TextStyle(color: Color(0xFF00FF88), fontSize: 10, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center)),
      const SizedBox(height: 8),
      _r('🐙', 'Every 5s: tentacles strike 4-5 cells → items destroyed!'),
      _r('🛡️', 'Shield appears every ~20s for 6s — merges BLOCKED while shielded'),
      _r('✅', 'When shield drops: merge items freely → each merge = 1 progress'),
      _r('📊', 'Tentacle hits do NOT count as merges — keep merging to win!'),
      _r('💰', 'Defeat = +50 COINS BONUS!'),
    ]));
  Widget _r(String i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [Text(i, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6),
      Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.4)))]));
}

// ── Shared ─────────────────────────────────────────────────────────────────────
class _DialogueBubble extends StatelessWidget {
  final String text; final Color color;
  const _DialogueBubble({required this.text, required this.color});
  @override Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF001008).withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.9), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 16)]),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
    Positioned(bottom: -10, left: 0, right: 0,
      child: Center(child: CustomPaint(size: const Size(16,10), painter: _Tail(color: color)))),
  ]);
}
class _Tail extends CustomPainter {
  final Color color; const _Tail({required this.color});
  @override void paint(Canvas canvas, Size size) { canvas.drawPath(Path()..moveTo(0,0)..lineTo(size.width,0)..lineTo(size.width/2,size.height)..close(), Paint()..color = color.withOpacity(0.9)); }
  @override bool shouldRepaint(_) => false;
}
class _P { final double angle, speed, size, delay; final Color color;
  const _P(this.angle, this.speed, this.size, this.color, this.delay); }
class _Coin { final double x, delay, speed, size; const _Coin(this.x, this.delay, this.speed, this.size); }
