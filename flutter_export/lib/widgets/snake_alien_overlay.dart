// snake_alien_overlay.dart — Snake-Alien Hybrid Boss UI
// L37 (35 merges) / L38 (40 merges)
// NEW: Dialogue bubble, Snake Jr. indicators, L38 death dialogue,
//      coin shower, HP vignette, slow-mo flash

import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/snake_alien_controller.dart';

class SnakeAlienOverlay extends StatelessWidget {
  final SnakeAlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  final bool isDialogActive;
  const SnakeAlienOverlay({super.key, required this.controller, required this.getCellRect, this.isDialogActive = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final p = controller.phase;
      if (p == SnakeAlienPhase.idle) return const SizedBox.shrink();
      if (isDialogActive) return const SizedBox.shrink();
      return Stack(children: [
        if (controller.isSlowMo) Positioned.fill(child: IgnorePointer(child: _Flash())),
        if (p == SnakeAlienPhase.entry) _Entry(controller: controller),
        if (p == SnakeAlienPhase.active) _Active(controller: controller, getCellRect: getCellRect),
        if (p == SnakeAlienPhase.active) _DropTimers(controller: controller, getCellRect: getCellRect),
        if (p == SnakeAlienPhase.active) _SnakeJrCells(controller: controller, getCellRect: getCellRect),
        if (controller.isLowHp && p == SnakeAlienPhase.active) const _LowHpVignette(),
        if (p == SnakeAlienPhase.winBlast) _WinBlast(controller: controller),
      ]);
    });
  }
}

// ── Slow-Mo Flash ──────────────────────────────────────────────────────────────
class _Flash extends StatefulWidget { @override State<_Flash> createState() => _FlashState(); }
class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => Container(color: Colors.white.withOpacity((math.sin(_c.value*math.pi)*0.65).clamp(0.0,0.65))));
}

// ── Low HP Vignette ────────────────────────────────────────────────────────────
class _LowHpVignette extends StatefulWidget { const _LowHpVignette(); @override State<_LowHpVignette> createState() => _LHVS(); }
class _LHVS extends State<_LowHpVignette> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
      center: Alignment.center, radius: 1.1,
      colors: [Colors.transparent, Colors.transparent, Colors.red.withOpacity(0.18+_c.value*0.18), Colors.red.withOpacity(0.42+_c.value*0.22)],
      stops: const [0.0, 0.45, 0.75, 1.0])))));
}

// ── Entry Animation ────────────────────────────────────────────────────────────
class _Entry extends StatefulWidget {
  final SnakeAlienController controller; const _Entry({required this.controller});
  @override State<_Entry> createState() => _EntryState();
}
class _EntryState extends State<_Entry> with TickerProviderStateMixin {
  late AnimationController _main, _grow, _limb, _ptcl, _rules;
  late Animation<double> _sc; late Animation<Offset> _pos;
  final _rng = Random(); final List<_P> _ps = [];
  @override void initState() {
    super.initState();
    _main  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..forward();
    _grow  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..repeat(reverse: true);
    _limb  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _ptcl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..forward();
    _rules = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _sc    = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.6), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.8), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.8, end: 0.4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.65), weight: 15),
    ]).animate(CurvedAnimation(parent: _main, curve: Curves.easeInOut));
    _pos   = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: const Offset(0,0.6), end: const Offset(0,0)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: const Offset(0,0), end: const Offset(0,-0.28)), weight: 50),
    ]).animate(CurvedAnimation(parent: _main, curve: Curves.easeInOut));
    for (int i = 0; i < 75; i++) {
      _ps.add(_P(_rng.nextDouble()*math.pi*2, 0.15+_rng.nextDouble()*0.55, 2+_rng.nextDouble()*7,
        [const Color(0xFFFF4400), const Color(0xFFFF8800), const Color(0xFF00FFCC), const Color(0xFF9B30FF), const Color(0xFFFFEE00), Colors.white][_rng.nextInt(6)],
        _rng.nextDouble()*0.35));
    }
    _main.addStatusListener((s) { if (s == AnimationStatus.completed && mounted) _rules.forward(); });
  }
  @override void dispose() { _main.dispose(); _grow.dispose(); _limb.dispose(); _ptcl.dispose(); _rules.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size; final cx = sz.width/2; final cy = sz.height/2;
    return AnimatedBuilder(animation: Listenable.merge([_main,_grow,_limb,_ptcl,_rules]), builder: (_, __) {
      final t = _main.value; final pt = _ptcl.value;
      final sc = _sc.value; final po = _pos.value;
      final bx = cx + po.dx*sz.width; final by = cy + po.dy*sz.height;
      final bp = 1.0 + _grow.value*0.08; final le = 0.5+_limb.value*0.5;
      return Stack(children: [
        Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity((t*0.8).clamp(0.0,0.8))))),
        ..._ps.map((p) {
          final pr = ((pt-p.delay)/(1-p.delay)).clamp(0.0,1.0); if (pr<=0) return const SizedBox.shrink();
          final dx = cx+math.cos(p.angle)*pr*sz.width*0.65*p.speed; final dy = cy+math.sin(p.angle)*pr*sz.height*0.65*p.speed;
          final op = (1-pr*pr).clamp(0.0,1.0);
          return Positioned(left: dx-p.size/2, top: dy-p.size/2, child: IgnorePointer(child: Container(width: p.size, height: p.size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
              boxShadow: [BoxShadow(color: p.color.withOpacity(op*0.5), blurRadius: p.size*1.5)]))));
        }),
        Positioned(left: bx-55*sc*bp, top: by-60*sc*bp,
          child: IgnorePointer(child: Transform.scale(scale: sc*bp,
            child: _SnakeBody(limbExt: le, glow: 0.7+_grow.value*0.3)))),
        if (_rules.value > 0.01)
          Positioned(bottom: sz.height*0.06, left: 16, right: 16,
            child: Opacity(opacity: _rules.value, child: _RulesCard(level: widget.controller.currentLevel))),
      ]);
    });
  }
}

