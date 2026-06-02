// ============================================================
// game_board_screen.dart — Main Game Board (All 5 Phases)
// 3D tactile grid, delivery zone drag-target, animations,
// HUD, timer, popups, all 4 AdMob rules
// Tech Tycoon Merge
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';
import '../themes/phase_themes.dart';
import '../painters/painters.dart';
import '../services/ad_manager.dart';
import '../services/audio_manager.dart';
import '../providers/settings_provider.dart';
import 'settings_screen.dart';

class GameBoardScreen extends ConsumerWidget {
  const GameBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelDef = ref.watch(gameProvider).currentLevel;
    final theme    = themeOf(levelDef.phase);

    // PopScope prevents the Android hardware/gesture back button from
    // navigating away mid-game. Players must use the in-game back arrow.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: theme.backgroundDecoration,
          child: buildPhaseBackground(
            phase: levelDef.phase,
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _TopBar(levelDef: levelDef, theme: theme),
                      if (levelDef.hasTimer) _TimerBar(theme: theme),
                      _DeliveryZone(levelDef: levelDef, theme: theme),
                      Expanded(child: _Grid(levelDef: levelDef, theme: theme)),
                      _Spawner(levelDef: levelDef, theme: theme),
                    ],
                  ),
                  // Hazard hit flash — full-screen red blip
                  const _HazardFlashOverlay(),
                  // Dialog overlay layer
                  _DialogLayer(theme: theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  final LevelDefinition levelDef;
  final PhaseTheme theme;
  const _TopBar({required this.levelDef, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final energyPct = state.energy / state.maxEnergy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back
              GestureDetector(
                onTap: () => ref.read(gameProvider.notifier).goToMap(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white38, size: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Level ${levelDef.number}: ${levelDef.title}',
                    style: TextStyle(
                      color: theme.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(themeOf(levelDef.phase).name,
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ]),
              ),
              // Coins
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('COINS', style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1)),
                Text('💰 ${state.totalCoins}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
              const SizedBox(width: 6),
              // Mute toggle — reactive to settingsProvider
              Consumer(builder: (_, ref2, __) {
                final muted = ref2.watch(settingsProvider).muted;
                return GestureDetector(
                  onTap: () => ref2.read(settingsProvider.notifier).setMuted(!muted),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: muted
                          ? Colors.red.withOpacity(0.2)
                          : Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      muted ? Icons.volume_off : Icons.volume_up,
                      color: muted ? Colors.red : Colors.white38,
                      size: 16,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),
              // Settings gear
              GestureDetector(
                onTap: () => showSettingsSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white38, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Energy bar
          Row(children: [
            Text('⚡${state.energy}',
              style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: energyPct,
                  minHeight: 8,
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
            Text('${state.maxEnergy}',
              style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ]),
        ],
      ),
    );
  }
}

// ─── Timer Bar (Phase 4+) ─────────────────────────────────────────────────────

class _TimerBar extends ConsumerWidget {
  final PhaseTheme theme;
  const _TimerBar({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secs = ref.watch(timerProvider);
    final urgent = secs <= 10;
    final mins = secs ~/ 60;
    final s    = secs % 60;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: urgent ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent ? Colors.red : theme.primary.withOpacity(0.3),
          width: urgent ? 2 : 1,
        ),
        boxShadow: urgent
          ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 12)]
          : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(urgent ? '⚠️' : '⏱️', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '${mins.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: urgent ? Colors.red : theme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          const Text('remaining', style: TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Delivery Zone ────────────────────────────────────────────────────────────

class _DeliveryZone extends ConsumerWidget {
  final LevelDefinition levelDef;
  final PhaseTheme theme;
  const _DeliveryZone({required this.levelDef, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state   = ref.watch(gameProvider);
    final pct     = ref.watch(quotaPctProvider);

    return DragTarget<_DragData>(
      onAcceptWithDetails: (details) {
        ref.read(gameProvider.notifier)
            .handleDrag(details.data.col, details.data.row, isDelivery: true);
      },
      builder: (ctx, candidates, _) {
        final isActive = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? theme.primary.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? theme.primary : Colors.white12,
              width: isActive ? 2.5 : 1,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: theme.primary.withOpacity(0.5), blurRadius: 16)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(isActive ? '📦 DROP HERE' : '📦 DELIVERY QUOTA',
                  style: TextStyle(
                    color: isActive ? theme.primary : Colors.white38,
                    fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                  )),
                const Spacer(),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: pct >= 1.0 ? Colors.green : theme.primary,
                    fontWeight: FontWeight.w900, fontSize: 14,
                  )),
              ]),
              const SizedBox(height: 6),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(
                    pct >= 1.0 ? Colors.green : theme.primary),
                ),
              ),
              const SizedBox(height: 8),
              // Quota items
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: levelDef.quota.map((q) {
                    final delivered = state.quotaDelivered[q.itemId] ?? 0;
                    final done      = delivered >= q.count;
                    final item      = ItemDictionary.getById(q.itemId);
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _QuotaChip(
                        emoji: item?.emoji ?? '?',
                        name:  item?.name  ?? '',
                        needed: q.count,
                        delivered: delivered,
                        done: done,
                        theme: theme,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuotaChip extends StatelessWidget {
  final String emoji, name;
  final int needed, delivered;
  final bool done;
  final PhaseTheme theme;

  const _QuotaChip({
    required this.emoji, required this.name,
    required this.needed, required this.delivered,
    required this.done, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? Colors.green.withOpacity(0.2)
            : theme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done ? Colors.green : theme.primary.withOpacity(0.4),
          width: done ? 2 : 1,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(done ? '✅' : emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text('$delivered/$needed',
          style: TextStyle(
            color: done ? Colors.green : Colors.white,
            fontWeight: FontWeight.w900, fontSize: 12,
          )),
        Text(name.length > 8 ? '${name.substring(0, 7)}…' : name,
          style: const TextStyle(color: Colors.white38, fontSize: 8)),
      ]),
    );
  }
}

// ─── Drag Data ────────────────────────────────────────────────────────────────

class _DragData {
  final int col, row;
  final int itemId;
  const _DragData({required this.col, required this.row, required this.itemId});
}

// ─── Grid ─────────────────────────────────────────────────────────────────────

class _Grid extends ConsumerWidget {
  final LevelDefinition levelDef;
  final PhaseTheme theme;
  const _Grid({required this.levelDef, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid        = ref.watch(gridProvider);
    final deletionMode = ref.watch(deletionModeProvider);
    if (grid.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cellW = (constraints.maxWidth  - (levelDef.gridCols + 1) * 5) / levelDef.gridCols;
          final cellH = (constraints.maxHeight - (levelDef.gridRows + 1) * 5) / levelDef.gridRows;
          final cellSize = min(cellW, cellH).clamp(0.0, 70.0);

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(levelDef.gridRows, (r) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(levelDef.gridCols, (c) => Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: _GridCell(
                    cell: grid[c][r], col: c, row: r,
                    size: cellSize, theme: theme,
                    deletionMode: deletionMode,
                  ),
                )),
              )),
            ),
          );
        },
      ),
    );
  }
}

