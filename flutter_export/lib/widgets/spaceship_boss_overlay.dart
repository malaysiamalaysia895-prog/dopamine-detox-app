// spaceship_boss_overlay.dart — Spaceship Alien Boss UI
// NEW: Dialogue bubble, HP pulse vignette, slow-mo flash,
//      L35 obstacle cell indicator, victory coin shower

import 'dart:async';
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
    final sz = MediaQuery.of(context).size;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        if (phase == SpaceshipBossPhase.idle) return const SizedBox.shrink();
        if (isDialogActive) return const SizedBox.shrink();
        // Compute boss Y for drop animations
        final cellR   = getCellRect(0, 0);
        final gridTop = cellR?.top ?? sz.height * 0.40;
        final bossY   = (gridTop - 110).clamp(10.0, gridTop - 110.0);
        return Stack(clipBehavior: Clip.none, children: [
          if (controller.isSlowMo)
            Positioned.fill(child: IgnorePointer(child: _SlowMoFlash(color: Colors.white))),
          if (phase == SpaceshipBossPhase.entry && !controller.entryComplete)
            _EntryAnimation(controller: controller, getCellRect: getCellRect),
          if (phase == SpaceshipBossPhase.active)
            _ActiveWidget(controller: controller, getCellRect: getCellRect),
          if (phase == SpaceshipBossPhase.active)
            _ThrowTimers(controller: controller, getCellRect: getCellRect, bossY: bossY),
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
    // Main timeline: ~3.0s cinematic (kept snappy so the whole entry —
    // cinematic + rules screen — lands around ~5s after the level starts)
    _main     = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _pulse    = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _particle = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))..forward();
    _rules    = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    // Landing impact controller (fires once ship reaches grid)
    _land     = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));

    // Scale: large-but-onscreen → smooth shrink → settle at 1.0.
    // IMPORTANT: kept modest (was 4.6-5.0x, which combined with the
    // off-screen start position pushed the ship entirely out of the
    // viewport for most of the descent — on real devices it looked like
    // there was no animation at all, just a hard cut once it landed.
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 2.1, end: 2.3), weight: 5),   // quick flash zoom-in (stays on-screen)
      TweenSequenceItem(tween: Tween(begin: 2.3, end: 1.0), weight: 53),  // main descent shrink
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
    // Was -200 (fixed). Combined with the old 5x scale this pushed the ship
    // well outside the viewport for most of the descent on real device
    // screen sizes, so the "animation" was invisible until the final
    // settle frame. Keep it close enough to the top edge that the ship is
    // at least partially in view from frame 1.
    // Start the ship at the very top of the visible area so the entry
    // cinematic is on-screen from frame 1 on every device.
    final startY  = -30.0;

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

        // Cinematic spin-down: ship tumbles in as it enters, decelerating to
        // dead-level right as it reaches the grid, then a small landing wobble.
        final descentP = (t / 0.58).clamp(0.0, 1.0);
        final spin = (1.0 - Curves.easeOut.transform(descentP)) * math.pi * 3.4;
        final wobble = _landFired
            ? (1.0 - _land.value) * math.sin(_land.value * math.pi * 5) * 0.22
            : spin;

        // Side boosters: flare out wide during descent, retract into the hull
        // once the ship touches down (driven by _land).
        final boosterExtend = _landFired
            ? (1.0 - Curves.easeOut.transform(_land.value)).clamp(0.0, 1.0)
            : (0.35 + 0.65 * Curves.easeOut.transform(descentP));
        final boosterFlicker = 0.7 + _pulse.value * 0.3;

        return Stack(clipBehavior: Clip.none, children: [
          // Cinematic dark backdrop — capped lower than before (was 0.82,
          // nearly opaque) so the ship/particles stay clearly readable
          // against it instead of nearly vanishing into black.
          Positioned.fill(child: IgnorePointer(child: Container(
            color: Colors.black.withOpacity((0.35 + t * 0.30).clamp(0.0, 0.65))))),

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

          // Side booster nacelles — flare wide during the spin-in descent,
          // then retract into the hull once the ship settles on the grid.
          if (boosterExtend > 0.02)
            Positioned(left: cx - 55 * sc, top: by - 38 * sc,
              child: IgnorePointer(child:
                Transform.rotate(angle: wobble, alignment: Alignment.center,
                  child: Transform.scale(scale: sc, alignment: Alignment.center,
                    child: SizedBox(width: 140, height: 116, child: Stack(children: [
                      Positioned(top: 46, left: 70 - 55 * boosterExtend,
                        child: Opacity(opacity: boosterExtend, child: _BoosterPod(flicker: boosterFlicker, facesRight: false))),
                      Positioned(top: 46, left: 70 + 20 * boosterExtend,
                        child: Opacity(opacity: boosterExtend, child: _BoosterPod(flicker: boosterFlicker, facesRight: true))),
                    ])))))),

          // The ship: spins/tumbles as it descends, then kneels on touchdown
          Positioned(left: cx - 55 * sc, top: by - 38 * sc,
            child: IgnorePointer(child:
              Transform.rotate(angle: wobble, alignment: Alignment.center,
                child: Transform.scale(scale: sc, alignment: Alignment.center,
                  child: _ShipWidget(
                    glow: 0.7 + _pulse.value * 0.3,
                    thruster: _pulse.value))))),

          // Full-screen rules overlay with skip button
          if (_rules.value > 0.01)
            Positioned.fill(child: _FullscreenRulesOverlay(
              level: widget.controller.currentLevel,
              onSkip: () => widget.controller.skipEntry())),
        ]);
      },
    );
  }
}