// ── Active Phase ──────────────────────────────────────────────────────────────
class _Active extends StatefulWidget {
  final SnakeAlienController controller; final Rect? Function(int,int) getCellRect;
  const _Active({required this.controller, required this.getCellRect});
  @override State<_Active> createState() => _ActiveState();
}
class _ActiveState extends State<_Active> with TickerProviderStateMixin {
  late AnimationController _pulse, _limb, _orbit, _hpP, _dlg;
  String? _prevDlg;
  @override void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _limb  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _hpP   = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..repeat(reverse: true);
    _dlg   = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    widget.controller.addListener(_onChange);
  }
  void _onChange() { final d = widget.controller.dialogueText; if (d != _prevDlg && d != null) { _prevDlg = d; _dlg.forward(from: 0); } }
  @override void dispose() { widget.controller.removeListener(_onChange); _pulse.dispose(); _limb.dispose(); _orbit.dispose(); _hpP.dispose(); _dlg.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size; final fc = widget.getCellRect(0,0);
    final gt = fc?.top ?? sz.height*0.40; final cx = sz.width/2; final by = (gt-125).clamp(8.0, gt-125);
    final c = widget.controller; final isLow = c.isLowHp;
    return AnimatedBuilder(animation: Listenable.merge([_pulse,_limb,_orbit,_hpP,_dlg]), builder: (_, __) {
      final orb = _orbit.value*math.pi*2; final hpOp = isLow ? (0.5+_hpP.value*0.5) : 1.0;
      return Stack(children: [
        Positioned(left: cx-55, top: by, child: IgnorePointer(child: _SnakeBody(limbExt: 0.5+_limb.value*0.5, glow: 0.7+_pulse.value*0.3))),
        if (c.dialogueText != null)
          Positioned(top: by-52, left: cx-150, width: 300,
            child: ScaleTransition(scale: CurvedAnimation(parent: _dlg, curve: Curves.elasticOut),
              child: _DialogueBubble(text: c.dialogueText!, color: const Color(0xFFFF4400)))),
        ...List.generate(6, (i) {
          final a = orb + i*math.pi/3;
          return Positioned(left: cx+math.cos(a)*60-5, top: by+50+math.sin(a)*20-5,
            child: IgnorePointer(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF4400).withOpacity(0.7+_pulse.value*0.3),
              boxShadow: [BoxShadow(color: const Color(0xFFFF8800).withOpacity(0.5), blurRadius: 8)]))));
        }),
        Positioned(top: by+128, left: 28, right: 28, child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('🐍 BOSS HP', style: TextStyle(
              color: isLow ? Colors.red.withOpacity(hpOp) : const Color(0xFFFF4400).withOpacity(0.9),
              fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Text('${c.mergesDone}/${c.mergesNeeded}', style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 3),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: c.progressFraction, minHeight: isLow ? 10 : 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(isLow ? Colors.red.withOpacity(hpOp)
                : Color.lerp(const Color(0xFFFF0000), const Color(0xFF00FF88), c.progressFraction)!))),
          if (isLow)
            Padding(padding: const EdgeInsets.only(top: 2),
              child: Text('⚠️ BOSS ENRAGED — ATTACKS INTENSIFY!', style: TextStyle(
                color: Colors.red.withOpacity(hpOp), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
        ])),
      ]);
    });
  }
}

