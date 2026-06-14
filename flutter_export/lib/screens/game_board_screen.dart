// ============================================================
// game_board_screen.dart — Main Game Board (All 5 Phases)
// AAA overhaul: neumorphic tiles, VFX, 3D Printer spawner,
// locked/rusted tiles, supply drop care packages, arc overlay
// Tech Tycoon Merge
// ============================================================

import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui' as ui;
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
import '../widgets/malware_overlay.dart';
import '../widgets/robot_overlay.dart';

// ─── GameBoardScreen (ConsumerStatefulWidget for arc overlay keys) ────────────

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  final _spawnerKey = GlobalKey();
  final _gridKey    = GlobalKey();
  double _lastCellSize = 60.0;

  void _onCellSizeChanged(double size) {
    _lastCellSize = size;
  }

  @override
  Widget build(BuildContext context) {
    final levelDef = ref.watch(gameProvider).currentLevel;
    final theme    = themeOf(levelDef.phase);

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
                  // Full-screen ambient particles — floats behind everything, theme-tinted
                  Positioned.fill(
                    child: _AmbientParticleLayer(color: theme.primary, count: 30),
                  ),
                  // Subtle vignette behind all UI (depth layer, reduced opacity)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.85,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withOpacity(0.20),
                              Colors.black.withOpacity(0.45),
                            ],
                            stops: const [0.0, 0.45, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _TopBar(levelDef: levelDef, theme: theme),
                      if (levelDef.hasTimer) _TimerBar(theme: theme),
                      _DeliveryZone(levelDef: levelDef, theme: theme),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          // ── GLASSMORPHISM GAME BOARD ─────────────────────
                          // Outer shell: transparent so phase particles show
                          // through. Only the boxShadow renders here (neon glow
                          // ring + depth shadow) — NO opaque fill.
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                // Phase neon outer glow
                                BoxShadow(
                                  color: theme.primary.withOpacity(0.72),
                                  blurRadius: 44,
                                  spreadRadius: 8,
                                ),
                                // Deep depth shadow beneath board
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.90),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                  spreadRadius: 2,
                                ),
                                // Top-left metallic highlight
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.10),
                                  blurRadius: 6,
                                  offset: const Offset(-4, -4),
                                ),
                              ],
                            ),
                            // ClipRRect MUST wrap BackdropFilter so the blur
                            // is clipped to the rounded rectangle shape.
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                // Blur sigmaX/Y = 16 → Frosted Dark Glass effect.
                                // Blurs the phase particles + bg gradient that sit
                                // BEHIND this widget in the render layer, making
                                // the dynamic phase environment visible through
                                // the board while keeping block tiles sharp.
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 16.0, sigmaY: 16.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    // Near-black base — stops outer gradient from
                                    // bleeding through as yellow. The frosted-glass
                                    // look comes from the border + BackdropFilter.
                                    color: Colors.black.withOpacity(0.82),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: theme.primary.withOpacity(0.85),
                                      width: 4.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        // ① AAA depth atmosphere — phase-specific
                                        //    bottom-up radial glow: looks like heat
                                        //    rising in the Forge, cyan energy in
                                        //    Office, etc. Changes per phase via
                                        //    theme.primary. Depth/3D feel.
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                  center: const Alignment(0.0, 1.0),
                                                  radius: 1.4,
                                                  colors: [
                                                    Color.lerp(Colors.black,
                                                      theme.primary, 0.30)!,
                                                    Color.lerp(Colors.black,
                                                      theme.primary, 0.12)!,
                                                    const Color(0xFF050508),
                                                  ],
                                                  stops: const [0.0, 0.42, 1.0],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // ② Phase-tinted floating particles —
                                        //    drifting upward like energy/heat.
                                        Positioned.fill(
                                          child: _AmbientParticleLayer(
                                            color: theme.primary,
                                            count: 38,
                                          ),
                                        ),
                                        // ③ Grid tiles on top of the atmosphere
                                        _Grid(
                                          key: _gridKey,
                                          levelDef: levelDef,
                                          theme: theme,
                                          onCellSizeChanged: _onCellSizeChanged,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _3DPrinterSpawner(
                        key: _spawnerKey,
                        levelDef: levelDef,
                        theme: theme,
                      ),
                    ],
                  ),
                  // Red hazard flash overlay
                  const _HazardFlashOverlay(),
                  // Spawn arc overlay (parabolic trajectory)
                  _SpawnArcOverlay(
                    spawnerKey: _spawnerKey,
                    gridKey: _gridKey,
                    getCellSize: () => _lastCellSize,
                    levelDef: levelDef,
                  ),
                  // Dialog overlay
                  _DialogLayer(theme: theme),
                  // Malware Boss overlay (invisible when not on boss level)
                  MalwareOverlay(
                    controller: ref.read(gameProvider.notifier).malwareController,
                    onTutorialSkip: () =>
                        ref.read(gameProvider.notifier).malwareController.startAfterTutorial(),
                    getCellRect: (col, row) {
                      final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                      if (box == null || _lastCellSize == 0) return null;
                      const gap = 5.0;
                      final cs  = _lastCellSize;
                      // Mirror the exact layout math used by _SpawnArcOverlay:
                      // the inner grid is centered inside the ClipRRect container.
                      final totalW = levelDef.gridCols * (cs + gap) - gap;
                      final totalH = levelDef.gridRows * (cs + gap) - gap;
                      final gridGlobal = box.localToGlobal(Offset.zero);
                      final dx = gridGlobal.dx + (box.size.width  - totalW) / 2 + col * (cs + gap);
                      final dy = gridGlobal.dy + (box.size.height - totalH) / 2 + row * (cs + gap);
                      return Rect.fromLTWH(dx, dy, cs, cs);
                    },
                  ),
                  // Robot Boss overlay (L13, L15, L17, L20)
                  RobotOverlay(
                    controller: ref.read(gameProvider.notifier).robotController,
                  ),

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
    final state     = ref.watch(gameProvider);
    final energyPct = state.energy / state.maxEnergy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => ref.read(gameProvider.notifier).goToMap(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primary.withOpacity(0.75),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withOpacity(0.40),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
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
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('COINS', style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1)),
                Text('💰 ${state.totalCoins}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
              const SizedBox(width: 6),
              Consumer(builder: (_, ref2, __) {
                final muted = ref2.watch(settingsProvider).muted;
                return GestureDetector(
                  onTap: () => ref2.read(settingsProvider.notifier).setMuted(!muted),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: muted
                          ? Colors.red.withOpacity(0.25)
                          : Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: muted ? Colors.red.withOpacity(0.5) : Colors.white30,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      muted ? Icons.volume_off : Icons.volume_up,
                      color: muted ? Colors.red : Colors.white70,
                      size: 16,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => showSettingsSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white70, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
    final secs   = ref.watch(timerProvider);
    final urgent = secs <= 10;
    final mins   = secs ~/ 60;
    final s      = secs % 60;

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
    final state = ref.watch(gameProvider);
    final pct   = ref.watch(quotaPctProvider);

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
            borderRadius: BorderRadius.circular(16),
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primary.withOpacity(0.22),
                      const Color(0xFF0A0D18),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.primary.withOpacity(0.10), const Color(0xFF0D1020)],
                  ),
            border: Border.all(
              color: isActive ? theme.primary : theme.primary.withOpacity(0.35),
              width: isActive ? 2.0 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.primary.withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Color(0xAA000000),
                      offset: Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  isActive ? '📦  DROP HERE' : '🚀  DELIVERY QUOTA',
                  style: TextStyle(
                    color: isActive
                        ? theme.primary
                        : Colors.white.withOpacity(0.90),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: (pct >= 1.0 ? const Color(0xFF00E676) : theme.primary)
                        .withOpacity(0.18),
                    border: Border.all(
                      color: (pct >= 1.0 ? const Color(0xFF00E676) : theme.primary)
                          .withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: pct >= 1.0 ? const Color(0xFF00E676) : theme.primary,
                      fontWeight: FontWeight.w900, fontSize: 13,
                    )),
                ),
              ]),
              const SizedBox(height: 6),
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
                        itemId: q.itemId,
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
  final int itemId;
  final String name;
  final int needed, delivered;
  final bool done;
  final PhaseTheme theme;

  const _QuotaChip({
    required this.itemId, required this.name,
    required this.needed, required this.delivered,
    required this.done, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final chipNeon = done ? const Color(0xFF00E676) : theme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: done
              ? [const Color(0xFF0D2A1A), const Color(0xFF071510)]
              : [const Color(0xFF2E3458), const Color(0xFF1C2038)],
        ),
        border: Border.all(
          color: chipNeon.withOpacity(done ? 0.80 : 0.50),
          width: done ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: chipNeon.withOpacity(done ? 0.45 : 0.20),
            blurRadius: done ? 10 : 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 36, height: 32,
          child: done
              ? const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 26)
              : _ItemIconWidget(itemId: itemId, size: 28),
        ),
        const SizedBox(height: 3),
        Text('$delivered/$needed',
          style: TextStyle(
            color: done ? const Color(0xFF00E676) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          )),
        const SizedBox(height: 1),
        Text(
          name.length > 8 ? '${name.substring(0, 7)}…' : name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.80),
            fontSize: 8,
            letterSpacing: 0.3,
          ),
        ),
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
  final void Function(double) onCellSizeChanged;

  const _Grid({
    super.key,
    required this.levelDef,
    required this.theme,
    required this.onCellSizeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid         = ref.watch(gridProvider);
    final deletionMode = ref.watch(deletionModeProvider);
    if (grid.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cellW    = (constraints.maxWidth  - (levelDef.gridCols + 1) * 5) / levelDef.gridCols;
          final cellH    = (constraints.maxHeight - (levelDef.gridRows + 1) * 5) / levelDef.gridRows;
          final cellSize = min(cellW, cellH).clamp(0.0, 70.0);

          // Report cell size to parent for arc overlay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onCellSizeChanged(cellSize);
          });

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

// ─── Grid Cell (Animated + Neumorphic) ───────────────────────────────────────

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
  late AnimationController _mergeGlowCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _mergePulseCtrl;
  late AnimationController _decoyHitCtrl;   // floating -30 ⚡ text on decoy tap
  late Animation<double>   _scaleAnim;
  late Animation<double>   _shakeAnim;
  late Animation<double>   _mergeGlowAnim;
  late Animation<double>   _mergePulseAnim;
  bool   _highlighted = false;
  bool   _spawnPending = false;   // true while arc is in flight: show empty socket
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _mergeGlowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _burstCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
    _decoyHitCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.25).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 40),
    ]).animate(_scaleCtrl);

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));

    _mergeGlowAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 80),
    ]).animate(_mergeGlowCtrl);

    // FIX BUG 2: Merge uses a PULSE animation (1.0→1.28→1.0) so the block
    // never disappears — it just zooms briefly and settles back.
    _mergePulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _mergePulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),  weight: 60),
    ]).animate(_mergePulseCtrl);
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _shakeCtrl.dispose();
    _mergeGlowCtrl.dispose();
    _burstCtrl.dispose();
    _mergePulseCtrl.dispose();
    _decoyHitCtrl.dispose();
    super.dispose();
  }

  void _triggerDecoyHit() => _decoyHitCtrl.forward(from: 0);

  void _triggerSpawn() => _scaleCtrl.forward(from: 0);
  void _triggerMerge() {
    // BUG FIX: Stop any in-flight spawn scale animation immediately.
    // If _scaleCtrl is mid-animation (0→1.25→1), its value can be near 0
    // (block invisible) or above 1.0 (block overflows upward). Stopping it
    // makes isAnimating=false so the AnimatedBuilder falls through to scale=1.0.
    _scaleCtrl.stop();
    // BUG FIX: Clear the spawn-pending flag so the cell stops showing an empty
    // socket. Without this, if a merge fires within 550ms of a spawn arc
    // landing on this cell, the block stays invisible for the remaining delay.
    if (_spawnPending) setState(() => _spawnPending = false);
    _mergeGlowCtrl.forward(from: 0);
    _burstCtrl.forward(from: 0);
  }
  void _triggerError() => _shakeCtrl.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    // Listen for pending animations targeting this cell
    ref.listen<List<PendingAnimation>>(animProvider, (prev, next) {
      for (final anim in next) {
        if (anim.col == widget.col && anim.row == widget.row) {
          switch (anim.type) {
            case AnimType.spawn:       _triggerSpawn();  break;
            case AnimType.upwardSpawn:
              // TIMING FIX: keep empty socket visible during arc flight (600ms),
              // only reveal the item tile when arc arrives (at ~550ms).
              setState(() => _spawnPending = true);
              ref.read(gameProvider.notifier).consumeAnimation(anim);
              Future.delayed(const Duration(milliseconds: 550), () {
                // Guard: only reveal if _triggerMerge() hasn't already cleared
                // _spawnPending. Without this check, the delayed callback would
                // re-hide and re-show the merged block (causing a flash/jump).
                if (mounted && _spawnPending) {
                  setState(() => _spawnPending = false);
                  _triggerSpawn();
                }
              });
              continue; // skip the consumeAnimation call below
            case AnimType.merge:       _triggerMerge();  break;
            case AnimType.error:       _triggerError();  break;
            case AnimType.unlock:      _triggerSpawn();  break;
            case AnimType.hazardHit:   break; // handled by _HazardFlashOverlay
            case AnimType.decoyHit:    _triggerDecoyHit(); break;
          }
          ref.read(gameProvider.notifier).consumeAnimation(anim);
        }
      }
    });

    final cell         = widget.cell;
    final item         = cell.itemId != null ? ItemDictionary.getById(cell.itemId!) : null;
    final isBlackHole  = cell.obstacle == ObstacleType.blackHole;
    final isDeletable  = widget.deletionMode && cell.itemId != null && !cell.isBlocked;
    final isLockedItem = cell.obstacle == ObstacleType.lockedItem;

    // Supply drop detection
    final supplyDrop       = ref.watch(supplyDropProvider);
    final isSupplyDropCell = supplyDrop.$1 == widget.col && supplyDrop.$2 == widget.row;
    final supplyCountdown  = isSupplyDropCell ? ref.watch(supplyDropCountdownProvider) : 0;

    // Pre-capture decoration before any widget wrapping
    final Widget decoration = _buildCellDecoration(
      cell, item, isBlackHole, isDeletable, isLockedItem,
      isSupplyDropCell, supplyCountdown,
    );
    Widget cellBody = decoration;

    // ── Supply drop cell — tappable, not draggable ───────────────────────────
    if (isSupplyDropCell && !isLockedItem) {
      cellBody = GestureDetector(
        onTap: () => ref.read(gameProvider.notifier).tapSupplyDrop(widget.col, widget.row),
        child: decoration,
      );
    }
    // ── Locked item cell — drag target only ─────────────────────────────────
    else if (isLockedItem) {
      cellBody = DragTarget<_DragData>(
        onWillAcceptWithDetails: (details) {
          setState(() => _highlighted = true);
          return true; // actual validation in provider
        },
        onLeave: (_) => setState(() => _highlighted = false),
        onAcceptWithDetails: (details) {
          setState(() => _highlighted = false);
          ref.read(gameProvider.notifier).handleDrag(
            details.data.col, details.data.row,
            toCol: widget.col, toRow: widget.row,
          );
        },
        builder: (ctx, candidates, _) => decoration,
      );
    }
    // ── Normal item cell — draggable + drag target ───────────────────────────
    else if (item != null && !widget.deletionMode) {
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
            child: decoration,
          );
        },
      );
    }
    // ── Empty cell — drag target for moves ───────────────────────────────────
    else if (cell.isEmpty) {
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
    // BUG FIX (levels 5-20): hazardTrap/glitchedDecoy had no DragTarget.
    // Dropping an item on them now fires the same penalty as tapping.
    else if (cell.isHazard || cell.isDecoy) {
      cellBody = DragTarget<_DragData>(
        onWillAcceptWithDetails: (_) => true,
        onLeave: (_) => setState(() => _highlighted = false),
        onAcceptWithDetails: (details) {
          setState(() => _highlighted = false);
          ref.read(gameProvider.notifier).handleDrag(
            details.data.col, details.data.row,
            toCol: widget.col, toRow: widget.row,
          );
        },
        builder: (ctx, candidates, rejected) => decoration,
      );
    }

    // ── Merge glow ring overlay ───────────────────────────────────────────────
    final withGlow = AnimatedBuilder(
      animation: _mergeGlowAnim,
      builder: (_, child) {
        final glow = _mergeGlowAnim.value;
        if (glow <= 0) return child!;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.theme.primary.withOpacity(0.8 * glow),
                        blurRadius: 24 * glow,
                        spreadRadius: 4 * glow,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.6 * glow),
                        blurRadius: 12 * glow,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: cellBody,
    );

    // ── Merge burst particle overlay (sits above the glow ring) ─────────────
    final withBurst = AnimatedBuilder(
      animation: _burstCtrl,
      builder: (_, child) {
        final t = _burstCtrl.value;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            child!,
            if (t > 0 && t < 1.0)
              // LAYOUT BUG FIX: OverflowBox as a non-positioned Stack child
              // receives loose constraints from the Stack. Under loose
              // constraints it reports its size as the full available grid
              // height, making the Stack — and therefore the Row — as tall as
              // the entire grid. The Column then overflows its container, and
              // ClipRRect clips away all rows except the topmost ones, giving
              // the appearance that all blocks jumped to the top.
              // Fix: wrap in SizedBox.shrink() (0×0) so the Stack sees a
              // zero-size child and does NOT resize. OverflowBox still passes
              // its maxWidth/maxHeight to CustomPaint, so sparks render at
              // full size centred on the cell — purely visual, zero layout impact.
              IgnorePointer(
                child: SizedBox.shrink(
                  child: OverflowBox(
                    maxWidth: widget.size * 3.2,
                    maxHeight: widget.size * 3.2,
                    child: SizedBox(
                      width: widget.size * 3.2,
                      height: widget.size * 3.2,
                      child: CustomPaint(
                        painter: _SparkBurstPainter(
                          progress: t,
                          primaryColor: widget.theme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: withGlow,
    );

    final core = AnimatedBuilder(
      animation: Listenable.merge([_scaleCtrl, _shakeCtrl, _mergePulseCtrl]),
      builder: (_, child) {
        // spawn uses scale-from-0 pop-in; merge uses pulse 1→1.28→1
        final double scale;
        if (_mergePulseCtrl.isAnimating) {
          scale = _mergePulseAnim.value;
        } else if (_scaleCtrl.isAnimating) {
          scale = _scaleAnim.value;
        } else {
          scale = 1.0;
        }
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          // FIX BUG 4: debounce rapid taps — ignore if <350ms since last tap
          final now = DateTime.now();
          if (_lastTapTime != null &&
              now.difference(_lastTapTime!).inMilliseconds < 350) return;
          _lastTapTime = now;

          if (isDeletable) {
            ref.read(gameProvider.notifier).deleteItemInRescueMode(widget.col, widget.row);
          } else if (cell.isHazard) {
            ref.read(gameProvider.notifier).tapHazard(widget.col, widget.row);
          } else if (cell.isDecoy) {
            ref.read(gameProvider.notifier).tapDecoy(widget.col, widget.row);
          } else if (cell.isEmpty && !isSupplyDropCell) {
            ref.read(gameProvider.notifier).spawnItem(
              targetCol: widget.col, targetRow: widget.row);
          } else if (isSupplyDropCell) {
            ref.read(gameProvider.notifier).tapSupplyDrop(widget.col, widget.row);
          }
        },
        child: withBurst,
      ),
    );

    // ── Floating "-30 ⚡" text when a Glitched Decoy is tapped ────────────
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        core,
        IgnorePointer(
          child: SizedBox.shrink(
            child: AnimatedBuilder(
              animation: _decoyHitCtrl,
              builder: (_, __) {
                final t = _decoyHitCtrl.value;
                if (t <= 0) return const SizedBox.shrink();
                return Transform.translate(
                  offset: Offset(0, -widget.size * 2.6 * t),
                  child: Opacity(
                    opacity: (1.0 - t * 1.3).clamp(0.0, 1.0),
                    child: Text(
                      '-30 ⚡',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: widget.size * 0.24,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Colors.red, blurRadius: 10),
                          Shadow(color: Colors.red, blurRadius: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCellDecoration(
    GridCell cell, ItemDef? item, bool isBlackHole, bool isDeletable,
    bool isLockedItem, bool isSupplyDropCell, int supplyCountdown,
  ) {
    if (isBlackHole) return _BlackHoleTile(size: widget.size);
    if (cell.obstacle == ObstacleType.hazardTrap)
      return _HazardTile(size: widget.size);
    if (cell.obstacle == ObstacleType.dustyWeb)
      return _ObstacleTile(icon: Icons.filter_vintage, label: 'Web', size: widget.size, theme: widget.theme);
    if (cell.obstacle == ObstacleType.lockedCrate)
      return _ObstacleTile(icon: Icons.lock, label: 'Locked', size: widget.size, theme: widget.theme);
    if (cell.obstacle == ObstacleType.glitchedDecoy) {
      final mimicItem = cell.decoyItemId != null
          ? ItemDictionary.getById(cell.decoyItemId!)
          : null;
      return _GlitchedDecoyTile(
        size: widget.size, theme: widget.theme, item: mimicItem);
    }
    if (isLockedItem) {
      final lockedItem = cell.lockedItemId != null
          ? ItemDictionary.getById(cell.lockedItemId!)
          : null;
      return _LockedItemTile(
        size: widget.size, theme: widget.theme,
        item: lockedItem, isHighlighted: _highlighted,
      );
    }
    if (isSupplyDropCell) {
      return _SupplyDropTile(size: widget.size, countdown: supplyCountdown, theme: widget.theme);
    }

    // ── Empty cell: neumorphic inset well (no 3D model needed) ────────────
    if (item == null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size, height: widget.size,
        // Phase-aware empty socket: transparent with phase color tint
        decoration: widget.theme.gridCellDecoration(isEmpty: true),
      );
    }
    // ── Spawn pending: arc still in flight — show empty socket, not the item ──
    // The empty socket stays visible the whole time; the arc "delivers" the item.
    if (_spawnPending) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 0),
        width: widget.size, height: widget.size,
        // Phase-aware empty socket: transparent with phase color tint
        decoration: widget.theme.gridCellDecoration(isEmpty: true),
      );
    }
    // ── Item present: True 3D tile ────────────────────────────────────────────
    return _3DItemTile(
      key: ValueKey(item.id),
      item: item,
      size: widget.size,
      theme: widget.theme,
      isDeletable: isDeletable,
    );
  }

  BoxDecoration _neumorphicDecoration(ItemDef? item, bool isDeletable) {
    if (item == null) {
      // Empty socket: carbon-fiber dark inset cell
      return BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D101A), Color(0xFF080B12)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF060809), offset: Offset(3, 4), blurRadius: 7, spreadRadius: 1),
          BoxShadow(color: Color(0xFF1A2035), offset: Offset(-2, -2), blurRadius: 5),
        ],
        border: Border.all(color: Color(0xFF1E2535), width: 1),
      );
    }
    // Item tile: uses _3DItemTile widget for the full sci-fi look (called via _buildCellDecoration).
    // This fallback BoxDecoration is used only for non-item cells.
    final neon = isDeletable ? Colors.red : _itemGlowColor(item.id);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF22263A), Color(0xFF0E1018)],
      ),
      border: Border.all(color: neon, width: 2.2),
      boxShadow: [
        BoxShadow(color: neon.withOpacity(0.70), blurRadius: 14, spreadRadius: 1),
        const BoxShadow(color: Color(0xCC000000), offset: Offset(2, 4), blurRadius: 8),
      ],
    );
  }

  Widget _buildEmptyCell() => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: widget.size, height: widget.size,
    decoration: widget.theme.gridCellDecoration(isEmpty: true),
  );
}

