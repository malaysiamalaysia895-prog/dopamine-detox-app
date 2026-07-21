// antigravity_overlay.dart — "Anti-Gravity" Boss UI (Level 37)
// Liquid-metal jellyfish/cyborg hybrid: shapeless morphing body, deep nebula
// blue + dark violet palette, glowing white neon-star core, purple gravity
// aura, orbiting debris, heat-distortion trail while it drifts, a telegraphed
// warning ring on cells about to be pulled, and a blackhole-vortex flight
// that carries doomed items up into the boss's containment jar.

import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/antigravity_controller.dart';
import '../models/models.dart';

const _kNebulaBlue = Color(0xFF1A2A6C);
const _kDeepViolet = Color(0xFF4B1E8C);
const _kCoreWhite  = Color(0xFFF5FBFF);
const _kAuraPurple = Color(0xFFB47CFF);
const _kWarnAmber  = Color(0xFFFFC163);

/// Fixed on-screen anchor for the containment jar (top-right corner), shared
/// between the jar badge and the fly-to-jar attack animation so items always
/// converge on exactly where the jar icon is drawn.
Offset _jarAnchor(Size sz) => Offset(sz.width - 40, sz.height * 0.135);

/// Rest position the boss settles at once its entry animation completes —
/// shared by the entry animation's end point and the active-phase drift's
/// starting anchor so there is no visual jump at the phase handoff.
double _restY(Size sz) => sz.height * 0.30;

class AntiGravityOverlay extends StatelessWidget {
  final AntiGravityController controller;
  final Rect? Function(int col, int row) getCellRect;
  final bool isDialogActive;
  const AntiGravityOverlay({super.key, required this.controller, required this.getCellRect, this.isDialogActive = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: (context, _) {
      final p = controller.phase;
      if (p == AntiGravityPhase.idle) return const SizedBox.shrink();
      if (isDialogActive) return const SizedBox.shrink();
      return Stack(children: [
        if (p == AntiGravityPhase.entry) _Entry(controller: controller),
        if (p == AntiGravityPhase.active) _Active(controller: controller),
        if (p == AntiGravityPhase.active) _TelegraphEffects(controller: controller, getCellRect: getCellRect),
        if (p == AntiGravityPhase.active) _PullEffects(controller: controller, getCellRect: getCellRect),
        if (p == AntiGravityPhase.active && controller.jarCount > 0) _JarBadge(count: controller.jarCount),
        if (p == AntiGravityPhase.winBlast) _WinBlast(),
      ]);
    });
  }
}

// ── Entry Animation ────────────────────────────────────────────────────────────
class _Entry extends StatefulWidget {
  final AntiGravityController controller; const _Entry({required this.controller});
  @override State<_Entry> createState() => _EntryState();
}
class _EntryState extends State<_Entry> with TickerProviderStateMixin {
  late AnimationController _main, _morph, _rules;
  late Animation<double> _sc; late Animation<double> _descend; late Animation<double> _dark;
  final _rng = Random(); final List<_Shard> _shards = [];
  @override void initState() {
    super.initState();
    _main  = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..forward();
    _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _rules = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    // Gentle overshoot-free settle: shrinks in from big, eases down to 1.0 —
    // no curve overshoot on the driving controller, so no out-of-range frame.
    _sc = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.15, end: 1.18).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
    ]).animate(_main);
    // Progress 1 → 0: how far the boss still is from its final rest point.
    _descend = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _main, curve: Curves.easeOutCubic));
    // Darken-in then fade back OUT before the entry ends, so the handoff to
    // the active phase is a smooth reveal instead of an abrupt brightness cut
    // (this abrupt cut was reported as a "white flash").
    _dark = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.68), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 0.68, end: 0.68), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.68, end: 0.0), weight: 32),
    ]).animate(CurvedAnimation(parent: _main, curve: Curves.easeInOut));
    for (int i = 0; i < 26; i++) {
      _shards.add(_Shard(_rng.nextDouble()*math.pi*2, 0.2+_rng.nextDouble()*0.6, 3+_rng.nextDouble()*6, _rng.nextDouble()));
    }
    _main.addStatusListener((s) { if (s == AnimationStatus.completed && mounted) _rules.forward(); });
  }
  @override void dispose() { _main.dispose(); _morph.dispose(); _rules.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size; final cx = sz.width/2;
    final restY = _restY(sz);
    // Descend from just above the top edge down to the shared rest point —
    // this exactly matches where _Active picks the boss up, so there is no
    // jump cut when the phase switches.
    return AnimatedBuilder(animation: Listenable.merge([_main, _morph, _rules]), builder: (_, __) {
      final by = restY - _descend.value * (restY * 0.9 + 40);
      final bx = cx;
      return Stack(children: [
        Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black.withOpacity(_dark.value.clamp(0.0, 0.68))))),
        ..._shards.map((s) {
          final dx = bx + math.cos(s.angle+_morph.value*math.pi)*sz.width*0.18*s.reach;
          final dy = by + math.sin(s.angle+_morph.value*math.pi)*sz.height*0.14*s.reach;
          final op = (_main.value*0.9).clamp(0.0,0.9);
          return Positioned(left: dx-s.size/2, top: dy-s.size/2, child: IgnorePointer(child: Container(
            width: s.size, height: s.size,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _kAuraPurple.withOpacity(op*0.7),
              boxShadow: [BoxShadow(color: _kAuraPurple.withOpacity(op*0.5), blurRadius: s.size*1.4)]))));
        }),
        Positioned(left: bx-80, top: by-80,
          child: IgnorePointer(child: Transform.scale(scale: _sc.value,
            child: _AntiGravityBody(morph: _morph.value, glow: 0.75+_morph.value*0.25)))),
        if (_rules.value > 0.01)
          Positioned(bottom: sz.height*0.06, left: 16, right: 16,
            child: Opacity(opacity: _rules.value, child: const _RulesCard())),
      ]);
    });
  }
}

