// snake_alien_overlay.dart — "Exosuit Alien" Boss UI
// Level 38 (40 merges)
// Creature: mechanical alien in a full power-exosuit with animated eyes,
//           pistons, claws, legs, electricity arcs, and shoulder cannons.
// Attack:   electricity beam to 5 cells every 5s, 5-second fuse → blast.
// Win:      3D Printer fires a laser → boss destroyed with AAA blast.
// Hints:    rotating every 5s during active phase.

import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/snake_alien_controller.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kElectric   = Color(0xFF00E5FF);
const _kDanger     = Color(0xFFFF1744);
const _kArmorDark  = Color(0xFF1C2B35);
const _kArmor      = Color(0xFF263238);
const _kArmorMid   = Color(0xFF37474F);
const _kArmorHL    = Color(0xFF546E7A);
const _kWarn       = Color(0xFFFF6D00);

// ─── L38 rotating hints ───────────────────────────────────────────────────────
const _kL38Hints = [
  ('⚡', 'Exosuit fires electricity every 5s — 5 cells targeted per wave!'),
  ('💥', 'Un-merged items EXPLODE after 5 seconds — merge fast to survive!'),
  ('🏆', 'Complete your DELIVERY QUOTA to destroy the Exosuit boss!'),
  ('🖨️', 'Quota done → 3D Printer fires a LASER to obliterate the boss!'),
  ('🎯', 'Countdown shown on each targeted cell — merge before it hits 0!'),
  ('⚠️', 'Each item destroyed = energy penalty. Stay ahead of the attacks!'),
];

// ─── Main Overlay ─────────────────────────────────────────────────────────────
class SnakeAlienOverlay extends StatelessWidget {
  final SnakeAlienController controller;
  final Rect? Function(int col, int row) getCellRect;
  final bool isDialogActive;
  const SnakeAlienOverlay({
    super.key,
    required this.controller,
    required this.getCellRect,
    this.isDialogActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final p = controller.phase;
      if (p == SnakeAlienPhase.idle) return const SizedBox.shrink();
      if (isDialogActive) return const SizedBox.shrink();
      return Stack(children: [
        if (controller.isSlowMo)
          Positioned.fill(child: IgnorePointer(child: _Flash())),
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
class _Flash extends StatefulWidget {
  @override State<_Flash> createState() => _FlashState();
}
class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => Container(color: Colors.white.withOpacity((math.sin(_c.value * math.pi) * 0.65).clamp(0.0, 0.65))));
}

// ── Low HP Vignette ────────────────────────────────────────────────────────────
class _LowHpVignette extends StatefulWidget {
  const _LowHpVignette();
  @override State<_LowHpVignette> createState() => _LHVS();
}
class _LHVS extends State<_LowHpVignette> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: _c,
    builder: (_, __) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(
      center: Alignment.center, radius: 1.1,
      colors: [Colors.transparent, Colors.transparent,
        Colors.red.withOpacity(0.18 + _c.value * 0.18),
        Colors.red.withOpacity(0.42 + _c.value * 0.22)],
      stops: const [0.0, 0.45, 0.75, 1.0])))));
}

// ── Entry Animation ────────────────────────────────────────────────────────────
class _Entry extends StatefulWidget {
  final SnakeAlienController controller;
  const _Entry({required this.controller});
  @override State<_Entry> createState() => _EntryState();
}
class _EntryState extends State<_Entry> with TickerProviderStateMixin {
  late AnimationController _main, _limb, _glow, _electric, _ptcl, _rules;
  late Animation<double> _sc;
  late Animation<Offset> _pos;
  final _rng = Random();
  final List<_P> _ps = [];

  @override
  void initState() {
    super.initState();
    _main     = AnimationController(vsync: this, duration: const Duration(milliseconds: 3900))..forward();
    _limb     = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _glow     = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _electric = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..repeat();
    _ptcl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600))..forward();
    _rules    = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _sc = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.7), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.85), weight: 24),
      TweenSequenceItem(tween: Tween(begin: 1.85, end: 0.55), weight: 21),
      TweenSequenceItem(tween: Tween(begin: 0.55, end: 0.72), weight: 15),
    ]).animate(CurvedAnimation(parent: _main, curve: Curves.easeInOut));
    _pos = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: const Offset(0, 0.55), end: const Offset(0, 0)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: const Offset(0, 0), end: const Offset(0, -0.22)), weight: 50),
    ]).animate(CurvedAnimation(parent: _main, curve: Curves.easeInOut));
    for (int i = 0; i < 85; i++) {
      _ps.add(_P(
        _rng.nextDouble() * math.pi * 2,
        0.15 + _rng.nextDouble() * 0.55,
        3 + _rng.nextDouble() * 9,
        [_kElectric, const Color(0xFF0088AA), const Color(0xFF00FFCC),
         const Color(0xFFFFEE00), const Color(0xFF7B1FA2), Colors.white][_rng.nextInt(6)],
        _rng.nextDouble() * 0.38,
      ));
    }
    _main.addStatusListener((s) { if (s == AnimationStatus.completed && mounted) _rules.forward(); });
  }

  @override
  void dispose() {
    _main.dispose(); _limb.dispose(); _glow.dispose(); _electric.dispose();
    _ptcl.dispose(); _rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    return AnimatedBuilder(
      animation: Listenable.merge([_main, _limb, _glow, _electric, _ptcl, _rules]),
      builder: (_, __) {
        final t  = _main.value;
        final pt = _ptcl.value;
        final sc = _sc.value;
        final po = _pos.value;
        final bx = cx + po.dx * sz.width;
        final by = cy + po.dy * sz.height;
        return Stack(children: [
          Positioned.fill(child: IgnorePointer(child: Container(
            color: Colors.black.withOpacity((t * 0.85).clamp(0.0, 0.85))))),
          ..._ps.map((p) {
            final pr = ((pt - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
            if (pr <= 0) return const SizedBox.shrink();
            final dx = cx + math.cos(p.angle) * pr * sz.width  * 0.70 * p.speed;
            final dy = cy + math.sin(p.angle) * pr * sz.height * 0.70 * p.speed;
            final op = (1 - pr * pr).clamp(0.0, 1.0);
            return Positioned(left: dx - p.size / 2, top: dy - p.size / 2,
              child: IgnorePointer(child: Container(width: p.size, height: p.size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
                  boxShadow: [BoxShadow(color: p.color.withOpacity(op * 0.5), blurRadius: p.size * 1.5)]))));
          }),
          Positioned(
            left: bx - 60 * sc,
            top:  by  - 80 * sc,
            child: IgnorePointer(child: Transform.scale(
              scale: sc.clamp(0.05, 4.5),
              alignment: Alignment.topLeft,
              child: _ExosuitBody(
                limbExt:   _limb.value,
                glow:      _glow.value,
                eyeT:      0,
                electricT: _electric.value * math.pi * 2,
              ),
            )),
          ),
          if (_rules.value > 0.01)
            Positioned(bottom: sz.height * 0.06, left: 16, right: 16,
              child: Opacity(opacity: _rules.value,
                child: _RulesCard(level: widget.controller.currentLevel))),
        ]);
      },
    );
  }
}

