import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const GunvantiGameApp());
}

class GunvantiGameApp extends StatelessWidget {
  const GunvantiGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gunvanti: Brahm-Mani',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF25B7FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF02030A),
        useMaterial3: true,
      ),
      home: const GameShell(),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  bool _conceptSeen = false;
  bool _introComplete = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        child: !_conceptSeen
            ? ConceptBriefingScreen(
                key: const ValueKey('concept'),
                onContinue: () => setState(() => _conceptSeen = true),
              )
            : _introComplete
                ? const RuinsGameplayScene(key: ValueKey('gameplay'))
                : AnimeIntroScene(
                    key: const ValueKey('intro'),
                    onEnterRuins: () => setState(() => _introComplete = true),
                  ),
      ),
    );
  }
}

class ConceptBriefingScreen extends StatefulWidget {
  const ConceptBriefingScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<ConceptBriefingScreen> createState() => _ConceptBriefingScreenState();
}

class _ConceptBriefingScreenState extends State<ConceptBriefingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: ConceptAnimePainter(time: _controller.value)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _GameLogo(),
                    const Spacer(),
                    const _AnimeBriefingCard(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onContinue,
                        icon: const Icon(Icons.movie_filter),
                        label: const Text('Watch cinematic intro'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimeBriefingCard extends StatelessWidget {
  const _AnimeBriefingCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD050814),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x8854D9FF)),
        boxShadow: const [
          BoxShadow(color: Color(0x773F79FF), blurRadius: 34, spreadRadius: -8),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Animated Story Mode',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'This opening now tells the Gunwanti legend in English with a full anime-style moving backdrop: bright royal village colors for the golden kingdom, dark blue-red cursed textures for Bhairav, and a 2D action pose of Vicky entering the ruins.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFD7E8FF),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 12),
            const _ScenePill(icon: Icons.wb_sunny, text: 'Colorful Gunwanti village'),
            const _ScenePill(icon: Icons.bolt, text: 'Vicky anime action frame'),
            const _ScenePill(icon: Icons.dark_mode, text: 'Dark cursed night textures'),
          ],
        ),
      ),
    );
  }
}

class _ScenePill extends StatelessWidget {
  const _ScenePill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF54D9FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE9F8FF), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimeIntroScene extends StatefulWidget {
  const AnimeIntroScene({super.key, required this.onEnterRuins});

  final VoidCallback onEnterRuins;

  @override
  State<AnimeIntroScene> createState() => _AnimeIntroSceneState();
}

class _AnimeIntroSceneState extends State<AnimeIntroScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final List<_StoryBeat> _beats = const [
    _StoryBeat(
      title: 'Gunwanti: Secret Suryavanshi Capital',
      body:
          'Centuries ago, King Maharudra protected Gunwanti, a hidden jungle kingdom of golden pillars, sacred stepwells, and temples aligned with the stars.',
      focus: _IntroFocus.king,
    ),
    _StoryBeat(
      title: "Bhairav's Dark Attack",
      body:
          'On a terrifying night, Bhairav attacked to steal the Brahm-Mani. Maharudra performed a final ritual and scattered its power into five fragments.',
      focus: _IntroFocus.villain,
    ),
    _StoryBeat(
      title: 'The Cursed Ruins',
      body:
          'By sunrise, Gunwanti had become a haunted ruin. Soldiers turned into ash-and-shadow guardians, cursed to patrol the village forever.',
      focus: _IntroFocus.guardians,
    ),
    _StoryBeat(
      title: "Today: Vicky's Return",
      body:
          "With his great-grandfather's diary and a blue-glowing pendant, Vicky enters Gunwanti without knowing he is Maharudra's last descendant.",
      focus: _IntroFocus.hero,
    ),
  ];

  int get _beatIndex {
    final index = (_controller.value * _beats.length).floor();
    return index.clamp(0, _beats.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..addListener(() => setState(() {}));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beat = _beats[_beatIndex];
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: AnimeIntroPainter(
            progress: _controller.value,
            focus: beat.focus,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GameLogo(),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  child: _NarrationCard(key: ValueKey(beat.title), beat: beat),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _controller.value,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(99),
                        color: const Color(0xFF54D9FF),
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: widget.onEnterRuins,
                      child: Text(_controller.isCompleted ? 'Start Game' : 'Skip'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _IntroFocus { king, villain, guardians, hero }

class _StoryBeat {
  const _StoryBeat({required this.title, required this.body, required this.focus});

  final String title;
  final String body;
  final _IntroFocus focus;
}

class _GameLogo extends StatelessWidget {
  const _GameLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GUNVANTI',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: const Color(0xFFE9F8FF),
              ),
        ),
        Text(
          'Brahm-Mani: Night Ruins 2026',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF85E8FF),
                letterSpacing: 1.4,
              ),
        ),
      ],
    );
  }
}