// ── Active (ambient hover) ────────────────────────────────────────────────────
class _Active extends StatefulWidget {
  final AntiGravityController controller; const _Active({required this.controller});
  @override State<_Active> createState() => _ActiveState();
}
class _ActiveState extends State<_Active> with TickerProviderStateMixin {
  late AnimationController _morph, _orbit, _drift, _dlg;
  String? _prevDlg;
  final _rng = Random();
  late Offset _fromAnchor, _toAnchor;

  // Coach-voice hints — NOT through the creature's dialogue bubble.
  int _hintIndex = 0;
  Timer? _hintTimer;
  static const _kHints = [
    ('💡', 'Merge items early — once merged they\'re safe from the gravity pull!'),
    ('🔀', 'See a violet glowing cell? Merge that item before the 5-second window closes.'),
    ('⚡', 'Item not merged when time runs out = destroyed + 15 energy penalty.'),
    ('🎯', 'You only need to merge an item once to protect it from the gravity attack.'),
  ];

  @override void initState() {
    super.initState();
    _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();
    _dlg   = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _drift = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600))..repeat();
    _fromAnchor = const Offset(0.0, 0.0);
    _toAnchor   = _randomAnchor();
    _drift.addListener(() { if (_drift.value < 0.01 && mounted) setState(() { _fromAnchor = _toAnchor; _toAnchor = _randomAnchor(); }); });
    widget.controller.addListener(_onChange);
    // Rotate coach hint every 5 s — independent of creature dialogue cycle.
    _hintTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _hintIndex = (_hintIndex + 1) % _kHints.length);
    });
  }
  Offset _randomAnchor() => Offset((_rng.nextDouble()-0.5)*0.5, (_rng.nextDouble()-0.5)*0.12);
  void _onChange() { final d = widget.controller.dialogueText; if (d != _prevDlg && d != null) { _prevDlg = d; _dlg.forward(from: 0); } }
  @override void dispose() {
    widget.controller.removeListener(_onChange);
    _hintTimer?.cancel();
    _morph.dispose(); _orbit.dispose(); _drift.dispose(); _dlg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size; final cx = sz.width/2; final by = _restY(sz);
    final c = widget.controller;
    return AnimatedBuilder(animation: Listenable.merge([_morph, _orbit, _drift, _dlg]), builder: (_, __) {
      final dt = Curves.easeInOut.transform(_drift.value);
      final anchor = Offset.lerp(_fromAnchor, _toAnchor, dt)!;
      final bx = cx + anchor.dx*sz.width; final byy = by + anchor.dy*sz.height*0.6;
      final orb = _orbit.value*math.pi*2;
      final trailStrength = (math.sin(dt*math.pi)).clamp(0.0, 1.0); // strongest mid-transit
      return Stack(children: [
        // Heat-distortion / space-bending trail behind the boss's drift path
        ..._distortionTrail(bx, byy, _fromAnchor, anchor, cx, by, sz, trailStrength),
        // Purple gravity aura
        Positioned(left: bx-95, top: byy-95, child: IgnorePointer(child: Container(width: 190, height: 190,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _kAuraPurple.withOpacity(0.22+_morph.value*0.1), Colors.transparent,
            ], stops: const [0.35, 1.0]))))),
        // Orbiting debris: asteroids / broken gears / glass shards
        ...List.generate(5, (i) {
          final a = orb + i*(math.pi*2/5);
          final rr = 62.0 + math.sin(a*1.3)*8;
          final dx = bx + math.cos(a)*rr; final dy = byy + math.sin(a)*rr*0.55;
          final kinds = ['🪨', '⚙️', '💎', '🪨', '⚙️'];
          return Positioned(left: dx-9, top: dy-9, child: IgnorePointer(child: Transform.rotate(
            angle: a*2, child: Text(kinds[i], style: const TextStyle(fontSize: 16)))));
        }),
        Positioned(left: bx-80, top: byy-80, child: IgnorePointer(
          child: _AntiGravityBody(morph: _morph.value, glow: 0.75+_morph.value*0.25))),
        // Creature flavor-taunt bubble (attack warnings only — no hints here)
        if (c.dialogueText != null)
          Positioned(top: byy-64, left: bx-150, width: 300,
            child: ScaleTransition(scale: CurvedAnimation(parent: _dlg, curve: Curves.elasticOut),
              child: _DialogueBubble(text: c.dialogueText!, warning: c.isWarning))),
        // ── Coach-voice hint banner — fixed just below creature, NOT a
        //    creature speech bubble; reads as a neutral game HUD tip row.
        Positioned(left: 16, right: 16, top: by + 110,
          child: _AntiGravHintBanner(
            icon: c.telegraphCells.isNotEmpty ? '⚠️' : _kHints[_hintIndex].$1,
            text: c.telegraphCells.isNotEmpty
                ? 'Merge the violet-glowing item NOW — 5 seconds before it\'s absorbed!'
                : _kHints[_hintIndex].$2,
            isUrgent: c.telegraphCells.isNotEmpty,
            hintKey: ValueKey(c.telegraphCells.isNotEmpty ? 'atk' : _hintIndex),
          )),
      ]);
    });
  }

  List<Widget> _distortionTrail(double bx, double by, Offset from, Offset to, double cx, double baseY, Size sz, double strength) {
    if (strength < 0.05) return const [];
    final fx = cx + from.dx*sz.width; final fy = baseY + from.dy*sz.height*0.6;
    final steps = 5;
    final out = <Widget>[];
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final x = fx + (bx-fx)*t; final y = fy + (by-fy)*t;
      final op = strength * (1-t) * 0.35;
      out.add(Positioned(left: x-26, top: y-26, child: IgnorePointer(child: Opacity(opacity: op,
        child: Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: _kAuraPurple.withOpacity(0.6), width: 1.4),
          gradient: RadialGradient(colors: [_kAuraPurple.withOpacity(0.18), Colors.transparent])))))));
    }
    return out;
  }
}