// ── Active Phase ──────────────────────────────────────────────────────────────
class _Active extends StatefulWidget {
  final SnakeAlienController controller;
  final Rect? Function(int, int) getCellRect;
  const _Active({required this.controller, required this.getCellRect});
  @override State<_Active> createState() => _ActiveState();
}
class _ActiveState extends State<_Active> with TickerProviderStateMixin {
  late AnimationController _limb, _glow, _orbit, _hpP, _dlg, _electric, _blink;
  String? _prevDlg;
  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _limb     = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _glow     = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _orbit    = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _electric = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..repeat();
    _blink    = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _hpP      = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..repeat(reverse: true);
    _dlg      = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    widget.controller.addListener(_onChange);
    _scheduleBlink();
    _hintTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _hintIndex = (_hintIndex + 1) % _kL38Hints.length);
    });
  }

  void _onChange() {
    if (!mounted) return;
    final d = widget.controller.dialogueText;
    if (d != _prevDlg && d != null) { _prevDlg = d; _dlg.forward(from: 0); }
  }

  void _scheduleBlink() {
    Future.delayed(Duration(milliseconds: 2400 + Random().nextInt(2100)), () {
      if (!mounted) return;
      _blink.forward(from: 0).whenComplete(() {
        if (mounted) _blink.reverse().whenComplete(() { if (mounted) _scheduleBlink(); });
      });
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _limb.dispose(); _glow.dispose(); _orbit.dispose(); _electric.dispose();
    _blink.dispose(); _hpP.dispose(); _dlg.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz  = MediaQuery.of(context).size;
    final fc  = widget.getCellRect(0, 0);
    final gt  = fc?.top ?? sz.height * 0.40;
    final cx  = sz.width / 2;
    final by  = (gt - 152).clamp(8.0, gt - 152);
    final c   = widget.controller;
    final isLow = c.isLowHp;

    return AnimatedBuilder(
      animation: Listenable.merge([_limb, _glow, _orbit, _electric, _blink, _hpP, _dlg]),
      builder: (_, __) {
        final orb   = _orbit.value * math.pi * 2;
        final hpOp  = isLow ? (0.5 + _hpP.value * 0.5) : 1.0;

        return Stack(children: [
          // ── Exosuit creature ─────────────────────────────────────────────
          Positioned(left: cx - 60, top: by,
            child: IgnorePointer(child: _ExosuitBody(
              limbExt:   _limb.value,
              glow:      _glow.value,
              eyeT:      _blink.value,
              electricT: _electric.value * math.pi * 2,
            ))),

          // ── Electricity orbit ring around creature ─────────────────────
          ...List.generate(8, (i) {
            final a    = orb + i * math.pi / 4;
            final dist = 56 + math.sin(_glow.value * math.pi * 2 + i) * 8;
            return Positioned(
              left: cx + math.cos(a) * dist - 5,
              top:  by + 66 + math.sin(a) * 22 - 5,
              child: IgnorePointer(child: Container(width: 9, height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _kElectric.withOpacity(0.50 + _glow.value * 0.38),
                  boxShadow: [BoxShadow(color: _kElectric.withOpacity(0.65), blurRadius: 10)]))));
          }),

          // ── Dialogue bubble ────────────────────────────────────────────
          if (c.dialogueText != null)
            Positioned(top: by - 54, left: cx - 160, width: 320,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _dlg, curve: Curves.elasticOut),
                child: _DialogueBubble(text: c.dialogueText!, color: _kElectric))),

          // ── HP bar + hint banner ───────────────────────────────────────
          Positioned(top: by + 158, left: 22, right: 22,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('🤖 EXOSUIT HP', style: TextStyle(
                  color: isLow ? Colors.red.withOpacity(hpOp) : _kElectric.withOpacity(0.9),
                  fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                Text('${c.mergesDone}/${c.mergesNeeded}',
                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: c.progressFraction, minHeight: isLow ? 10 : 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(isLow
                    ? Colors.red.withOpacity(hpOp)
                    : Color.lerp(_kDanger, _kElectric, c.progressFraction)!))),
              if (isLow)
                Padding(padding: const EdgeInsets.only(top: 2),
                  child: Text('⚠️ EXOSUIT OVERCHARGING — ATTACKS INTENSIFY!', style: TextStyle(
                    color: Colors.red.withOpacity(hpOp), fontSize: 8,
                    fontWeight: FontWeight.w900, letterSpacing: 1.2))),
              const SizedBox(height: 6),
              _L38HintBanner(
                icon:    _kL38Hints[_hintIndex].$1,
                text:    _kL38Hints[_hintIndex].$2,
                hintKey: ValueKey(_hintIndex),
              ),
            ])),
        ]);
      },
    );
  }
}