class _NarrationCard extends StatelessWidget {
  const _NarrationCard({super.key, required this.beat});

  final _StoryBeat beat;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD08101F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x6654D9FF)),
        boxShadow: const [
          BoxShadow(color: Color(0x883F79FF), blurRadius: 32, spreadRadius: -10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(beat.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 10),
            Text(beat.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFD7E8FF),
                      height: 1.45,
                    )),
          ],
        ),
      ),
    );
  }
}

class RuinsGameplayScene extends StatefulWidget {
  const RuinsGameplayScene({super.key});

  @override
  State<RuinsGameplayScene> createState() => _RuinsGameplaySceneState();
}

class _RuinsGameplaySceneState extends State<RuinsGameplayScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int fragments = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: NightRuinsPainter(time: _pulse.value)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _MissionHud(fragments: fragments),
                    const Spacer(),
                    _ControlPanel(
                      onCollect: () => setState(
                        () => fragments = math.min(5, fragments + 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MissionHud extends StatelessWidget {
  const _MissionHud({required this.fragments});

  final int fragments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xCC050814),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x5554D9FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.explore, color: Color(0xFF54D9FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fragments == 5
                  ? "Final Boss unlocked: Bhairav's spirit is waiting."
                  : 'Mission: Find the 5 Brahm-Mani fragments • $fragments/5',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.shield_moon, color: Color(0xFFFF5A7D)),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.onCollect});

  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD090D18),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Demo controls: guide Vicky through the night ruins, collect 5 Brahm-Mani fragments, use stealth, and solve ancient mirror puzzles.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onCollect,
                  icon: const Icon(Icons.diamond),
                  label: const Text('Collect Mani'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.visibility_off),
                  label: const Text('Stealth'),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Solve Puzzle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ConceptAnimePainter extends CustomPainter {
  ConceptAnimePainter({required this.time});

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final brightPhase = (math.sin(time * math.pi * 2) + 1) / 2;
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(const Color(0xFF123C8C), const Color(0xFF090B1F), brightPhase)!,
          Color.lerp(const Color(0xFFFFB85C), const Color(0xFF240614), brightPhase)!,
          const Color(0xFF02030A),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    _drawSunAndMoon(canvas, size, brightPhase);
    _drawGunwantiVillage(canvas, size, brightPhase);
    _drawCursedTexture(canvas, size, brightPhase);
    _drawVickyActionPose(canvas, size);
    _drawBhairavSlash(canvas, size, brightPhase);
  }

  void _drawSunAndMoon(Canvas canvas, Size size, double dark) {
    final sunCenter = Offset(size.width * .18, size.height * (.16 + dark * .05));
    canvas.drawCircle(sunCenter, 46, Paint()..color = Color.lerp(const Color(0xFFFFD76A), const Color(0x3354D9FF), dark)!);
    final moonCenter = Offset(size.width * .82, size.height * .13);
    canvas.drawCircle(moonCenter, 36, Paint()..color = Color.lerp(const Color(0x33FFFFFF), const Color(0xFFE8F7FF), dark)!);
    canvas.drawCircle(moonCenter.translate(-12, -8), 36, Paint()..color = const Color(0xFF090B1F).withOpacity(.72));
  }

  void _drawGunwantiVillage(Canvas canvas, Size size, double dark) {
    final groundY = size.height * .70;
    final gold = Color.lerp(const Color(0xFFFFC857), const Color(0xFF3B2B2F), dark)!;
    final teal = Color.lerp(const Color(0xFF20E3B2), const Color(0xFF12364C), dark)!;
    final stone = Color.lerp(const Color(0xFFB98754), const Color(0xFF111827), dark)!;

    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, size.height - groundY), Paint()..color = const Color(0xFF0D1726));
    for (var i = 0; i < 6; i++) {
      final x = size.width * (.08 + i * .16);
      final h = 92.0 + (i % 3) * 26;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, groundY - h, 44, h), const Radius.circular(8)),
        Paint()..color = i.isEven ? gold : stone,
      );
      canvas.drawCircle(Offset(x + 22, groundY - h - 22), 25, Paint()..color = teal);
      canvas.drawLine(Offset(x + 8, groundY - h + 12), Offset(x + 36, groundY - h + 48), Paint()..color = Colors.white.withOpacity(.24)..strokeWidth = 2);
    }

    final temple = Path()
      ..moveTo(size.width * .18, groundY)
      ..lineTo(size.width * .50, groundY - 210)
      ..lineTo(size.width * .84, groundY)
      ..close();
    canvas.drawPath(temple, Paint()..color = Color.lerp(const Color(0xFFFF8A5B), const Color(0xFF171B2E), dark)!);
    canvas.drawPath(temple, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xAA54D9FF));
  }

  void _drawCursedTexture(Canvas canvas, Size size, double dark) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Color.lerp(const Color(0x2254D9FF), const Color(0xAAFF355E), dark)!;
    for (var i = 0; i < 18; i++) {
      final y = size.height * (.28 + i * .025);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 28) {
        path.lineTo(x, y + math.sin(x * .04 + time * math.pi * 2 + i) * 9);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawVickyActionPose(Canvas canvas, Size size) {
    final base = Offset(size.width * (.36 + math.sin(time * math.pi * 2) * .025), size.height * .64);
    final aura = Paint()..color = const Color(0x6654D9FF);
    canvas.drawCircle(base.translate(0, -72), 62, aura);
    canvas.drawCircle(base.translate(0, -112), 22, Paint()..color = const Color(0xFFFFD8B7));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: base.translate(0, -62), width: 50, height: 90), const Radius.circular(18)), Paint()..color = const Color(0xFF1D9BF0));
    canvas.drawCircle(base.translate(0, -70), 8, Paint()..color = const Color(0xFF9EF7FF));
    canvas.drawLine(base.translate(-20, -84), base.translate(-70, -44), Paint()..color = const Color(0xFFE9F8FF)..strokeWidth = 8..strokeCap = StrokeCap.round);
    canvas.drawLine(base.translate(20, -84), base.translate(78, -122), Paint()..color = const Color(0xFFE9F8FF)..strokeWidth = 8..strokeCap = StrokeCap.round);
    canvas.drawLine(base.translate(22, -20), base.translate(66, 18), Paint()..color = const Color(0xFF0B1220)..strokeWidth = 9..strokeCap = StrokeCap.round);
    canvas.drawLine(base.translate(-16, -20), base.translate(-44, 24), Paint()..color = const Color(0xFF0B1220)..strokeWidth = 9..strokeCap = StrokeCap.round);
  }

  void _drawBhairavSlash(Canvas canvas, Size size, double dark) {
    final slash = Paint()
      ..shader = const LinearGradient(colors: [Color(0x00FF355E), Color(0xFFFF355E), Color(0x00FF355E)]).createShader(Offset.zero & size)
      ..strokeWidth = 12 + dark * 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .62, size.height * .24), Offset(size.width * .92, size.height * .56), slash);
    canvas.drawCircle(Offset(size.width * .78, size.height * .40), 54 * dark, Paint()..color = const Color(0x55FF355E));
  }

  @override
  bool shouldRepaint(covariant ConceptAnimePainter oldDelegate) => oldDelegate.time != time;
}