// ── Telegraph: black holes hover over each targeted cell ─────────────────────
// Each targeted cell shows a spinning black-hole vortex descending from the
// creature, plus a "MERGE NOW!" label and a "fresh 3D-print" scanline overlay
// so the player immediately knows this item is the threat.
class _TelegraphEffects extends StatefulWidget {
  final AntiGravityController controller; final Rect? Function(int,int) getCellRect;
  const _TelegraphEffects({required this.controller, required this.getCellRect});
  @override State<_TelegraphEffects> createState() => _TelegraphEffectsState();
}
class _TelegraphEffectsState extends State<_TelegraphEffects> with TickerProviderStateMixin {
  late AnimationController _spin;  // vortex rotation
  late AnimationController _pulse; // danger pulse 0→1→0
  late AnimationController _drop;  // black hole descends from creature 0→1
  bool _lastWasEmpty = true;
  @override void initState() {
    super.initState();
    _spin  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _drop  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    widget.controller.addListener(_onChange);
  }
  void _onChange() {
    final nowEmpty = widget.controller.telegraphCells.isEmpty;
    if (_lastWasEmpty && !nowEmpty) _drop.forward(from: 0);
    _lastWasEmpty = nowEmpty;
  }
  @override void dispose() {
    widget.controller.removeListener(_onChange);
    _spin.dispose(); _pulse.dispose(); _drop.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final sz  = MediaQuery.of(context).size;
    final csx = sz.width / 2; // creature horizontal centre (approx)
    final csy = _restY(sz);   // creature vertical rest position
    return AnimatedBuilder(animation: Listenable.merge([_spin, _pulse, _drop]), builder: (_, __) =>
      ListenableBuilder(listenable: widget.controller, builder: (_, __) {
        final p  = Curves.easeInOut.transform(_pulse.value);  // 0..1
        final dr = Curves.easeOutBack.transform(_drop.value.clamp(0.0, 1.0));
        return Stack(clipBehavior: Clip.none, children: widget.controller.telegraphCells.expand((cell) {
          final r = widget.getCellRect(cell.$1, cell.$2); if (r == null) return const <Widget>[];
          final cx = r.center.dx; final cy = r.center.dy;
          // Black hole descends from creature body to cell top
          final bhY = csy + (cy - 46 - csy) * dr;
          final bhX = csx + (cx - csx) * dr;
          return <Widget>[
            // ── Descending black hole ──────────────────────────────────────
            Positioned(left: bhX - 26, top: bhY - 26,
              child: IgnorePointer(child: Transform.rotate(
                angle: _spin.value * math.pi * 2,
                child: Container(width: 52, height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [
                      Colors.black, _kAuraPurple.withOpacity(0.6),
                      Colors.black, const Color(0xFFFF00FF).withOpacity(0.3),
                      Colors.black,
                    ]),
                    boxShadow: [
                      BoxShadow(color: _kAuraPurple.withOpacity(0.8 + p*0.2), blurRadius: 18 + p*10, spreadRadius: 3),
                      BoxShadow(color: Colors.black, blurRadius: 6),
                    ]))))),
            // Black hole core
            Positioned(left: bhX - 8, top: bhY - 8,
              child: IgnorePointer(child: Container(width: 16, height: 16,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black,
                  boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.9 + p*0.1), blurRadius: 12, spreadRadius: 4)])))),
            // ── Cell danger border (urgent red-violet) ─────────────────────
            Positioned.fromRect(rect: r.inflate(4), child: IgnorePointer(child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.6 + p*0.4), width: 3 + p),
                color: const Color(0xFF5500AA).withOpacity(0.18 + p*0.1),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFAA00FF).withOpacity(0.45 + p*0.3), blurRadius: 14 + p*8, spreadRadius: 2),
                ])))),
            // ── Scanline "fresh 3D-print" overlay ─────────────────────────
            Positioned.fromRect(rect: r, child: IgnorePointer(child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(painter: _ScanlinePainter(p), size: r.size)))),
            // ── "MERGE NOW!" floating label ────────────────────────────────
            Positioned(left: cx - 38, top: r.top - 22,
              child: IgnorePointer(child: Opacity(opacity: 0.85 + p*0.15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF880000).withOpacity(0.94),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFF44FF).withOpacity(0.8), width: 1),
                    boxShadow: [BoxShadow(color: const Color(0xFFAA00FF).withOpacity(0.6), blurRadius: 10)]),
                  child: Text('⚠️ MERGE NOW!',
                    style: TextStyle(color: Colors.white.withOpacity(0.9 + p*0.1),
                      fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)))))),
          ];
        }).toList());
      }));
  }
}