// ── Drop Timers + Electric Beams ──────────────────────────────────────────────
class _DropTimers extends StatefulWidget {
  final SnakeAlienController controller;
  final Rect? Function(int, int) getCellRect;
  const _DropTimers({required this.controller, required this.getCellRect});
  @override State<_DropTimers> createState() => _DropTimersState();
}
class _DropTimersState extends State<_DropTimers> with TickerProviderStateMixin {
  late AnimationController _flash, _spark, _beam;
  List<MiniAlienDrop> _prevDrops = [];
  final List<_CellBlast> _blasts = [];

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..repeat(reverse: true);
    _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
    _beam  = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..repeat();
    _prevDrops = List.from(widget.controller.activeDrops);
    widget.controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (!mounted) return;
    final curr = widget.controller.activeDrops;
    final removed = _prevDrops.where((d) => !curr.any((c) => c.id == d.id)).toList();
    for (final d in removed) {
      final r = widget.getCellRect(d.col, d.row);
      if (r != null) {
        final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
        final blast = _CellBlast(ctrl: ctrl, center: r.center);
        _blasts.add(blast);
        ctrl.forward().whenComplete(() {
          if (!mounted) return;
          ctrl.dispose();
          setState(() => _blasts.remove(blast));
        });
      }
    }
    _prevDrops = List.from(curr);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _flash.dispose(); _spark.dispose(); _beam.dispose();
    for (final b in _blasts) { try { b.ctrl.dispose(); } catch (_) {} }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final fc = widget.getCellRect(0, 0);
    final gt = fc?.top ?? sz.height * 0.40;
    final cx = sz.width / 2;
    final creatureCenter = Offset(cx, (gt - 152).clamp(8.0, gt - 152) + 75);

    return AnimatedBuilder(
      animation: Listenable.merge([_flash, _spark, _beam]),
      builder: (_, __) => ListenableBuilder(listenable: widget.controller, builder: (_, __) {
        return Stack(children: [
          // ── Cell blast effects ────────────────────────────────────────────
          ..._blasts.expand((b) {
            return <Widget>[
              AnimatedBuilder(animation: b.ctrl, builder: (_, __) {
                final t   = b.ctrl.value;
                final rng = Random(b.center.dx.toInt() * 79 + b.center.dy.toInt());
                return Stack(children: [
                  // Flash circle
                  Positioned(left: b.center.dx - 30, top: b.center.dy - 30,
                    child: IgnorePointer(child: Container(width: 60, height: 60,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _kElectric.withOpacity(((t < 0.18 ? t / 0.18 : (1 - t) / 0.82) * 0.55).clamp(0.0, 0.55)),
                        boxShadow: [BoxShadow(color: _kElectric.withOpacity(0.5), blurRadius: 18, spreadRadius: 4)])))),
                  // Particles
                  ...List.generate(16, (i) {
                    final a  = (i / 16) * math.pi * 2 + rng.nextDouble() * 0.4;
                    final sp = 0.4 + rng.nextDouble() * 0.6;
                    final pr = Curves.decelerate.transform(t);
                    final dx = b.center.dx + math.cos(a) * pr * 58 * sp;
                    final dy = b.center.dy + math.sin(a) * pr * 58 * sp;
                    final op = ((1 - pr) * (1 - pr)).clamp(0.0, 1.0);
                    final pSz = (3 + rng.nextDouble() * 6) * (1 - t * 0.5);
                    final col = [_kElectric, _kDanger, _kWarn, Colors.white][rng.nextInt(4)];
                    return Positioned(left: dx - pSz / 2, top: dy - pSz / 2,
                      child: IgnorePointer(child: Container(width: pSz, height: pSz,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: col.withOpacity(op),
                          boxShadow: [BoxShadow(color: col.withOpacity(op * 0.5), blurRadius: pSz * 2)]))));
                  }),
                ]);
              }),
            ];
          }),

          // ── Electric beams from creature to each targeted cell ───────────
          ...widget.controller.activeDrops.expand((d) {
            final r = widget.getCellRect(d.col, d.row);
            if (r == null) return const <Widget>[];
            return [
              Positioned.fill(child: IgnorePointer(child: CustomPaint(
                painter: _LightningPainter(
                  start:   creatureCenter,
                  end:     r.center,
                  phase:   _beam.value * math.pi * 2,
                  opacity: (0.22 + _spark.value * 0.14).clamp(0.0, 0.40),
                  color:   d.secondsLeft <= 2 ? _kDanger : _kElectric,
                ),
              ))),
            ];
          }),

          // ── Cell countdown boxes ─────────────────────────────────────────
          ...widget.controller.activeDrops.expand((d) {
            final r = widget.getCellRect(d.col, d.row);
            if (r == null) return const <Widget>[];
            final urgent = d.secondsLeft <= 2;
            final f = urgent ? _flash.value : 1.0;
            final c = urgent ? _kDanger : _kElectric;
            return <Widget>[
              Positioned(left: r.left, top: r.top, width: r.width, height: r.height,
                child: IgnorePointer(child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withOpacity(f * 0.92), width: urgent ? 3 : 2),
                    color: c.withOpacity(f * (urgent ? 0.26 : 0.12)),
                    boxShadow: [BoxShadow(color: c.withOpacity(f * 0.55), blurRadius: 16, spreadRadius: 2)]),
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned(top: 3, child: Text('⚡',
                      style: TextStyle(fontSize: 17,
                        shadows: [Shadow(color: c, blurRadius: 8)]))),
                    Positioned(bottom: 3, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: c.withOpacity(0.75), width: 1)),
                      child: Text('${d.secondsLeft}s',
                        style: TextStyle(color: urgent ? _kDanger : _kElectric,
                          fontSize: 10, fontWeight: FontWeight.w900)))),
                  ])))),
              // Crackle sparks orbiting the targeted cell
              ..._buildSparks(r.center, _spark.value, c, urgent),
            ];
          }),
        ]);
      }),
    );
  }

  List<Widget> _buildSparks(Offset center, double t, Color color, bool urgent) {
    final count = urgent ? 7 : 4;
    return List.generate(count, (i) {
      final a     = (i / count) * math.pi * 2 + t * math.pi * 2 * (urgent ? 1.8 : 1.0);
      final reach = 23 + math.sin(t * math.pi * 2 + i) * 7;
      final dx    = center.dx + math.cos(a) * reach;
      final dy    = center.dy + math.sin(a) * reach;
      const sz = 4.5;
      return Positioned(left: dx - sz / 2, top: dy - sz / 2,
        child: IgnorePointer(child: Container(width: sz, height: sz,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.88),
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)]))));
    });
  }
}