// ─── Grid Cell (Animated) ─────────────────────────────────────────────────────

class _GridCell extends ConsumerStatefulWidget {
  final GridCell cell;
  final int col, row;
  final double size;
  final PhaseTheme theme;
  final bool deletionMode;

  const _GridCell({
    required this.cell, required this.col, required this.row,
    required this.size, required this.theme, required this.deletionMode,
  });

  @override
  ConsumerState<_GridCell> createState() => _GridCellState();
}

class _GridCellState extends ConsumerState<_GridCell>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _shakeAnim;
  bool _highlighted = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(_scaleCtrl);

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _triggerSpawn() {
    _scaleCtrl.forward(from: 0);
  }

  void _triggerMerge() {
    _scaleCtrl.forward(from: 0);
  }

  void _triggerError() {
    _shakeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for pending animations targeting this cell
    ref.listen<List<PendingAnimation>>(animProvider, (prev, next) {
      for (final anim in next) {
        if (anim.col == widget.col && anim.row == widget.row) {
          switch (anim.type) {
            case AnimType.spawn:      _triggerSpawn();  break;
            case AnimType.merge:      _triggerMerge();  break;
            case AnimType.error:      _triggerError();  break;
            case AnimType.unlock:     _triggerSpawn();  break;
            case AnimType.hazardHit:  break; // handled by _HazardFlashOverlay
          }
          ref.read(gameProvider.notifier).consumeAnimation(anim);
        }
      }
    });

    final cell   = widget.cell;
    final item   = cell.itemId != null ? ItemDictionary.getById(cell.itemId!) : null;
    final isBlackHole = cell.obstacle == ObstacleType.blackHole;
    final isDeletable = widget.deletionMode && cell.itemId != null && !cell.isBlocked;

    // Build the visual decoration FIRST and capture it before any reassignment.
    // This is critical: the DragTarget/Draggable builder is a closure that captures
    // variables by reference. If we reassigned 'cellBody' and then referenced it
    // inside the builder, Flutter would get the DragTarget itself as the Draggable's
    // child → infinite widget loop → blank grid.
    final Widget decoration = _buildCellDecoration(cell, item, isBlackHole, isDeletable);
    Widget cellBody = decoration;

    // Wrap with draggable if it has an item and not in deletion mode
    if (item != null && !widget.deletionMode) {
      cellBody = DragTarget<_DragData>(
        onWillAcceptWithDetails: (details) {
          setState(() => _highlighted = true);
          return !cell.isBlocked;
        },
        onLeave: (_) => setState(() => _highlighted = false),
        onAcceptWithDetails: (details) {
          setState(() => _highlighted = false);
          ref.read(gameProvider.notifier).handleDrag(
            details.data.col, details.data.row,
            toCol: widget.col, toRow: widget.row,
          );
        },
        builder: (ctx, candidates, rejected) {
          return Draggable<_DragData>(
            data: _DragData(col: widget.col, row: widget.row, itemId: item.id),
            feedback: _DragFeedback(item: item, size: widget.size),
            childWhenDragging: _buildEmptyCell(),
            // Use 'decoration' (the pre-captured value), NOT 'cellBody' (the variable),
            // to avoid the DragTarget wrapping itself recursively.
            child: decoration,
          );
        },
      );
    } else if (cell.isEmpty) {
      // Empty cell — also a drag target for moves
      cellBody = DragTarget<_DragData>(
        onWillAcceptWithDetails: (_) { setState(() => _highlighted = true); return true; },
        onLeave: (_) => setState(() => _highlighted = false),
        onAcceptWithDetails: (details) {
          setState(() => _highlighted = false);
          ref.read(gameProvider.notifier).handleDrag(
            details.data.col, details.data.row,
            toCol: widget.col, toRow: widget.row,
          );
        },
        builder: (ctx, candidates, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.size, height: widget.size,
            decoration: widget.theme.gridCellDecoration(
              isEmpty: true, isHighlighted: _highlighted || candidates.isNotEmpty),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleCtrl, _shakeCtrl]),
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: Transform.scale(
            scale: _scaleCtrl.isAnimating ? _scaleAnim.value : 1.0,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          if (isDeletable) {
            ref.read(gameProvider.notifier).deleteItemInRescueMode(widget.col, widget.row);
          } else if (cell.isHazard) {
            ref.read(gameProvider.notifier).tapHazard(widget.col, widget.row);
          } else if (cell.isEmpty) {
            ref.read(gameProvider.notifier).spawnItem(
              targetCol: widget.col, targetRow: widget.row);
          }
        },
        child: cellBody,
      ),
    );
  }

  Widget _buildCellDecoration(GridCell cell, ItemDef? item, bool isBlackHole, bool isDeletable) {
    if (isBlackHole) return _BlackHoleTile(size: widget.size);
    if (cell.obstacle == ObstacleType.hazardTrap)
      return _HazardTile(size: widget.size);
    if (cell.obstacle == ObstacleType.dustyWeb)
      return _ObstacleTile(emoji: '🕸️', label: 'Web', size: widget.size, theme: widget.theme);
    if (cell.obstacle == ObstacleType.lockedCrate)
      return _ObstacleTile(emoji: '📦', label: 'Locked', size: widget.size, theme: widget.theme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: widget.size, height: widget.size,
      decoration: widget.theme.gridCellDecoration(
        isEmpty: item == null,
        isHighlighted: _highlighted || isDeletable,
      ),
      child: item == null ? null : Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(item.emoji, style: TextStyle(fontSize: widget.size * 0.38)),
          const SizedBox(height: 1),
          Text(
            item.name.length > 10 ? '${item.name.substring(0, 9)}…' : item.name,
            style: TextStyle(
              color: isDeletable ? Colors.redAccent : widget.theme.textPrimary.withOpacity(0.7),
              fontSize: widget.size * 0.1,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          if (isDeletable) ...[
            Text('🗑️', style: TextStyle(fontSize: widget.size * 0.18)),
          ],
        ]),
      ),
    );
  }

  Widget _buildEmptyCell() => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: widget.size, height: widget.size,
    decoration: widget.theme.gridCellDecoration(isEmpty: true),
  );
}