// Scanline painter — horizontal scan lines to give the "just 3D-printed /
// freshly materialized" holographic look on each targeted item.
class _ScanlinePainter extends CustomPainter {
  final double t; _ScanlinePainter(this.t);
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFAA44FF).withOpacity(0.08 + t*0.06);
    const spacing = 5.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // Sweep line that moves top→bottom with pulse
    final sweepY = size.height * t;
    canvas.drawLine(Offset(0, sweepY), Offset(size.width, sweepY),
      Paint()..color = const Color(0xFFDD88FF).withOpacity(0.45)..strokeWidth = 1.5);
  }
  @override bool shouldRepaint(_ScanlinePainter old) => old.t != t;
}

// ── Gravity-pull: item flies UP into the creature body (not into a jar) ───────
class _PullEffects extends StatefulWidget {
  final AntiGravityController controller; final Rect? Function(int,int) getCellRect;
  const _PullEffects({required this.controller, required this.getCellRect});
  @override State<_PullEffects> createState() => _PullEffectsState();
}
class _PullEffectsState extends State<_PullEffects> with TickerProviderStateMixin {
  late AnimationController _spin;
  late AnimationController _flight;
  bool _wasEmpty = true;
  @override void initState() {
    super.initState();
    _spin   = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat();
    _flight = AnimationController(vsync: this, duration: AntiGravityController.pullFlightDuration);
    widget.controller.addListener(_onChange);
  }
  void _onChange() {
    final nowEmpty = widget.controller.pullingCells.isEmpty;
    if (_wasEmpty && !nowEmpty) _flight.forward(from: 0);
    _wasEmpty = nowEmpty;
  }
  @override void dispose() { widget.controller.removeListener(_onChange); _spin.dispose(); _flight.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    // Fly to creature centre — this is where the body lives at rest.
    final dest = Offset(sz.width / 2, _restY(sz) - 10);
    return AnimatedBuilder(animation: Listenable.merge([_spin, _flight]), builder: (_, __) =>
      ListenableBuilder(listenable: widget.controller, builder: (_, __) {
        final spin = _spin.value;
        final ft   = Curves.easeInCubic.transform(_flight.value.clamp(0.0, 1.0));
        return Stack(children: widget.controller.pullingCells.expand((cell) {
          final r = widget.getCellRect(cell.$1, cell.$2); if (r == null) return const <Widget>[];
          final origin = r.center;
          // Fly straight up with a slight inward curve toward creature
          final flyPos = Offset(
            origin.dx + (dest.dx - origin.dx) * ft,
            origin.dy + (dest.dy - origin.dy) * ft,
          );
          final vortexOp  = (1 - ft * 1.8).clamp(0.0, 1.0);
          final iconOp    = (1 - ((ft - 0.6) / 0.4)).clamp(0.0, 1.0);
          final iconScale = (1.0 - ft * 0.8).clamp(0.2, 1.0);
          final itemId    = widget.controller.getItemId?.call(cell.$1, cell.$2);
          final emoji     = itemId != null ? ItemDictionary.getById(itemId)?.emoji : null;

          final widgets = <Widget>[];
          // Vortex on original cell fades as item lifts off
          if (vortexOp > 0.01) {
            widgets.add(Positioned(left: origin.dx-32, top: origin.dy-32,
              child: IgnorePointer(child: Opacity(opacity: vortexOp,
                child: Transform.rotate(angle: spin*math.pi*2,
                  child: Container(width: 64, height: 64,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [
                        Colors.black, _kAuraPurple.withOpacity(0.7),
                        Colors.black, const Color(0xFFFF00FF).withOpacity(0.4),
                        Colors.black,
                      ]),
                      boxShadow: [BoxShadow(color: _kAuraPurple.withOpacity(0.8), blurRadius: 22, spreadRadius: 4)])))))));
            widgets.add(Positioned(left: origin.dx-10, top: origin.dy-10,
              child: IgnorePointer(child: Opacity(opacity: vortexOp,
                child: Container(width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black,
                    boxShadow: [BoxShadow(color: _kAuraPurple, blurRadius: 16, spreadRadius: 5)]))))));
          }
          // Item flying into the creature
          if (emoji != null && iconOp > 0.01) {
            widgets.add(Positioned(left: flyPos.dx-16, top: flyPos.dy-16,
              child: IgnorePointer(child: Opacity(opacity: iconOp,
                child: Transform.scale(scale: iconScale,
                  child: Transform.rotate(angle: ft*math.pi*3,
                    child: Text(emoji, style: const TextStyle(fontSize: 24))))))));
          }
          // Purple energy streaks along the flight path
          for (int i = 0; i < 4; i++) {
            final wt   = (ft - i * 0.06).clamp(0.0, 1.0);
            final trOp = (1 - wt) * 0.38 * vortexOp;
            final wp   = Offset(origin.dx + (dest.dx - origin.dx)*wt, origin.dy + (dest.dy - origin.dy)*wt);
            widgets.add(Positioned(left: wp.dx-4, top: wp.dy-4,
              child: IgnorePointer(child: Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _kAuraPurple.withOpacity(trOp),
                  boxShadow: [BoxShadow(color: _kAuraPurple.withOpacity(trOp*0.6), blurRadius: 8)])))));
          }
          // Flash on creature body when item arrives
          if (ft > 0.88) {
            final flash = ((ft - 0.88) / 0.12).clamp(0.0, 1.0);
            widgets.add(Positioned(left: dest.dx-40, top: dest.dy-40,
              child: IgnorePointer(child: Opacity(opacity: (1-flash)*0.7,
                child: Container(width: 80, height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _kAuraPurple.withOpacity(0.45),
                    boxShadow: [BoxShadow(color: _kAuraPurple, blurRadius: 30, spreadRadius: 10)]))))));
          }
          return widgets;
        }).toList());
      }));
  }
}