class _CellBlast {
  final AnimationController ctrl;
  final Offset center;
  _CellBlast({required this.ctrl, required this.center});
}

// ── Snake Jr. Cell Indicators ─────────────────────────────────────────────────
class _SnakeJrCells extends StatefulWidget {
  final SnakeAlienController controller;
  final Rect? Function(int, int) getCellRect;
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
              border: Border.all(color: _kDanger.withOpacity(0.70 + _c.value * 0.30), width: 2.5),
              color: _kDanger.withOpacity(0.15 + _c.value * 0.10),
              boxShadow: [BoxShadow(color: _kDanger.withOpacity(0.35 + _c.value * 0.20), blurRadius: 12)]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🤖', style: TextStyle(fontSize: 17)),
              Text('JR.', style: TextStyle(color: _kDanger, fontSize: 8, fontWeight: FontWeight.w900)),
            ]))));
      }).toList())));
}

// ── Win Blast — 3D Printer Laser + AAA Particle Explosion ─────────────────────
class _WinBlast extends StatefulWidget {
  final SnakeAlienController controller;
  const _WinBlast({required this.controller});
  @override State<_WinBlast> createState() => _WinBlastState();
}
class _WinBlastState extends State<_WinBlast> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  final _rng = Random();
  final List<_P> _ps = [];
  final List<_Coin> _cs = [];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5400))..forward();
    // 150 particles for AAA quality
    for (int i = 0; i < 150; i++) {
      _ps.add(_P(
        _rng.nextDouble() * math.pi * 2,
        0.18 + _rng.nextDouble() * 0.82,
        2 + _rng.nextDouble() * 14,
        [_kElectric, const Color(0xFF00FFCC), const Color(0xFFFFEE00),
         _kDanger, const Color(0xFF7B1FA2), Colors.white, _kWarn][_rng.nextInt(7)],
        _rng.nextDouble() * 0.28,
      ));
    }
    for (int i = 0; i < 72; i++) {
      _cs.add(_Coin(_rng.nextDouble(), 0.28 + _rng.nextDouble() * 0.50,
        0.35 + _rng.nextDouble() * 0.65, 13 + _rng.nextDouble() * 13));
    }
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz  = MediaQuery.of(context).size;
    final cx  = sz.width / 2;
    final ey  = sz.height * 0.26;            // creature was near here
    final lStart = Offset(cx, sz.height * 0.91); // 3D printer (bottom area)
    final lEnd   = Offset(cx, ey);

    final lvl = widget.controller.currentLevel;
    final dd  = widget.controller.deathDialogue;

    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = _c.value;
      // Phase 1 (0.00–0.22): 3D printer laser travels upward
      final laserT    = (t / 0.22).clamp(0.0, 1.0);
      final laserOp   = (t < 0.22) ? (laserT * (1 - laserT * 0.4)).clamp(0.0, 1.0) : 0.0;
      // Phase 2 (0.18+): explosion spreads
      final explodeT  = ((t - 0.18) / 0.82).clamp(0.0, 1.0);

      return Stack(children: [
        // Background
        Positioned.fill(child: IgnorePointer(child: Container(
          color: Colors.black.withOpacity((math.sin(t * math.pi) * 0.90).clamp(0.0, 0.90))))),

        // Phase 1 — laser beam from printer to boss
        if (laserOp > 0.01)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _LaserBeamPainter(
              start: lStart, end: lEnd,
              progress: laserT, opacity: laserOp,
            ),
          ))),

        // Explosion flash (when laser hits)
        if (t > 0.18 && t < 0.44)
          Positioned.fill(child: IgnorePointer(child: Container(
            color: _kElectric.withOpacity(
              (math.sin(((t - 0.18) / 0.26) * math.pi) * 0.78).clamp(0.0, 0.78))))),

        // 3 shockwave rings expanding outward
        if (explodeT > 0) ...List.generate(3, (ri) {
          final rDelay = ri * 0.13;
          final rT     = ((explodeT - rDelay) / (1.0 - rDelay)).clamp(0.0, 1.0);
          if (rT <= 0) return const SizedBox.shrink();
          final ringR   = rT * sz.width * 0.82;
          final ringOp  = (1 - rT * 1.50).clamp(0.0, 0.68);
          if (ringOp <= 0.01) return const SizedBox.shrink();
          final ringCol = [_kElectric, Colors.white, _kWarn][ri];
          return Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _ShockwavePainter(
              center: Offset(cx, ey), radius: ringR,
              opacity: ringOp, color: ringCol,
            ),
          )));
        }),

        // Particles
        ..._ps.map((p) {
          if (explodeT <= 0) return const SizedBox.shrink();
          final pr = ((explodeT - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final dx = cx + math.cos(p.angle) * pr * sz.width  * 0.82 * p.speed;
          final dy = ey + math.sin(p.angle) * pr * sz.height * 0.82 * p.speed;
          final op = ((1 - pr) * (1 - pr)).clamp(0.0, 1.0);
          return Positioned(left: dx - p.size / 2, top: dy - p.size / 2,
            child: IgnorePointer(child: Container(width: p.size, height: p.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
                boxShadow: [BoxShadow(color: p.color.withOpacity(op * 0.5), blurRadius: p.size * 2)]))));
        }),

        // Coin shower
        ..._cs.map((coin) {
          if (explodeT <= 0) return const SizedBox.shrink();
          final pr = ((explodeT - coin.delay) / (1 - coin.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final op = t > 0.88 ? ((1 - t) / 0.12).clamp(0.0, 1.0) : 1.0;
          return Positioned(
            left: coin.x * sz.width - coin.size / 2,
            top:  pr * sz.height * 1.1 * coin.speed - coin.size / 2,
            child: IgnorePointer(child: Opacity(opacity: op,
              child: Text('💰', style: TextStyle(fontSize: coin.size)))));
        }),

        // Victory text
        if (t > 0.34)
          Positioned(top: sz.height * 0.34, left: 18, right: 18,
            child: Opacity(opacity: ((t - 0.34) / 0.42).clamp(0.0, 1.0),
              child: Column(children: [
                Text('🤖 EXOSUIT DESTROYED! 💥', textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _kElectric, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2,
                    shadows: [Shadow(color: _kElectric, blurRadius: 24),
                              Shadow(color: Colors.white, blurRadius: 10)])),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.72))),
                  child: const Text('+50 COINS BONUS! 💰',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900))),
                if (lvl == 38 && dd != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kElectric.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kElectric.withOpacity(0.55), width: 1.5),
                      boxShadow: [BoxShadow(color: _kElectric.withOpacity(0.28), blurRadius: 14)]),
                    child: Column(children: [
                      Text('💬 LAST WORDS:', style: TextStyle(color: _kElectric, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text('"$dd"', textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                    ])),
                  const SizedBox(height: 10),
                  const Text('🏆 ALL BOSSES DEFEATED!\nYou are the Ultimate Tech Tycoon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFFFD600), fontSize: 16, fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Color(0xFFFFD600), blurRadius: 18)])),
                ],
              ]))),
      ]);
    });
  }
}