class _ObstacleTile extends StatelessWidget {
  final String emoji, label;
  final double size;
  final PhaseTheme theme;
  const _ObstacleTile({required this.emoji, required this.label, required this.size, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: TextStyle(fontSize: size * 0.38)),
        Text(label, style: TextStyle(color: Colors.white24, fontSize: size * 0.1)),
      ]),
    );
  }
}

// ─── Hazard Flash Overlay (full-screen red blip on trap tap) ─────────────────

class _HazardFlashOverlay extends ConsumerStatefulWidget {
  const _HazardFlashOverlay();

  @override
  ConsumerState<_HazardFlashOverlay> createState() => _HazardFlashOverlayState();
}

class _HazardFlashOverlayState extends ConsumerState<_HazardFlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    // Quick flash: fade in fast (0→peak), then fade out slowly
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.55)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 75,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerFlash() {
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<PendingAnimation>>(animProvider, (_, next) {
      for (final anim in next) {
        if (anim.col == -1 && anim.row == -1 &&
            anim.type == AnimType.hazardHit) {
          _triggerFlash();
          ref.read(gameProvider.notifier).consumeAnimation(anim);
        }
      }
    });

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) {
        if (_opacity.value == 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: Container(
            color: const Color(0xFFDD0000).withOpacity(_opacity.value),
          ),
        );
      },
    );
  }
}

