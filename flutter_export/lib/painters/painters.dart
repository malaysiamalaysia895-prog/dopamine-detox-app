// ============================================================
// painters.dart — All 5 Phase Particle Systems
// CustomPainter + AnimationController-driven backgrounds
// Tech Tycoon Merge
// ============================================================

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/models.dart';

// ─── PHASE 1: Floating Dust Particles (Garage) ────────────────────────────────

class DustParticle {
  late double x, y, vx, vy, radius, opacity;

  DustParticle(Random rng, Size size) {
    _reset(rng, size, init: true);
  }

  void _reset(Random rng, Size size, {bool init = false}) {
    x  = rng.nextDouble() * size.width;
    y  = init ? rng.nextDouble() * size.height : size.height + 5;
    vx = (rng.nextDouble() - 0.5) * 0.4;
    vy = -(rng.nextDouble() * 0.5 + 0.2);
    radius  = rng.nextDouble() * 2.5 + 0.5;
    opacity = rng.nextDouble() * 0.3 + 0.1;
  }

  void update(Random rng, Size size, double dt) {
    x += vx + sin(y * 0.02) * 0.3;
    y += vy;
    if (y < -5) _reset(rng, size);
  }
}

class DustParticlePainter extends CustomPainter {
  final double progress;
  final List<DustParticle> particles;