// ── Drop Timers ───────────────────────────────────────────────────────────────
class _DropTimers extends StatefulWidget {
  final SnakeAlienController controller; final Rect? Function(int,int) getCellRect;
  const _DropTimers({required this.controller, required this.getCellRect});
  @override State<_DropTimers> createState() => _DropTimersState();
}
class _DropTimersState extends State<_DropTimers> with TickerProviderStateMixin {
  late AnimationController _flash, _spark;
  @override void initState() {
    super.initState();
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
    _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  }
  @override void dispose() { _flash.dispose(); _spark.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: Listenable.merge([_flash, _spark]),
    builder: (_, __) => ListenableBuilder(listenable: widget.controller,
      builder: (_, __) => Stack(children: widget.controller.activeDrops.expand((d) {
        final r = widget.getCellRect(d.col, d.row); if (r == null) return const <Widget>[];
        final urgent = d.secondsLeft <= 2; final f = urgent ? _flash.value : 1.0;
        final c = urgent ? Colors.red : const Color(0xFFFF6600);
        return <Widget>[
          Positioned(left: r.left, top: r.top, width: r.width, height: r.height,
            child: IgnorePointer(child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.withOpacity(f*0.9), width: 2.5),
                color: c.withOpacity(f*0.18), boxShadow: [BoxShadow(color: c.withOpacity(f*0.4), blurRadius: 10)]),
              child: Stack(alignment: Alignment.center, children: [
                const Positioned(top: 3, child: Text('👽', style: TextStyle(fontSize: 18))),
                Positioned(bottom: 3, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(4)),
                  child: Text('${d.secondsLeft}s', style: TextStyle(color: urgent ? Colors.red : Colors.orange, fontSize: 10, fontWeight: FontWeight.w900)))),
              ])))),
          ..._crackleSparks(r.center, _spark.value, c, urgent),
        ];
      }).toList())));

  // Crackling energy sparks around each falling-alien target — reinforces the
  // sense of imminent danger as the countdown runs out.
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

// ── Snake Jr. Cell Indicators ─────────────────────────────────────────────────
class _SnakeJrCells extends StatefulWidget {
  final SnakeAlienController controller; final Rect? Function(int,int) getCellRect;
  const _SnakeJrCells({required this.controller, required this.getCellRect});
  @override State<_SnakeJrCells> createState() => _SnakeJrCellsState();
}
class _SnakeJrCellsState extends State<_SnakeJrCells> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => ListenableBuilder(listenable: widget.controller,
      builder: (_, __) => Stack(children: widget.controller.snakeJrCells.map((s) {
        final r = widget.getCellRect(s.col, s.row); if (r == null) return const SizedBox.shrink();
        return Positioned(left: r.left, top: r.top, width: r.width, height: r.height,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFAA0000).withOpacity(0.7+_c.value*0.3), width: 2.5),
              color: const Color(0xFF880000).withOpacity(0.2+_c.value*0.1),
              boxShadow: [BoxShadow(color: const Color(0xFFFF2200).withOpacity(0.35+_c.value*0.2), blurRadius: 10)]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🐍', style: TextStyle(fontSize: 18)),
              const Text('JR.', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900)),
            ]))));
      }).toList())));
}