// ─── Hazard Trap Tile (pulsing red warning) ────────────────────────────────────

class _HazardTile extends StatefulWidget {
  final double size;
  const _HazardTile({required this.size});

  @override
  State<_HazardTile> createState() => _HazardTileState();
}

class _HazardTileState extends State<_HazardTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        return Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFF1A0000), const Color(0xFF420000), t),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Color.lerp(Colors.red.shade800, Colors.redAccent, t)!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.25 + 0.35 * t),
                blurRadius: 8 + 8 * t,
                spreadRadius: t * 2,
              ),
            ],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('⚡', style: TextStyle(fontSize: widget.size * 0.30)),
            Text('TRAP',
              style: TextStyle(
                color: Color.lerp(Colors.red.shade400, const Color(0xFFFF6E6E), t),
                fontSize: widget.size * 0.115,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              )),
            Text('-20⚡',
              style: TextStyle(
                color: Colors.redAccent.withOpacity(0.65 + 0.35 * t),
                fontSize: widget.size * 0.095,
                fontWeight: FontWeight.bold,
              )),
          ]),
        );
      },
    );
  }
}

// ─── Black Hole Tile (rotating) ───────────────────────────────────────────────

class _BlackHoleTile extends StatefulWidget {
  final double size;
  const _BlackHoleTile({required this.size});

  @override
  State<_BlackHoleTile> createState() => _BlackHoleTileState();
}