class AnimeIntroPainter extends CustomPainter {
  AnimeIntroPainter({required this.progress, required this.focus});

  final double progress;
  final _IntroFocus focus;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050614), Color(0xFF120617), Color(0xFF02030A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    _drawMoon(canvas, size);
    _drawTempleSilhouette(canvas, size);
    _drawCharacter(canvas, size, const Offset(.30, .53), 'V', const Color(0xFF54D9FF), focus == _IntroFocus.hero);
    _drawCharacter(canvas, size, const Offset(.52, .44), 'M', const Color(0xFFFFD66B), focus == _IntroFocus.king);
    _drawCharacter(canvas, size, const Offset(.73, .51), 'B', const Color(0xFFFF355E), focus == _IntroFocus.villain);

    if (focus == _IntroFocus.guardians) {
      for (var i = 0; i < 5; i++) {
        _drawGuardian(canvas, size, Offset(size.width * (.15 + i * .17), size.height * .66));
      }
    }
  }

  void _drawMoon(Canvas canvas, Size size) {
    canvas.drawCircle(Offset(size.width * .78, size.height * .15), 42,
        Paint()..color = const Color(0xFFE8F7FF));
    canvas.drawCircle(Offset(size.width * .75, size.height * .13), 42,
        Paint()..color = const Color(0xFF050614));
  }

  void _drawTempleSilhouette(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF111827);
    final y = size.height * .72;
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, size.height - y), paint);
    for (var i = 0; i < 6; i++) {
      final x = size.width * (i / 5);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, y - 45), width: 20, height: 90), paint);
      canvas.drawCircle(Offset(x, y - 95), 22, paint);
    }
    final path = Path()
      ..moveTo(size.width * .22, y)
      ..lineTo(size.width * .50, y - 190)
      ..lineTo(size.width * .82, y)
      ..close();
    canvas.drawPath(path, paint..color = const Color(0xFF172033));
  }

  void _drawCharacter(Canvas canvas, Size size, Offset anchor, String label, Color aura, bool active) {
    final center = Offset(size.width * anchor.dx, size.height * anchor.dy);
    final scale = active ? 1.18 : .82;
    canvas.drawCircle(center, 78 * scale,
        Paint()..color = aura.withOpacity(active ? .24 : .08));
    canvas.drawOval(Rect.fromCenter(center: center.translate(0, -44 * scale), width: 54 * scale, height: 66 * scale),
        Paint()..color = const Color(0xFFFFD8B7));
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - 102 * scale)
        ..lineTo(center.dx - 46 * scale, center.dy - 20 * scale)
        ..lineTo(center.dx + 48 * scale, center.dy - 24 * scale)
        ..close(),
      Paint()..color = aura.withOpacity(.86),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 38 * scale), width: 82 * scale, height: 120 * scale),
        Radius.circular(24 * scale),
      ),
      Paint()..color = aura.withOpacity(.58),
    );
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: Colors.white, fontSize: 28 * scale, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawGuardian(Canvas canvas, Size size, Offset base) {
    final paint = Paint()..color = const Color(0xAA8A97A8);
    canvas.drawOval(Rect.fromCenter(center: base.translate(0, -44), width: 40, height: 54), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: base, width: 48, height: 88), const Radius.circular(14)), paint);
    canvas.drawCircle(base.translate(-9, -48), 3, Paint()..color = const Color(0xFFFF365D));
    canvas.drawCircle(base.translate(9, -48), 3, Paint()..color = const Color(0xFFFF365D));
  }

  @override
  bool shouldRepaint(covariant AnimeIntroPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.focus != focus;
}