// ─── Obstacle Tile ────────────────────────────────────────────────────────────

class _ObstacleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;
  final PhaseTheme theme;
  const _ObstacleTile({required this.icon, required this.label, required this.size, required this.theme});

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
        Icon(icon, color: Colors.white38, size: size * 0.38),
        Text(label, style: TextStyle(color: Colors.white24, fontSize: size * 0.1)),
      ]),
    );
  }
}

// ─── Locked / Rusted Item Tile ────────────────────────────────────────────────

class _LockedItemTile extends StatefulWidget {
  final double size;
  final PhaseTheme theme;
  final ItemDef? item;
  final bool isHighlighted;
  const _LockedItemTile({
    required this.size, required this.theme,
    required this.item, required this.isHighlighted,
  });

  @override
  State<_LockedItemTile> createState() => _LockedItemTileState();
}

class _LockedItemTileState extends State<_LockedItemTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _rust;

  @override
  void initState() {
    super.initState();
    _rust = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _rust.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rust,
      builder: (_, __) {
        final t = _rust.value;
        return Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF2A1800), const Color(0xFF3D2200), t)!,
                Color.lerp(const Color(0xFF1A1000), const Color(0xFF2C1A00), t)!,
              ],
            ),
            border: Border.all(
              color: widget.isHighlighted
                  ? Colors.greenAccent
                  : Color.lerp(const Color(0xFF8B4513), const Color(0xFFCD853F), t)!,
              width: widget.isHighlighted ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isHighlighted
                    ? Colors.greenAccent.withOpacity(0.5)
                    : const Color(0xFFCD853F).withOpacity(0.2 + 0.2 * t),
                blurRadius: widget.isHighlighted ? 12 : 6,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Rust texture stripes
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Opacity(
                    opacity: 0.15 + 0.1 * t,
                    child: CustomPaint(
                      painter: _RustStripePainter(),
                    ),
                  ),
                ),
              ),
              // Item emoji (dimmed)
              Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Opacity(
                    opacity: 0.55,
                    child: SizedBox(
                      width: widget.size * 0.58,
                      height: widget.size * 0.40,
                      child: widget.item != null
                          ? _ItemIconWidget(itemId: widget.item!.id, size: widget.size * 0.38)
                          : Icon(
                              Icons.lock_outline,
                              color: const Color(0xFFCD853F).withOpacity(0.7),
                              size: widget.size * 0.28,
                            ),
                    ),
                  ),
                  Text(
                    widget.isHighlighted ? 'UNLOCK!' : 'LOCKED',
                    style: TextStyle(
                      color: widget.isHighlighted ? Colors.greenAccent : const Color(0xFFCD853F),
                      fontSize: widget.size * 0.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ]),
              ),
              // Lock icon — top right corner
              Positioned(
                top: 3, right: 4,
                child: Icon(
                  widget.isHighlighted ? Icons.lock_open : Icons.lock,
                  color: widget.isHighlighted
                      ? Colors.greenAccent
                      : const Color(0xFFCD853F).withOpacity(0.8 + 0.2 * t),
                  size: widget.size * 0.22,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RustStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCD853F)
      ..strokeWidth = 3;
    for (double i = -size.height; i < size.width + size.height; i += 12) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Supply Drop Care Package Tile ────────────────────────────────────────────

class _SupplyDropTile extends StatefulWidget {
  final double size;
  final int countdown;
  final PhaseTheme theme;
  const _SupplyDropTile({required this.size, required this.countdown, required this.theme});

  @override
  State<_SupplyDropTile> createState() => _SupplyDropTileState();
}

class _SupplyDropTileState extends State<_SupplyDropTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _bounce.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final urgent = widget.countdown <= 3;

    return AnimatedBuilder(
      animation: _bounce,
      builder: (_, __) {
        final t = _bounce.value;
        return Transform.translate(
          offset: Offset(0, -4 * t),
          child: Container(
            width: widget.size, height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: urgent
                    ? [const Color(0xFF4A0000), const Color(0xFF2A0000)]
                    : [const Color(0xFF003A4A), const Color(0xFF001E2A)],
              ),
              border: Border.all(
                color: urgent
                    ? Colors.red.withOpacity(0.7 + 0.3 * t)
                    : Colors.cyanAccent.withOpacity(0.5 + 0.3 * t),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: urgent
                      ? Colors.red.withOpacity(0.4 + 0.3 * t)
                      : Colors.cyanAccent.withOpacity(0.25 + 0.2 * t),
                  blurRadius: 12 + 6 * t,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Mystery box icon with question mark (RNG loot — unknown outcome)
                Positioned(
                  top: widget.size * 0.06, left: 0, right: 0,
                  child: Center(
                    child: Text(
                      '❓',
                      style: TextStyle(
                        fontSize: widget.size * 0.36,
                        shadows: [
                          Shadow(
                            color: (urgent ? Colors.red : Colors.cyanAccent)
                                .withOpacity(0.85),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // "DROP BOX" label
                Positioned(
                  top: widget.size * 0.44, left: 0, right: 0,
                  child: Text(
                    'DROP BOX',
                    style: TextStyle(
                      color: (urgent ? Colors.red : Colors.cyanAccent).withOpacity(0.90),
                      fontSize: widget.size * 0.10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Countdown overlay
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.88)],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${widget.countdown}s',
                      style: TextStyle(
                        color: urgent ? Colors.red : Colors.cyanAccent,
                        fontSize: widget.size * 0.14,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Glitched Decoy Tile ──────────────────────────────────────────────────────
// Visually identical to _3DItemTile but with a periodic electric short-circuit
// glitch animation — a quick horizontal displacement + blue/red flash overlay.
// Triggered globally via decoyGlitchTickProvider.

class _GlitchedDecoyTile extends ConsumerStatefulWidget {
  final double size;
  final PhaseTheme theme;
  final ItemDef? item;
  const _GlitchedDecoyTile({required this.size, required this.theme, required this.item});
  @override
  ConsumerState<_GlitchedDecoyTile> createState() => _GlitchedDecoyTileState();
}

class _GlitchedDecoyTileState extends ConsumerState<_GlitchedDecoyTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _glitch;
  late Animation<double> _glitchAnim;

  @override
  void initState() {
    super.initState();
    _glitch = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _glitchAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: -1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -1.0, end: 0.0), weight: 30),
    ]).animate(_glitch);
  }

  @override
  void dispose() { _glitch.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(decoyGlitchTickProvider, (_, __) {
      if (mounted) _glitch.forward(from: 0);
    });

    if (widget.item == null) {
      return Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.theme.primary.withOpacity(0.55), width: 2),
          boxShadow: [BoxShadow(
            color: widget.theme.primary.withOpacity(0.30), blurRadius: 10)],
        ),
        child: Center(child: Text('?',
          style: TextStyle(color: widget.theme.primary,
            fontSize: widget.size * 0.40, fontWeight: FontWeight.w900))),
      );
    }

    final neon = _itemGlowColor(widget.item!.id);

    return AnimatedBuilder(
      animation: _glitchAnim,
      builder: (_, __) {
        final g = _glitchAnim.value;
        final glitching = _glitch.isAnimating;
        return Stack(
          children: [
            Transform.translate(
              offset: Offset(glitching ? g * 4.0 : 0.0, 0),
              child: Container(
                width: widget.size, height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: neon.withOpacity(0.80), blurRadius: 18, spreadRadius: 2),
                    const BoxShadow(color: Color(0xDD000000), offset: Offset(0, 5), blurRadius: 10),
                    BoxShadow(color: Colors.white.withOpacity(0.18), offset: const Offset(-1, -1), blurRadius: 3),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [neon.withOpacity(0.90), neon.withOpacity(0.55), neon.withOpacity(0.20)],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2.2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(const Color(0xFF060810), widget.theme.primary, 0.18)!.withOpacity(0.68),
                        Color.lerp(const Color(0xFF020408), widget.theme.primary, 0.08)!.withOpacity(0.55),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      children: [
                        Positioned.fill(child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-0.8, -0.8), radius: 1.6,
                              colors: [neon.withOpacity(0.45), Colors.transparent],
                            ),
                          ),
                        )),
                        Positioned.fill(child: Opacity(
                          opacity: 0.07, child: CustomPaint(painter: _HexGridPainter()))),
                        Positioned(
                          top: 0, left: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(11)),
                            child: Container(
                              width: widget.size * 0.55, height: widget.size * 0.55,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  colors: [Colors.white.withOpacity(0.12), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0, left: 0, right: 0, bottom: widget.size * 0.17,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _ItemIconWidget(itemId: widget.item!.id, size: widget.size * 0.56),
                          ),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Color.lerp(Colors.black, widget.theme.primary, 0.20)!.withOpacity(0.90),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              widget.item!.name.length > 9
                                  ? '${widget.item!.name.substring(0, 8)}…'
                                  : widget.item!.name,
                              style: TextStyle(
                                color: neon.withOpacity(0.90),
                                fontSize: widget.size * 0.095,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center, maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ── Electric voltage flash overlay ─────────────────────────────
            if (glitching)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: (g > 0 ? Colors.cyanAccent : Colors.redAccent)
                          .withOpacity(0.30 * g.abs()),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Hazard Flash Overlay ─────────────────────────────────────────────────────

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.55).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 75,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _triggerFlash() => _ctrl.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    ref.listen<List<PendingAnimation>>(animProvider, (_, next) {
      for (final anim in next) {
        if (anim.col == -1 && anim.row == -1 && anim.type == AnimType.hazardHit) {
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
          child: Container(color: const Color(0xFFDD0000).withOpacity(_opacity.value)),
        );
      },
    );
  }
}

// ─── Hazard Trap Tile ─────────────────────────────────────────────────────────

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
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
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

// ─── Black Hole Tile ──────────────────────────────────────────────────────────

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
    final neon = _itemGlowColor(item.id);
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.88,
        child: Container(
          width: size * 1.08, height: size * 1.08,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF22263A), Color(0xFF0E1018)],
            ),
            border: Border.all(color: neon, width: 2.5),
            boxShadow: [
              BoxShadow(color: neon.withOpacity(0.80), blurRadius: 20, spreadRadius: 2),
              const BoxShadow(color: Color(0xBB000000), offset: Offset(2, 4), blurRadius: 8),
            ],
          ),
          child: _ItemIconWidget(itemId: item.id, size: size * 0.72),
        ),
      ),
    );
  }
}



/// Returns the sci-fi neon glow color for a tile based on item tier.
/// Orange = tier 1-3, Purple = tier 4-8, Cyan = tier 9-16, Teal = tier 17-30, Gold = ultra
Color _itemGlowColor(int itemId) {
  if (itemId <= 3)  return const Color(0xFFFF6B00);  // orange  — basic components
  if (itemId <= 8)  return const Color(0xFFAA00FF);  // purple  — keyboards / CPUs
  if (itemId <= 16) return const Color(0xFF00BCD4);  // cyan    — builds / PCs
  if (itemId <= 30) return const Color(0xFF00E676);  // green   — advanced tech
  return const Color(0xFFFFD700);                    // gold    — ultra / legendary
}

// ─── True 3D Item Tile ────────────────────────────────────────────────────────

/// Stateful tile: shows an animated shimmer while the .glb streams in,
/// then fades the shimmer out once the model is ready.
class _3DItemTile extends StatefulWidget {
  final ItemDef    item;
  final double     size;
  final PhaseTheme theme;
  final bool       isDeletable;

  const _3DItemTile({
    super.key,
    required this.item,
    required this.size,
    required this.theme,
    this.isDeletable = false,
  });

  @override
  State<_3DItemTile> createState() => _3DItemTileState();
}

class _3DItemTileState extends State<_3DItemTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popIn;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    // value: 1.0 → tile starts fully visible; parent _GridCellState handles
    // ALL scale animation (spawn/merge), so no auto-forward pop-in here.
    // Previously _popIn.forward() caused the merged tile to be invisible
    // (scale 0) for 380ms while the parent's mergePulse played at scale 1,
    // resulting in a black flash on every merge.
    _popIn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380), value: 1.0);
    _popScale = CurvedAnimation(parent: _popIn, curve: Curves.elasticOut);
  }

  @override
  void dispose() { _popIn.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final neon = widget.isDeletable ? Colors.red : _itemGlowColor(widget.item.id);

    return ScaleTransition(
      scale: _popScale,
      child: Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // Outer metallic frame: bright neon glow + deep drop shadow + top-left highlight
          boxShadow: [
            // Neon bloom — outer ring
            BoxShadow(color: neon.withOpacity(0.80), blurRadius: 18, spreadRadius: 2),
            // Deep depth shadow beneath tile
            const BoxShadow(color: Color(0xDD000000), offset: Offset(0, 5), blurRadius: 10),
            // Top-left metallic edge highlight (simulates overhead light)
            BoxShadow(color: Colors.white.withOpacity(0.18), offset: const Offset(-1, -1), blurRadius: 3),
          ],
          // Outer gradient border ring (neon top-left → darker bottom-right = 3D chamfer)
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              neon.withOpacity(0.90),
              neon.withOpacity(0.55),
              neon.withOpacity(0.20),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        // Inner border ring creates the raised-bezel look
        child: Container(
          margin: const EdgeInsets.all(2.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Phase-tinted glassmorphism: semi-transparent so the neon border
            // glow and grid background bleed through. Color tint shifts with
            // each game phase (garage=amber, office=blue, silicon=pink,
            // megacorp=green, universe=gold).
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF060810), widget.theme.primary, 0.18)!
                    .withOpacity(0.68),
                Color.lerp(const Color(0xFF020408), widget.theme.primary, 0.08)!
                    .withOpacity(0.55),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                // Corner radial inner glow from top-left (key lighting)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.8, -0.8),
                        radius: 1.6,
                        // Boosted from 0.22 → 0.45: glass bg is more transparent
                        // so inner glow needs to be stronger to stay visible.
                        colors: [neon.withOpacity(0.45), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Carbon-fiber hex dot pattern
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.07,
                    child: CustomPaint(painter: _HexGridPainter()),
                  ),
                ),
                // Diagonal shine strip — top-left bevel highlight
                Positioned(
                  top: 0, left: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                    ),
                    child: Container(
                      width: widget.size * 0.55,
                      height: widget.size * 0.55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Real rotating 3D model — no emoji, no red-box
                Positioned(
                  top: 0, left: 0, right: 0,
                  bottom: widget.size * 0.17,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _ItemIconWidget(itemId: widget.item.id, size: widget.size * 0.56),
                  ),
                ),
                // Bottom name label with gradient scrim
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // Phase-tinted scrim instead of pure black
                        colors: [
                          Colors.transparent,
                          Color.lerp(Colors.black, widget.theme.primary, 0.20)!
                              .withOpacity(0.90),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      widget.item.name.length > 9
                          ? '${widget.item.name.substring(0, 8)}…'
                          : widget.item.name,
                      style: TextStyle(
                        color: widget.isDeletable
                            ? Colors.redAccent
                            : neon.withOpacity(0.90),
                        fontSize: widget.size * 0.095,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ),
                // Delete mode overlay
                if (widget.isDeletable) ...[
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: Colors.red.withOpacity(0.45),
                      ),
                    ),
                  ),
                  const Center(child: Text('🗑️', style: TextStyle(fontSize: 22))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hex-grid Carbon Fibre Painter ───────────────────────────────────────────
class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    const w = 10.0;
    const h = 11.5;
    for (double y = 0; y < size.height + h; y += h) {
      for (double x = 0; x < size.width + w; x += w * 1.5) {
        final ox = (y ~/ h) % 2 == 0 ? 0.0 : w * 0.75;
        final path = Path()
          ..moveTo(x + ox + w * 0.5, y)
          ..lineTo(x + ox + w, y + h * 0.25)
          ..lineTo(x + ox + w, y + h * 0.75)
          ..lineTo(x + ox + w * 0.5, y + h)
          ..lineTo(x + ox, y + h * 0.75)
          ..lineTo(x + ox, y + h * 0.25)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── 3D Printer Spawner ───────────────────────────────────────────────────────

class _3DPrinterSpawner extends ConsumerStatefulWidget {
  final LevelDefinition levelDef;
  final PhaseTheme theme;
  const _3DPrinterSpawner({super.key, required this.levelDef, required this.theme});

  @override
  ConsumerState<_3DPrinterSpawner> createState() => _3DPrinterSpawnerState();
}

class _3DPrinterSpawnerState extends ConsumerState<_3DPrinterSpawner>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;
  DateTime? _lastSpawnTap;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _glow.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(gameProvider);
    final base     = ItemDictionary.getById(widget.levelDef.spawnerItemId);
    final canSpawn = state.energy > 0;

    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        final t = _glow.value;
        final glowNeon = canSpawn
            ? widget.theme.primary
            : Colors.white.withOpacity(0.18);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
          child: GestureDetector(
            onTap: () {
              // FIX BUG 1/4: debounce spawner — prevents rapid multi-spawn
              final now = DateTime.now();
              if (_lastSpawnTap != null &&
                  now.difference(_lastSpawnTap!).inMilliseconds < 400) return;
              _lastSpawnTap = now;
              ref.read(gameProvider.notifier).spawnItem();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: canSpawn ? [
                  BoxShadow(
                    color: widget.theme.primary.withOpacity(0.45 + 0.2 * t),
                    blurRadius: 22 + 10 * t,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 6),
                    blurRadius: 12,
                  ),
                ] : [
                  const BoxShadow(
                    color: Color(0xAA000000),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: canSpawn
                            ? [
                                widget.theme.primary.withOpacity(0.18 + 0.06 * t),
                                Colors.white.withOpacity(0.04),
                                const Color(0xFF0A0D16),
                              ]
                            : [
                                Colors.white.withOpacity(0.06),
                                const Color(0xFF0A0D16),
                              ],
                        stops: canSpawn ? const [0.0, 0.4, 1.0] : const [0.0, 1.0],
                      ),
                      border: Border.all(
                        color: glowNeon.withOpacity(canSpawn ? 0.6 + 0.25 * t : 0.25),
                        width: canSpawn ? 1.8 : 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Spawner item icon — neon sci-fi tile style
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF22263A), Color(0xFF0E1018)],
                            ),
                            border: Border.all(
                              color: (canSpawn
                                  ? widget.theme.primary
                                  : Colors.white24)
                                  .withOpacity(canSpawn ? 0.7 + 0.2 * t : 0.3),
                              width: 1.8,
                            ),
                            boxShadow: canSpawn ? [
                              BoxShadow(
                                color: widget.theme.primary.withOpacity(0.5 + 0.2 * t),
                                blurRadius: 12, spreadRadius: 1,
                              ),
                            ] : null,
                          ),
                          child: base != null
                              ? _ItemIconWidget(itemId: base.id, size: 44)
                              : const Icon(Icons.print, color: Colors.white54, size: 36),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('3D PRINTER',
                              style: TextStyle(
                                color: widget.theme.primary.withOpacity(0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                              )),
                            const SizedBox(height: 2),
                            Text('Print ${base?.name ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              )),
                            const SizedBox(height: 2),
                            Text(
                              canSpawn ? 'Costs 1 ⚡ — tap to print' : '⛔ Out of Energy',
                        style: TextStyle(
                          color: canSpawn ? Colors.white60 : Colors.red,
                          fontSize: 10,
                        ),
                      ),
                    ]),
                  ),
                  // Energy counter
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('ENERGY',
                      style: TextStyle(color: Colors.white54, fontSize: 7, letterSpacing: 1)),
                    Text('${state.energy}',
                      style: TextStyle(
                        color: canSpawn ? widget.theme.primary : Colors.red.withOpacity(0.6),
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      )),
                    if (canSpawn)
                      Text('⚡',
                        style: TextStyle(
                          fontSize: 10 + 4 * t,
                          color: widget.theme.primary.withOpacity(0.7),
                        )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
        );
      },
    );
  }
}