// ── Absorption badge — floating near creature, counts items consumed ──────────
class _JarBadge extends StatefulWidget {
  final int count; const _JarBadge({required this.count});
  @override State<_JarBadge> createState() => _JarBadgeState();
}
class _JarBadgeState extends State<_JarBadge> with SingleTickerProviderStateMixin {
  late AnimationController _pop; int _lastCount = 0;
  @override void initState() { super.initState(); _lastCount = widget.count; _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward(); }
  @override void didUpdateWidget(_JarBadge old) {
    super.didUpdateWidget(old);
    if (widget.count != _lastCount) { _lastCount = widget.count; _pop.forward(from: 0); }
  }
  @override void dispose() { _pop.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    // Badge sits just to the right of the creature's rest position
    final bx = sz.width / 2 + 60; final by = _restY(sz) - 30;
    return AnimatedBuilder(animation: _pop, builder: (_, __) {
      final bump = 1.0 + (1 - Curves.elasticOut.transform(_pop.value)).abs() * 0.3;
      return Positioned(left: bx - 24, top: by - 24, child: IgnorePointer(child: Transform.scale(scale: bump,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0622).withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAuraPurple.withOpacity(0.9), width: 1.5),
            boxShadow: [BoxShadow(color: _kAuraPurple.withOpacity(0.5), blurRadius: 14)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🕳️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('×${widget.count}',
              style: const TextStyle(color: _kAuraPurple, fontSize: 11, fontWeight: FontWeight.w900)),
          ])))));
    });
  }
}