// ── Booster Pod (entry-only side thrusters that extend then retract) ──────────
class _BoosterPod extends StatelessWidget {
  final double flicker; final bool facesRight;
  const _BoosterPod({required this.flicker, required this.facesRight});
  @override
  Widget build(BuildContext context) {
    final flame = Container(width: 30, height: 12,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: facesRight ? Alignment.centerLeft : Alignment.centerRight,
          end:   facesRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            const Color(0xFFFFDD55).withOpacity(0.95 * flicker),
            const Color(0xFFFF7700).withOpacity(0.75 * flicker),
            Colors.transparent]),
        boxShadow: [BoxShadow(color: const Color(0xFFFF8800).withOpacity(0.55 * flicker), blurRadius: 12)]));
    final pod = Container(width: 20, height: 16,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(colors: [Color(0xFF9944DD), Color(0xFF551199)]),
        border: Border.all(color: const Color(0xFFCC88FF).withOpacity(0.85), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.5), blurRadius: 8)]));
    return Row(mainAxisSize: MainAxisSize.min,
      children: facesRight ? [pod, flame] : [flame, pod]);
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
  late AnimationController _pulse, _thruster, _orbit, _hpPulse, _dialogueAnim, _hover;
  String? _prevDialogue;
  Timer? _hintTimer;
  int _hintIndex = 0;
  static const _kHintCount = 4;

  // Dynamic — last hint shows a live "X more to go" count so the player always
  // knows exactly how close they are to destroying the boss.
  List<(String, String)> _hints(SpaceshipBossController c) {
    final remaining = (c.mergesNeeded - c.mergesDone).clamp(0, c.mergesNeeded);
    return [
      ('⚠️', 'Merge the highlighted item before its timer hits 0 — or take an HP penalty!'),
      ('🛡️', 'Rescue it before the fuse ends to dodge the penalty and earn +15 coins!'),
      ('💥', 'Every merge damages the boss — keep merging to destroy it!'),
      ('🎯', '$remaining more merge${remaining == 1 ? '' : 's'} to defeat the boss!'),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pulse       = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _thruster    = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..repeat(reverse: true);
    _orbit       = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _hpPulse     = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..repeat(reverse: true);
    _dialogueAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _hover       = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    widget.controller.addListener(_onChange);
    // Rotating in-game reminder — keeps telling the player how to dodge the
    // penalty and how the boss actually gets destroyed, throughout the fight.
    _hintTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (!mounted) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _kHintCount);
    });
  }
  void _onChange() {
    final d = widget.controller.dialogueText;
    if (d != _prevDialogue && d != null) { _prevDialogue = d; _dialogueAnim.forward(from: 0); }
  }
  @override void dispose() {
    widget.controller.removeListener(_onChange);
    _hintTimer?.cancel();
    _pulse.dispose(); _thruster.dispose(); _orbit.dispose(); _hpPulse.dispose(); _dialogueAnim.dispose(); _hover.dispose();
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
      animation: Listenable.merge([_pulse, _thruster, _orbit, _hpPulse, _dialogueAnim, _hover]),
      builder: (_, __) {
        final orb = _orbit.value * math.pi * 2;
        final hpOp = isLow ? (0.5 + _hpPulse.value * 0.5) : 1.0;
        // Gentle hover — 7 px vertical bob + 4° tilt
        final hoverOff  = math.sin(_hover.value * math.pi * 2) * 7.0;
        final hoverTilt = math.sin(_hover.value * math.pi * 2) * 0.07;
        final shipY = bossY + hoverOff;
        return Stack(children: [
          Positioned(left: 0, right: 0, top: shipY,
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: hoverTilt,
                  child: _ShipWidget(glow: 0.7 + _pulse.value * 0.3, thruster: _thruster.value)),
              ])),
          if (c.dialogueText != null)
            Positioned(top: shipY - 50, left: cx - 140, width: 280,
              child: ScaleTransition(scale: CurvedAnimation(parent: _dialogueAnim, curve: Curves.elasticOut),
                child: _DialogueBubble(text: c.dialogueText!, color: const Color(0xFFCC00FF)))),
          ...List.generate(8, (i) {
            final a = orb + i * math.pi / 4;
            return Positioned(left: cx + math.cos(a) * 52 - 4, top: shipY + 35 + math.sin(a) * 22 - 4,
              child: IgnorePointer(child: Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFCC00FF).withOpacity(0.7),
                  boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.5), blurRadius: 6)]))));
          }),
          Positioned(top: shipY + 78, left: 30, right: 30,
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
              const SizedBox(height: 7),
              _HintBanner(icon: _hints(c)[_hintIndex].$1, text: _hints(c)[_hintIndex].$2),
            ])),
        ]);
      },
    );
  }
}

