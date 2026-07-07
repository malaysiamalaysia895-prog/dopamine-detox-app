// octopus_alien_controller.dart — Octopus-Alien Hybrid Boss
// Level 36: 30 merges to defeat
// Polish: Dialogue bubbles, Shield mechanic, coin reward, death slow-mo

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum OctopusAlienPhase {
  idle,
  alienEntry,
  tentacleJoin,
  active,
  slowMo,
  winBlast,
}

class TentacleStrike {
  final int col;
  final int row;
  final double id;
  const TentacleStrike(this.col, this.row, this.id);
}

const _kOctopusDialogues = [
  'YOUR GRID IS MY OCEAN! 🌊',
  'FEEL MY TENTACLES! 🐙',
  'I AM UNSTOPPABLE! 💀',
  'MERGE ALL YOU WANT! 😈',
  'YOUR ITEMS ARE MINE! ⚡',
  'YOU CANNOT ESCAPE! 🔱',
  'I WILL DRAIN YOU! 🌀',
  'FOOLISH HUMAN! 👾',
];

class OctopusAlienController extends ChangeNotifier {

  OctopusAlienPhase phase   = OctopusAlienPhase.idle;
  int  currentLevel         = 0;
  int  mergesDone           = 0;
  static const int mergesNeeded = 30;
  bool entryComplete        = false;

  String? dialogueText;
  bool    isShielded   = false;
  bool    isSlowMo     = false;
  bool    isLowHp      = false;

  List<TentacleStrike> activeTentacleStrikes = [];

  void Function(int col, int row)? onCellDestroyed;
  void Function(int damage)?       onPlayerDamage;
  void Function(int coins)?        onCoinReward;
  bool Function(int col, int row)? isCellOccupied;

  bool _disposed = false;
  final Random _rng       = Random();
  double       _idCounter = 0;

  Timer? _entryTimer;
  Timer? _tentacleJoinTimer;
  Timer? _strikeTimer;
  Timer? _vibTimer;
  Timer? _dialogueTimer;
  Timer? _shieldCycleTimer;
  Timer? _shieldOffTimer;
  Timer? _slowMoTimer;

  int _gridCols = 6;
  int _gridRows = 5;

  bool   get isIdle => phase == OctopusAlienPhase.idle;
  double get progressFraction => (mergesDone / mergesNeeded).clamp(0.0, 1.0);

  void triggerForLevel(
    int level, {
    required int gridCols,
    required int gridRows,
    required void Function(int col, int row) onCellDestroy,
    required void Function(int damage) onDamage,
    void Function(int coins)? onCoins,
    bool Function(int col, int row)? isCellOccupied,
  }) {
    if (level != 36) { _goIdle(); return; }

    _cancelTimers();
    currentLevel          = level;
    mergesDone            = 0;
    entryComplete         = false;
    isShielded            = false;
    isSlowMo              = false;
    isLowHp               = false;
    dialogueText          = null;
    activeTentacleStrikes = [];
    _gridCols             = gridCols;
    _gridRows             = gridRows;
    onCellDestroyed       = onCellDestroy;
    onPlayerDamage        = onDamage;
    onCoinReward          = onCoins;
    this.isCellOccupied   = isCellOccupied;

    _hapticBurst();
    AudioManager.instance.playAlienBgm('assets/audio/bgm_alien.mp3').catchError((_) {});

    phase = OctopusAlienPhase.alienEntry;
    notifyListeners();

    _entryTimer = Timer(const Duration(milliseconds: 2800), () {
      if (_disposed) return;
      phase = OctopusAlienPhase.tentacleJoin;
      notifyListeners();
      _tentacleJoinTimer = Timer(const Duration(milliseconds: 2200), () {
        if (_disposed) return;
        entryComplete = true;
        phase = OctopusAlienPhase.active;
        _startStrikeCycle();
        _startShieldCycle();
        _startVibPulse();
        _startDialogueCycle();
        notifyListeners();
      });
    });
  }