// ── Exosuit Body Widget ────────────────────────────────────────────────────────
class _ExosuitBody extends StatelessWidget {
  final double limbExt;   // 0→1 arm/leg oscillation phase
  final double glow;      // 0→1 body glow pulse
  final double eyeT;      // 0→1 eye blink (0=open, 1=closed)
  final double electricT; // 0→2π electricity arc phase
  const _ExosuitBody({
    required this.limbExt,
    required this.glow,
    required this.eyeT,
    required this.electricT,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 165,
    child: CustomPaint(
      painter: _ExosuitPainter(
        limbExt:   limbExt,
        glow:      glow,
        eyeT:      eyeT,
        electricT: electricT,
      ),
    ),
  );
}

// ── Exosuit Painter ──────────────────────────────────────────────────────────
class _ExosuitPainter extends CustomPainter {
  final double limbExt, glow, eyeT, electricT;
  const _ExosuitPainter({
    required this.limbExt,
    required this.glow,
    required this.eyeT,
    required this.electricT,
  });

  // ── Armor plate helper ────────────────────────────────────────────────────
  void _plate(Canvas c, Rect r, {double radius = 4}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    // Drop shadow
    c.drawRRect(rr.inflate(1.8), Paint()
      ..color = Colors.black.withOpacity(0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Metal fill
    c.drawRRect(rr, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [_kArmorHL, _kArmor, _kArmorDark],
    ).createShader(r));
    // Top edge highlight (reads as catch-light)
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 1, r.top + 1, r.width - 2, r.height * 0.28), const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.09));
    // Rim light
    c.drawRRect(rr, Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9);
    // Electric trim
    c.drawRRect(rr, Paint()
      ..color = _kElectric.withOpacity(0.16 + glow * 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1);
  }