// ── Win Blast (level complete — boss dissolves) ───────────────────────────────
class _WinBlast extends StatefulWidget {
  @override State<_WinBlast> createState() => _WinBlastState();
}
class _WinBlastState extends State<_WinBlast> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  final _rng = Random();
  final List<_AGPtcl> _ps  = [];
  final List<_AGCoin> _cs  = [];

  @override
  void initState() {
    super.initState();
    // Full AAA blast — 130 particles, shockwave rings, 4.8s
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))..forward();
    for (int i = 0; i < 130; i++) {
      _ps.add(_AGPtcl(
        _rng.nextDouble() * math.pi * 2,
        0.18 + _rng.nextDouble() * 0.82,
        2 + _rng.nextDouble() * 14,
        [_kAuraPurple, const Color(0xFFDD00FF), const Color(0xFF9900FF),
         const Color(0xFFCC88FF), Colors.white, const Color(0xFF00DDFF),
         const Color(0xFFFFEE00)][_rng.nextInt(7)],
        _rng.nextDouble() * 0.28));
    }
    for (int i = 0; i < 65; i++) {
      _cs.add(_AGCoin(_rng.nextDouble(), 0.22 + _rng.nextDouble() * 0.55,
        0.38 + _rng.nextDouble() * 0.62, 13 + _rng.nextDouble() * 11));
    }
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final cx = sz.width / 2;
    final cy = sz.height * 0.27;
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final t = _c.value;
      return Stack(children: [
        // Background darkness
        Positioned.fill(child: IgnorePointer(child: Container(
          color: Colors.black.withOpacity((math.sin(t * math.pi) * 0.90).clamp(0.0, 0.90))))),
        // Purple anti-gravity flash at start
        if (t < 0.30) Positioned.fill(child: IgnorePointer(child: Container(
          color: _kAuraPurple.withOpacity(((1 - t / 0.30) * 0.80).clamp(0.0, 0.80))))),
        // 3 expanding shockwave rings
        ...List.generate(3, (ri) {
          final rDelay = ri * 0.11;
          final rT = ((t - rDelay) / (1.0 - rDelay)).clamp(0.0, 1.0);
          if (rT <= 0) return const SizedBox.shrink();
          final ringR  = rT * sz.width * 0.82;
          final ringOp = (1 - rT * 1.48).clamp(0.0, 0.70);
          if (ringOp <= 0.01) return const SizedBox.shrink();
          final ringColor = [_kAuraPurple, Colors.white, const Color(0xFFDD00FF)][ri];
          return Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _AGRingPainter(center: Offset(cx, cy), radius: ringR, opacity: ringOp, color: ringColor),
          )));
        }),
        // Particles
        ..._ps.map((p) {
          final pr = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final dx = cx + math.cos(p.angle) * pr * sz.width  * 0.80 * p.speed;
          final dy = cy + math.sin(p.angle) * pr * sz.height * 0.92 * p.speed;
          final op = ((1 - pr) * (1 - pr)).clamp(0.0, 1.0);
          return Positioned(left: dx - p.size / 2, top: dy - p.size / 2,
            child: IgnorePointer(child: Container(width: p.size, height: p.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
                boxShadow: [BoxShadow(color: p.color.withOpacity(op * 0.5), blurRadius: p.size * 2)]))));
        }),
        // Coin shower
        ..._cs.map((c) {
          final pr = ((t - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final op = t > 0.86 ? ((1 - t) / 0.14).clamp(0.0, 1.0) : 1.0;
          return Positioned(left: c.x * sz.width - c.size / 2,
            top: pr * sz.height * 1.1 * c.speed - c.size / 2,
            child: IgnorePointer(child: Opacity(opacity: op,
              child: Text('💰', style: TextStyle(fontSize: c.size)))));
        }),
        // Victory text
        if (t > 0.36)
          Positioned(top: sz.height * 0.38, left: 24, right: 24,
            child: Opacity(opacity: ((t - 0.36) / 0.44).clamp(0.0, 1.0),
              child: Column(children: [
                Text('🌀 ANTI-GRAVITY DEFEATED! 💥', textAlign: TextAlign.center,
                  style: TextStyle(color: _kAuraPurple, fontSize: 24,
                    fontWeight: FontWeight.w900, letterSpacing: 2,
                    shadows: [Shadow(color: _kAuraPurple, blurRadius: 24),
                              const Shadow(color: Colors.white, blurRadius: 10)])),
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.72))),
                  child: const Text('+50 COINS BONUS! 💰',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w900))),
              ]))),
      ]);
    });
  }
}

// Helpers for anti-gravity win blast (local scope, no conflict with other files)
class _AGPtcl {
  final double angle, speed, size, delay;
  final Color color;
  const _AGPtcl(this.angle, this.speed, this.size, this.color, this.delay);
}
class _AGCoin {
  final double x, delay, speed, size;
  const _AGCoin(this.x, this.delay, this.speed, this.size);
}
class _AGRingPainter extends CustomPainter {
  final Offset center;
  final double radius, opacity;
  final Color color;
  const _AGRingPainter({required this.center, required this.radius, required this.opacity, required this.color});
  @override void paint(Canvas canvas, Size size) {
    if (opacity < 0.01 || radius < 1) return;
    canvas.drawCircle(center, radius, Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawCircle(center, radius * 0.87, Paint()
      ..color = color.withOpacity(opacity * 0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }
  @override bool shouldRepaint(_AGRingPainter o) => o.radius != radius || o.opacity != opacity;
}

// ── Anti-Gravity Body — shapeless liquid-metal jellyfish/cyborg hybrid ───────
class _AntiGravityBody extends StatelessWidget {
  final double morph, glow; const _AntiGravityBody({required this.morph, required this.glow});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 160, height: 160, child: CustomPaint(
      painter: _BodyPainter(morph: morph, glow: glow),
      child: Center(child: Padding(padding: const EdgeInsets.only(top: 8), child: _NeonCore(glow: glow))),
    ));
  }
}

class _NeonCore extends StatelessWidget {
  final double glow; const _NeonCore({required this.glow});
  @override Widget build(BuildContext context) => Container(width: 22, height: 22,
    decoration: BoxDecoration(shape: BoxShape.circle, color: _kCoreWhite,
      boxShadow: [
        BoxShadow(color: _kCoreWhite.withOpacity(0.95), blurRadius: 10+glow*8, spreadRadius: 1+glow*2),
        BoxShadow(color: _kAuraPurple.withOpacity(0.7), blurRadius: 22+glow*10, spreadRadius: 2),
      ]),
    child: CustomPaint(painter: _StarPainter()));
}

class _StarPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero); final r = size.width/2;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final a = i*math.pi/4;
      final rad = i.isEven ? r*0.95 : r*0.4;
      final p = Offset(c.dx+math.cos(a)*rad, c.dy+math.sin(a)*rad);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _kNebulaBlue.withOpacity(0.35));
  }
  @override bool shouldRepaint(_) => false;
}

