// antigravity_controller.dart — "Anti-Gravity" Boss (Level 37)
// Liquid-metal / jellyfish-cyborg hybrid that floats above the grid.
// Every 5s it performs a gravity-pull attack in two stages:
//   1. TELEGRAPH (~2.8s) — vulnerable (never-merged) cells are highlighted
//      with a warning ring so the player has a real chance to merge them
//      away before the pull actually lands.
//   2. PULL (~1s) — cells still vulnerable at the end of the telegraph are
//      sucked upward into the boss's containment jar and destroyed, costing
//      a coin penalty per item. Items merged at least once are always safe.
//
// Unlike the merge-count bosses (Malware/Alien/Snake/Octopus), this boss is
// not "defeated" by merging N times — the level is won the normal way
// (delivery quota). The boss is simply an ambient, ever-present hazard that
// is dismissed (fades out) once the level completes.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum AntiGravityPhase {
  idle,
  entry,
  active,
  winBlast,
}

// Flavor taunts, mixed with explicit instructional reminders so the player
// always knows what to do without needing to re-read the rules card.
const _kAntiGravityFlavorLines = [
  'GRAVITY BENDS TO MY WILL! 🌌',
  'NOTHING ESCAPES THE VOID! 🕳️',
  'YOUR ITEMS ARE ALREADY MINE! 💫',
  'FLOAT. SHATTER. VANISH. 🔮',
  'THE VOID HUNGERS! 🌀',
];
const _kAntiGravityHintLines = [
  '💡 MERGE ITEMS AT LEAST ONCE TO MAKE THEM SAFE FOREVER!',
  '💡 UN-MERGED ITEMS GET PULLED INTO MY JAR — MERGE FAST!',
  '💡 A MERGED ITEM NEVER GETS PULLED AGAIN. KEEP MERGING!',
];

class AntiGravityController extends ChangeNotifier {

  AntiGravityPhase phase = AntiGravityPhase.idle;
  int  currentLevel  = 0;
  bool entryComplete = false;

  String? dialogueText;
  bool isWarning = false; // true while dialogueText is an attack warning

  /// Cells currently in the "telegraph" warning window — about to be checked
  /// again; merging them now still saves them.
  List<(int, int)> telegraphCells = [];

  /// Cells confirmed doomed — mid flight-to-jar animation before destruction.
  List<(int, int)> pullingCells = [];

  /// Total items the jar has consumed this level (for the jar badge UI).
  int jarCount = 0;

  void Function(int col, int row)? onCellDestroyed;
  void Function(int energy)?       onEnergyPenalty;  // 15 energy per destroyed item
  bool Function(int col, int row)? isCellVulnerable; // occupied + never merged
  int? Function(int col, int row)? getItemId;        // for flight-icon lookup

  bool _disposed = false;
  final Random _rng = Random();

  Timer? _entryTimer;
  Timer? _attackTimer;
  Timer? _telegraphTimer;
  Timer? _pullTimer;
  Timer? _dialogueTimer;
  Timer? _dialogueClearTimer;
  Timer? _vibTimer;

  int _gridCols = 6;
  int _gridRows = 5;
  int _hintCounter = 0;

  static const telegraphDuration  = Duration(seconds: 5);       // full 5-second merge window
  static const pullFlightDuration = Duration(milliseconds: 1000);

  bool get isIdle   => phase == AntiGravityPhase.idle;
  bool get isActive => phase == AntiGravityPhase.active;

  void triggerForLevel(
    int level, {
    required int gridCols,
    required int gridRows,
    required void Function(int col, int row) onDestroy,
    required void Function(int energy) onPenalty,
    required bool Function(int col, int row) isVulnerable,
    required int? Function(int col, int row) itemIdAt,
  }) {
    if (level != 37) { _goIdle(); return; }

    _cancelTimers();
    currentLevel    = level;
    entryComplete   = false;
    dialogueText    = null;
    isWarning       = false;
    telegraphCells  = [];
    pullingCells    = [];
    jarCount        = 0;
    _hintCounter    = 0;
    _gridCols       = gridCols;
    _gridRows       = gridRows;
    onCellDestroyed  = onDestroy;
    onEnergyPenalty  = onPenalty;
    isCellVulnerable = isVulnerable;
    getItemId       = itemIdAt;

    _hapticBurst();
    AudioManager.instance.playAlienBgm('assets/audio/bgm_alien_boss.mp3').catchError((_) {});

    phase = AntiGravityPhase.entry;
    notifyListeners();

    _entryTimer = Timer(const Duration(milliseconds: 3200), () {
      if (_disposed) return;
      entryComplete = true;
      phase = AntiGravityPhase.active;
      _startAttackCycle();
      _startDialogueCycle();
      _startVibPulse();
      notifyListeners();
    });
  }

  void onLevelComplete() {
    if (phase == AntiGravityPhase.idle || phase == AntiGravityPhase.winBlast) return;
    _handleWin();
  }

  void reset() {
    _cancelTimers();
    AudioManager.instance.resumePreAlienBgm();
    _goIdle();
  }