  // ── Tech line helper ──────────────────────────────────────────────────────
  void _tech(Canvas c, Offset a, Offset b, {double alpha = 0.40}) {
    c.drawLine(a, b, Paint()
      ..color = _kElectric.withOpacity((alpha + glow * 0.18).clamp(0.0, 1.0))
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  // ── Electricity arc ───────────────────────────────────────────────────────
  void _arc(Canvas canvas, Offset start, Offset end, double phase) {
    const segs = 7;
    final path = Path();
    path.moveTo(start.dx, start.dy);
    final ddx = end.dx - start.dx;
    final ddy = end.dy - start.dy;
    final len = math.sqrt(ddx * ddx + ddy * ddy);
    if (len < 1) return;
    final nx = -ddy / len;
    final ny =  ddx / len;
    for (int i = 1; i < segs; i++) {
      final t   = i / segs;
      final px  = start.dx + ddx * t;
      final py  = start.dy + ddy * t;
      final off = math.sin(phase + i * 1.35) * 5.0;
      path.lineTo(px + nx * off, py + ny * off);
    }
    path.lineTo(end.dx, end.dy);
    // Glow
    canvas.drawPath(path, Paint()
      ..color = _kElectric.withOpacity(0.18 + glow * 0.10)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Bright inner line
    canvas.drawPath(path, Paint()
      ..color = _kElectric.withOpacity(0.65 + glow * 0.28)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const cx = 60.0;

    // ── Body aura ──────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(7, 4, 106, 156), const Radius.circular(20)),
      Paint()
        ..color = _kElectric.withOpacity(0.06 + glow * 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));

    // ── Legs (animated step) ──────────────────────────────────────────────
    final lLegY =  math.sin(limbExt * math.pi * 2) * 3.5;
    final rLegY = math.sin(limbExt * math.pi * 2 + math.pi) * 3.5;
    _plate(canvas, Rect.fromLTWH(16, 112 + lLegY, 28, 36), radius: 4);
    _plate(canvas, Rect.fromLTWH(76, 112 + rLegY, 28, 36), radius: 4);
    // Piston detail lines
    _tech(canvas, Offset(cx - 28, 114 + lLegY), Offset(cx - 28, 140 + lLegY), alpha: 0.40);
    _tech(canvas, Offset(cx + 28, 114 + rLegY), Offset(cx + 28, 140 + rLegY), alpha: 0.40);
    // Leg joint electricity arcs
    _arc(canvas, Offset(cx - 20, 112 + lLegY), Offset(cx - 20, 148 + lLegY), electricT);
    _arc(canvas, Offset(cx + 20, 112 + rLegY), Offset(cx + 20, 148 + rLegY), electricT + math.pi);

    // ── Boots ──────────────────────────────────────────────────────────────
    _plate(canvas, Rect.fromLTWH(10, 142 + lLegY, 40, 14), radius: 5);
    _plate(canvas, Rect.fromLTWH(70, 142 + rLegY, 40, 14), radius: 5);
    // Boot toe lines
    _tech(canvas, Offset(10, 150 + lLegY), Offset(50, 150 + lLegY), alpha: 0.25);
    _tech(canvas, Offset(70, 150 + rLegY), Offset(110, 150 + rLegY), alpha: 0.25);

    // ── Hip plate ─────────────────────────────────────────────────────────
    _plate(canvas, Rect.fromLTWH(14, 103, 92, 14), radius: 4);
    _tech(canvas, Offset(cx - 32, 110), Offset(cx + 32, 110), alpha: 0.30);

    // ── Torso ─────────────────────────────────────────────────────────────
    _plate(canvas, Rect.fromLTWH(10, 50, 100, 57), radius: 6);
    // Horizontal tech lines across torso
    _tech(canvas, Offset(cx - 34, 64),  Offset(cx + 34, 64),  alpha: 0.35);
    _tech(canvas, Offset(cx - 34, 100), Offset(cx + 34, 100), alpha: 0.35);
    _tech(canvas, Offset(cx, 52),  Offset(cx, 66),  alpha: 0.22);
    _tech(canvas, Offset(cx, 98),  Offset(cx, 108), alpha: 0.22);

    // ── Energy core ────────────────────────────────────────────────────────
    final cg = 0.55 + glow * 0.45;
    // Outer glow
    canvas.drawCircle(const Offset(cx, 79), 20, Paint()
      ..color = _kElectric.withOpacity(cg * 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    // Ring
    canvas.drawCircle(const Offset(cx, 79), 16, Paint()
      ..color = _kElectric.withOpacity(cg * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8);
    // Inner fill
    canvas.drawCircle(const Offset(cx, 79), 11, Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.90), _kElectric.withOpacity(0.80), _kArmor],
      ).createShader(Rect.fromCircle(center: const Offset(cx, 79), radius: 11)));
    // Sparkle
    canvas.drawCircle(const Offset(cx - 3, 76), 3.0, Paint()
      ..color = Colors.white.withOpacity(0.95));
    // Small secondary dot
    canvas.drawCircle(const Offset(cx + 4, 81), 1.8, Paint()
      ..color = Colors.white.withOpacity(0.70));

    // ── Shoulder cannons ──────────────────────────────────────────────────
    _plate(canvas, Rect.fromLTWH(-1, 47, 17, 46), radius: 4);
    // Left cannon barrel
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-7, 61, 13, 9), const Radius.circular(3)),
      Paint()..color = _kArmorDark);
    canvas.drawCircle(const Offset(-4, 65), 3.5, Paint()
      ..color = _kElectric.withOpacity(0.48 + glow * 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    _plate(canvas, Rect.fromLTWH(104, 47, 17, 46), radius: 4);
    // Right cannon barrel
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(114, 61, 13, 9), const Radius.circular(3)),
      Paint()..color = _kArmorDark);
    canvas.drawCircle(const Offset(124, 65), 3.5, Paint()
      ..color = _kElectric.withOpacity(0.48 + glow * 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // ── Arms ──────────────────────────────────────────────────────────────
    final lSwing = -0.20 - limbExt * 0.30;
    final rSwing =  0.20 + limbExt * 0.30;

    // Left arm
    canvas.save();
    canvas.translate(8, 90);
    canvas.rotate(lSwing);
    _plate(canvas, Rect.fromLTWH(-7, 0, 14, 30), radius: 4);
    _tech(canvas, const Offset(0, 4), const Offset(0, 26), alpha: 0.50);
    canvas.drawCircle(const Offset(0, 30), 5, Paint()
      ..color = _kArmorMid
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    _arc(canvas, Offset.zero, const Offset(0, 30), electricT + 0.5);
    _plate(canvas, Rect.fromLTWH(-6, 30, 12, 26), radius: 3);
    _drawClaw(canvas, const Offset(0, 56), true);
    canvas.restore();

    // Right arm
    canvas.save();
    canvas.translate(112, 90);
    canvas.rotate(rSwing);
    _plate(canvas, Rect.fromLTWH(-7, 0, 14, 30), radius: 4);
    _tech(canvas, const Offset(0, 4), const Offset(0, 26), alpha: 0.50);
    canvas.drawCircle(const Offset(0, 30), 5, Paint()
      ..color = _kArmorMid
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    _arc(canvas, Offset.zero, const Offset(0, 30), electricT + 1.5);
    _plate(canvas, Rect.fromLTWH(-6, 30, 12, 26), radius: 3);
    _drawClaw(canvas, const Offset(0, 56), false);
    canvas.restore();

    // ── Neck connector ────────────────────────────────────────────────────
    _plate(canvas, Rect.fromLTWH(38, 40, 44, 14), radius: 4);

    // ── Helmet ─────────────────────────────────────────────────────────────
    final helmetRect = Rect.fromLTWH(12, 0, 96, 47);
    final helmetRR   = RRect.fromRectAndRadius(helmetRect, const Radius.circular(9));
    // Outer glow
    canvas.drawRRect(helmetRR.inflate(2), Paint()
      ..color = _kElectric.withOpacity(0.22 + glow * 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    // Metal fill
    canvas.drawRRect(helmetRR, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [_kArmorHL, _kArmorMid, _kArmor, _kArmorDark],
    ).createShader(helmetRect));
    // Top highlight band
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(12, 0, 96, 14), const Radius.circular(9)),
      Paint()..color = Colors.white.withOpacity(0.09));
    // Rim
    canvas.drawRRect(helmetRR, Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9);
    canvas.drawRRect(helmetRR, Paint()
      ..color = _kElectric.withOpacity(0.28 + glow * 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8);

    // ── Visor / Eyes ───────────────────────────────────────────────────────
    final eyeOpen = (1.0 - eyeT * 0.94).clamp(0.05, 1.0);
    final eyeH    = 15.0 * eyeOpen;
    final eyeY    = 13.0 + (15 - eyeH) / 2;

    for (final isLeft in [true, false]) {
      final ex = isLeft ? 20.0 : 70.0;
      final eye = Rect.fromLTWH(ex, eyeY, 30, eyeH.clamp(1.0, 15));
      final er  = RRect.fromRectAndRadius(eye, const Radius.circular(3));
      // Glow
      canvas.drawRRect(er.inflate(4), Paint()
        ..color = _kElectric.withOpacity((0.38 + glow * 0.38) * eyeOpen)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      // Fill
      canvas.drawRRect(er, Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.88 * eyeOpen), _kElectric.withOpacity(0.82 * eyeOpen)],
      ).createShader(eye));
      // Scanlines
      if (eyeOpen > 0.35) {
        for (int si = 0; si < 3; si++) {
          final ly = eye.top + (eye.height / 4) * (si + 1);
          canvas.drawLine(Offset(eye.left + 2, ly), Offset(eye.right - 2, ly),
            Paint()..color = Colors.black.withOpacity(0.22)..strokeWidth = 0.8);
        }
      }
    }

    // ── Helmet vents ──────────────────────────────────────────────────────
    for (int i = 0; i < 3; i++) {
      _tech(canvas, Offset(20 + i * 8, 34), Offset(20 + i * 8, 42), alpha: 0.22);
      _tech(canvas, Offset(76 + i * 8, 34), Offset(76 + i * 8, 42), alpha: 0.22);
    }

    // ── Antenna ───────────────────────────────────────────────────────────
    canvas.drawLine(const Offset(cx, 0), const Offset(cx, -19),
      Paint()..color = _kElectric.withOpacity(0.72)..strokeWidth = 2.0);
    canvas.drawCircle(const Offset(cx, -22), 5.5, Paint()
      ..color = _kElectric.withOpacity(0.68 + glow * 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(const Offset(cx, -22), 3, Paint()
      ..color = Colors.white.withOpacity(0.90));
  }

  void _drawClaw(Canvas canvas, Offset tip, bool isLeft) {
    final sign = isLeft ? -1.0 : 1.0;
    final col  = Color.lerp(_kArmorHL, _kElectric, glow * 0.45)!;
    for (int i = 0; i < 3; i++) {
      final xOff = (i - 1) * 4.5;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx + xOff, tip.dy)
          ..lineTo(tip.dx + xOff + sign * 7, tip.dy + 14)
          ..lineTo(tip.dx + xOff - sign * 1.5, tip.dy + 9)
          ..close(),
        Paint()..color = col.withOpacity(0.95));
    }
  }

  @override
  bool shouldRepaint(_ExosuitPainter o) =>
      o.limbExt != limbExt || o.glow != glow ||
      o.eyeT != eyeT || o.electricT != electricT;
}

// ── Lightning Line Painter (creature → targeted cells) ────────────────────────
class _LightningPainter extends CustomPainter {
  final Offset start, end;
  final double phase, opacity;
  final Color color;
  const _LightningPainter({
    required this.start, required this.end,
    required this.phase, required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.02) return;
    const segs = 9;
    final path = Path();
    path.moveTo(start.dx, start.dy);
    final ddx = end.dx - start.dx;
    final ddy = end.dy - start.dy;
    final len = math.sqrt(ddx * ddx + ddy * ddy);
    if (len < 5) return;
    final nx = -ddy / len;
    final ny =  ddx / len;
    for (int i = 1; i < segs; i++) {
      final t   = i / segs;
      final px  = start.dx + ddx * t;
      final py  = start.dy + ddy * t;
      final off = math.sin(phase + i * 1.2) * (6 + math.cos(phase * 0.7 + i) * 4);
      path.lineTo(px + nx * off, py + ny * off);
    }
    path.lineTo(end.dx, end.dy);

    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(opacity * 0.40)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(opacity * 0.90)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withOpacity(opacity * 0.48)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_LightningPainter o) =>
      o.start != start || o.end != end ||
      o.phase != phase || o.opacity != opacity;
}

// ── 3D Printer Laser Painter ──────────────────────────────────────────────────
class _LaserBeamPainter extends CustomPainter {
  final Offset start, end;
  final double progress, opacity;
  const _LaserBeamPainter({
    required this.start, required this.end,
    required this.progress, required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.02 || progress < 0.02) return;
    final currEnd = Offset(
      start.dx + (end.dx - start.dx) * progress,
      start.dy + (end.dy - start.dy) * progress,
    );
    // Wide outer glow
    canvas.drawLine(start, currEnd, Paint()
      ..color = _kElectric.withOpacity(opacity * 0.32)
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    // Mid glow
    canvas.drawLine(start, currEnd, Paint()
      ..color = _kElectric.withOpacity(opacity * 0.65)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round);
    // Bright core
    canvas.drawLine(start, currEnd, Paint()
      ..color = Colors.white.withOpacity(opacity * 0.96)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
    // Impact halo at travel point
    canvas.drawCircle(currEnd, 16, Paint()
      ..color = _kElectric.withOpacity(opacity * 0.48)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(currEnd, 6, Paint()
      ..color = Colors.white.withOpacity(opacity * 0.92));
  }

  @override
  bool shouldRepaint(_LaserBeamPainter o) =>
      o.progress != progress || o.opacity != opacity;
}

// ── Shockwave Ring Painter ─────────────────────────────────────────────────────
class _ShockwavePainter extends CustomPainter {
  final Offset center;
  final double radius, opacity;
  final Color color;
  const _ShockwavePainter({
    required this.center, required this.radius,
    required this.opacity, required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.01 || radius < 1) return;
    canvas.drawCircle(center, radius, Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawCircle(center, radius * 0.87, Paint()
      ..color = color.withOpacity(opacity * 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_ShockwavePainter o) =>
      o.radius != radius || o.opacity != opacity;
}

// ── L38 Hint Banner ────────────────────────────────────────────────────────────
class _L38HintBanner extends StatelessWidget {
  final String icon, text;
  final Key hintKey;
  const _L38HintBanner({required this.icon, required this.text, required this.hintKey});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
          child: child)),
      child: Container(
        key: hintKey,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF001820).withOpacity(0.95), const Color(0xFF000E18).withOpacity(0.95)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kElectric.withOpacity(0.65), width: 1.3),
          boxShadow: [BoxShadow(color: _kElectric.withOpacity(0.22), blurRadius: 10, spreadRadius: 1)]),
        child: Row(children: [
          Container(width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _kElectric.withOpacity(0.18),
              border: Border.all(color: _kElectric.withOpacity(0.55), width: 1)),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 10))),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10,
            fontWeight: FontWeight.w800, height: 1.28, letterSpacing: 0.14))),
        ]),
      ),
    );
  }
}