// ── Persistent in-fight hint banner (rotates: avoid penalty / destroy boss) ────
// Fixed full-width card in a stable slot above the grid — never drops into the
// grid or floats mid-screen, so it always reads as a deliberate HUD element.
class _HintBanner extends StatelessWidget {
  final String icon, text;
  const _HintBanner({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(anim), child: child)),
      child: Container(
        key: ValueKey(text),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF2A0044).withOpacity(0.92), const Color(0xFF12001F).withOpacity(0.92)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.75), width: 1.3),
          boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.32), blurRadius: 12, spreadRadius: 1)]),
        child: Row(children: [
          Container(width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFCC00FF).withOpacity(0.22),
              border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.6), width: 1)),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 11))),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.28, letterSpacing: 0.2))),
        ]),
      ),
    );
  }
}

// ── Throw Timers ───────────────────────────────────────────────────────────────

class _ThrowTimers extends StatefulWidget {
  final SpaceshipBossController controller;
  final Rect? Function(int col, int row) getCellRect;
  final double bossY;
  const _ThrowTimers({required this.controller, required this.getCellRect, required this.bossY});
  @override State<_ThrowTimers> createState() => _ThrowTimersState();
}
class _ThrowTimersState extends State<_ThrowTimers> with TickerProviderStateMixin {
  late AnimationController _flash, _spark, _frame;
  // id → epoch-ms when first seen (for drop animation)
  final Map<double, int> _birthMs = {};