  void _startAttackCycle() {
    _attackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (phase != AntiGravityPhase.active || _disposed) return;
      _gravityPullAttack();
    });
  }

  /// Two-stage attack: telegraph the vulnerable cells first (giving the
  /// player a real window to merge them away), then re-check and only
  /// destroy whatever is still vulnerable once the warning expires.
  void _gravityPullAttack() {
    final vuln = isCellVulnerable;
    if (vuln == null) return;
    if (telegraphCells.isNotEmpty || pullingCells.isNotEmpty) return; // one cycle at a time

    final allVuln = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 0; r < _gridRows; r++) {
        if (vuln(c, r)) allVuln.add((c, r));
      }
    }
    if (allVuln.isEmpty) return;

    // Pick 4–5 random vulnerable cells per attack cycle so the player sees
    // discrete, dodge-able threats rather than the whole board lighting up.
    allVuln.shuffle(_rng);
    final targets = allVuln.take(4 + _rng.nextInt(2)).toList();

    telegraphCells = targets;
    _setDialogue('⚠️ GRAVITY PULL INCOMING! MERGE NOW!', warning: true, holdOpen: true);
    notifyListeners();
    _safeVibrate(pattern: const [0, 30, 40, 30]);

    _telegraphTimer = Timer(telegraphDuration, () {
      if (_disposed) return;
      telegraphCells = [];

      final vuln2 = isCellVulnerable;
      final survivors = <(int, int)>[];
      if (vuln2 != null) {
        for (final t in targets) {
          if (vuln2(t.$1, t.$2)) survivors.add(t);
        }
      }

      if (survivors.isEmpty) {
        _setDialogue('✅ ALL SAFE! GREAT MERGING!', warning: false);
        notifyListeners();
        return;
      }

      pullingCells = survivors;
      _setDialogue('🕳️ PULLING THEM IN...', warning: true, holdOpen: true);
      notifyListeners();
      _safeVibrate(pattern: const [0, 40, 30, 40, 30, 120]);

      _pullTimer = Timer(pullFlightDuration, () {
        if (_disposed) return;
        for (final t in survivors) {
          onCellDestroyed?.call(t.$1, t.$2);
        }
        // 15 energy penalty per item that was NOT merged in time
        onEnergyPenalty?.call(15 * survivors.length);
        jarCount += survivors.length;
        pullingCells = [];
        _setDialogue(null, warning: false);
        notifyListeners();
        _safeVibrate(pattern: const [0, 180, 60, 260]);
      });
    });
  }

  void _startDialogueCycle() {
    _dialogueTimer = Timer(const Duration(seconds: 7), () {
      if (_disposed || phase != AntiGravityPhase.active) return;
      _showDialogue();
      _dialogueTimer = Timer.periodic(const Duration(seconds: 9), (_) {
        if (_disposed || phase != AntiGravityPhase.active) return;
        _showDialogue();
      });
    });
  }

  void _showDialogue() {
    if (dialogueText != null) return; // don't stomp attack-warning bubble
    // Only flavor taunts go through the creature's speech bubble now.
    // Coach-voice gameplay hints live in the overlay's _AntiGravHintBanner
    // so they never look like the creature is talking to the player.
    final text = _kAntiGravityFlavorLines[_rng.nextInt(_kAntiGravityFlavorLines.length)];
    _setDialogue(text, warning: false, autoClearAfter: const Duration(milliseconds: 3400));
  }

  /// Centralizes dialogue changes so timed auto-clears never stomp a newer
  /// message (guards against the old race where a stale Timer could wipe a
  /// bubble set by a later call).
  void _setDialogue(String? text, {required bool warning, bool holdOpen = false, Duration? autoClearAfter}) {
    _dialogueClearTimer?.cancel();
    dialogueText = text;
    isWarning = warning;
    if (!holdOpen && text != null) {
      final d = autoClearAfter ?? const Duration(milliseconds: 1800);
      _dialogueClearTimer = Timer(d, () {
        if (!_disposed && dialogueText == text) {
          dialogueText = null;
          notifyListeners();
        }
      });
    }
  }

  void _startVibPulse() {
    _vibTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (phase != AntiGravityPhase.active) { _vibTimer?.cancel(); return; }
      _safeVibrate(pattern: const [0, 15, 10, 15]);
    });
  }

  void _handleWin() {
    _cancelTimers();
    telegraphCells = [];
    pullingCells = [];
    dialogueText = null;
    phase = AntiGravityPhase.winBlast;
    AudioManager.instance.resumePreAlienBgm();
    notifyListeners();
    _entryTimer = Timer(const Duration(milliseconds: 1800), _goIdle);
  }

  void _hapticBurst() {
    try { HapticFeedback.mediumImpact(); } catch (_) {}
    Future.delayed(const Duration(milliseconds: 160), () {
      try { HapticFeedback.mediumImpact(); } catch (_) {}
    });
    _safeVibrate(pattern: const [0, 120, 40, 180]);
  }

  void _goIdle() {
    if (_disposed) return;
    phase         = AntiGravityPhase.idle;
    currentLevel  = 0;
    entryComplete = false;
    dialogueText  = null;
    telegraphCells = [];
    pullingCells  = [];
    notifyListeners();
  }

  void _cancelTimers() {
    _entryTimer?.cancel();
    _attackTimer?.cancel();
    _telegraphTimer?.cancel();
    _pullTimer?.cancel();
    _dialogueTimer?.cancel();
    _dialogueClearTimer?.cancel();
    _vibTimer?.cancel();
    _entryTimer = _attackTimer = _telegraphTimer = _pullTimer = _dialogueTimer = _dialogueClearTimer = _vibTimer = null;
  }

  Future<void> _safeVibrate({List<int>? pattern, int duration = 150}) async {
    try {
      final has = await Vibration.hasVibrator() ?? false;
      if (!has) return;
      if (pattern != null) await Vibration.vibrate(pattern: pattern);
      else await Vibration.vibrate(duration: duration);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
