// ============================================================
// level_map_screen.dart — Scrollable Level Selection Map
// 5 Themes: Basic Tech, Robotics, Sci-Fi, Galaxy, Cosmic
// Tech Tycoon Merge
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';
import '../themes/phase_themes.dart';
import '../painters/painters.dart';
import 'settings_screen.dart';

class LevelMapScreen extends ConsumerWidget {
  const LevelMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter, radius: 1.5,
          colors: [Color(0xFF1A0A2E), Color(0xFF0A0014), Color(0xFF000000)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const _StaticStarField(),
          SafeArea(
            child: Column(
              children: [
                const _Header(),
                const Expanded(child: _PhaseScrollMap()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCoins = ref.watch(gameProvider).totalCoins;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFF42A5F5), Color(0xFF00E5FF), Color(0xFFAA00FF), Color(0xFFFFD700)],
            ).createShader(r),
            child: const Text('Tech Tycoon Merge',
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 1.2,
              )),
          ),
          const Spacer(),
          _CoinBadge(coins: totalCoins),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => showSettingsSheet(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.settings_outlined, color: Colors.white60, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final int coins;
  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFFFD700)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.5), blurRadius: 12)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('💰', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Text('$coins',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
      ]),
    );
  }
}

// ─── Phase Scroll Map ─────────────────────────────────────────────────────────

class _PhaseScrollMap extends StatelessWidget {
  const _PhaseScrollMap();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: GamePhase.values.length,
      itemBuilder: (ctx, phaseIdx) {
        final phase = GamePhase.values[phaseIdx];
        final theme = themeOf(phase);
        final startLevel = phaseIdx * 10 + 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PhaseHeader(theme: theme, phase: phase),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: List.generate(10, (i) {
                  final lvlNum = startLevel + i;
                  return _LevelNode(
                    levelNumber: lvlNum,
                    theme: theme,
                  );
                }),
              ),
              const SizedBox(height: 8),
              Divider(color: theme.primary.withOpacity(0.2), thickness: 1),
            ],
          ),
        );
      },
    );
  }
}

// ─── Phase Header ─────────────────────────────────────────────────────────────

class _PhaseHeader extends StatelessWidget {
  final PhaseTheme theme;
  final GamePhase phase;
  const _PhaseHeader({required this.theme, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primary.withOpacity(0.20), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: theme.primary, width: 4)),
        boxShadow: [
          BoxShadow(color: theme.primary.withOpacity(0.15), blurRadius: 12),
        ],
      ),
      child: Row(children: [
        // Theme icon badge
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [theme.primary.withOpacity(0.4), theme.primary.withOpacity(0.1)],
            ),
            border: Border.all(color: theme.primary.withOpacity(0.7), width: 2),
            boxShadow: [BoxShadow(color: theme.primary.withOpacity(0.5), blurRadius: 10)],
          ),
          child: Center(
            child: Text(_phaseEmoji(phase), style: const TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(theme.name,
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.5,
            )),
          const SizedBox(height: 2),
          Text(theme.subtitle,
            style: TextStyle(
              color: theme.primary.withOpacity(0.55),
              fontSize: 11,
              letterSpacing: 0.3,
            )),
          const SizedBox(height: 2),
          Text(_phaseDesc(phase),
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
        const Spacer(),
        // Phase tier range badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.primary.withOpacity(0.4)),
            color: theme.primary.withOpacity(0.08),
          ),
          child: Text(_phaseTierRange(phase),
            style: TextStyle(
              color: theme.primary.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
        ),
      ]),
    );
  }

  String _phaseEmoji(GamePhase p) {
    switch (p) {
      case GamePhase.garage: return '🔌';
      case GamePhase.office:  return '🤖';
      case GamePhase.silicon:     return '🚀';
      case GamePhase.megacorp:    return '🛸';
      case GamePhase.universe:    return '⚫';
    }
  }

  String _phaseDesc(GamePhase p) {
    switch (p) {
      case GamePhase.garage: return 'Copper Wire → PC Case';
      case GamePhase.office:  return 'Servo Motor → Full Cyborg';
      case GamePhase.silicon:     return 'Neon Wire → Spaceship Engine';
      case GamePhase.megacorp:    return 'Meteorite Shard → Galaxy Portal';
      case GamePhase.universe:    return 'Dark Matter → Black Hole';
    }
  }

  String _phaseTierRange(GamePhase p) {
    switch (p) {
      case GamePhase.garage: return 'T1 – T10';
      case GamePhase.office:  return 'T11 – T20';
      case GamePhase.silicon:     return 'T21 – T30';
      case GamePhase.megacorp:    return 'T31 – T40';
      case GamePhase.universe:    return 'T41 – T50';
    }
  }
}

// ─── Level Node ───────────────────────────────────────────────────────────────

class _LevelNode extends ConsumerWidget {
  final int levelNumber;
  final PhaseTheme theme;