  @override void initState() {
    super.initState();
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _spark = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    // High-freq ticker drives smooth drop animation (≈60 fps)
    _frame = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))..repeat();
  }
  @override void dispose() {
    _flash.dispose(); _spark.dispose(); _frame.dispose(); super.dispose();
  }

  static const _dropMs = 700; // ms each mini-ship takes to fall to cell

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return AnimatedBuilder(animation: Listenable.merge([_flash, _spark, _frame]),
      builder: (_, __) => ListenableBuilder(listenable: widget.controller,
        builder: (_, __) {
          final now = DateTime.now().millisecondsSinceEpoch;
          // Track birth time for every active throw
          for (final t in widget.controller.activeThrows) {
            _birthMs.putIfAbsent(t.id, () => now);
          }
          _birthMs.removeWhere((id, _) =>
              !widget.controller.activeThrows.any((t) => t.id == id));

          final widgets = <Widget>[];

          for (final t in widget.controller.activeThrows) {
            final r = widget.getCellRect(t.col, t.row);
            if (r == null) continue;
            final birth = _birthMs[t.id] ?? now;
            final age   = now - birth;

            if (age < _dropMs) {
              // ── DROP ANIMATION: mini-ship dives from boss to the target item ──
              final raw = (age / _dropMs).clamp(0.0, 1.0);
              final p   = Curves.easeIn.transform(raw);
              final startX = sz.width / 2;
              final endX   = r.center.dx;
              final startY = widget.bossY + 55;  // bottom of boss ship
              final endY   = r.top + r.height * 0.42;
              // Slight arc: ship swings sideways before diving straight down
              final arc = math.sin(raw * math.pi) * (endX - startX) * 0.18;
              final cx = startX + (endX - startX) * p + arc * (1 - raw);
              final cy = startY + (endY - startY) * (p * p * (3 - 2 * p)); // smootherstep
              final sc = (0.38 + p * 0.78).clamp(0.0, 1.16);
              final spin = (1 - raw) * 5.0; // radians — spins fast, settles as it nears cell
              final tilt = (endX - startX) > 0 ? 0.22 : -0.22;
              widgets.add(Positioned(left: cx - 26, top: cy - 30,
                child: IgnorePointer(child: Transform.rotate(
                  angle: spin + tilt * raw,
                  alignment: Alignment.center,
                  child: Opacity(opacity: (0.35 + p * 0.65).clamp(0.0, 1.0),
                    child: Transform.scale(scale: sc, child: _MiniShipDrop(progress: raw))),
                ))));
              // Motion-trail glow streaking behind the falling ship
              for (int k = 1; k <= 3; k++) {
                final tp = (raw - k * 0.09).clamp(0.0, 1.0);
                final tcx = startX + (endX - startX) * Curves.easeIn.transform(tp) + arc * (1 - tp);
                final tcy = startY + (endY - startY) * (tp * tp * (3 - 2 * tp));
                final top2 = (1 - k * 0.28) * (1 - raw) * 0.5;
                widgets.add(Positioned(left: tcx - 7, top: tcy - 7,
                  child: IgnorePointer(child: Container(width: 14, height: 14,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: const Color(0xFFFF8800).withOpacity(top2.clamp(0.0, 0.5)),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF6600).withOpacity(top2), blurRadius: 10)])))));
              }
            } else {
              // ── LANDED: targeting reticle around the item + countdown ──
              final settleAge = (age - _dropMs).clamp(0, 260);
              final settle = 1.0 - Curves.easeOutBack.transform((settleAge / 260).clamp(0.0, 1.0));
              final squash = 1.0 + settle * 0.14; // brief squash-bounce on touchdown
              final urgent = t.secondsLeft <= 3;
              final f = urgent ? _flash.value : 1.0;
              final c = urgent ? const Color(0xFFFF2200) : const Color(0xFFFF8800);
              final br = 16.0; // bracket arm length
              widgets.add(Positioned(left: r.left, top: r.top, width: r.width, height: r.height,
                child: IgnorePointer(child: Transform.scale(
                  scaleX: squash, scaleY: 2 - squash, alignment: Alignment.bottomCenter,
                  child: Stack(children: [
                    // pulsing danger ring (item stays fully visible underneath)
                    Center(child: Container(
                      width: r.width * (0.86 + f * 0.06), height: r.height * (0.86 + f * 0.06),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: c.withOpacity(f * 0.55), blurRadius: 14, spreadRadius: 1)]))),
                    // 4 corner target brackets
                    Positioned(left: 2, top: 2, child: _bracket(c, f, br, 0)),
                    Positioned(right: 2, top: 2, child: _bracket(c, f, br, 1)),
                    Positioned(left: 2, bottom: 2, child: _bracket(c, f, br, 2)),
                    Positioned(right: 2, bottom: 2, child: _bracket(c, f, br, 3)),
                    // hovering mini-ship marker above the cell
                    Positioned(top: -20, left: 0, right: 0,
                      child: Center(child: Opacity(opacity: 0.55 + f * 0.45,
                        child: Transform.scale(scale: 0.62, child: const _MiniShipDrop(progress: 1.0))))),
                    // countdown badge
                    Positioned(bottom: 3, left: 0, right: 0,
                      child: Center(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: c.withOpacity(f * 0.8), width: 1)),
                        child: Text('${t.secondsLeft}s', style: TextStyle(
                          color: urgent ? const Color(0xFFFF5544) : const Color(0xFFFFAA55),
                          fontSize: 10, fontWeight: FontWeight.w900))))),
                  ])))));
              widgets.addAll(_crackleSparks(r.center, _spark.value, c, urgent));
            }
          }
          return Stack(children: widgets);
        }));
  }

  // corner: 0=TL,1=TR,2=BL,3=BR
  Widget _bracket(Color c, double f, double len, int corner) {
    final horiz = (corner == 1 || corner == 3);
    final vert  = (corner == 2 || corner == 3);
    return CustomPaint(size: Size(len, len),
      painter: _CornerBracketPainter(color: c.withOpacity(0.55 + f * 0.45), flipH: horiz, flipV: vert));
  }

  List<Widget> _crackleSparks(Offset center, double t, Color color, bool urgent) {
    final count = urgent ? 6 : 4;
    final out = <Widget>[];
    for (int i = 0; i < count; i++) {
      final a = (i / count) * math.pi * 2 + t * math.pi * 2 * (urgent ? 1.6 : 1.0);
      final reach = 20 + math.sin(t * math.pi * 2 + i) * 6;
      final dx = center.dx + math.cos(a) * reach;
      final dy = center.dy + math.sin(a) * reach;
      const s = 4.0;
      out.add(Positioned(left: dx - s / 2, top: dy - s / 2,
        child: IgnorePointer(child: Container(width: s, height: s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.8),
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)])))));
    }
    return out;
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color color; final bool flipH, flipV;
  _CornerBracketPainter({required this.color, required this.flipH, required this.flipV});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.6..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final x0 = flipH ? size.width : 0.0;
    final y0 = flipV ? size.height : 0.0;
    final dx = flipH ? -1.0 : 1.0;
    final dy = flipV ? -1.0 : 1.0;
    canvas.drawLine(Offset(x0, y0), Offset(x0 + dx * size.width, y0), paint);
    canvas.drawLine(Offset(x0, y0), Offset(x0, y0 + dy * size.height), paint);
  }
  @override
  bool shouldRepaint(covariant _CornerBracketPainter old) => old.color != color;
}