  void onItemMerged() {
    if (phase != OctopusAlienPhase.active) return;
    if (isShielded) {
      dialogueText = 'SHIELD BLOCKS YOU! 🛡️';
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        if (!_disposed) { dialogueText = null; notifyListeners(); }
      });
      return;
    }
    mergesDone++;
    _updateLowHp();
    notifyListeners();
    if (mergesDone >= mergesNeeded) _handleWin();
  }

  void onLevelComplete() {
    if (phase == OctopusAlienPhase.idle || phase == OctopusAlienPhase.winBlast) return;
    _handleWin();
  }

  void reset() {
    _cancelTimers();
    AudioManager.instance.resumePreAlienBgm();
    _goIdle();
  }

  void _startStrikeCycle() {
    _strikeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (phase != OctopusAlienPhase.active || _disposed) return;
      _doTentacleStrike();
    });
  }

  void _startShieldCycle() {
    Timer(const Duration(seconds: 15), () {
      if (phase == OctopusAlienPhase.active && !_disposed) _activateShield();
    });
    _shieldCycleTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (phase != OctopusAlienPhase.active || _disposed) return;
      _activateShield();
    });
  }

  void _activateShield() {
    isShielded   = true;
    dialogueText = 'SHIELD ACTIVATED! 🛡️ MERGES BLOCKED!';
    _safeVibrate(pattern: [0, 100, 30, 100]);
    notifyListeners();
    _shieldOffTimer?.cancel();
    _shieldOffTimer = Timer(const Duration(seconds: 6), () {
      if (_disposed) return;
      isShielded   = false;
      dialogueText = 'SHIELD DOWN... FOR NOW! 😤';
      notifyListeners();
      Timer(const Duration(seconds: 2), () {
        if (!_disposed) { dialogueText = null; notifyListeners(); }
      });
    });
  }

  void _doTentacleStrike() {
    if (isShielded) return;
    // Only target cells that actually hold an item — a tentacle should never
    // lash out at empty grid space (fixes "attacks nothing" bug).
    final candidates = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 1; r < _gridRows; r++) {
        final occupied = isCellOccupied?.call(c, r) ?? true;
        if (occupied) candidates.add((c, r));
      }
    }
    if (candidates.isEmpty) return;
    candidates.shuffle(_rng);
    // Strike 4-5 items simultaneously (was previously only ever 1 target).
    final targetCount = min(candidates.length, 4 + _rng.nextInt(2));
    final strikes = <TentacleStrike>[];
    for (int i = 0; i < targetCount; i++) {
      _idCounter += 1;
      strikes.add(TentacleStrike(candidates[i].$1, candidates[i].$2, _idCounter));
    }
    activeTentacleStrikes = strikes;
    _safeVibrate(pattern: [0, 60, 20, 100, 20, 100]);
    notifyListeners();

    Timer(const Duration(milliseconds: 1200), () {
      if (_disposed || phase != OctopusAlienPhase.active) return;
      for (final s in strikes) {
        // Re-verify the item is still there right before impact (it may have
        // been merged away in the meantime) to avoid destroying empty cells.
        final stillThere = isCellOccupied?.call(s.col, s.row) ?? true;
        if (stillThere) onCellDestroyed?.call(s.col, s.row);
      }
      activeTentacleStrikes =
          activeTentacleStrikes.where((s) => !strikes.contains(s)).toList();
      onPlayerDamage?.call(10);
      _updateLowHp();
      notifyListeners();
    });
  }

  void _updateLowHp() {
    final newLow = progressFraction >= 0.75;
    if (newLow != isLowHp) { isLowHp = newLow; notifyListeners(); }
  }

  void _startDialogueCycle() {
    _dialogueTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed || phase != OctopusAlienPhase.active) return;
      if (!isShielded) {
        dialogueText = _kOctopusDialogues[_rng.nextInt(_kOctopusDialogues.length)];
        notifyListeners();
      }
      _dialogueTimer = Timer.periodic(const Duration(seconds: 9), (_) {
        if (_disposed || phase != OctopusAlienPhase.active) return;
        if (!isShielded) {
          dialogueText = _kOctopusDialogues[_rng.nextInt(_kOctopusDialogues.length)];
          notifyListeners();
          Timer(const Duration(milliseconds: 3500), () {
            if (!_disposed && !isShielded) { dialogueText = null; notifyListeners(); }
          });
        }
      });
    });
  }

  void _handleWin() {
    _cancelTimers();
    isSlowMo     = true;
    isShielded   = false;
    dialogueText = 'NO... IMPOSSIBLE! 😱';
    notifyListeners();
    _slowMoTimer = Timer(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      isSlowMo              = false;
      dialogueText          = null;
      activeTentacleStrikes = [];
      phase = OctopusAlienPhase.winBlast;
      AudioManager.instance.resumePreAlienBgm();
      _safeVibrate(pattern: [0, 300, 80, 300, 80, 600, 80, 1000]);
      notifyListeners();
      _entryTimer = Timer(const Duration(milliseconds: 3800), _goIdle);
    });
  }

  void _startVibPulse() {
    _vibTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (phase != OctopusAlienPhase.active) { _vibTimer?.cancel(); return; }
      if (!isShielded) _safeVibrate(pattern: [0, 20, 10, 20]);
    });
  }

  void _hapticBurst() {
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    Future.delayed(const Duration(milliseconds: 100), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
    _safeVibrate(pattern: [0, 150, 50, 200, 50, 350]);
  }

  void _goIdle() {
    if (_disposed) return;
    phase                = OctopusAlienPhase.idle;
    currentLevel         = 0;
    mergesDone           = 0;
    entryComplete        = false;
    isShielded           = false;
    isSlowMo              = false;
    isLowHp               = false;
    dialogueText          = null;
    activeTentacleStrikes = [];
    notifyListeners();
  }

  void _cancelTimers() {
    _entryTimer?.cancel();
    _tentacleJoinTimer?.cancel();
    _strikeTimer?.cancel();
    _vibTimer?.cancel();
    _dialogueTimer?.cancel();
    _shieldCycleTimer?.cancel();
    _shieldOffTimer?.cancel();
    _slowMoTimer?.cancel();
    _entryTimer = _tentacleJoinTimer = _strikeTimer = _vibTimer =
        _dialogueTimer = _shieldCycleTimer = _shieldOffTimer = _slowMoTimer = null;
  }

  Future<void> _safeVibrate({List<int>? pattern, int duration = 200}) async {
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