// ─── Spawn Arc Overlay ────────────────────────────────────────────────────────

class _SpawnArcOverlay extends ConsumerStatefulWidget {
  final GlobalKey spawnerKey;
  final GlobalKey gridKey;
  final double Function() getCellSize;
  final LevelDefinition levelDef;

  const _SpawnArcOverlay({
    required this.spawnerKey,
    required this.gridKey,
    required this.getCellSize,
    required this.levelDef,
  });

  @override
  ConsumerState<_SpawnArcOverlay> createState() => _SpawnArcOverlayState();
}

class _SpawnArcOverlayState extends ConsumerState<_SpawnArcOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _progress;

  bool   _active  = false;
  Offset _start   = Offset.zero;
  Offset _end     = Offset.zero;
  String _emoji   = '📦';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _active = false);
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _trigger(int col, int row, String emoji) {
    final spawnerBox = widget.spawnerKey.currentContext?.findRenderObject() as RenderBox?;
    final gridBox    = widget.gridKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;
    if (spawnerBox == null || overlayBox == null) return;

    final spawnerGlobal = spawnerBox.localToGlobal(spawnerBox.size.center(Offset.zero));
    final start = overlayBox.globalToLocal(spawnerGlobal);

    Offset end;
    if (gridBox != null) {
      final cellSize = widget.getCellSize();
      const gap      = 5.0;
      final gridTopLeftGlobal = gridBox.localToGlobal(Offset.zero);
      final gridTopLeft       = overlayBox.globalToLocal(gridTopLeftGlobal);

      // Account for Center widget inside Grid's LayoutBuilder
      final totalGridWidth  = widget.levelDef.gridCols * (cellSize + gap);
      final totalGridHeight = widget.levelDef.gridRows * (cellSize + gap);
      final contentTopLeft  = Offset(
        gridTopLeft.dx + (gridBox.size.width  - totalGridWidth)  / 2,
        gridTopLeft.dy + (gridBox.size.height - totalGridHeight) / 2,
      );
      end = contentTopLeft + Offset(
        col * (cellSize + gap) + cellSize / 2,
        row * (cellSize + gap) + cellSize / 2,
      );
    } else {
      end = start - const Offset(0, 200);
    }

    setState(() {
      _start  = start;
      _end    = end;
      _emoji  = emoji;
      _active = true;
    });
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Listen for upwardSpawn animations
    ref.listen<List<PendingAnimation>>(animProvider, (_, next) {
      for (final anim in next) {
        if (anim.type == AnimType.upwardSpawn) {
          final levelDef = ref.read(gameProvider).currentLevel;
          final item     = ItemDictionary.getById(levelDef.spawnerItemId);
          _trigger(anim.col, anim.row, item?.name ?? 'item');
          // Don't consume here — _GridCellState will consume it
        }
      }
    });

    if (!_active) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, __) {
          final t = _progress.value;
          final dx  = _end.dx - _start.dx;
          final dy  = _end.dy - _start.dy;
          final arc = -min(200.0, (_start - _end).distance * 0.5);
          final x   = _start.dx + dx * t;
          final y   = _start.dy + dy * t + arc * 4 * t * (1 - t);
          final sc  = 0.4 + 0.6 * t;
          final op  = (t < 0.9 ? 1.0 : (1.0 - t) / 0.1).clamp(0.0, 1.0);

          return SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ArcTrailPainter(
                      start: _start,
                      current: Offset(x, y),
                      progress: t,
                      arc: arc,
                    ),
                  ),
                ),
                Positioned(
                  left: x - 16 * sc,
                  top:  y - 16 * sc,
                  child: Opacity(
                    opacity: op,
                    child: Transform.scale(
                      scale: sc,
                      child: _ItemIconWidget(
                        itemId: ref.read(gameProvider).currentLevel.spawnerItemId,
                        size: 30 * sc,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArcTrailPainter extends CustomPainter {
  final Offset start, current;
  final double progress, arc;

  const _ArcTrailPainter({
    required this.start, required this.current,
    required this.progress, required this.arc,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.05) return;
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.25 * (1 - progress))
      ..strokeWidth = 2
      ..strokeCap  = StrokeCap.round
      ..style      = PaintingStyle.stroke;

    final path = Path()..moveTo(start.dx, start.dy);
    final steps = 12;
    for (int i = 1; i <= (steps * progress).round(); i++) {
      final t2 = i / steps;
      final dx = (current.dx - start.dx) / progress;
      final dy = (current.dy - start.dy) / progress;
      path.lineTo(
        start.dx + dx * t2,
        start.dy + dy * t2 + arc * 4 * t2 * (1 - t2),
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcTrailPainter old) => true;
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
                child: Text('×${q.count} ${item?.name ?? '?'}',
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

// ─── Zero Energy Dialog ───────────────────────────────────────────────────────

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
      _FullButton('📺 Watch Ad — Refill 100 ⚡  (Free)',
        color: const Color(0xFFFFD700), dark: true,
        onTap: () => ref.read(gameProvider.notifier).watchAdForEnergy()),
      const SizedBox(height: 14),
      const Row(children: [
        Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('OR', style: TextStyle(color: Colors.white24, fontSize: 11, letterSpacing: 1.5)),
        ),
        Expanded(child: Divider(color: Colors.white12)),
      ]),
      const SizedBox(height: 14),
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

// ─── Grid Full Dialog ─────────────────────────────────────────────────────────

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

// ─── Victory Dialog ───────────────────────────────────────────────────────────

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
    final state  = ref.watch(gameProvider);
    final level  = state.currentLevel;
    final isLast = level.number == kLevels.length;

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
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(children: [
          const Text('COINS EARNED',
            style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          Text('💰 ${state.levelEarnedCoins}',
            style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 40)),
          if (state.coinsMultiplied)
            const Text('🎉 3× MULTIPLIER APPLIED!',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      if (!state.coinsMultiplied) ...[
        _FullButton('📺 Watch Ad for 3× Coins!',
          color: const Color(0xFFFFD700), dark: true,
          onTap: () => ref.read(gameProvider.notifier).watchAdForMultiplier()),
        const SizedBox(height: 10),
      ],
      _busy
          ? const CircularProgressIndicator(color: Colors.white38)
          : _FullButton(
              isLast ? '🎉 You\'ve Won!' : 'Next Level →',
              color: Colors.white12, dark: false,
              onTap: () async {
                if (_busy) return;
                setState(() => _busy = true);
                await ref.read(gameProvider.notifier).goToNextLevel();
              }),
    ]);
  }
}

// ─── Time Fail Dialog ─────────────────────────────────────────────────────────

class _TimeFailDialog extends ConsumerWidget {
  final PhaseTheme theme;
  const _TimeFailDialog({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(gameProvider).currentLevel;
    return _BaseDialog(theme: theme, children: [
      const Text('⏰', style: TextStyle(fontSize: 60)),
      const SizedBox(height: 10),
      const Text('TIME\'S UP!',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 28)),
      const SizedBox(height: 6),
      Text('Level ${level.number}: ${level.title}',
        style: const TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 20),
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

// ─── Full-Width Button ────────────────────────────────────────────────────────

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

// ─── Spark Burst Painter ──────────────────────────────────────────────────────

/// Paints N radial sparks exploding outward from centre when a merge occurs.
/// Each spark gets a deterministic random angle + speed (seed = 42), so the
/// burst pattern is consistent — only `progress` (0→1) changes per frame.
class _SparkBurstPainter extends CustomPainter {
  final double progress;
  final Color  primaryColor;

  static const int _kCount = 20;

  const _SparkBurstPainter({
    required this.progress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final cx = size.width  / 2;
    final cy = size.height / 2;
    final rng = math.Random(42);

    for (int i = 0; i < _kCount; i++) {
      // Fixed random params per spark (same every frame — only `progress` moves)
      final baseAngle  = (i / _kCount) * 2 * math.pi;
      final jitter     = rng.nextDouble() * 0.55 - 0.275;
      final speedFactor= 0.50 + rng.nextDouble() * 0.50;
      final sizeBase   = 2.4 + rng.nextDouble() * 3.2;
      final isAccent   = i % 3 == 0; // every 3rd spark is white

      final angle  = baseAngle + jitter;
      final eased  = Curves.easeOut.transform(progress);
      final radius = (size.width * 0.46) * speedFactor * eased;

      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);

      // Opacity: fast rise (0→15 %), long plateau, fade out
      double opacity;
      if (progress < 0.15) {
        opacity = progress / 0.15;
      } else {
        opacity = 1.0 - ((progress - 0.15) / 0.85);
      }
      opacity = opacity.clamp(0.0, 1.0);

      final sparkR = sizeBase * (1.0 - progress * 0.55);
      final color  = isAccent ? Colors.white : primaryColor;

      // Head dot
      canvas.drawCircle(
        Offset(x, y),
        sparkR,
        Paint()
          ..color = color.withOpacity(opacity * 0.92)
          ..style = PaintingStyle.fill,
      );

      // Trailing tail — short line back toward centre
      if (opacity > 0.15) {
        final trailLen = sparkR * 2.2;
        canvas.drawLine(
          Offset(x, y),
          Offset(x - trailLen * math.cos(angle), y - trailLen * math.sin(angle)),
          Paint()
            ..color = color.withOpacity(opacity * 0.40)
            ..strokeWidth = sparkR * 0.55
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SparkBurstPainter old) => old.progress != progress;
}


// ─── Item Icon Widget (reliable cross-device rendering) ───────────────────────
// Replaces model_viewer_plus WebView tiles with instant-rendering Flutter icons.
// Uses Material Icons (bundled font) + phase-specific gradients for a 3D look.

class _ItemIconWidget extends StatelessWidget {
  final int    itemId;
  final double size;
  const _ItemIconWidget({required this.itemId, required this.size});

  @override
  Widget build(BuildContext context) {
    final item = ItemDictionary.getById(itemId);
    final neon  = _itemGlowColor(itemId);
    final icon  = _iconForItem(itemId);
    final bg1   = _itemBgTop(itemId);
    final bg2   = _itemBgBot(itemId);
    final sz    = size.clamp(16.0, 80.0);

    return SizedBox(
      width: sz, height: sz,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Neon glow ring
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: neon.withOpacity(0.35), blurRadius: sz * 0.5, spreadRadius: 0)],
            ),
          ),
          // Tile background + icon
          Container(
            width: sz, height: sz,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(sz * 0.18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bg1, bg2],
              ),
              border: Border.all(color: neon.withOpacity(0.75), width: sz > 40 ? 2.0 : 1.5),
            ),
            child: Center(
              child: Icon(icon, color: neon, size: sz * 0.58),
            ),
          ),
          // Top-left highlight shimmer (3D effect)
          Positioned(
            top: sz * 0.08, left: sz * 0.08,
            child: Container(
              width: sz * 0.35, height: sz * 0.22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(sz * 0.10),
                  bottomRight: Radius.circular(sz * 0.10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.22), Colors.transparent],
                ),
              ),
            ),
          ),
          // Item name micro-label
          if (item != null && sz >= 48)
            Positioned(
              bottom: sz * 0.04, left: 0, right: 0,
              child: Text(
                item.name.length > 9 ? '${item.name.substring(0, 8)}…' : item.name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: sz * 0.10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }
}

/// Material icon for each of the 51 game items.
IconData _iconForItem(int itemId) {
  switch (itemId) {
    case  1: return Icons.electrical_services;
    case  2: return Icons.usb;
    case  3: return Icons.mouse;
    case  4: return Icons.keyboard;
    case  5: return Icons.monitor;
    case  6: return Icons.developer_board;
    case  7: return Icons.memory;
    case  8: return Icons.speed;
    case  9: return Icons.ac_unit;
    case 10: return Icons.battery_charging_full;
    case 11: return Icons.computer;
    case 12: return Icons.laptop;
    case 13: return Icons.videogame_asset;
    case 14: return Icons.desktop_windows;
    case 15: return Icons.mic;
    case 16: return Icons.storage;
    case 17: return Icons.dns;
    case 18: return Icons.speaker;
    case 19: return Icons.security;
    case 20: return Icons.battery_full;
    case 21: return Icons.sports_esports;
    case 22: return Icons.view_in_ar;
    case 23: return Icons.flight_takeoff;
    case 24: return Icons.watch;
    case 25: return Icons.currency_bitcoin;
    case 26: return Icons.print;
    case 27: return Icons.cloud;
    case 28: return Icons.directions_car;
    case 29: return Icons.accessibility_new;
    case 30: return Icons.smart_toy;
    case 31: return Icons.data_usage;
    case 32: return Icons.movie;
    case 33: return Icons.psychology;
    case 34: return Icons.science;
    case 35: return Icons.shield;
    case 36: return Icons.biotech;
    case 37: return Icons.settings_input_antenna;
    case 38: return Icons.electric_scooter;
    case 39: return Icons.engineering;
    case 40: return Icons.android;
    case 41: return Icons.satellite_alt;
    case 42: return Icons.rocket;
    case 43: return Icons.air;
    case 44: return Icons.blur_on;
    case 45: return Icons.location_on;
    case 46: return Icons.access_time;
    case 47: return Icons.star;
    case 48: return Icons.favorite;
    case 49: return Icons.language;
    case 50: return Icons.blur_circular;
    case 51: return Icons.brightness_high;
    default: return Icons.devices;
  }
}

/// Dark background top-color per phase tier (creates depth illusion).
Color _itemBgTop(int itemId) {
  if (itemId <= 12) return const Color(0xFF2A1800);   // Garage: warm dark amber
  if (itemId <= 22) return const Color(0xFF001830);   // Office: deep navy
  if (itemId <= 32) return const Color(0xFF1C0030);   // Silicon: deep purple
  if (itemId <= 42) return const Color(0xFF001C06);   // Megacorp: deep green
  return             const Color(0xFF1C1400);          // Universe: dark gold
}

/// Dark background bottom-color per phase tier.
Color _itemBgBot(int itemId) {
  if (itemId <= 12) return const Color(0xFF0D0800);
  if (itemId <= 22) return const Color(0xFF000C18);
  if (itemId <= 32) return const Color(0xFF0E0018);
  if (itemId <= 42) return const Color(0xFF000E03);
  return             const Color(0xFF0D0A00);
}

// ─── Ambient Particle Layer ───────────────────────────────────────────────────
// Slow-drifting tech dust particles for the game background.
// Uses a deterministic time-based position (no setState per frame) — only the
// RepaintBoundary subtree repaints each tick, keeping the rest of the UI clean.

class _Ptcl {
  final double x0, y0, speed, angle, radius, baseOpacity, phase;
  const _Ptcl(this.x0, this.y0, this.speed, this.angle,
              this.radius, this.baseOpacity, this.phase);

  Offset pos(double t, double w, double h) {
    final x = ((x0 + math.cos(angle) * speed * t) % 1.0 + 1.0) % 1.0;
    final y = ((y0 + math.sin(angle) * speed * t) % 1.0 + 1.0) % 1.0;
    return Offset(x * w, y * h);
  }
}

class _AmbientPainter extends CustomPainter {
  final List<_Ptcl> ptcls;
  final Color color;
  final double t;
  _AmbientPainter({required this.ptcls, required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (final p in ptcls) {
      // Gentle pulse — opacity breathes slowly per particle
      final pulse = (math.sin(t * 1.1 + p.phase)).abs();
      final opacity = p.baseOpacity * (0.40 + 0.60 * pulse);
      if (opacity < 0.005) continue;

      final pos = p.pos(t, w, h);
      // Main dot
      canvas.drawCircle(
        pos,
        p.radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );
      // Tiny trailing line on bigger particles — circuit-trace tech feel
      if (p.radius > 1.25) {
        final tx = pos.dx + math.cos(p.angle + math.pi) * p.radius * 4;
        final ty = pos.dy + math.sin(p.angle + math.pi) * p.radius * 4;
        canvas.drawLine(
          pos,
          Offset(tx.clamp(0.0, w), ty.clamp(0.0, h)),
          Paint()
            ..color = color.withOpacity(opacity * 0.28)
            ..strokeWidth = 0.55
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.t != t;
}

class _AmbientParticleLayer extends StatefulWidget {
  final Color color;
  final int count;
  const _AmbientParticleLayer({required this.color, this.count = 32});

  @override
  State<_AmbientParticleLayer> createState() => _AmbientParticleLayerState();
}

class _AmbientParticleLayerState extends State<_AmbientParticleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Ptcl> _ptcls;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(98765);
    _ptcls = List.generate(widget.count, (_) {
      // Mostly upward drift (−π/2 ± 35°) with slight randomness → natural float
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 0.60;
      return _Ptcl(
        rng.nextDouble(),                      // x0
        rng.nextDouble(),                      // y0
        rng.nextDouble() * 0.018 + 0.006,      // speed 0.006–0.024 units/s
        angle,
        rng.nextDouble() * 1.55 + 0.5,        // radius 0.5–2.05 px
        rng.nextDouble() * 0.085 + 0.020,     // base opacity 0.02–0.105
        rng.nextDouble() * math.pi * 2,       // phase offset for pulse
      );
    });
    // 80-second cycle — smooth, never perceptible loop
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 80),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _AmbientPainter(
              ptcls:  _ptcls,
              color:  widget.color,
              t:      _ctrl.value * 80.0,   // maps 0..1 → 0..80 virtual seconds
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}
