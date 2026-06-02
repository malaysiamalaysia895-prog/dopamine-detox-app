// ============================================================
// level_map_screen.dart — Scrollable 3D Level Selection Map
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
              colors: [Color(0xFF00E5FF), Color(0xFFCC00FF), Color(0xFFFFD700)],
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
          // Settings gear
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

class _PhaseHeader extends StatelessWidget {
  final PhaseTheme theme;
  final GamePhase phase;
  const _PhaseHeader({required this.theme, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primary.withOpacity(0.25), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: theme.primary, width: 3)),
      ),
      child: Row(children: [
        Text(_phaseEmoji(phase), style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(theme.name,
            style: TextStyle(
              color: theme.primary, fontWeight: FontWeight.w900, fontSize: 14)),
          Text(theme.subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ]),
    );
  }

  String _phaseEmoji(GamePhase p) {
    switch (p) {
      case GamePhase.garage:   return '🔌';
      case GamePhase.office:   return '💻';
      case GamePhase.silicon:  return '🥽';
      case GamePhase.megacorp: return '🧠';
      case GamePhase.universe: return '☀️';
    }
  }
}

// ─── Level Node ───────────────────────────────────────────────────────────────
// PERFORMANCE FIX: We use a ConsumerWidget to read the highestUnlockedLevel
// and then delegate to either _AnimatedLevelNode (for the one "next" level
// that actually needs a bounce) or _StaticLevelNode (for all 49 others).
//
// The old approach created 50 AnimationController objects in initState()
// simultaneously, causing a 4-5 second freeze on the Level Map screen.
// Now only exactly ONE AnimationController is ever alive at a time.

class _LevelNode extends ConsumerWidget {
  final int levelNumber;
  final PhaseTheme theme;

  const _LevelNode({required this.levelNumber, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highest    = ref.watch(highestLvlProvider);
    final isNext     = levelNumber == highest;
    final isUnlocked = levelNumber <= highest;
    final levelDef   = kLevels[levelNumber - 1];

    if (isNext) {
      // Only this one node creates an AnimationController.
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
// Exactly ONE of these exists at a time, so exactly ONE AnimationController.

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

// ── Static Node — all other levels (no AnimationController) ──────────────────

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

  @override
  Widget build(BuildContext context) {
    const size = 68.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isUnlocked
              ? RadialGradient(colors: [
                  theme.primary.withOpacity(0.4),
                  theme.primary.withOpacity(0.1),
                ])
              : const RadialGradient(colors: [Color(0xFF2A2A2A), Color(0xFF111111)]),
          border: Border.all(
            color: isUnlocked
                ? (isGlowing ? theme.primary : theme.primary.withOpacity(0.5))
                : Colors.white12,
            width: isGlowing ? 3 : 1.5,
          ),
          boxShadow: isGlowing
              ? [BoxShadow(color: theme.primary.withOpacity(0.8), blurRadius: 20, spreadRadius: 3)]
              : isUnlocked
                  ? [BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 8)]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isUnlocked)
              const Text('🔒', style: TextStyle(fontSize: 22, color: Colors.white38))
            else
              Text('${levelDef.number}',
                style: TextStyle(
                  color: isGlowing ? theme.primary : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                )),
            if (isUnlocked) ...[
              const SizedBox(height: 2),
              Text(
                levelDef.title.length > 7
                    ? '${levelDef.title.substring(0, 6)}…'
                    : levelDef.title,
                style: TextStyle(
                  color: theme.primary.withOpacity(0.8),
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Static Star Field (map background) ──────────────────────────────────────

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
    final rng = Random(42); // fixed seed for stable map
    for (int i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.4 + 0.2;
      final o = rng.nextDouble() * 0.4 + 0.05;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withOpacity(o));
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
