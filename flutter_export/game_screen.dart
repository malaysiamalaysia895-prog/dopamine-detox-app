// ============================================================
// game_screen.dart
// Tech Tycoon Merge — Flutter UI
// Adapts to all 5 grid sizes (4×4, 5×5, 6×5, 6×6)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'level_config.dart';
import 'game_state.dart';
import 'ad_manager.dart';

// ─── Root game view ──────────────────────────────────────────────────────────

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPhase = ref.watch(appPhaseProvider);

    return switch (appPhase) {
      AppPhase.menu         => const _MenuView(),
      AppPhase.playing      => const _PlayingView(),
      AppPhase.levelComplete => const _LevelCompleteOverlay(),
      AppPhase.gameOver     => const _GameOverOverlay(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MENU VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _MenuView extends ConsumerWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameNotifier = ref.read(gameProvider.notifier);
    final totalCoins   = ref.watch(gameProvider).totalCoins;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0A000F), Color(0xFF000510)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text('🖥️', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFCC00FF)],
                ).createShader(r),
                child: const Text('Tech Tycoon Merge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text('50 Levels · 5 Phases · From Garage to Galaxy',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
              if (totalCoins > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                  ),
                  child: Text('💰 ${totalCoins.toStringAsFixed(0)} coins',
                    style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                ),
              ],
              const Spacer(),
              // Phase quick-start buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _MenuButton('▶  Start Game (Level 1)',
                      color: const Color(0xFF00E5FF),
                      onTap: () => gameNotifier.startLevel(0)),
                    const SizedBox(height: 10),
                    ...['🔌 Phase 1: Garage (L1)', '💻 Phase 2: Office (L11)',
                        '🥽 Phase 3: Silicon (L21)', '🧠 Phase 4: Corp (L31)',
                        '☀️ Phase 5: Universe (L41)']
                      .asMap()
                      .entries
                      .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MenuButton(e.value,
                          color: const Color(0xFF444455),
                          onTap: () => gameNotifier.startLevel(e.key * 10),
                          small: true),
                      )),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool small;

  const _MenuButton(this.label, {required this.color, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: small ? 12 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: small ? 13 : 16),
        ),
        child: Text(label),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAYING VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _PlayingView extends ConsumerWidget {
  const _PlayingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state  = ref.watch(gameProvider);
    final cfg    = state.currentLevel;
    final theme  = PhaseThemes.of(cfg.phase);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [theme.background, theme.background.withOpacity(0.6), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _GameHUD(cfg: cfg, theme: theme),
                  Expanded(child: _GameGrid(cfg: cfg, theme: theme)),
                  _Spawner(cfg: cfg, theme: theme),
                ],
              ),
              // Rule 2 — hard energy lockout wall
              if (state.showEnergyWarning)
                _ZeroEnergyWall(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HUD ──────────────────────────────────────────────────────────────────────

class _GameHUD extends ConsumerWidget {
  final LevelModel cfg;
  final PhaseTheme theme;

  const _GameHUD({required this.cfg, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final target = ItemChains.getById(cfg.targetItemId);
    final energyPct = state.energy / state.maxEnergy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          // Top row
          Row(
            children: [
              // Back
              GestureDetector(
                onTap: () => ref.read(gameProvider.notifier).goToMenu(),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white38, size: 18),
              ),
              const SizedBox(width: 8),
              // Level info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level ${cfg.levelNumber}: ${cfg.title}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(cfg.story, style: const TextStyle(color: Colors.white38, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Timer (Phase 4 timed orders)
              if (state.timerActive)
                _TimerBadge(seconds: state.timerSeconds),
              const SizedBox(width: 8),
              // Coins
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('COINS', style: TextStyle(color: Colors.white38, fontSize: 9)),
                Text('💰 ${state.totalCoins}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          // Target
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Text('Target: ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                Text(target?.emoji ?? '?', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(target?.name ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                Text('+${cfg.baseCoins} 💰',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Energy bar
          Row(
            children: [
              Text('⚡${state.energy}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: energyPct,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      energyPct > 0.5 ? Colors.green
                          : energyPct > 0.2 ? Colors.orange
                          : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${state.maxEnergy}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          // Rule 1 — low energy ad button
          if (ref.watch(gameProvider).shouldShowLowEnergyButton) ...[
            const SizedBox(height: 8),
            _LowEnergyAdButton(theme: theme),
          ],
        ],
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final int seconds;
  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: urgent ? Colors.red.withOpacity(0.3) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: urgent ? Colors.red : Colors.white24),
      ),
      child: Text(
        '${(seconds ~/ 60).toString().padLeft(1, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
        style: TextStyle(
          color: urgent ? Colors.red : Colors.white,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          fontSize: 16,
        ),
      ),
    );
  }
}

// ── Rule 1: Low Energy Ad Button ─────────────────────────────────────────────

class _LowEnergyAdButton extends ConsumerWidget {
  final PhaseTheme theme;
  const _LowEnergyAdButton({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await AdManagerService.instance.showRewardedAd(
          // onReward fires ONLY after full ad completion
          onReward: () => ref.read(gameProvider.notifier).addEnergy(50),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFFFFD700), Colors.orange]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 12)],
        ),
        child: const Center(
          child: Text('⚡ Low Energy! Watch Ad for +50 ⚡',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ),
    );
  }
}

// ── Rule 2: Zero Energy Hard Lockout Popup ────────────────────────────────────

class _ZeroEnergyWall extends ConsumerWidget {
  final PhaseTheme theme;
  const _ZeroEnergyWall({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF2A0000), Color(0xFF0A0010)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AdUnit ID badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Text(
                  'REWARDED AD · ${TechTycoonLevels.rewardedAdUnitId}',
                  style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              const Text('⚡', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 10),
              const Text('Energy Depleted!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('You cannot spawn items.\nWatch a Video to recharge.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 20),
              // Watch ad button — onReward callback adds energy
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    ref.read(gameProvider.notifier).dismissEnergyWarning();
                    await AdManagerService.instance.showRewardedAd(
                      onReward: () => ref.read(gameProvider.notifier).addEnergy(50),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  child: const Text('📺 Watch Video to Recharge +50 ⚡'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => ref.read(gameProvider.notifier).dismissEnergyWarning(),
                child: const Text('Dismiss', style: TextStyle(color: Colors.white30)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game Grid ─────────────────────────────────────────────────────────────────

class _GameGrid extends ConsumerStatefulWidget {
  final LevelModel cfg;
  final PhaseTheme theme;
  const _GameGrid({required this.cfg, required this.theme});

  @override
  ConsumerState<_GameGrid> createState() => _GameGridState();
}

class _GameGridState extends ConsumerState<_GameGrid> {
  int? _dragFromCol;
  int? _dragFromRow;

  @override
  Widget build(BuildContext context) {
    final grid = ref.watch(gridProvider);
    if (grid.isEmpty) return const SizedBox.shrink();

    final cfg = widget.cfg;
    final theme = widget.theme;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cellW = (constraints.maxWidth  - (cfg.gridCols - 1) * 6) / cfg.gridCols;
          final cellH = (constraints.maxHeight - (cfg.gridRows - 1) * 6) / cfg.gridRows;
          final cellSize = cellW < cellH ? cellW : cellH;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cfg.gridRows, (r) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(cfg.gridCols, (c) {
                    return Padding(
                      padding: const EdgeInsets.all(3),
                      child: _GridCellWidget(
                        cell: grid[c][r],
                        col: c, row: r,
                        size: cellSize,
                        theme: theme,
                        isDragSource: _dragFromCol == c && _dragFromRow == r,
                        isDragging: _dragFromCol != null,
                        onDragStart: () => setState(() {
                          _dragFromCol = c;
                          _dragFromRow = r;
                        }),
                        onDrop: () {
                          if (_dragFromCol != null && _dragFromRow != null) {
                            ref.read(gameProvider.notifier)
                                .moveItem(_dragFromCol!, _dragFromRow!, c, r);
                          }
                          setState(() { _dragFromCol = null; _dragFromRow = null; });
                        },
                        onTap: () {
                          if (_dragFromCol != null) {
                            ref.read(gameProvider.notifier)
                                .moveItem(_dragFromCol!, _dragFromRow!, c, r);
                            setState(() { _dragFromCol = null; _dragFromRow = null; });
                          } else {
                            ref.read(gameProvider.notifier).spawnItem(c, r);
                          }
                        },
                      ),
                    );
                  }),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _GridCellWidget extends StatelessWidget {
  final GridCell cell;
  final int col, row;
  final double size;
  final PhaseTheme theme;
  final bool isDragSource;
  final bool isDragging;
  final VoidCallback onDragStart;
  final VoidCallback onDrop;
  final VoidCallback onTap;

  const _GridCellWidget({
    required this.cell, required this.col, required this.row,
    required this.size, required this.theme,
    required this.isDragSource, required this.isDragging,
    required this.onDragStart, required this.onDrop, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = cell.itemId != null ? ItemChains.getById(cell.itemId!) : null;
    final isBlackHole = cell.obstacle == ObstacleType.blackHole;

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: item != null ? (_) => onDragStart() : null,
      onLongPressEnd: item != null ? (_) => onDrop() : null,
      child: DragTarget<String>(
        onAcceptWithDetails: (_) => onDrop(),
        builder: (ctx, candidateData, __) {
          return Draggable<String>(
            data: '${col}_$row',
            feedback: _CellFeedback(item: item, size: size),
            childWhenDragging: _CellBody(
              item: null, cell: cell, theme: theme, size: size,
              isDragSource: true, isDragging: false, isCandidate: false, isBlackHole: isBlackHole,
            ),
            onDragStarted: onDragStart,
            onDragEnd: (_) {},
            child: _CellBody(
              item: item, cell: cell, theme: theme, size: size,
              isDragSource: isDragSource,
              isDragging: isDragging && !isDragSource,
              isCandidate: candidateData.isNotEmpty,
              isBlackHole: isBlackHole,
            ),
          );
        },
      ),
    );
  }
}

class _CellBody extends StatelessWidget {
  final ItemDef? item;
  final GridCell cell;
  final PhaseTheme theme;
  final double size;
  final bool isDragSource, isDragging, isCandidate, isBlackHole;

  const _CellBody({
    required this.item, required this.cell, required this.theme,
    required this.size, required this.isDragSource, required this.isDragging,
    required this.isCandidate, required this.isBlackHole,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;

    if (isBlackHole) {
      bg = Colors.black;
      border = Colors.purple.withOpacity(0.5);
    } else if (cell.isLocked) {
      bg = Colors.black26;
      border = Colors.white10;
    } else if (isCandidate) {
      bg = theme.primaryColor.withOpacity(0.3);
      border = theme.primaryColor;
    } else if (isDragSource) {
      bg = Colors.white.withOpacity(0.2);
      border = const Color(0xFFFFD700);
    } else if (item != null) {
      bg = Colors.white.withOpacity(0.1);
      border = Colors.white24;
    } else {
      bg = Colors.white.withOpacity(0.04);
      border = Colors.white10;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: isCandidate ? 2 : 1),
        boxShadow: isDragSource
          ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 10)]
          : null,
      ),
      child: Center(
        child: isBlackHole
          ? Text('🕳️', style: TextStyle(fontSize: size * 0.42))
          : cell.isLocked
            ? _ObstacleIcon(type: cell.obstacle, size: size)
            : item != null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(item!.emoji, style: TextStyle(fontSize: size * 0.4)),
                  const SizedBox(height: 2),
                  Text(item!.name,
                    style: TextStyle(color: Colors.white70, fontSize: size * 0.11,
                        fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                ])
              : null,
      ),
    );
  }
}

class _CellFeedback extends StatelessWidget {
  final ItemDef? item;
  final double size;
  const _CellFeedback({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.white30, blurRadius: 16)],
        ),
        child: Center(
          child: Text(item?.emoji ?? '?', style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }
}

class _ObstacleIcon extends StatelessWidget {
  final ObstacleType type;
  final double size;
  const _ObstacleIcon({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    final emoji = switch (type) {
      ObstacleType.dustyWeb    => '🕸️',
      ObstacleType.lockedCrate => '📦',
      ObstacleType.timedOrder  => '⏱️',
      ObstacleType.blackHole   => '🕳️',
      ObstacleType.none        => '',
    };
    return Text(emoji, style: TextStyle(fontSize: size * 0.4));
  }
}

// ── Spawner ───────────────────────────────────────────────────────────────────

class _Spawner extends ConsumerWidget {
  final LevelModel cfg;
  final PhaseTheme theme;
  const _Spawner({required this.cfg, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(gameProvider);
    final baseItem = ItemChains.chainForPhase(cfg.phase).first;
    final canSpawn = state.energy > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('SPAWNER', style: TextStyle(color: Colors.white24, fontSize: 9,
              letterSpacing: 3)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              // Find first empty cell and spawn there
              final grid = ref.read(gridProvider);
              for (int c = 0; c < cfg.gridCols; c++) {
                for (int r = 0; r < cfg.gridRows; r++) {
                  if (grid[c][r].isEmpty) {
                    ref.read(gameProvider.notifier).spawnItem(c, r);
                    return;
                  }
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: canSpawn
                  ? LinearGradient(colors: [theme.primaryColor.withOpacity(0.4), theme.accentColor.withOpacity(0.2)])
                  : null,
                color: canSpawn ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canSpawn ? theme.primaryColor : Colors.white12,
                  width: canSpawn ? 2 : 1,
                ),
                boxShadow: canSpawn
                  ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 14)]
                  : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(baseItem.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Spawn ${baseItem.name}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    Text('-${cfg.energyCostPerSpawn}${cfg.fasterEnergyDrain ? " ⚡ (fast drain)" : " ⚡"}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                  const SizedBox(width: 14),
                  Text('⚡${state.energy}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEVEL COMPLETE OVERLAY (Rules 3 & 4)
// ═══════════════════════════════════════════════════════════════════════════

class _LevelCompleteOverlay extends ConsumerStatefulWidget {
  const _LevelCompleteOverlay();

  @override
  ConsumerState<_LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends ConsumerState<_LevelCompleteOverlay> {
  bool _adWatched = false;
  bool _awaitingInterstitial = false;

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(gameProvider);
    final cfg    = state.currentLevel;
    final theme  = PhaseThemes.of(cfg.phase);
    final target = ItemChains.getById(cfg.targetItemId);
    final isLast = state.currentLevelIndex == TechTycoonLevels.get50Levels().length - 1;

    // Rule 4: interstitial only fires on even levels
    final willShowInterstitial = cfg.triggerInterstitialNext && cfg.levelNumber % 2 == 0;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [theme.primaryColor.withOpacity(0.15), Colors.black],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text('Level ${cfg.levelNumber} Complete!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                const SizedBox(height: 6),
                Text(cfg.story, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 20),
                // Target item
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(target?.emoji ?? '?', style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(target?.name ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text('Built!', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 20),
                // Coin display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(children: [
                    const Text('Coins Earned', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('💰 ${state.levelCompleteCoins}',
                      style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 38)),
                    if (_adWatched)
                      const Text('✓ 3× MULTIPLIER APPLIED!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Rule 3 — 3× ad button (only if allowScoreMultiplier is true)
                if (cfg.allowScoreMultiplier && !_adWatched) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final shown = await AdManagerService.instance.showRewardedAd(
                          // onReward fires ONLY after full ad completion
                          onReward: () {
                            ref.read(gameProvider.notifier).multiplyCoins(3);
                            setState(() => _adWatched = true);
                          },
                        );
                        if (!shown) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ad not ready. Try again shortly.')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      child: const Text('📺 Watch Ad to get 3× Coins!'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Rule 4 — Next Level button (fires interstitial on even levels)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _awaitingInterstitial ? null : () async {
                      setState(() => _awaitingInterstitial = true);
                      // goToNextLevel() handles Rule 4 internally:
                      //   - even levels: showInterstitialAd → startLevel in onDismiss
                      //   - odd levels: startLevel immediately
                      await ref.read(gameProvider.notifier).goToNextLevel();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    child: Text(
                      _awaitingInterstitial ? '⏳ Loading ad…'
                        : isLast ? '🎉 Back to Menu'
                        : willShowInterstitial ? 'Next Level → (Ad)'
                        : 'Next Level →',
                    ),
                  ),
                ),
                if (willShowInterstitial && !_awaitingInterstitial) ...[
                  const SizedBox(height: 4),
                  Text('Interstitial · ${TechTycoonLevels.interstitialAdUnitId}',
                    style: const TextStyle(color: Colors.white12, fontSize: 8)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GAME OVER OVERLAY (Timed Order expired)
// ═══════════════════════════════════════════════════════════════════════════

class _GameOverOverlay extends ConsumerWidget {
  const _GameOverOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(currentLevelProvider);

    return Scaffold(
      backgroundColor: Colors.black90,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A0000), Color(0xFF0A000A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 10),
              const Text("Time's Up!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
              const SizedBox(height: 8),
              Text('Level ${cfg.levelNumber}: ${cfg.title}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              // Watch ad to retry
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await AdManagerService.instance.showRewardedAd(
                      onReward: () {
                        ref.read(gameProvider.notifier).addEnergy(50);
                        ref.read(gameProvider.notifier).restartLevel();
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  child: const Text('📺 Watch Ad to Retry'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ref.read(gameProvider.notifier).restartLevel(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Restart Level'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => ref.read(gameProvider.notifier).goToMenu(),
                child: const Text('Main Menu', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