class NightRuinsPainter extends CustomPainter {
  NightRuinsPainter({required this.time});

  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF02030A));
    final sky = Paint()
      ..shader = RadialGradient(
        center: Alignment(.3 + math.sin(time * math.pi * 2) * .06, -.35),
        radius: 1.1,
        colors: const [Color(0xFF173B75), Color(0xFF050817), Color(0xFF02030A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    for (var i = 0; i < 42; i++) {
      final x = (i * 71 % size.width).toDouble();
      final y = (i * 37 % (size.height * .55)).toDouble();
      canvas.drawCircle(Offset(x, y), (i % 3 + 1).toDouble(), Paint()..color = Colors.white.withOpacity(.45));
    }

    final groundY = size.height * .72;
    final ground = Paint()..color = const Color(0xFF11131A);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, size.height - groundY), ground);

    for (var i = 0; i < 7; i++) {
      final depth = i / 7;
      final x = size.width * (i * .16 - .05);
      final h = 170.0 - depth * 58;
      final w = 54.0 + depth * 28;
      final y = groundY - h + depth * 40;
      final wall = Paint()..color = Color.lerp(const Color(0xFF1E293B), const Color(0xFF0F172A), depth)!;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(6)), wall);
      canvas.drawRect(Rect.fromLTWH(x + w * .35, y + h * .25, w * .3, h * .75), Paint()..color = const Color(0xFF050814));
    }

    final path = Path()
      ..moveTo(size.width * .48, groundY - 260)
      ..lineTo(size.width * .18, groundY)
      ..lineTo(size.width * .83, groundY)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF182238));
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x663CCBFF);
    canvas.drawPath(path, outline);

    final auraCenter = Offset(size.width * .52, groundY - 95);
    canvas.drawCircle(auraCenter, 48 + math.sin(time * math.pi * 2) * 10,
        Paint()..color = const Color(0x6654D9FF));
    canvas.drawCircle(auraCenter, 18, Paint()..color = const Color(0xFF8EF4FF));

    _drawVicky(canvas, Offset(size.width * .33, groundY - 45));
    _drawBhairavShadow(canvas, Offset(size.width * .76, groundY - 88));
  }

  void _drawVicky(Canvas canvas, Offset base) {
    canvas.drawCircle(base.translate(0, -64), 18, Paint()..color = const Color(0xFFFFD7B5));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: base.translate(0, -24), width: 38, height: 72), const Radius.circular(14)), Paint()..color = const Color(0xFF1D9BF0));
    canvas.drawCircle(base.translate(0, -26), 7, Paint()..color = const Color(0xFF9EF7FF));
  }

  void _drawBhairavShadow(Canvas canvas, Offset base) {
    final shadow = Paint()..color = const Color(0x99FF355E);
    canvas.drawOval(Rect.fromCenter(center: base.translate(0, -74), width: 58, height: 70), shadow);
    canvas.drawPath(Path()..moveTo(base.dx, base.dy - 150)..lineTo(base.dx - 56, base.dy + 15)..lineTo(base.dx + 64, base.dy + 15)..close(), shadow);
  }

  @override
  bool shouldRepaint(covariant NightRuinsPainter oldDelegate) => oldDelegate.time != time;
}