// ── Rules Card ──────────────────────────────────────────────────────────────────
class _RulesCard extends StatelessWidget {
  final int level;
  const _RulesCard({required this.level});
  @override
  Widget build(BuildContext context) {
    final n = kSnakeAlienLevels[level] ?? 40;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF001820).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kElectric.withOpacity(0.85), width: 2),
        boxShadow: [BoxShadow(color: _kElectric.withOpacity(0.28), blurRadius: 22)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🤖 LEVEL $level — EXOSUIT ALIEN', style: const TextStyle(color: _kElectric,
          fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: _kElectric.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kElectric.withOpacity(0.55))),
          child: const Text('🎯 WIN: Complete the DELIVERY QUOTA — triggers the laser!',
            style: TextStyle(color: _kElectric, fontSize: 10, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        _r('⚡', 'Every 5s: 5 cells get zapped by electricity — 5s fuse!'),
        _r('✅', 'Merge items on a zapped cell before fuse = 0 → saved!'),
        _r('💥', 'Fuse hits 0? That item EXPLODES + you lose energy!'),
        _r('🖨️', 'Deliver all quota → 3D Printer fires LASER → Boss destroyed!'),
        _r('💰', 'Defeat = +50 COINS BONUS!'),
        if (level == 38)
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: _kDanger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kDanger.withOpacity(0.45))),
              child: Text('👑 FINAL BOSS — Defeat the Exosuit to conquer all $n levels!',
                style: TextStyle(color: _kDanger.withOpacity(0.90), fontSize: 10, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center))),
      ]));
  }
  Widget _r(String i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(children: [Text(i, style: const TextStyle(fontSize: 14)), const SizedBox(width: 7),
      Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.4)))]));
}

// ── Dialogue Bubble ────────────────────────────────────────────────────────────
class _DialogueBubble extends StatelessWidget {
  final String text;
  final Color color;
  const _DialogueBubble({required this.text, required this.color});
  @override Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF001820).withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.9), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 16)]),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
    Positioned(bottom: -10, left: 0, right: 0,
      child: Center(child: CustomPaint(size: const Size(16, 10), painter: _Tail(color: color)))),
  ]);
}
class _Tail extends CustomPainter {
  final Color color;
  const _Tail({required this.color});
  @override void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width / 2, size.height)..close(),
      Paint()..color = color.withOpacity(0.9));
  }
  @override bool shouldRepaint(_) => false;
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
class _P {
  final double angle, speed, size, delay;
  final Color color;
  const _P(this.angle, this.speed, this.size, this.color, this.delay);
}
class _Coin {
  final double x, delay, speed, size;
  const _Coin(this.x, this.delay, this.speed, this.size);
}