class _BlackHoleTileState extends State<_BlackHoleTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _rot;

  @override
  void initState() {
    super.initState();
    _rot = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() { _rot.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rot,
      builder: (_, __) => Transform.rotate(
        angle: _rot.value * 2 * pi,
        child: Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            boxShadow: [
              BoxShadow(color: const Color(0xFF9C27B0).withOpacity(0.8), blurRadius: 18, spreadRadius: 3),
              BoxShadow(color: const Color(0xFF4B0082).withOpacity(0.5), blurRadius: 6),
            ],
          ),
          child: Center(
            child: Text('🕳️', style: TextStyle(fontSize: widget.size * 0.45)),
          ),
        ),
      ),
    );
  }
}

// ─── Drag Feedback ────────────────────────────────────────────────────────────

class _DragFeedback extends StatelessWidget {
  final ItemDef item;
  final double size;
  const _DragFeedback({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.white30, blurRadius: 16)],
        ),
        child: Center(child: Text(item.emoji, style: TextStyle(fontSize: size * 0.45))),
      ),
    );
  }
}

// ─── Spawner Bar ──────────────────────────────────────────────────────────────

class _Spawner extends ConsumerWidget {
  final LevelDefinition levelDef;
  final PhaseTheme theme;
  const _Spawner({required this.levelDef, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state   = ref.watch(gameProvider);
    final base    = ItemDictionary.getById(levelDef.spawnerItemId);
    final canSpawn = state.energy > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
      child: GestureDetector(
        onTap: () => ref.read(gameProvider.notifier).spawnItem(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: canSpawn ? theme.spawnerDecoration : BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(base?.emoji ?? '?', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Spawn ${base?.name ?? ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                Text(canSpawn ? 'Costs 1 ⚡' : '⛔ Out of Energy',
                  style: TextStyle(
                    color: canSpawn ? Colors.white38 : Colors.red,
                    fontSize: 11)),
              ]),
              const Spacer(),
              // Energy counter
              Column(children: [
                const Text('ENERGY', style: TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 1)),
                Text('${state.energy}',
                  style: TextStyle(
                    color: theme.primary, fontWeight: FontWeight.w900, fontSize: 22)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIALOG LAYER — all popups overlaid on the game board
// ═══════════════════════════════════════════════════════════════════════════════

class _DialogLayer extends ConsumerWidget {
  final PhaseTheme theme;
  const _DialogLayer({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialog = ref.watch(dialogProvider);
    if (dialog == ActiveDialog.none) return const SizedBox.shrink();

    Widget popup;
    switch (dialog) {
      case ActiveDialog.story:
        popup = _StoryDialog(theme: theme);
        break;
      case ActiveDialog.zeroEnergy:
        popup = _ZeroEnergyDialog(theme: theme);
        break;
      case ActiveDialog.gridFull:
        popup = _GridFullDialog(theme: theme);
        break;
      case ActiveDialog.victory:
        popup = _VictoryDialog(theme: theme);
        break;
      case ActiveDialog.timeFail:
        popup = _TimeFailDialog(theme: theme);
        break;
      case ActiveDialog.gameBeaten:
        popup = _GameBeatenDialog(theme: theme);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(child: popup),
    );
  }
}

// ─── Story Dialog ─────────────────────────────────────────────────────────────

class _StoryDialog extends ConsumerWidget {
  final PhaseTheme theme;
  const _StoryDialog({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(gameProvider).currentLevel;
    return _BaseDialog(
      theme: theme,
      children: [
        Text(_phaseEmoji(level.phase), style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        Text('Level ${level.number}: ${level.title}',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 10),
        Text(level.story,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        const SizedBox(height: 6),
        if (level.quota.isNotEmpty) ...[
          const Divider(color: Colors.white12),
          const SizedBox(height: 6),
          const Text('DELIVERY QUOTA',
            style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: level.quota.map((q) {
              final item = ItemDictionary.getById(q.itemId);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.primary.withOpacity(0.4)),
                ),
                child: Text('${item?.emoji ?? '?'} ×${q.count} ${item?.name ?? ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),
        _FullButton('Let\'s Go! 🚀', color: theme.primary, dark: true,
          onTap: () => ref.read(gameProvider.notifier).dismissStory()),
      ],
    );
  }

  String _phaseEmoji(GamePhase p) => switch (p) {
    GamePhase.garage   => '🔧',
    GamePhase.office   => '💼',
    GamePhase.silicon  => '🧬',
    GamePhase.megacorp => '🌐',
    GamePhase.universe => '🌌',
  };
}

// ─── Zero Energy Dialog — Dual Refill Options ─────────────────────────────────

class _ZeroEnergyDialog extends ConsumerWidget {
  final PhaseTheme theme;
  const _ZeroEnergyDialog({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins     = ref.watch(gameProvider).totalCoins;
    final canAfford = coins >= 200;

    return _BaseDialog(theme: theme, children: [
      const Text('⚡', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 10),
      const Text('Out of Energy!',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
      const SizedBox(height: 8),
      const Text('Choose a refill option to restore 100 ⚡',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 20),

      // ── Option A: Watch Ad ────────────────────────────────────────────────
      _FullButton('📺 Watch Ad — Refill 100 ⚡  (Free)',
        color: const Color(0xFFFFD700), dark: true,
        onTap: () => ref.read(gameProvider.notifier).watchAdForEnergy()),

      const SizedBox(height: 14),
      const Row(children: [
        Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('OR', style: TextStyle(color: Colors.white24, fontSize: 11,
              letterSpacing: 1.5)),
        ),
        Expanded(child: Divider(color: Colors.white12)),
      ]),
      const SizedBox(height: 14),

      // ── Option B: Spend 200 Coins ─────────────────────────────────────────
      Opacity(
        opacity: canAfford ? 1.0 : 0.38,
        child: _FullButton(
          canAfford
              ? '💰 Spend 200 Coins — Refill 100 ⚡'
              : '💰 Need 200 Coins  (you have $coins)',
          color: const Color(0xFF00E5FF), dark: true,
          onTap: canAfford
              ? () => ref.read(gameProvider.notifier).spendCoinsForEnergy()
              : () {},
        ),
      ),

      const SizedBox(height: 16),
      TextButton(
        onPressed: () => ref.read(gameProvider.notifier).retryLevel(),
        child: const Text('↩ Restart Level',
          style: TextStyle(color: Colors.white30, fontSize: 12)),
      ),
    ]);
  }
}

// ─── Grid Full Dialog (Phase 3+: Rewarded Ad) ─────────────────────────────────

class _GridFullDialog extends ConsumerWidget {
  final PhaseTheme theme;
  const _GridFullDialog({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BaseDialog(theme: theme, children: [
      const Text('🗑️', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 10),
      const Text('Grid Full!',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
      const SizedBox(height: 8),
      const Text('No more merges possible.\nWatch an ad to destroy 1 junk item.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 24),
      _FullButton('📺 Watch Ad — Delete 1 Item 🗑️',
        color: const Color(0xFFCC00FF), dark: true,
        onTap: () => ref.read(gameProvider.notifier).watchAdForGridRescue()),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => ref.read(gameProvider.notifier).dismissVictory(),
        child: const Text('Dismiss', style: TextStyle(color: Colors.white30)),
      ),
    ]);
  }
}

// ─── Victory Dialog (Rules 3 + 4) ────────────────────────────────────────────

class _VictoryDialog extends ConsumerStatefulWidget {
  final PhaseTheme theme;
  const _VictoryDialog({required this.theme});

  @override
  ConsumerState<_VictoryDialog> createState() => _VictoryDialogState();
}

class _VictoryDialogState extends ConsumerState<_VictoryDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(gameProvider);
    final level    = state.currentLevel;
    final isEven   = level.number % 2 == 0;
    final isLast   = level.number == kLevels.length;

    return _BaseDialog(theme: widget.theme, children: [
      const Text('🏆', style: TextStyle(fontSize: 72)),
      const SizedBox(height: 8),
      Text('Level ${level.number} Complete!',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
      const SizedBox(height: 6),
      Text(level.story.split('.').first + '.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 18),
      // Coins display
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(children: [
          const Text('COINS EARNED', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          Text('💰 ${state.levelEarnedCoins}',
            style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 40)),
          if (state.coinsMultiplied)
            const Text('🎉 3× MULTIPLIER APPLIED!',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      // Rule 3 — 3× coins button
      if (!state.coinsMultiplied) ...[
        _FullButton('📺 Watch Ad for 3× Coins!',
          color: const Color(0xFFFFD700), dark: true,
          onTap: () => ref.read(gameProvider.notifier).watchAdForMultiplier()),
        const SizedBox(height: 10),
      ],
      // Rule 4 — Next Level / interstitial gate (ad plays automatically)
      _busy
          ? const CircularProgressIndicator(color: Colors.white38)
          : _FullButton(
              isLast ? '🎉 You\'ve Won!' : 'Next Level →',
              color: Colors.white12, dark: false,
              onTap: () async {
                if (_busy) return;
                setState(() => _busy = true);
                await ref.read(gameProvider.notifier).goToNextLevel();
                // Do NOT reset _busy here — the widget unmounts when the next
                // level starts. Resetting it early would briefly re-show the
                // button while an interstitial ad is still covering the screen,
                // allowing a double-tap that triggers a second level transition.
              }),
    ]);
  }
}

// ─── Time Fail Dialog (Phase 4+ timer expired) ────────────────────────────────

class _TimeFailDialog extends ConsumerWidget {
  final PhaseTheme theme;
  const _TimeFailDialog({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(gameProvider).currentLevel;
    return _BaseDialog(theme: theme, children: [
      const Text('⏰', style: TextStyle(fontSize: 60)),
      const SizedBox(height: 10),
      const Text('TIME\'S UP!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 28)),
      const SizedBox(height: 6),
      Text('Level ${level.number}: ${level.title}',
        style: const TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 20),
      // Time extension ad button (Phase 4+)
      if (level.allowTimeExtension) ...[
        _FullButton('📺 Watch Ad for +60 Seconds! ⏳',
          color: const Color(0xFFFFD700), dark: true,
          onTap: () => ref.read(gameProvider.notifier).watchAdForTimeExtension()),
        const SizedBox(height: 10),
      ],
      _FullButton('🔄 Try Again', color: Colors.red.withOpacity(0.3), dark: false,
        onTap: () => ref.read(gameProvider.notifier).retryLevel()),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => ref.read(gameProvider.notifier).goToMap(),
        child: const Text('Main Menu', style: TextStyle(color: Colors.white38)),
      ),
    ]);
  }
}

// ─── Game Beaten Dialog ───────────────────────────────────────────────────────

class _GameBeatenDialog extends ConsumerWidget {
  final PhaseTheme theme;
  const _GameBeatenDialog({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BaseDialog(theme: theme, children: [
      const Text('☀️', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 12),
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFE5E4E2), Color(0xFFFFD700)],
        ).createShader(r),
        child: const Text('YOU CONQUERED\nTHE UNIVERSE!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
      ),
      const SizedBox(height: 10),
      const Text('GAME BEATEN — Tech God Status Achieved',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, letterSpacing: 1)),
      const SizedBox(height: 30),
      _FullButton('🌌 Back to Map', color: const Color(0xFFFFD700), dark: true,
        onTap: () => ref.read(gameProvider.notifier).goToMap()),
    ]);
  }
}

// ─── Shared Dialog Shell ──────────────────────────────────────────────────────

class _BaseDialog extends StatelessWidget {
  final PhaseTheme theme;
  final List<Widget> children;

  const _BaseDialog({required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            theme.primary.withOpacity(0.12),
            Colors.black.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primary.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: theme.primary.withOpacity(0.3), blurRadius: 30, spreadRadius: 2),
          const BoxShadow(color: Colors.black87, blurRadius: 10),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _FullButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool dark;
  final VoidCallback onTap;

  const _FullButton(this.label, {required this.color, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: dark ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 8,
          shadowColor: color.withOpacity(0.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        child: Text(label),
      ),
    );
  }
}
