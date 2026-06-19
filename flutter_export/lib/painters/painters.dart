// ============================================================
// painters.dart — Professional 5-Phase Particle Backgrounds
// Tech Tycoon Merge
//
// Design principles (AAA mobile-game quality):
//  • 3 depth layers (far/mid/near) + atmospheric vignette per phase
//  • Deterministic time-based positions — seed array + sin/cos,
//    NO Random() or mutation inside paint().  Smooth, no jitter.
//  • RepaintBoundary on every layer → only the canvas repaints.
//  • No TextPainter inside paint() (mega-corp uses geometry).
//  • shouldRepaint checks t != old.t only.
// ============================================================

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/models.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

/// Pre-seeded double array for deterministic particle positions.
List<double> _seeds(int n, int salt) {
  final r = math.Random(salt);
  return List.generate(n, (_) => r.nextDouble());
}

/// Smooth fractional loop: wraps value into [0,1).
double _wrap(double v) => v - v.floor();

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 1 — THE DUSTY GARAGE  (warm amber / orange forge)
// Layers:
//   Far  : 12 large glowing heat orbs (very slow, very transparent)
//   Mid  : 55 dust motes (upward drift + sine sway)
//   Near : 20 bright forge sparks (fast, orange-white)
//   FX   : radial warm vignette + rising heat shimmer columns
// ══════════════════════════════════════════════════════════════════════════════

class _GaragePainter extends CustomPainter {
  final double t;
  // seed arrays (pre-allocated, never touched inside paint)
  final List<double> sx, sy, sspd, sang, srad, sopa, sphs; // heat orbs
  final List<double> dx, dy, dspd, dang, drad, dopa, dphs; // dust
  final List<double> fx, fy, fspd, fopa, fphs;             // sparks

  _GaragePainter(this.t,
      this.sx, this.sy, this.sspd, this.sang, this.srad, this.sopa, this.sphs,
      this.dx, this.dy, this.dspd, this.dang, this.drad, this.dopa, this.dphs,
      this.fx, this.fy, this.fspd, this.fopa, this.fphs);

  @override
  void paint(Canvas canvas, Size sz) {
    final W = sz.width, H = sz.height;

    // ── Far layer: heat orbs ──────────────────────────────────────────────
    final orbPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < sx.length; i++) {
      final x = _wrap(sx[i] + t * (sspd[i] * 0.008)) * W;
      final y = _wrap(sy[i] - t * (sspd[i] * 0.012)) * H;
      final pulse = 0.5 + 0.5 * math.sin(t * 0.3 + sphs[i]);
      final r = srad[i] * (0.85 + 0.15 * pulse);
      orbPaint.shader = ui.Gradient.radial(
        Offset(x, y), r,
        [
          const Color(0xFFFF6B00).withOpacity(sopa[i] * pulse * 0.22),
          Colors.transparent,
        ],
      );
      canvas.drawCircle(Offset(x, y), r, orbPaint);
    }