// ── Mini-Ship (used both for the falling drop & the hover marker) ─────────────
class _MiniShipDrop extends StatelessWidget {
  final double progress; // 0 = just launched, 1 = fully landed/visible
  const _MiniShipDrop({required this.progress});
  @override
  Widget build(BuildContext context) {
    final flame = 0.5 + math.sin(progress * math.pi * 6) * 0.3;
    return SizedBox(width: 42, height: 50, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      // exhaust flame trailing above (ship is diving nose-down)
      Positioned(top: -2, child: Container(width: 9, height: 16 + flame * 10,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [
            const Color(0xFFFFCC00).withOpacity(0.9),
            const Color(0xFFFF6600).withOpacity(0.55),
            Colors.transparent])))),
      // saucer hull
      Positioned(top: 14, child: Container(width: 34, height: 14,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(colors: [Color(0xFFDD8800), Color(0xFF8A3A00), Color(0xFFCC6600)]),
          border: Border.all(color: const Color(0xFFFFAA33).withOpacity(0.85), width: 1),
          boxShadow: [BoxShadow(color: const Color(0xFFFF8800).withOpacity(0.65), blurRadius: 10, spreadRadius: 1)]))),
      // cockpit bubble
      Positioned(top: 8, child: Container(width: 16, height: 13,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF66EEFF), Color(0xFF0077BB)]),
          border: Border.all(color: const Color(0xFFAAFFFF).withOpacity(0.8), width: 1)))),
      // small side fins
      Positioned(top: 18, left: 1, child: Container(width: 7, height: 4,
        decoration: BoxDecoration(color: const Color(0xFF8A3A00), borderRadius: BorderRadius.circular(2)))),
      Positioned(top: 18, right: 1, child: Container(width: 7, height: 4,
        decoration: BoxDecoration(color: const Color(0xFF8A3A00), borderRadius: BorderRadius.circular(2)))),
    ]));
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
    // Enhanced: 4.8s, 130 particles, richer colors
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))..forward();
    for (int i = 0; i < 130; i++) {
      _pts.add(_Ptcl(
        _rng.nextDouble() * math.pi * 2,
        0.18 + _rng.nextDouble() * 0.82,
        2 + _rng.nextDouble() * 14,
        [const Color(0xFFCC00FF), const Color(0xFF00DDFF), const Color(0xFFFF8800),
         const Color(0xFFFFEE00), const Color(0xFFFF00AA), Colors.white,
         const Color(0xFF00FFCC)][_rng.nextInt(7)],
        _rng.nextDouble() * 0.28));
    }
    for (int i = 0; i < 65; i++) {
      _coins.add(_Coin(_rng.nextDouble(), 0.22 + _rng.nextDouble() * 0.55,
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
        // Background
        Positioned.fill(child: IgnorePointer(child: Container(
          color: Colors.black.withOpacity((math.sin(t * math.pi) * 0.88).clamp(0.0, 0.88))))),
        // Bright initial flash
        if (t < 0.28) Positioned.fill(child: IgnorePointer(child: Container(
          color: Colors.white.withOpacity(((1 - t / 0.28) * 0.82).clamp(0.0, 0.82))))),
        // 3 expanding shockwave rings
        ...List.generate(3, (ri) {
          final rDelay = ri * 0.11;
          final rT = ((t - rDelay) / (1.0 - rDelay)).clamp(0.0, 1.0);
          if (rT <= 0) return const SizedBox.shrink();
          final ringR  = rT * sz.width * 0.80;
          final ringOp = (1 - rT * 1.45).clamp(0.0, 0.68);
          if (ringOp <= 0.01) return const SizedBox.shrink();
          final ringColor = [const Color(0xFFCC00FF), Colors.white, const Color(0xFF00DDFF)][ri];
          return Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _WBRingPainter(center: Offset(cx, cy), radius: ringR, opacity: ringOp, color: ringColor),
          )));
        }),
        // Particles
        ..._pts.map((p) {
          final pr = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final dx = cx + math.cos(p.angle) * pr * sz.width  * 0.78 * p.speed;
          final dy = cy + math.sin(p.angle) * pr * sz.height * 0.92 * p.speed;
          final op = ((1 - pr) * (1 - pr)).clamp(0.0, 1.0);
          return Positioned(left: dx - p.size / 2, top: dy - p.size / 2,
            child: IgnorePointer(child: Container(width: p.size, height: p.size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.color.withOpacity(op),
                boxShadow: [BoxShadow(color: p.color.withOpacity(op * 0.5), blurRadius: p.size * 2)]))));
        }),
        // Coin shower
        ..._coins.map((c) {
          final pr = ((t - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
          if (pr <= 0) return const SizedBox.shrink();
          final op = t > 0.86 ? ((1 - t) / 0.14).clamp(0.0, 1.0) : 1.0;
          return Positioned(left: c.x * sz.width - c.size / 2,
            top: pr * sz.height * 1.1 * c.speed - c.size / 2,
            child: IgnorePointer(child: Opacity(opacity: op, child: Text('💰', style: TextStyle(fontSize: c.size)))));
        }),
        // Victory text
        if (t > 0.36)
          Positioned(top: sz.height * 0.36, left: 24, right: 24,
            child: Opacity(opacity: ((t - 0.36) / 0.44).clamp(0.0, 1.0),
              child: Column(children: [
                const Text('🛸 ALIEN DESTROYED! 💥', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFFFEE00), fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2,
                    shadows: [Shadow(color: Color(0xFFFF8800), blurRadius: 22),
                              Shadow(color: Color(0xFFCC00FF), blurRadius: 38)])),
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

// Shockwave ring painter used by spaceship win blast
class _WBRingPainter extends CustomPainter {
  final Offset center;
  final double radius, opacity;
  final Color color;
  const _WBRingPainter({required this.center, required this.radius, required this.opacity, required this.color});
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
  @override bool shouldRepaint(_WBRingPainter o) => o.radius != radius || o.opacity != opacity;
}

// ── Full-Screen Rules Overlay (with skip button) ───────────────────────────────

class _FullscreenRulesOverlay extends StatefulWidget {
  final int level;
  final VoidCallback onSkip;
  const _FullscreenRulesOverlay({required this.level, required this.onSkip});
  @override State<_FullscreenRulesOverlay> createState() => _FullscreenRulesOverlayState();
}
class _FullscreenRulesOverlayState extends State<_FullscreenRulesOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  Timer? _countdown;
  int _sec = 2;
  bool _dismissed = false;

  @override void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() { _sec--; });
      if (_sec <= 0) _dismiss();
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _countdown?.cancel();
    _anim.reverse().then((_) { if (mounted) widget.onSkip(); });
  }

  @override void dispose() { _anim.dispose(); _countdown?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_dismissed && _anim.value < 0.01) return const SizedBox.shrink();
    final n = kSpaceshipBossLevels[widget.level] ?? 20;
    return AnimatedBuilder(animation: _anim, builder: (_, __) => Opacity(
      opacity: _anim.value,
      child: Container(color: Colors.black.withOpacity(0.93),
        child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // ── Header ──
            Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF9900CC).withOpacity(0.35),
                  const Color(0xFF440088).withOpacity(0.35)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.85), width: 2),
                boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.4), blurRadius: 20)]),
              child: Column(children: [
                Text('🛸  LEVEL ${widget.level}',
                  style: const TextStyle(color: Color(0xFFFF44FF), fontSize: 30,
                    fontWeight: FontWeight.w900, letterSpacing: 3,
                    shadows: [Shadow(color: Color(0xFFCC00FF), blurRadius: 18)])),
                const SizedBox(height: 4),
                const Text('SPACESHIP ALIEN BOSS', style: TextStyle(color: Color(0xFFCC88FF),
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
              ])),
            const SizedBox(height: 18),
            // ── Win condition ──
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCC00FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.65))),
              child: Row(children: [
                const Text('🎯', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Merge $n items total to defeat the boss!\nWatch the X/$n counter above the grid.',
                  style: const TextStyle(color: Color(0xFFFF88FF), fontSize: 13,
                    fontWeight: FontWeight.w800, height: 1.45))),
              ])),
            const SizedBox(height: 14),
            // ── Rules ──
            ...[
              ('🛸', 'Every 10s: 5 mini-ships launch from boss and dive onto grid cells!'),
              ('✅', 'Merge items on a mini-ship cell before fuse hits 0 → +15 💰!'),
              ('❌', 'Fuse hits 0 → that item is destroyed + you lose 25 HP!'),
              ('📊', 'Every merge = 1 step toward $n total — keep merging!'),
              if (widget.level == 35)
                ('⚠️', 'L35 extra: Boss blocks 2 cells for 15s every 30s!'),
            ].map((r) => Padding(padding: const EdgeInsets.only(bottom: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.$1, style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 10),
                Expanded(child: Text(r.$2,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
              ]))),
            const SizedBox(height: 22),
            // ── Skip button ──
            GestureDetector(onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFCC00FF), Color(0xFF6600CC)]),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: const Color(0xFFCC00FF).withOpacity(0.55), blurRadius: 20, spreadRadius: 2)]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('▶  START', style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                  const SizedBox(width: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text('$_sec', style: const TextStyle(color: Color(0xFFDDBBFF),
                      fontSize: 14, fontWeight: FontWeight.w800))),
                ]))),
          ]))))));
  }
}