/// Enhanced liquid-metal anti-gravity body — bigger (160×160), 8 fronds,
/// dual outer glow rings, scanning beam, tractor-beam emitter and heavier
/// specular highlights. All driven by the continuous [morph] 0→1→0 cycle.
class _BodyPainter extends CustomPainter {
  final double morph, glow; const _BodyPainter({required this.morph, required this.glow});

  Path _blobPath(Offset c, double baseR, double wobble, double scale) {
    final path = Path(); const pts = 12;
    for (int i = 0; i <= pts; i++) {
      final a  = (i / pts) * math.pi * 2;
      final rr = baseR * scale *
          (1 + 0.18 * math.sin(a * 3 + wobble * math.pi * 2)
             + 0.09 * math.cos(a * 2 - wobble * math.pi * 3)
             + 0.04 * math.sin(a * 5 + wobble * math.pi));
      final p  = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr * 0.90);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close(); return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c      = Offset(size.width / 2, size.height / 2 - 10);
    final baseR  = size.width * 0.32;
    final wobble = morph;
    final path   = _blobPath(c, baseR, wobble, 1.0);

    // ── Outer "gravity field" glow rings ──────────────────────────────────
    canvas.drawCircle(c, baseR * 1.55, Paint()
      ..color = _kAuraPurple.withOpacity(0.12 + glow * 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));
    canvas.drawCircle(c, baseR * 1.22, Paint()
      ..color = const Color(0xFF9900FF).withOpacity(0.18 + glow * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));

    // Depth silhouette
    canvas.drawPath(_blobPath(c + const Offset(4, 7), baseR, wobble, 0.97), Paint()
      ..color = const Color(0xFF03010F).withOpacity(0.65));

    // Outer purple glow on body outline
    canvas.drawPath(path, Paint()
      ..color = _kAuraPurple.withOpacity(0.40 + glow * 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));

    // Body fill — deep nebula gradient with 5 stops for more volume
    canvas.drawPath(path, Paint()..shader = RadialGradient(
      center: const Alignment(-0.40, -0.50), radius: 1.2,
      colors: [
        Colors.white.withOpacity(0.34 + glow * 0.12),
        const Color(0xFF7B2FBE).withOpacity(0.88),
        _kDeepViolet.withOpacity(0.94),
        _kNebulaBlue.withOpacity(0.97),
        const Color(0xFF02030E).withOpacity(0.99),
      ],
      stops: const [0.0, 0.18, 0.38, 0.65, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: baseR * 1.35)));

    // Rim lights (two layers — wide+faint outer, narrow+bright inner)
    canvas.drawPath(path, Paint()
      ..color = _kAuraPurple.withOpacity(0.50 * glow + 0.28)
      ..style = PaintingStyle.stroke..strokeWidth = 3.0);
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withOpacity(0.16 + glow * 0.10)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // ── Tractor-beam emitter at bottom centre ─────────────────────────────
    final emX = c.dx; final emY = c.dy + baseR * 0.85;
    canvas.drawCircle(Offset(emX, emY), 5, Paint()
      ..color = const Color(0xFFCC44FF).withOpacity(0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Beam cone (down toward grid)
    final beamOp = 0.12 + glow * 0.10;
    canvas.drawPath(
      Path()..moveTo(emX - 8, emY)..lineTo(emX + 8, emY)
            ..lineTo(emX + 34, emY + 70)..lineTo(emX - 34, emY + 70)..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_kAuraPurple.withOpacity(beamOp * 2), Colors.transparent],
      ).createShader(Rect.fromLTWH(emX - 34, emY, 68, 70)));

    // ── Scanning beam (horizontal sweep driven by morph) ─────────────────
    final sweepY = c.dy - baseR * 0.5 + baseR * morph;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawLine(Offset(c.dx - baseR, sweepY), Offset(c.dx + baseR, sweepY),
      Paint()..color = const Color(0xFFDD99FF).withOpacity(0.38)..strokeWidth = 1.5);
    canvas.restore();

    // ── 8 jellyfish fronds — longer, tapered, bioluminescent tips ────────
    for (int i = 0; i < 8; i++) {
      final fx   = c.dx - baseR * 0.82 + i * (baseR * 1.64 / 7);
      final sway = math.sin(wobble * math.pi * 2 + i * 0.85) * 12;
      final tipY = c.dy + baseR * 1.65 + (i % 2 == 0 ? 10 : 0);
      final tip  = Offset(fx + sway * 0.65, tipY);
      final fPath = Path()
        ..moveTo(fx, c.dy + baseR * 0.52)
        ..quadraticBezierTo(fx + sway, c.dy + baseR * 1.18, tip.dx, tip.dy);
      // Wide dark stroke (body of frond)
      canvas.drawPath(fPath, Paint()
        ..color = _kDeepViolet.withOpacity(0.76 - i * 0.04)
        ..style = PaintingStyle.stroke..strokeWidth = 5.0..strokeCap = StrokeCap.round);
      // Narrower bright purple overlay (inner glow)
      canvas.drawPath(fPath, Paint()
        ..color = _kAuraPurple.withOpacity(0.40 * glow + 0.10)
        ..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round);
      // Bioluminescent tip bulb
      canvas.drawCircle(tip, 3.2, Paint()
        ..color = const Color(0xFFDD66FF).withOpacity(0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // ── Specular highlights (3-layer for strong wet/metallic read) ────────
    canvas.drawCircle(Offset(c.dx - baseR*0.38, c.dy - baseR*0.44), baseR*0.22,
      Paint()..color = Colors.white.withOpacity(0.28 + glow*0.14));
    canvas.drawCircle(Offset(c.dx + baseR*0.28, c.dy - baseR*0.08), baseR*0.11,
      Paint()..color = Colors.white.withOpacity(0.16 + glow*0.10));
    canvas.drawCircle(Offset(c.dx - baseR*0.05, c.dy - baseR*0.30), baseR*0.06,
      Paint()..color = Colors.white.withOpacity(0.22 + glow*0.08));
  }

  @override bool shouldRepaint(_BodyPainter old) => old.morph != morph || old.glow != glow;
}

// ── Rules Card ─────────────────────────────────────────────────────────────────
class _RulesCard extends StatelessWidget {
  const _RulesCard();
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF10082A).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAuraPurple.withOpacity(0.8), width: 2),
        boxShadow: [BoxShadow(color: _kAuraPurple.withOpacity(0.35), blurRadius: 20)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌌 LEVEL 37 — ANTI-GRAVITY', style: TextStyle(color: _kAuraPurple,
          fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: _kAuraPurple.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAuraPurple.withOpacity(0.55))),
          child: const Text('🎯 WIN: Complete the delivery quota as normal!',
            style: TextStyle(color: _kAuraPurple, fontSize: 10, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        _r('⚠️', 'Watch for the amber warning ring — that item is next!'),
        _r('✅', 'Merge it before the ring fills to make it safe FOREVER.'),
        _r('🕳️', 'Still un-merged when the ring fills → absorbed into the creature!'),
        _r('⚡', 'Each item absorbed costs you 15 energy — merge fast!'),
      ]));
  }
  Widget _r(String i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(children: [Text(i, style: const TextStyle(fontSize: 13)), const SizedBox(width: 7),
      Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.4)))]));
}