// ── Win Blast + L38 Death Dialogue + Coin Shower ──────────────────────────────
class _WinBlast extends StatefulWidget {
  final SnakeAlienController controller; const _WinBlast({required this.controller});
  @override State<_WinBlast> createState() => _WinBlastState();
}
class _WinBlastState extends State<_WinBlast> with SingleTickerProviderStateMixin {
  late AnimationController _c; final _rng = Random(); final List<_P> _ps = []; final List<_Coin> _cs = [];
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..forward();
    for (int i = 0; i < 90; i++) {
      _ps.add(_P(_rng.nextDouble()*math.pi*2, 0.25+_rng.nextDouble()*0.75, 3+_rng.nextDouble()*12,
        [const Color(0xFFFF4400), const Color(0xFFFF8800), const Color(0xFFFFEE00), const Color(0xFF00FFCC), const Color(0xFF9B30FF), Colors.white][_rng.nextInt(6)],
        _rng.nextDouble()*0.4));
    }
    for (int i = 0; i < 60; i++) { _cs.add(_Coin(_rng.nextDouble(), 0.25+_rng.nextDouble()*0.55, 0.35+_rng.nextDouble()*0.65, 14+_rng.nextDouble()*12)); }
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size; final cx = sz.width/2; final cy = sz.height*0.28;
    final lvl = widget.controller.currentLevel; final dd = widget.controller.deathDialogue;
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = _c.value;
      return Stack(children: [
        Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity((math.sin(t*math.pi)*0.88).clamp(0.0,0.88))))),
        if (t < 0.2) Positioned.fill(child: IgnorePointer(child: Container(color: Colors.white.withOpacity((1-t/0.2)*0.75)))),
        ..._ps.map((p) { final pr = ((t-p.delay)/(1-p.delay)).clamp(0.0,1.0); if (pr<=0) return const SizedBox.shrink();
          final dx = cx+math.cos(p.angle)*pr*sz.width*0.75*p.speed; final dy = cy+math.sin(p.angle)*pr*sz.height*0.9*p.speed;
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
        if (t > 0.3)
          Positioned(top: sz.height*0.36, left: 24, right: 24,
            child: Opacity(opacity: ((t-0.3)/0.5).clamp(0.0,1.0), child: Column(children: [
              const Text('🐍 SNAKE ALIEN ANNIHILATED! 💥', textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFFFEE00), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2,
                  shadows: [Shadow(color: Color(0xFFFF8800), blurRadius: 20)])),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.6))),
                child: const Text('+50 COINS BONUS! 💰', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900))),
              if (lvl == 38 && dd != null) ...[
                const SizedBox(height: 14),
                Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12)]),
                  child: Column(children: [
                    const Text('💬 LAST WORDS:', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text('"$dd"', textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                  ])),
                const SizedBox(height: 10),
                const Text('🏆 ALL BOSSES DEFEATED!\nYou are the Ultimate Tech Tycoon!', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF00FFCC), fontSize: 16, fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Color(0xFF00FFCC), blurRadius: 15)])),
              ],
            ]))),
      ]);
    });
  }
}

// ── Snake Body ────────────────────────────────────────────────────────────────
class _SnakeBody extends StatelessWidget {
  final double limbExt, glow; const _SnakeBody({required this.limbExt, required this.glow});
  @override
  Widget build(BuildContext context) => SizedBox(width: 110, height: 115,
    child: Stack(clipBehavior: Clip.none, children: [
      ...List.generate(5, (i) {
        final yOff = 65.0+i*12; final xOff = math.sin(i*0.8+limbExt*math.pi*2)*8;
        return Positioned(left: 30+xOff, top: yOff, child: IgnorePointer(child: Container(
          width: 50-i*6, height: 14-i*1.5,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(colors: [const Color(0xFFAA3300).withOpacity(0.85-i*0.12), const Color(0xFF660000).withOpacity(0.7-i*0.1)]),
            border: Border.all(color: const Color(0xFFFF4400).withOpacity((glow-i*0.1).clamp(0.0,1.0)), width: 1)))));
      }),
      Positioned(top: 0, left: 5, child: Container(width: 100, height: 75,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(50), bottom: Radius.circular(15)),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF880000).withOpacity(0.95), const Color(0xFF550000).withOpacity(0.85)]),
          border: Border.all(color: const Color(0xFFFF4400).withOpacity(glow*0.9), width: 2.5),
          boxShadow: [BoxShadow(color: const Color(0xFFFF2200).withOpacity(glow*0.5), blurRadius: 20, spreadRadius: 4)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_Eye(glow: glow), _Eye(glow: glow)]),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_Fang(), const SizedBox(width: 16), _Fang()]),
        ]))),
      ...List.generate(4, (i) {
        final isL = i < 2; final ai = isL ? i : i-2;
        final baseY = 20.0+ai*22; final el = 30+limbExt*35;
        final angle = isL ? (-0.5-ai*0.3) : (0.5+ai*0.3);
        final ex = isL ? (5-el*math.cos(angle.abs())).clamp(-30.0,100.0) : (105+el*math.cos(angle.abs())).clamp(0.0,140.0);
        final ey = baseY+math.sin(angle.abs())*el*0.5;
        return Positioned(left: isL ? 5 : 105, top: baseY, child: IgnorePointer(child: CustomPaint(size: const Size(40,20),
          painter: _ArmP(end: Offset(ex-(isL?5:105), ey-baseY), color: const Color(0xFFCC2200), glow: glow))));
      }),
      const Positioned(top: 24, left: 38, child: Text('👾', style: TextStyle(fontSize: 20))),
    ]));
}
class _Eye extends StatelessWidget {
  final double glow; const _Eye({required this.glow});
  @override Widget build(BuildContext context) => Container(width: 14, height: 14,
    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF4400).withOpacity(glow),
      boxShadow: [BoxShadow(color: const Color(0xFFFF2200).withOpacity(glow*0.8), blurRadius: 6)]),
    child: Center(child: Container(width: 5, height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.black))));
}
class _Fang extends StatelessWidget {
  @override Widget build(BuildContext context) => CustomPaint(size: const Size(8,12), painter: _FangP());
}
class _FangP extends CustomPainter {
  @override void paint(Canvas c, Size s) { c.drawPath(Path()..moveTo(0,0)..lineTo(s.width,0)..lineTo(s.width/2,s.height)..close(), Paint()..color = Colors.white.withOpacity(0.9)); }
  @override bool shouldRepaint(_) => false;
}
class _ArmP extends CustomPainter {
  final Offset end; final Color color; final double glow;
  const _ArmP({required this.end, required this.color, required this.glow});
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.85)..strokeWidth = 4..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final g = Paint()..color = color.withOpacity(0.3*glow)..strokeWidth = 8..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)..style = PaintingStyle.stroke;
    final mid = Offset(end.dx*0.4, end.dy+8);
    final path = Path()..moveTo(0,0)..quadraticBezierTo(mid.dx,mid.dy,end.dx,end.dy);
    canvas.drawPath(path, g); canvas.drawPath(path, p);
  }
  @override bool shouldRepaint(_ArmP o) => true;
}