    // ── Mid layer: dust motes ─────────────────────────────────────────────
    final dustPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (int i = 0; i < dx.length; i++) {
      final sway = math.sin(t * 0.4 + dphs[i]) * 0.018;
      final x = _wrap(dx[i] + sway + t * dspd[i] * 0.004) * W;
      final y = _wrap(dy[i] - t * dspd[i] * 0.018) * H;
      final pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 1.2 + dphs[i]));
      dustPaint.color = Color.lerp(
          const Color(0xFFFF8C00), const Color(0xFFFFD060), dopa[i])!
          .withOpacity(dopa[i] * pulse * 0.65);
      canvas.drawCircle(Offset(x, y), drad[i], dustPaint);
    }

    // ── Near layer: forge sparks ──────────────────────────────────────────
    final spkPaint = Paint()..strokeWidth = 1.1..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
    for (int i = 0; i < fx.length; i++) {
      final x = _wrap(fx[i] + t * fspd[i] * 0.006) * W;
      final y = _wrap(fy[i] - t * fspd[i] * 0.032) * H;
      final life = 0.5 + 0.5 * math.sin(t * 3.5 + fphs[i]);
      if (life < 0.15) continue;
      final tail = 5.0 + life * 8;
      spkPaint.color = Color.lerp(
          const Color(0xFFFF4400), Colors.white, life * 0.6)!
          .withOpacity(fopa[i] * life);
      canvas.drawLine(Offset(x, y), Offset(x + 1, y - tail), spkPaint);
    }

    // ── Atmospheric: warm vignette ────────────────────────────────────────
    final vigPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(W / 2, H / 2), math.max(W, H) * 0.72,
        [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFFFF4500).withOpacity(0.09),
          const Color(0xFF1A0800).withOpacity(0.38),
        ],
        [0.0, 0.45, 0.72, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), vigPaint);

    // ── Rising heat columns (faint warm streaks) ──────────────────────────
    final heatPaint = Paint()..strokeWidth = 22..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final cx = W * (0.12 + i * 0.18 + 0.04 * math.sin(t * 0.07 + i));
      final alpha = 0.025 + 0.012 * math.sin(t * 0.18 + i * 1.3);
      heatPaint.shader = ui.Gradient.linear(
        Offset(cx, H), Offset(cx + 8, 0),
        [
          Colors.transparent,
          const Color(0xFFFF6B00).withOpacity(alpha),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
      canvas.drawLine(Offset(cx, H), Offset(cx + 8, 0), heatPaint);
    }
  }

  @override
  bool shouldRepaint(_GaragePainter o) => o.t != t;
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
  late _GaragePainter Function(double) _make;
  // seed arrays — allocated once in initState
  late final List<double> _sx, _sy, _sspd, _sang, _srad, _sopa, _sphs;
  late final List<double> _dx, _dy, _dspd, _dang, _drad, _dopa, _dphs;
  late final List<double> _fx, _fy, _fspd, _fopa, _fphs;

  @override
  void initState() {
    super.initState();
    // orbs
    _sx = _seeds(12, 1); _sy = _seeds(12, 2);
    _sspd = _seeds(12, 3).map((v) => v * 0.6 + 0.2).toList();
    _sang = _seeds(12, 4); _srad = _seeds(12, 5).map((v) => v * 80 + 40).toList();
    _sopa = _seeds(12, 6).map((v) => v * 0.55 + 0.15).toList();
    _sphs = _seeds(12, 7).map((v) => v * math.pi * 2).toList();
    // dust
    _dx = _seeds(55, 10); _dy = _seeds(55, 11);
    _dspd = _seeds(55, 12).map((v) => v * 0.8 + 0.3).toList();
    _dang = _seeds(55, 13); _drad = _seeds(55, 14).map((v) => v * 2.2 + 0.6).toList();
    _dopa = _seeds(55, 15).map((v) => v * 0.30 + 0.08).toList();
    _dphs = _seeds(55, 16).map((v) => v * math.pi * 2).toList();
    // sparks
    _fx = _seeds(20, 20); _fy = _seeds(20, 21);
    _fspd = _seeds(20, 22).map((v) => v * 1.5 + 0.8).toList();
    _fopa = _seeds(20, 23).map((v) => v * 0.5 + 0.3).toList();
    _fphs = _seeds(20, 24).map((v) => v * math.pi * 2).toList();

    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 90))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _GaragePainter(
                  _ctrl.value * 90,
                  _sx, _sy, _sspd, _sang, _srad, _sopa, _sphs,
                  _dx, _dy, _dspd, _dang, _drad, _dopa, _dphs,
                  _fx, _fy, _fspd, _fopa, _fphs,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 2 — THE OFFICE UPGRADE  (holographic blue / corporate tech)
// Layers:
//   Far  : Perspective vanishing-point grid (scrolls inward)
//   Mid  : 18 hex data-node orbs drifting upward + blinking
//   Near : 3 horizontal scanning light beams (slow sweep)
//   FX   : Cool blue vignette + top-centre lens flare
// ══════════════════════════════════════════════════════════════════════════════

class _OfficePainter extends CustomPainter {
  final double t;
  final List<double> nx, ny, nspd, nopa, nphs, nrad; // hex nodes

  _OfficePainter(this.t, this.nx, this.ny, this.nspd, this.nopa, this.nphs, this.nrad);

  void _drawHex(Canvas canvas, Offset center, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  void paint(Canvas canvas, Size sz) {
    final W = sz.width, H = sz.height;
    final vp = Offset(W / 2, H * 0.38); // vanishing point

    // ── Far: perspective grid ─────────────────────────────────────────────
    final gPaint = Paint()
      ..color = const Color(0xFF1E90FF).withOpacity(0.09)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const numV = 14; // vertical lines
    const numH = 12; // horizontal grid lines
    final gridScroll = (t * 0.28) % 1.0;

    for (int i = 0; i <= numV; i++) {
      final frac = i / numV;
      final bottomX = frac * W;
      canvas.drawLine(Offset(bottomX, H), vp, gPaint);
    }
    for (int j = 1; j <= numH; j++) {
      final y = H - (H - vp.dy) * (math.pow(j / numH + gridScroll * (1 / numH), 1.4) as double).clamp(0, 1);
      final frac = (y - vp.dy) / (H - vp.dy);
      final x0 = vp.dx - (vp.dx) * frac;
      final x1 = vp.dx + (W - vp.dx) * frac;
      canvas.drawLine(Offset(x0, y), Offset(x1, y), gPaint);
    }

    // Faint horizontal data-stream lines scrolling down
    final streamPaint = Paint()..strokeWidth = 0.5;
    for (int i = 0; i < 8; i++) {
      final yFrac = _wrap(0.1 * i + t * 0.014);
      final y = yFrac * H;
      final alpha = 0.04 + 0.03 * math.sin(t * 0.5 + i);
      streamPaint.color = const Color(0xFF00D4FF).withOpacity(alpha);
      canvas.drawLine(Offset(0, y), Offset(W, y), streamPaint);
    }

    // ── Mid: floating hex data nodes ──────────────────────────────────────
    final hexStrokePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1;
    final hexFillPaint   = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < nx.length; i++) {
      final x = _wrap(nx[i] + t * nspd[i] * 0.003) * W;
      final y = _wrap(ny[i] - t * nspd[i] * 0.015) * H;
      final blink = 0.5 + 0.5 * math.sin(t * (1.8 + nspd[i]) + nphs[i]);
      final r = nrad[i] * (0.9 + 0.1 * blink);

      hexFillPaint.color = const Color(0xFF1E90FF).withOpacity(0.035 * blink);
      hexStrokePaint.color = const Color(0xFF00D4FF).withOpacity(nopa[i] * blink * 0.75);
      _drawHex(canvas, Offset(x, y), r, hexFillPaint);
      _drawHex(canvas, Offset(x, y), r, hexStrokePaint);

      // Inner dot
      canvas.drawCircle(
        Offset(x, y), 1.4,
        Paint()..color = const Color(0xFFFFFFFF).withOpacity(nopa[i] * blink * 0.5),
      );
    }

    // ── Near: scanning light beams ────────────────────────────────────────
    for (int b = 0; b < 3; b++) {
      final yFrac = _wrap(0.28 * b + t * 0.022 + 0.05 * b);
      final y = yFrac * H;
      final beamPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y), Offset(W, y),
          [
            Colors.transparent,
            const Color(0xFF00BFFF).withOpacity(0.12),
            const Color(0xFF00BFFF).withOpacity(0.18),
            const Color(0xFF00BFFF).withOpacity(0.12),
            Colors.transparent,
          ],
          [0.0, 0.35, 0.5, 0.65, 1.0],
        )
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, y), Offset(W, y), beamPaint);
    }

    // ── Atmosphere: cool vignette ─────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..shader = ui.Gradient.radial(
        Offset(W / 2, H / 2), math.max(W, H) * 0.70,
        [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF001A3A).withOpacity(0.22),
          const Color(0xFF000D1F).withOpacity(0.55),
        ],
        [0.0, 0.42, 0.70, 1.0],
      ),
    );

    // Top lens flare
    final flareAnim = 0.5 + 0.5 * math.sin(t * 0.15);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..shader = ui.Gradient.radial(
        Offset(W / 2, 0), H * 0.45,
        [
          const Color(0xFF00BFFF).withOpacity(0.09 * flareAnim),
          Colors.transparent,
        ],
      ),
    );
  }

  @override
  bool shouldRepaint(_OfficePainter o) => o.t != t;
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
  late final List<double> _nx, _ny, _nspd, _nopa, _nphs, _nrad;

  @override
  void initState() {
    super.initState();
    _nx = _seeds(18, 30); _ny = _seeds(18, 31);
    _nspd = _seeds(18, 32).map((v) => v * 0.8 + 0.3).toList();
    _nopa = _seeds(18, 33).map((v) => v * 0.35 + 0.15).toList();
    _nphs = _seeds(18, 34).map((v) => v * math.pi * 2).toList();
    _nrad = _seeds(18, 35).map((v) => v * 10 + 5).toList();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _OfficePainter(
                  _ctrl.value * 60,
                  _nx, _ny, _nspd, _nopa, _nphs, _nrad,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 3 — SILICON VALLEY TYCOON  (cyberpunk neon / Blade Runner)
// Layers:
//   Far  : 50 fast vertical neon rain streaks (pink/purple gradient)
//   Mid  : 12 circuit-trace pulses (horizontal, travel left→right)
//   Near : 14 floating neon hex outlines drifting upward
//   FX   : CRT scanlines + hot-pink edge vignette + diagonal light shaft
// ══════════════════════════════════════════════════════════════════════════════

class _SiliconPainter extends CustomPainter {
  final double t;
  final List<double> rx, ry, rspd, rlen, ropa;              // rain
  final List<double> cx, cy, cspd, copa, cphs;              // circuit pulses
  final List<double> hx, hy, hspd, hopa, hphs, hrad;        // hex outlines

  _SiliconPainter(this.t,
      this.rx, this.ry, this.rspd, this.rlen, this.ropa,
      this.cx, this.cy, this.cspd, this.copa, this.cphs,
      this.hx, this.hy, this.hspd, this.hopa, this.hphs, this.hrad);

  void _hexPath(Path p, Offset c, double r) {
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
  }

  @override
  void paint(Canvas canvas, Size sz) {
    final W = sz.width, H = sz.height;

    // ── Far: neon rain ────────────────────────────────────────────────────
    final rainPaint = Paint()..strokeWidth = 1.4..style = PaintingStyle.stroke;
    for (int i = 0; i < rx.length; i++) {
      final x = rx[i] * W;
      final yBase = _wrap(ry[i] + t * rspd[i] * 0.028) * (H + rlen[i]);
      final y = yBase - rlen[i];
      rainPaint.shader = ui.Gradient.linear(
        Offset(x, y), Offset(x, y + rlen[i]),
        [
          Colors.transparent,
          const Color(0xFFCC00FF).withOpacity(ropa[i] * 0.55),
          const Color(0xFFFF007F).withOpacity(ropa[i]),
          Colors.transparent,
        ],
        [0.0, 0.3, 0.7, 1.0],
      );
      canvas.drawLine(Offset(x, y), Offset(x, y + rlen[i]), rainPaint);
    }

    // ── Mid: circuit trace pulses ─────────────────────────────────────────
    final circPaint = Paint()..strokeWidth = 0.9..style = PaintingStyle.stroke;
    for (int i = 0; i < cx.length; i++) {
      final y = cy[i] * H;
      final xHead = _wrap(t * cspd[i] * 0.012 + cphs[i]) * W;
      final tailLen = 55.0 + cx[i] * 45;
      final alpha = copa[i] * (0.5 + 0.5 * math.sin(t * 0.8 + cphs[i]));
      circPaint.shader = ui.Gradient.linear(
        Offset(xHead - tailLen, y), Offset(xHead, y),
        [
          Colors.transparent,
          const Color(0xFF00FFFF).withOpacity(alpha * 0.5),
          const Color(0xFFFF00FF).withOpacity(alpha),
        ],
      );
      canvas.drawLine(Offset(xHead - tailLen, y), Offset(xHead, y), circPaint);
      // bright head dot
      canvas.drawCircle(
        Offset(xHead, y), 1.8,
        Paint()..color = const Color(0xFFFFFFFF).withOpacity(alpha * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // ── Near: floating neon hexes ─────────────────────────────────────────
    final hPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (int i = 0; i < hx.length; i++) {
      final x = _wrap(hx[i] + t * hspd[i] * 0.003) * W;
      final y = _wrap(hy[i] - t * hspd[i] * 0.012) * H;
      final pulse = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 1.5 + hphs[i]));
      hPaint.color = Color.lerp(
          const Color(0xFFFF007F), const Color(0xFFCC00FF), hx[i])!
          .withOpacity(hopa[i] * pulse);
      final path = Path();
      _hexPath(path, Offset(x, y), hrad[i] * (0.9 + 0.1 * pulse));
      canvas.drawPath(path, hPaint);
    }

    // ── FX: CRT scanlines ─────────────────────────────────────────────────
    final scanPaint = Paint()
      ..color = Colors.black.withOpacity(0.055)
      ..strokeWidth = 1.0;
    for (double y = 0; y < H; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(W, y), scanPaint);
    }

    // ── FX: diagonal light shaft ──────────────────────────────────────────
    final shaftAnim = 0.4 + 0.4 * math.sin(t * 0.09);
    final shaftPath = Path()
      ..moveTo(W * 0.55, 0)
      ..lineTo(W * 0.85, 0)
      ..lineTo(W * 0.55, H)
      ..lineTo(W * 0.25, H)
      ..close();
    canvas.drawPath(
      shaftPath,
      Paint()..shader = ui.Gradient.linear(
        Offset(W * 0.55, 0), Offset(W * 0.4, H),
        [
          const Color(0xFFCC00FF).withOpacity(0.055 * shaftAnim),
          Colors.transparent,
        ],
      ),
    );

    // ── FX: hot-pink edge vignette ────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..shader = ui.Gradient.radial(
        Offset(W / 2, H / 2), math.max(W, H) * 0.68,
        [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF6600AA).withOpacity(0.18),
          const Color(0xFF1A0028).withOpacity(0.55),
        ],
        [0.0, 0.40, 0.68, 1.0],
      ),
    );
  }

  @override
  bool shouldRepaint(_SiliconPainter o) => o.t != t;
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
  late final List<double> _rx, _ry, _rspd, _rlen, _ropa;
  late final List<double> _cx, _cy, _cspd, _copa, _cphs;
  late final List<double> _hx, _hy, _hspd, _hopa, _hphs, _hrad;

  @override
  void initState() {
    super.initState();
    _rx = _seeds(50, 50); _ry = _seeds(50, 51);
    _rspd = _seeds(50, 52).map((v) => v * 1.8 + 0.8).toList();
    _rlen = _seeds(50, 53).map((v) => v * 55 + 22).toList();
    _ropa = _seeds(50, 54).map((v) => v * 0.35 + 0.15).toList();

    _cx = _seeds(12, 60); _cy = _seeds(12, 61);
    _cspd = _seeds(12, 62).map((v) => v * 1.2 + 0.5).toList();
    _copa = _seeds(12, 63).map((v) => v * 0.45 + 0.25).toList();
    _cphs = _seeds(12, 64).map((v) => v).toList();

    _hx = _seeds(14, 70); _hy = _seeds(14, 71);
    _hspd = _seeds(14, 72).map((v) => v * 0.7 + 0.3).toList();
    _hopa = _seeds(14, 73).map((v) => v * 0.28 + 0.12).toList();
    _hphs = _seeds(14, 74).map((v) => v * math.pi * 2).toList();
    _hrad = _seeds(14, 75).map((v) => v * 12 + 6).toList();

    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _SiliconPainter(
                  _ctrl.value * 60,
                  _rx, _ry, _rspd, _rlen, _ropa,
                  _cx, _cy, _cspd, _copa, _cphs,
                  _hx, _hy, _hspd, _hopa, _hphs, _hrad,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 4 — GLOBAL MEGA-CORP  (matrix green / corporate power)
// Layers:
//   Far  : Slow expanding pulse rings from centre (power radiating outward)
//   Mid  : Matrix-style data columns (geometry — NO TextPainter in paint)
//   Near : 8 scanline bursts (bright green horizontal flashes)
//   FX   : Matrix scanline overlay + deep green vignette
// ══════════════════════════════════════════════════════════════════════════════

class _MegaCorpPainter extends CustomPainter {
  final double t;
  final List<double> colX, colOpa, colSpd, colPhs;   // data columns
  final List<double> burstY, burstOpa, burstSpd;      // scanline bursts

  _MegaCorpPainter(this.t,
      this.colX, this.colOpa, this.colSpd, this.colPhs,
      this.burstY, this.burstOpa, this.burstSpd);

  @override
  void paint(Canvas canvas, Size sz) {
    final W = sz.width, H = sz.height;

    // ── Far: expanding pulse rings ────────────────────────────────────────
    final ringPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2;
    for (int r = 0; r < 5; r++) {
      final phase = _wrap(t * 0.015 + r * 0.2);
      final radius = phase * math.max(W, H) * 0.85;
      final alpha = (1.0 - phase) * 0.12;
      ringPaint.color = const Color(0xFF00FF41).withOpacity(alpha);
      canvas.drawCircle(Offset(W / 2, H / 2), radius, ringPaint);
    }

    // ── Mid: data columns (rectangles, NOT TextPainter) ───────────────────
    final colW = W / 24;
    final blockH = 10.0;
    final colPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < colX.length; i++) {
      final xPos = colX[i] * W;
      final yOff = _wrap(colSpd[i] * t * 0.018 + colPhs[i]) * (H + blockH * 16);
      for (int b = 0; b < 16; b++) {
        final y = yOff + b * blockH - blockH * 8;
        if (y < -blockH || y > H + blockH) continue;
        final fade = 1.0 - (b / 16.0);
        final blink = 0.6 + 0.4 * math.sin(t * 4 + b * 0.8 + colPhs[i]);
        colPaint.color = const Color(0xFF00FF41)
            .withOpacity(colOpa[i] * fade * blink * 0.7);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(xPos - colW * 0.3, y, colW * 0.6, blockH - 2),
            const Radius.circular(1),
          ),
          colPaint,
        );
      }
      // bright head (top of column)
      colPaint.color = const Color(0xFF00FF41).withOpacity(colOpa[i] * 0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(xPos - colW * 0.35, yOff - blockH * 8, colW * 0.7, blockH - 1),
          const Radius.circular(2),
        ),
        colPaint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
      colPaint.maskFilter = null;
    }

    // ── Near: scanline bursts ─────────────────────────────────────────────
    final burstPaint = Paint()..strokeWidth = 2..style = PaintingStyle.stroke;
    for (int i = 0; i < burstY.length; i++) {
      final y = _wrap(burstY[i] + t * burstSpd[i] * 0.014) * H;
      final flash = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 5 + i * 1.7));
      burstPaint.color = const Color(0xFF00FF41).withOpacity(burstOpa[i] * flash * 0.35);
      canvas.drawLine(Offset(0, y), Offset(W, y), burstPaint);
    }

    // ── FX: scanline grid overlay ─────────────────────────────────────────
    final scanPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1.0;
    for (double y = 0; y < H; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(W, y), scanPaint);
    }

    // ── FX: deep green vignette ───────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..shader = ui.Gradient.radial(
        Offset(W / 2, H / 2), math.max(W, H) * 0.65,
        [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF002200).withOpacity(0.25),
          const Color(0xFF000D00).withOpacity(0.60),
        ],
        [0.0, 0.38, 0.65, 1.0],
      ),
    );
  }

  @override
  bool shouldRepaint(_MegaCorpPainter o) => o.t != t;
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
  late final List<double> _colX, _colOpa, _colSpd, _colPhs;
  late final List<double> _burstY, _burstOpa, _burstSpd;

  @override
  void initState() {
    super.initState();
    _colX = _seeds(24, 80);
    _colOpa = _seeds(24, 81).map((v) => v * 0.40 + 0.15).toList();
    _colSpd = _seeds(24, 82).map((v) => v * 1.5 + 0.5).toList();
    _colPhs = _seeds(24, 83).map((v) => v).toList();

    _burstY   = _seeds(8, 90);
    _burstOpa = _seeds(8, 91).map((v) => v * 0.5 + 0.25).toList();
    _burstSpd = _seeds(8, 92).map((v) => v * 0.6 + 0.2).toList();

    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _MegaCorpPainter(
                  _ctrl.value * 60,
                  _colX, _colOpa, _colSpd, _colPhs,
                  _burstY, _burstOpa, _burstSpd,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHASE 5 — MASTERS OF THE UNIVERSE  (cosmic / interstellar)
// Layers:
//   Far  : 140 twinkling stars (static positions, animated opacity)
//   Mid  : 5 drifting nebula clouds (animated colour + position shift)
//   Near : 35 gold stardust motes drifting upward
//   FX   : Shooting stars (periodic) + aurora bands top + cosmic vignette
// ══════════════════════════════════════════════════════════════════════════════

class _UniversePainter extends CustomPainter {
  final double t;
  final List<double> stX, stY, stR, stOpa, stSpd, stPhs; // stars
  final List<double> nbX, nbY, nbR, nbOpa, nbPhs;         // nebulas
  final List<double> gdX, gdY, gdSpd, gdR, gdOpa, gdPhs;  // gold dust
  // shooting stars: 4 of them, periodic
  final List<double> shotX, shotPhs;

  _UniversePainter(this.t,
      this.stX, this.stY, this.stR, this.stOpa, this.stSpd, this.stPhs,
      this.nbX, this.nbY, this.nbR, this.nbOpa, this.nbPhs,
      this.gdX, this.gdY, this.gdSpd, this.gdR, this.gdOpa, this.gdPhs,
      this.shotX, this.shotPhs);

  @override
  void paint(Canvas canvas, Size sz) {
    final W = sz.width, H = sz.height;

    // ── Far: nebula clouds ────────────────────────────────────────────────
    final nebPaint = Paint();
    for (int i = 0; i < nbX.length; i++) {
      final x = (nbX[i] + 0.04 * math.sin(t * 0.04 + nbPhs[i])) * W;
      final y = (nbY[i] + 0.03 * math.cos(t * 0.03 + nbPhs[i])) * H;
      final r = nbR[i] * (0.92 + 0.08 * math.sin(t * 0.07 + nbPhs[i]));
      final alpha = nbOpa[i] * (0.7 + 0.3 * math.sin(t * 0.05 + nbPhs[i]));
      nebPaint.shader = ui.Gradient.radial(
        Offset(x, y), r,
        [
          Color.lerp(const Color(0xFF4B0082), const Color(0xFF001A5E),
              nbX[i])!.withOpacity(alpha * 0.28),
          Color.lerp(const Color(0xFF001A5E), const Color(0xFF110022),
              nbY[i])!.withOpacity(alpha * 0.08),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      );
      canvas.drawCircle(Offset(x, y), r, nebPaint);
    }

    // ── Far: stars ────────────────────────────────────────────────────────
    final starPaint = Paint();
    for (int i = 0; i < stX.length; i++) {
      final twinkle = 0.5 + 0.5 * math.sin(t * stSpd[i] + stPhs[i]);
      final opacity = stOpa[i] * (0.35 + 0.65 * twinkle);
      if (opacity < 0.01) continue;
      final r = stR[i] * (0.8 + 0.2 * twinkle);
      starPaint
        ..color = Colors.white.withOpacity(opacity)
        ..maskFilter = stR[i] > 1.2
            ? const MaskFilter.blur(BlurStyle.normal, 1.8)
            : null;
      canvas.drawCircle(Offset(stX[i] * W, stY[i] * H), r, starPaint);
    }
    starPaint.maskFilter = null;

    // ── Mid: gold stardust ────────────────────────────────────────────────
    final gdPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    for (int i = 0; i < gdX.length; i++) {
      final sway = math.sin(t * 0.35 + gdPhs[i]) * 0.016;
      final x = _wrap(gdX[i] + sway) * W;
      final y = _wrap(gdY[i] - t * gdSpd[i] * 0.016) * H;
      final pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 1.4 + gdPhs[i]));
      gdPaint.color = Color.lerp(
          const Color(0xFFFFD700), const Color(0xFFFFF8DC), gdR[i])!
          .withOpacity(gdOpa[i] * pulse);
      canvas.drawCircle(Offset(x, y), gdR[i] * (0.7 + 0.3 * pulse), gdPaint);
    }

    // ── Near: shooting stars ──────────────────────────────────────────────
    final shotPaint = Paint()..strokeWidth = 1.4..style = PaintingStyle.stroke;
    for (int i = 0; i < shotX.length; i++) {
      final phase = _wrap(t * 0.022 + shotPhs[i]);
      if (phase > 0.15) continue; // only visible for 15% of cycle
      final life = 1.0 - phase / 0.15;
      final startX = shotX[i] * W;
      final startY = (0.05 + shotPhs[i] * 0.35) * H;
      final tailLen = 80 + shotX[i] * 50;
      final ex = startX + tailLen * life;
      final ey = startY + tailLen * 0.35 * life;
      shotPaint.shader = ui.Gradient.linear(
        Offset(startX, startY), Offset(ex, ey),
        [
          Colors.white.withOpacity(0.9 * life),
          const Color(0xFFFFD700).withOpacity(0.4 * life),
          Colors.transparent,
        ],
      );
      canvas.drawLine(Offset(startX, startY), Offset(ex, ey), shotPaint);
    }

    // ── FX: aurora at top ─────────────────────────────────────────────────
    for (int b = 0; b < 3; b++) {
      final auroraAnim = 0.5 + 0.5 * math.sin(t * 0.06 + b * 1.1);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, W, H),
        Paint()..shader = ui.Gradient.linear(
          Offset(0, 0), Offset(0, H * 0.35),
          [
            Color.lerp(
                const Color(0xFF4B0082), const Color(0xFF00FFD0), b / 2.0)!
                .withOpacity(0.055 * auroraAnim),
            Colors.transparent,
          ],
        ),
      );
    }

    // ── FX: cosmic vignette ───────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..shader = ui.Gradient.radial(
        Offset(W / 2, H / 2), math.max(W, H) * 0.68,
        [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF200040).withOpacity(0.22),
          const Color(0xFF060010).withOpacity(0.60),
        ],
        [0.0, 0.38, 0.65, 1.0],
      ),
    );
  }

  @override
  bool shouldRepaint(_UniversePainter o) => o.t != t;
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
  late final List<double> _stX, _stY, _stR, _stOpa, _stSpd, _stPhs;
  late final List<double> _nbX, _nbY, _nbR, _nbOpa, _nbPhs;
  late final List<double> _gdX, _gdY, _gdSpd, _gdR, _gdOpa, _gdPhs;
  late final List<double> _shotX, _shotPhs;

  @override
  void initState() {
    super.initState();
    _stX  = _seeds(140, 100); _stY  = _seeds(140, 101);
    _stR  = _seeds(140, 102).map((v) => v * 1.8 + 0.3).toList();
    _stOpa= _seeds(140, 103).map((v) => v * 0.55 + 0.12).toList();
    _stSpd= _seeds(140, 104).map((v) => v * 2.5 + 0.5).toList();
    _stPhs= _seeds(140, 105).map((v) => v * math.pi * 2).toList();

    _nbX  = _seeds(5, 110); _nbY  = _seeds(5, 111);
    _nbR  = _seeds(5, 112).map((v) => v * 90 + 60).toList();
    _nbOpa= _seeds(5, 113).map((v) => v * 0.6 + 0.3).toList();
    _nbPhs= _seeds(5, 114).map((v) => v * math.pi * 2).toList();

    _gdX  = _seeds(35, 120); _gdY  = _seeds(35, 121);
    _gdSpd= _seeds(35, 122).map((v) => v * 0.7 + 0.2).toList();
    _gdR  = _seeds(35, 123).map((v) => v * 1.8 + 0.4).toList();
    _gdOpa= _seeds(35, 124).map((v) => v * 0.35 + 0.1).toList();
    _gdPhs= _seeds(35, 125).map((v) => v * math.pi * 2).toList();

    _shotX = _seeds(4, 130);
    _shotPhs = _seeds(4, 131);

    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 80))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _UniversePainter(
                  _ctrl.value * 80,
                  _stX, _stY, _stR, _stOpa, _stSpd, _stPhs,
                  _nbX, _nbY, _nbR, _nbOpa, _nbPhs,
                  _gdX, _gdY, _gdSpd, _gdR, _gdOpa, _gdPhs,
                  _shotX, _shotPhs,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
      widget.child,
    ]);
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

  BurstParticle(math.Random rng, this.color)
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