// ── Coach-voice hint banner for Level 37 — identical feel to Level 35 ─────────
// Positioned just below the creature (not inside any dialogue bubble), so it
// reads as a neutral game-HUD tip, never as the creature speaking.
class _AntiGravHintBanner extends StatelessWidget {
  final String icon, text;
  final bool isUrgent;
  final Key hintKey;
  const _AntiGravHintBanner({required this.icon, required this.text, required this.isUrgent, required this.hintKey});
  @override
  Widget build(BuildContext context) {
    final accent = isUrgent ? const Color(0xFFFF4400) : _kAuraPurple;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 340),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(anim),
          child: child)),
      child: Container(
        key: hintKey,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0A0620).withOpacity(0.95), const Color(0xFF06031A).withOpacity(0.95)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: accent.withOpacity(0.72), width: 1.3),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.28), blurRadius: 12, spreadRadius: 1)]),
        child: Row(children: [
          Container(width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: accent.withOpacity(0.20),
              border: Border.all(color: accent.withOpacity(0.60), width: 1)),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 11))),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 10,
              fontWeight: FontWeight.w800, height: 1.28, letterSpacing: 0.2))),
        ]),
      ),
    );
  }
}

// ── Shared bits ────────────────────────────────────────────────────────────────
class _DialogueBubble extends StatelessWidget {
  final String text; final bool warning; const _DialogueBubble({required this.text, this.warning = false});
  @override Widget build(BuildContext context) {
    final tint = warning ? _kWarnAmber : _kAuraPurple;
    return Stack(clipBehavior: Clip.none, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF0A0620).withOpacity(0.96),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: tint.withOpacity(0.9), width: 2),
          boxShadow: [BoxShadow(color: tint.withOpacity(0.5), blurRadius: 16)]),
        child: Text(text, textAlign: TextAlign.center,
          style: TextStyle(color: tint, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0))),
      Positioned(bottom: -10, left: 0, right: 0, child: Center(child: CustomPaint(size: const Size(16,10), painter: _Tail(color: tint)))),
    ]);
  }
}
class _Tail extends CustomPainter {
  final Color color; const _Tail({required this.color});
  @override void paint(Canvas c, Size s) { c.drawPath(Path()..moveTo(0,0)..lineTo(s.width,0)..lineTo(s.width/2,s.height)..close(), Paint()..color = color.withOpacity(0.9)); }
  @override bool shouldRepaint(covariant _Tail old) => old.color != color;
}
class _Shard { final double angle, reach, size, delay; const _Shard(this.angle, this.reach, this.size, this.delay); }