// ── Rules Card ─────────────────────────────────────────────────────────────────
class _RulesCard extends StatelessWidget {
  final int level; const _RulesCard({required this.level});
  @override
  Widget build(BuildContext context) {
    final n = kSnakeAlienLevels[level] ?? 35;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1A0000).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF4400).withOpacity(0.8), width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFFFF2200).withOpacity(0.35), blurRadius: 20)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🐍 LEVEL $level — SNAKE-ALIEN BOSS', style: const TextStyle(color: Color(0xFFFF4400),
          fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        if (level == 37) ...[
          Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.4))),
            child: const Text('📋 L35 RECAP: 25 merges defeated Spaceship Alien.\nNow face something MUCH worse!',
              style: TextStyle(color: Colors.orange, fontSize: 10, height: 1.4), textAlign: TextAlign.center)),
        ],
        _r('👽', 'Every 10s: 5 mini-aliens drop — 5s timer before destruction'),
        _r('🐍', 'Every 20s: Snake Jr. permanently blocks one grid cell!'),
        _r('🔧', 'Merge any 2 items to save a cell from mini-aliens'),
        _r('🎯', 'Merge $n items total → Snake-Alien obliterated!'),
        _r('💰', 'Defeat = +50 COINS BONUS!'),
        if (level == 38) Padding(padding: const EdgeInsets.only(top: 6),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.35))),
            child: const Text('👑 FINAL BOSS — Defeat to conquer ALL levels!',
              style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
      ]));
  }
  Widget _r(String i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(children: [Text(i, style: const TextStyle(fontSize: 13)), const SizedBox(width: 7),
      Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.4)))]));
}

// ── Shared ─────────────────────────────────────────────────────────────────────
class _DialogueBubble extends StatelessWidget {
  final String text; final Color color; const _DialogueBubble({required this.text, required this.color});
  @override Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF100000).withOpacity(0.96),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.9), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 16)]),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
    Positioned(bottom: -10, left: 0, right: 0, child: Center(child: CustomPaint(size: const Size(16,10), painter: _Tail(color: color)))),
  ]);
}
class _Tail extends CustomPainter {
  final Color color; const _Tail({required this.color});
  @override void paint(Canvas c, Size s) { c.drawPath(Path()..moveTo(0,0)..lineTo(s.width,0)..lineTo(s.width/2,s.height)..close(), Paint()..color = color.withOpacity(0.9)); }
  @override bool shouldRepaint(_) => false;
}
class _P { final double angle, speed, size, delay; final Color color; const _P(this.angle, this.speed, this.size, this.color, this.delay); }
class _Coin { final double x, delay, speed, size; const _Coin(this.x, this.delay, this.speed, this.size); }
