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
  // isShielded now means "creature is suppressed and cannot strike" — a
  // PLAYER-EARNED power (was previously the reverse: an anti-player shield
  // that blocked the player's own merges from counting).
  bool    isShielded   = false;
  bool    isSlowMo     = false;
  bool    isLowHp      = false;
  int     _mergesSincePower = 0;
  static const int _mergesPerPower = 5;
  int     mergesUntilPower = _mergesPerPower;

  List<TentacleStrike> activeTentacleStrikes = [];

  void Function(int col, int row)? onCellDestroyed;
  void Function(int damage)?       onPlayerDamage;
  void Function(int coins)?        onCoinReward;
  bool Function(int col, int row)? isCellOccupied;

  bool _disposed      = false;
  bool _winTriggered  = false;   // guards against impact timers firing after win
  final Random _rng       = Random();
  double       _idCounter = 0;

  Timer? _entryTimer;
  Timer? _tentacleJoinTimer;
  Timer? _strikeTimer;
  Timer? _vibTimer;
  Timer? _dialogueTimer;
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
    _mergesSincePower     = 0;
    mergesUntilPower      = _mergesPerPower;
    _gridCols             = gridCols;
    _gridRows             = gridRows;
    onCellDestroyed       = onCellDestroy;
    onPlayerDamage        = onDamage;
    onCoinReward          = onCoins;
    this.isCellOccupied   = isCellOccupied;

    _winTriggered = false;
    _hapticBurst();
    AudioManager.instance.playAlienBgm('assets/audio/bgm_alien_boss.mp3').catchError((_) {});

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
        _startVibPulse();
        _startDialogueCycle();
        notifyListeners();
      });
    });
  }

  void onItemMerged() {
    if (phase != OctopusAlienPhase.active) return;
    // Merges always count now — the old build blocked the player's own
    // merges during "shield" windows, which felt punishing. Instead, merging
    // is what EARNS the player a power (see below).
    mergesDone++;
    _updateLowHp();
    _mergesSincePower++;
    mergesUntilPower = (_mergesPerPower - _mergesSincePower).clamp(0, _mergesPerPower);
    if (_mergesSincePower >= _mergesPerPower && !isShielded) {
      _mergesSincePower = 0;
      mergesUntilPower  = _mergesPerPower;
      _activatePlayerPower();
    }
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
    // Rebalanced (was every 5s with only a 1.2s warning before impact —
    // not enough time to notice and merge the targeted items). Now strikes
    // are slower and telegraph longer, so a player who's paying attention
    // has a real chance to save the targeted cells by merging them.
    _strikeTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (phase != OctopusAlienPhase.active || _disposed) return;
      _doTentacleStrike();
    });
  }

  /// PLAYER-EARNED power: every [_mergesPerPower] merges, the creature is
  /// suppressed (cannot strike) for 5 seconds — a reward for good play,
  /// replacing the old anti-player "shield blocks your merges" mechanic.
  void _activatePlayerPower() {
    isShielded   = true;
    dialogueText = 'POWER UP! 🛡️ CREATURE BLOCKED!';
    _safeVibrate(pattern: [0, 100, 30, 100]);
    notifyListeners();
    _shieldOffTimer?.cancel();
    _shieldOffTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      isShielded   = false;
      dialogueText = 'IT BREAKS FREE! 😤';
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
    // Strike 3-4 items simultaneously (was 4-5 — slightly fewer targets so
    // the wider warning window below stays fair to keep up with).
    final targetCount = min(candidates.length, 3 + _rng.nextInt(2));
    final strikes = <TentacleStrike>[];
    for (int i = 0; i < targetCount; i++) {
      _idCounter += 1;
      strikes.add(TentacleStrike(candidates[i].$1, candidates[i].$2, _idCounter));
    }
    activeTentacleStrikes = strikes;
    _safeVibrate(pattern: [0, 60, 20, 100, 20, 100]);
    notifyListeners();

    // Was 1200ms — far too short to notice the tentacle telegraph and merge
    // the targeted items in time. Widened to 2400ms so a player who reacts
    // right away has a real shot at saving the cells.
    Timer(const Duration(milliseconds: 2400), () {
      if (_disposed || _winTriggered || phase != OctopusAlienPhase.active) return;
      int destroyed = 0;
      for (final s in strikes) {
        // Re-verify the item is still there right before impact (it may have
        // been merged away in the meantime) — no destruction + no penalty if
        // the player already merged the targeted item.
        final stillThere = isCellOccupied?.call(s.col, s.row) ?? true;
        if (stillThere) { onCellDestroyed?.call(s.col, s.row); destroyed++; }
      }
      activeTentacleStrikes =
          activeTentacleStrikes.where((s) => !strikes.contains(s)).toList();
      // Only charge the energy penalty when at least one item was actually
      // destroyed.  If the player merged all targeted items in time, no penalty.
      if (destroyed > 0) onPlayerDamage?.call(10);
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
    _winTriggered = true;
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
    isSlowMo             = false;
    isLowHp              = false;
    dialogueText         = null;
    activeTentacleStrikes = [];
    _mergesSincePower    = 0;
    mergesUntilPower     = _mergesPerPower;
    _winTriggered        = false;
    notifyListeners();
  }

  void _cancelTimers() {
    _entryTimer?.cancel();
    _tentacleJoinTimer?.cancel();
    _strikeTimer?.cancel();
    _vibTimer?.cancel();
    _dialogueTimer?.cancel();
    _shieldOffTimer?.cancel();
    _slowMoTimer?.cancel();
    _entryTimer = _tentacleJoinTimer = _strikeTimer = _vibTimer =
        _dialogueTimer = _shieldOffTimer = _slowMoTimer = null;
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