  DustParticlePainter(this.progress, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      p.update(Random(), size, 0.016);
      final paint = Paint()
        ..color = Color.lerp(Colors.white, const Color(0xFF00E5FF), 0.4)!
            .withOpacity(p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class GarageBackground extends StatefulWidget {
  final Widget child;
  const GarageBackground({super.key, required this.child});

  @override
  State<GarageBackground> createState() => _GarageBackgroundState();
}

class _GarageBackgroundState extends State<GarageBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<DustParticle> _particles;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
    _particles = List.generate(
        40, (_) => DustParticle(_rng, const Size(400, 800)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: DustParticlePainter(_ctrl.value, _particles),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─── PHASE 2: Digital Grid Lines (Office) ────────────────────────────────────

class DigitalGridPainter extends CustomPainter {
  final double progress;

  DigitalGridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E90FF).withOpacity(0.12)
      ..strokeWidth = 0.8;

    const spacing = 36.0;
    final offset = (progress * spacing) % spacing;

    // Horizontal lines
    for (double y = -spacing + offset; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Floating geometric shapes
    final shapePaint = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 8; i++) {
      final cx = (i * 57.0 + progress * 18) % size.width;
      final cy = (i * 93.0 + progress * 8) % size.height;
      final s = 10.0 + i * 3;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy), width: s, height: s),
        shapePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class OfficeBackground extends StatefulWidget {
  final Widget child;
  const OfficeBackground({super.key, required this.child});

  @override
  State<OfficeBackground> createState() => _OfficeBackgroundState();
}

class _OfficeBackgroundState extends State<OfficeBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: DigitalGridPainter(_ctrl.value * 36),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─── PHASE 3: Neon Rain Lines (Silicon Valley) ────────────────────────────────

class NeonLine {
  late double x, y, speed, length, opacity;

  NeonLine(Random rng, Size size) {
    x       = rng.nextDouble() * size.width;
    y       = rng.nextDouble() * size.height;
    speed   = rng.nextDouble() * 2 + 1;
    length  = rng.nextDouble() * 40 + 20;
    opacity = rng.nextDouble() * 0.2 + 0.05;
  }

  void update(Size size) {
    y += speed;
    if (y > size.height + length) y = -length;
  }
}

class NeonRainPainter extends CustomPainter {
  final List<NeonLine> lines;

  NeonRainPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in lines) {
      l.update(size);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFF007F).withOpacity(0),
            const Color(0xFFCC00FF).withOpacity(l.opacity),
            const Color(0xFFFF007F).withOpacity(0),
          ],
        ).createShader(Rect.fromLTWH(l.x, l.y, 2, l.length))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(l.x, l.y), Offset(l.x, l.y + l.length), paint);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class SiliconBackground extends StatefulWidget {
  final Widget child;
  const SiliconBackground({super.key, required this.child});

  @override
  State<SiliconBackground> createState() => _SiliconBackgroundState();
}

class _SiliconBackgroundState extends State<SiliconBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<NeonLine> _lines;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _lines = List.generate(30, (_) => NeonLine(_rng, const Size(400, 800)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: NeonRainPainter(_lines),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─── PHASE 4: Binary/Digital Rain (Mega-Corp) ─────────────────────────────────

class BinaryColumn {
  late double x, y, speed, opacity;
  late List<String> chars;
  final Random _rng;

  BinaryColumn(this._rng, Size size) {
    x       = (_rng.nextInt(20) * (size.width / 20));
    y       = _rng.nextDouble() * size.height;
    speed   = _rng.nextDouble() * 3 + 1;
    opacity = _rng.nextDouble() * 0.25 + 0.05;
    chars   = List.generate(16, (_) => _rng.nextBool() ? '1' : '0');
  }

  void update(Size size) {
    y += speed;
    if (y > size.height + 160) {
      y = -160;
      x = (_rng.nextInt(20) * (size.width / 20));
    }
    if (_rng.nextInt(4) == 0) {
      final idx = _rng.nextInt(chars.length);
      chars[idx] = _rng.nextBool() ? '1' : '0';
    }
  }
}

class BinaryRainPainter extends CustomPainter {
  final List<BinaryColumn> columns;
  final double progress;

  BinaryRainPainter(this.columns, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const charH = 14.0;
    for (final col in columns) {
      col.update(size);
      for (int i = 0; i < col.chars.length; i++) {
        final fade = i / col.chars.length;
        final tp = TextPainter(
          text: TextSpan(
            text: col.chars[i],
            style: TextStyle(
              color: const Color(0xFF00FF41).withOpacity(col.opacity * fade),
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(col.x, col.y + i * charH));
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class MegaCorpBackground extends StatefulWidget {
  final Widget child;
  const MegaCorpBackground({super.key, required this.child});

  @override
  State<MegaCorpBackground> createState() => _MegaCorpBackgroundState();
}

class _MegaCorpBackgroundState extends State<MegaCorpBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<BinaryColumn> _columns;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))
      ..repeat();
    _columns = List.generate(20, (_) => BinaryColumn(_rng, const Size(400, 800)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: BinaryRainPainter(_columns, _ctrl.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─── PHASE 5: Twinkling Stars + Nebula + Gold Dust (Universe) ────────────────

class StarParticle {
  late double x, y, radius, baseOpacity, twinkleOffset, twinkleSpeed;

  StarParticle(Random rng, Size size) {
    x              = rng.nextDouble() * size.width;
    y              = rng.nextDouble() * size.height;
    radius         = rng.nextDouble() * 2.0 + 0.3;
    baseOpacity    = rng.nextDouble() * 0.5 + 0.1;
    twinkleOffset  = rng.nextDouble() * pi * 2;
    twinkleSpeed   = rng.nextDouble() * 2 + 0.5;
  }
}

class GoldDust {
  late double x, y, vx, vy, radius, opacity;

  GoldDust(Random rng, Size size) {
    x       = rng.nextDouble() * size.width;
    y       = rng.nextDouble() * size.height;
    vx      = (rng.nextDouble() - 0.5) * 0.3;
    vy      = -(rng.nextDouble() * 0.3 + 0.1);
    radius  = rng.nextDouble() * 1.5 + 0.3;
    opacity = rng.nextDouble() * 0.4 + 0.1;
  }

  void update(Size size) {
    x += vx + sin(y * 0.01) * 0.2;
    y += vy;
    if (y < -5) { y = size.height + 5; x = Random().nextDouble() * size.width; }
  }
}

class CosmicPainter extends CustomPainter {
  final double progress;
  final List<StarParticle> stars;
  final List<GoldDust> goldDust;

  CosmicPainter(this.progress, this.stars, this.goldDust);

  @override
  void paint(Canvas canvas, Size size) {
    // Stars
    for (final s in stars) {
      final twinkle = (sin(progress * s.twinkleSpeed * pi * 2 + s.twinkleOffset) * 0.5 + 0.5);
      final opacity = s.baseOpacity * (0.4 + 0.6 * twinkle);
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..maskFilter = s.radius > 1.5
            ? const MaskFilter.blur(BlurStyle.normal, 2.0)
            : null;
      canvas.drawCircle(Offset(s.x, s.y), s.radius, paint);
    }

    // Nebula clouds
    for (int i = 0; i < 3; i++) {
      final cx = size.width * (0.2 + i * 0.3);
      final cy = size.height * (0.3 + i * 0.2);
      final nebula = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4B0082).withOpacity(0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 80 + i * 20));
      canvas.drawCircle(Offset(cx, cy), 80 + i * 20.0, nebula);
    }

    // Gold dust particles
    for (final g in goldDust) {
      g.update(size);
      final paint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(g.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
      canvas.drawCircle(Offset(g.x, g.y), g.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class UniverseBackground extends StatefulWidget {
  final Widget child;
  const UniverseBackground({super.key, required this.child});

  @override
  State<UniverseBackground> createState() => _UniverseBackgroundState();
}

class _UniverseBackgroundState extends State<UniverseBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<StarParticle> _stars;
  late List<GoldDust> _goldDust;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _stars    = List.generate(80, (_) => StarParticle(_rng, const Size(400, 800)));
    _goldDust = List.generate(25, (_) => GoldDust(_rng, const Size(400, 800)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: CosmicPainter(_ctrl.value, _stars, _goldDust),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─── Phase Background Router ─────────────────────────────────────────────────

Widget buildPhaseBackground({required GamePhase phase, required Widget child}) {
  switch (phase) {
    case GamePhase.garage:   return GarageBackground(child: child);
    case GamePhase.office:   return OfficeBackground(child: child);
    case GamePhase.silicon:  return SiliconBackground(child: child);
    case GamePhase.megacorp: return MegaCorpBackground(child: child);
    case GamePhase.universe: return UniverseBackground(child: child);
  }
}

// ─── Burst Particle Effect (post-merge) ──────────────────────────────────────

class BurstParticle {
  final double vx, vy;
  double life = 1.0;
  final Color color;

  BurstParticle(Random rng, this.color)
      : vx = (rng.nextDouble() - 0.5) * 6,
        vy = (rng.nextDouble() - 0.5) * 6;

  void update() { life -= 0.06; }
  bool get isDead => life <= 0;
}

class MergeBurstPainter extends CustomPainter {
  final List<BurstParticle> particles;

  MergeBurstPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final dx = p.vx * (1 - p.life) * 30;
      final dy = p.vy * (1 - p.life) * 30;
      canvas.drawCircle(
        center + Offset(dx, dy),
        3 * p.life,
        Paint()..color = p.color.withOpacity(p.life * 0.9)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * p.life),
      );
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