// ── Rules Card (kept for reference) ───────────────────────────────────────────

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
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFCC00FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.5))),
          child: Text('🎯 WIN: Merge $n items total (track X/$n on screen!)',
            style: const TextStyle(color: Color(0xFFCC00FF), fontSize: 10, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        _r('🛸', 'Every 10s: 5 mini-ships land on grid cells (10s fuse!)'),
        _r('✅', 'Merge items on a mini-ship cell → ship neutralized + +15 💰'),
        _r('❌', 'Fuse hits 0 → item destroyed + you lose 25 HP!'),
        _r('📊', 'Each merge = 1 progress toward $n total — keep merging!'),
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
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(i, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 8),
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

// ── Ship Widget — professional redesign ────────────────────────────────────────
class _ShipWidget extends StatefulWidget {
  final double glow, thruster;
  const _ShipWidget({required this.glow, required this.thruster});
  @override State<_ShipWidget> createState() => _ShipWidgetState();
}
class _ShipWidgetState extends State<_ShipWidget> with TickerProviderStateMixin {
  late AnimationController _wave, _blink;
  @override void initState() {
    super.initState();
    _wave  = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))..repeat(reverse: true);
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..repeat(reverse: true);
  }
  @override void dispose() { _wave.dispose(); _blink.dispose(); super.dispose(); }

  Widget _eye(double w) => Container(width: 9, height: 11,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
      gradient: RadialGradient(colors: [
        const Color(0xFFFF3300).withOpacity(0.95 + w * 0.05),
        const Color(0xFFAA0000).withOpacity(0.9),
      ]),
      boxShadow: [
        BoxShadow(color: const Color(0xFFFF0000).withOpacity(0.95), blurRadius: 7 + w * 5),
        BoxShadow(color: const Color(0xFFFF6600).withOpacity(0.45), blurRadius: 14),
      ]),
    child: Stack(alignment: Alignment.center, children: [
      Container(width: 4, height: 5,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
          color: Colors.black.withOpacity(0.88))),
      // tiny specular catch-light so the eye reads as glossy, not a flat sticker
      Positioned(top: 1.5, left: 1.5, child: Container(width: 1.8, height: 1.8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.85)))),
    ]));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: Listenable.merge([_wave, _blink]), builder: (_, __) {
      final w = _wave.value;
      final bl = _blink.value;
      final g = widget.glow;
      final th = widget.thruster;
      // Slow specular sweep across the hull so the saucer reads as polished
      // metal rather than a flat painted shape.
      final sweep = (math.sin(DateTime.now().millisecondsSinceEpoch / 900) + 1) / 2;
      return SizedBox(width: 140, height: 122, child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [

        // Soft contact shadow beneath the hull — grounds the ship visually
        // instead of it looking like it's pasted on top of the scene.
        Positioned(bottom: 0, child: Container(width: 96, height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.black.withOpacity(0.38), Colors.transparent])))),

        // ── Thruster plumes (behind saucer) ──
        Positioned(bottom: 6, child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final dist = (i - 2).abs() * 0.18;
            final h = (12 + th * 24 - dist * 10).clamp(5.0, 36.0);
            return Container(width: 11, height: h, margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                  const Color(0xFFFF7700).withOpacity(0.95),
                  const Color(0xFFFF2200).withOpacity(0.75 + th * 0.2),
                  const Color(0xFFFF0077).withOpacity(0.3 + th * 0.3),
                  Colors.transparent,
                ])));
          }))),

        // ── Main saucer disc — layered metallic shading for real depth ──
        Positioned(top: 32, child: Container(width: 132, height: 50,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFBB66FF), Color(0xFF9944DD), Color(0xFF4D0099), Color(0xFF250055)],
              stops: [0.0, 0.32, 0.68, 1.0]),
            border: Border.all(color: const Color(0xFFEEBBFF).withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(color: const Color(0xFFCC00FF).withOpacity(g * 0.85), blurRadius: 32, spreadRadius: 8),
              BoxShadow(color: const Color(0xFF8800FF).withOpacity(g * 0.45), blurRadius: 60, spreadRadius: 2),
              const BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 10)),
            ]),
          child: ClipRRect(borderRadius: BorderRadius.circular(25), child: Stack(children: [
            // Moving specular sweep — reads as brushed chrome catching light
            Positioned(left: -40 + sweep * 170, top: -10, child: Transform.rotate(angle: -0.5,
              child: Container(width: 30, height: 80,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.30), Colors.white.withOpacity(0.0)]))))),
            // Bottom rim shade — gives the disc a curved, 3-D underside
            Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 20,
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.35)])))),
          ])))),

        // Metallic highlight streak on disc top
        Positioned(top: 36, left: 22, child: Container(width: 88, height: 10,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
            gradient: const LinearGradient(colors: [
              Color(0x00FFFFFF), Color(0x55FFFFFF), Color(0x28FFFFFF), Color(0x00FFFFFF)])))),

        // Underbelly panel line + rivet details for a more "built" hard-surface feel
        Positioned(top: 72, left: 34, child: Container(width: 72, height: 1.5,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(1),
            color: const Color(0xFFCC00FF).withOpacity(0.5)))),
        Positioned(top: 71, left: 30, child: Row(children: List.generate(5, (i) =>
          Container(width: 2.2, height: 2.2, margin: const EdgeInsets.symmetric(horizontal: 12.5),
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFEEBBFF).withOpacity(0.55)))))),

        // ── Orbit ring with alternating blinking lights ──
        Positioned(top: 44, child: Container(width: 120, height: 28,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCC00FF).withOpacity(0.55 + w * 0.4), width: 2),
            gradient: LinearGradient(colors: [
              const Color(0xFFCC00FF).withOpacity(0.07),
              const Color(0xFF9900FF).withOpacity(0.13),
              const Color(0xFFCC00FF).withOpacity(0.07),
            ])))),
        // Ring lights
        ...List.generate(6, (i) {
          final a = (i / 6) * math.pi * 2;
          final ping = i % 2 == 0 ? bl : 1 - bl;
          final lightColor = i % 2 == 0 ? const Color(0xFFFF00FF) : const Color(0xFF00DDFF);
          return Positioned(
            left: 70 + math.cos(a) * 55 - 5,
            top: 58 + math.sin(a) * 11 - 5,
            child: Container(width: 9, height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: lightColor.withOpacity(0.45 + ping * 0.55),
                boxShadow: [BoxShadow(color: lightColor.withOpacity(0.85), blurRadius: 7)])));
        }),

        // ── Cockpit dome — curved glass with true reflection + rim light ──
        Positioned(top: 3, child: Container(width: 68, height: 54,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            gradient: const RadialGradient(center: Alignment(-0.35, -0.5), radius: 1.15,
              colors: [Color(0xFFBFF7FF), Color(0xFF55BBEE), Color(0xFF0060B8), Color(0xFF002B66)],
              stops: [0.0, 0.32, 0.68, 1.0]),
            border: Border.all(color: const Color(0xFF9AFBFF).withOpacity(0.95), width: 2),
            boxShadow: [BoxShadow(color: const Color(0xFF00FFFF).withOpacity(0.4), blurRadius: 16)]),
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            // Dome glass reflection — two-tone glossy highlight for curvature
            Positioned(top: 6, left: 8, child: Container(width: 24, height: 16,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.05)])))),
            Positioned(bottom: 10, right: 10, child: Container(width: 10, height: 6,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                color: Colors.white.withOpacity(0.18)))),
            // Alien head — rounded skull shading (radial gradient reads as
            // a real head, not a flat sticker) with cheek shadow + jaw
            Positioned(top: 9, child: Container(width: 36, height: 30,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18), bottom: Radius.circular(10)),
                gradient: const RadialGradient(center: Alignment(-0.3, -0.6), radius: 1.2,
                  colors: [Color(0xFF3FA24A), Color(0xFF22662A), Color(0xFF0B2E10)],
                  stops: [0.0, 0.55, 1.0]),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.65 + w * 0.35), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFF00FF44).withOpacity(0.32 + w * 0.28), blurRadius: 9)]),
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                // Skull highlight — gives the head a rounded, glossy skin feel
                Positioned(top: 2, left: 6, child: Container(width: 12, height: 8,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withOpacity(0.10)))),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_eye(w), _eye(w)]),
                  const SizedBox(height: 4),
                  // Animated alien mouth — chatters open/close with the wave
                  Builder(builder: (_) {
                    final mH = (2.5 + w * 5.5).clamp(2.5, 8.0);
                    final mW = (12.0 + w * 6.0).clamp(12.0, 18.0);
                    return Container(width: mW, height: mH,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: const Color(0xFF001A0C).withOpacity(0.88),
                        border: Border.all(color: const Color(0xFF00FF44).withOpacity(0.35 + w * 0.45), width: 1)));
                  }),
                ]),
              ]))),
            // Left antenna
            Positioned(top: 0, left: 17, child: Container(width: 2.5, height: 12,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(1.5),
                color: const Color(0xFF00FF88).withOpacity(0.85)),
              child: Align(alignment: Alignment.topCenter, child: Container(width: 6, height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFFF3300).withOpacity(0.8 + bl * 0.2),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF3300).withOpacity(0.95), blurRadius: 5)]))))),
            // Right antenna
            Positioned(top: 0, right: 17, child: Container(width: 2.5, height: 12,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(1.5),
                color: const Color(0xFF00FF88).withOpacity(0.85)),
              child: Align(alignment: Alignment.topCenter, child: Container(width: 6, height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: const Color(0xFFFF3300).withOpacity(0.8 + bl * 0.2),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF3300).withOpacity(0.95), blurRadius: 5)]))))),
            // Left arm waving
            Positioned(left: 0, top: 24, child: Transform.rotate(
              angle: -0.5 - w * 0.85, alignment: Alignment.centerRight,
              child: Container(width: 13, height: 5,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                  color: const Color(0xFF22662A).withOpacity(0.95),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.6), width: 0.8))))),
            // Right arm waving (counter-phase)
            Positioned(right: 0, top: 24, child: Transform.rotate(
              angle: 0.5 + (1 - w) * 0.85, alignment: Alignment.centerLeft,
              child: Container(width: 13, height: 5,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                  color: const Color(0xFF22662A).withOpacity(0.95),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.6), width: 0.8))))),
          ]))),
      ]));
    });
  }
}

class _Ptcl { final double angle, speed, size, delay; final Color color;
  const _Ptcl(this.angle, this.speed, this.size, this.color, this.delay); }
class _Coin { final double x, delay, speed, size;
  const _Coin(this.x, this.delay, this.speed, this.size); }