  const _LevelNode({required this.levelNumber, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highest    = ref.watch(highestLvlProvider);
    final isNext     = levelNumber == highest;
    final isUnlocked = true; // TESTING: all levels unlocked
    final levelDef   = kLevels[levelNumber - 1];

    if (isNext) {
      return _AnimatedLevelNode(
        levelDef: levelDef,
        theme: theme,
        onTap: () => ref.read(gameProvider.notifier).startLevel(levelNumber - 1),
      );
    }

    return _StaticLevelNode(
      levelDef: levelDef,
      isUnlocked: isUnlocked,
      theme: theme,
      onTap: isUnlocked
          ? () => ref.read(gameProvider.notifier).startLevel(levelNumber - 1)
          : null,
    );
  }
}

// ── Animated Node — only the "next" level ────────────────────────────────────

class _AnimatedLevelNode extends StatefulWidget {
  final LevelDefinition levelDef;
  final PhaseTheme theme;
  final VoidCallback onTap;

  const _AnimatedLevelNode({
    required this.levelDef,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_AnimatedLevelNode> createState() => _AnimatedLevelNodeState();
}

class _AnimatedLevelNodeState extends State<_AnimatedLevelNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _bounce, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _bounceAnim.value),
        child: _NodeBody(
          levelDef: widget.levelDef,
          isUnlocked: true,
          isGlowing: true,
          theme: widget.theme,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

// ── Static Node ───────────────────────────────────────────────────────────────

class _StaticLevelNode extends StatelessWidget {
  final LevelDefinition levelDef;
  final bool isUnlocked;
  final PhaseTheme theme;
  final VoidCallback? onTap;

  const _StaticLevelNode({
    required this.levelDef,
    required this.isUnlocked,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _NodeBody(
      levelDef: levelDef,
      isUnlocked: isUnlocked,
      isGlowing: false,
      theme: theme,
      onTap: onTap,
    );
  }
}

// ─── Shared Node Body ─────────────────────────────────────────────────────────

class _NodeBody extends StatelessWidget {
  final LevelDefinition levelDef;
  final bool isUnlocked;
  final bool isGlowing;
  final PhaseTheme theme;
  final VoidCallback? onTap;

  const _NodeBody({
    required this.levelDef,
    required this.isUnlocked,
    required this.isGlowing,
    required this.theme,
    required this.onTap,
  });

  // Tier icon for each level based on its phase's starting item
  String _tierEmoji(LevelDefinition def) {
    switch (def.phase) {
      case GamePhase.garage: return ['🔌','🪢','💾','🔧','🧩','💿','🔋','🌀','🎮','🖥️'][(def.number - 1) % 10];
      case GamePhase.office:  return ['⚙️','👁️','🤖','🦾','🔋','🧠','🚗','🦿','⚙️','👾'][(def.number - 11) % 10];
      case GamePhase.silicon:     return ['💡','⚡','🔦','🛸','🧬','🔬','🦺','🛡️','🏍️','🚀'][(def.number - 21) % 10];
      case GamePhase.megacorp:    return ['🪨','💎','🔥','🛸','🗿','📡','🛰️','🌕','🚀','🌀'][(def.number - 31) % 10];
      case GamePhase.universe:    return ['⚫','🔭','⭐','🌌','⚛️','💥','🕳️','🌀','🌑','⚫'][(def.number - 41) % 10];
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 72.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isUnlocked
              ? RadialGradient(colors: [
                  theme.primary.withOpacity(0.45),
                  theme.primary.withOpacity(0.12),
                  Colors.black.withOpacity(0.3),
                ])
              : const RadialGradient(colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)]),
          border: Border.all(
            color: isUnlocked
                ? (isGlowing ? theme.primary : theme.primary.withOpacity(0.55))
                : Colors.white10,
            width: isGlowing ? 3 : 1.5,
          ),
          boxShadow: isGlowing
              ? [
                  BoxShadow(color: theme.primary.withOpacity(0.85), blurRadius: 24, spreadRadius: 4),
                  BoxShadow(color: theme.primary.withOpacity(0.40), blurRadius: 12),
                ]
              : isUnlocked
                  ? [BoxShadow(color: theme.primary.withOpacity(0.30), blurRadius: 10)]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isUnlocked)
              const Text('🔒', style: TextStyle(fontSize: 20, color: Colors.white24))
            else ...[
              Text(_tierEmoji(levelDef), style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 1),
              Text('${levelDef.number}',
                style: TextStyle(
                  color: isGlowing ? theme.primary : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                )),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Static Star Field ────────────────────────────────────────────────────────

class _StaticStarField extends StatelessWidget {
  const _StaticStarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _StarFieldPainter(),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    for (int i = 0; i < 140; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.6 + 0.2;
      final o = rng.nextDouble() * 0.45 + 0.05;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withOpacity(o));
    }
    // Extra gold/purple dust for cosmic feel
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final isGold = rng.nextBool();
      canvas.drawCircle(
        Offset(x, y),
        rng.nextDouble() * 1.0 + 0.2,
        Paint()..color = (isGold ? const Color(0xFFFFD700) : const Color(0xFFAA00FF))
            .withOpacity(rng.nextDouble() * 0.25 + 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
