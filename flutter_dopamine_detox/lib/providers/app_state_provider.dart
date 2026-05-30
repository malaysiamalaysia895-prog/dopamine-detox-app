import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChallengeType { none, studyFocus, mobileLock, healthChallenge }

class AppStateProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  AppStateProvider(this._prefs) {
    _loadPersistedState();
  }

  // ─── Active challenge ─────────────────────────────────────────────────────
  ChallengeType _activeChallenge = ChallengeType.none;
  ChallengeType get activeChallenge => _activeChallenge;

  bool get isLocked => _activeChallenge != ChallengeType.none;

  // ─── Locked app packages (study focus) ───────────────────────────────────
  List<String> _lockedPackages = [];
  List<String> get lockedPackages => List.unmodifiable(_lockedPackages);

  // ─── Timer state ─────────────────────────────────────────────────────────
  Duration _challengeDuration = Duration.zero;
  Duration _remainingTime = Duration.zero;
  Duration get remainingTime => _remainingTime;
  Duration get challengeDuration => _challengeDuration;

  Timer? _countdownTimer;

  double get progressFraction {
    if (_challengeDuration.inSeconds == 0) return 0;
    return 1.0 -
        (_remainingTime.inSeconds / _challengeDuration.inSeconds);
  }

  // ─── Emergency unlock state ───────────────────────────────────────────────
  static const int maxEmergencyUses = 2;
  int _emergencyUsesLeft = maxEmergencyUses;
  int get emergencyUsesLeft => _emergencyUsesLeft;

  bool _emergencyUnlockActive = false;
  bool get emergencyUnlockActive => _emergencyUnlockActive;

  Timer? _emergencyTimer;
  Duration _emergencyRemaining = const Duration(minutes: 2);
  Duration get emergencyRemaining => _emergencyRemaining;

  // ─── Billing / penalty unlock ─────────────────────────────────────────────
  bool _isPenaltyUnlocked = false;
  bool get isPenaltyUnlocked => _isPenaltyUnlocked;

  // ─── Health challenge ─────────────────────────────────────────────────────
  int _targetSteps = 1500;
  int get targetSteps => _targetSteps;

  int _currentSteps = 0;
  int get currentSteps => _currentSteps;

  bool _healthCompleted = false;
  bool get healthCompleted => _healthCompleted;

  // ─── Load persisted state ─────────────────────────────────────────────────
  void _loadPersistedState() {
    _lockedPackages = _prefs.getStringList('lockedPackages') ?? [];
    _emergencyUsesLeft =
        _prefs.getInt('emergencyUsesLeft') ?? maxEmergencyUses;

    final challengeIndex = _prefs.getInt('activeChallenge') ?? 0;
    _activeChallenge = ChallengeType.values[challengeIndex];

    final remainingSecs = _prefs.getInt('remainingSecs') ?? 0;
    final durationSecs = _prefs.getInt('durationSecs') ?? 0;

    if (_activeChallenge != ChallengeType.none && remainingSecs > 0) {
      _challengeDuration = Duration(seconds: durationSecs);
      _remainingTime = Duration(seconds: remainingSecs);
      _startCountdown();
    }
  }

  void _persistState() {
    _prefs.setStringList('lockedPackages', _lockedPackages);
    _prefs.setInt('emergencyUsesLeft', _emergencyUsesLeft);
    _prefs.setInt('activeChallenge', _activeChallenge.index);
    _prefs.setInt('remainingSecs', _remainingTime.inSeconds);
    _prefs.setInt('durationSecs', _challengeDuration.inSeconds);
  }

  // ─── Start challenges ─────────────────────────────────────────────────────

  /// Study Focus: lock specific apps for [duration].
  void startStudyFocus({
    required List<String> packages,
    required Duration duration,
  }) {
    _lockedPackages = packages;
    _activeChallenge = ChallengeType.studyFocus;
    _challengeDuration = duration;
    _remainingTime = duration;
    _emergencyUsesLeft = maxEmergencyUses;
    _isPenaltyUnlocked = false;
    _persistState();
    _startCountdown();
    notifyListeners();
  }

  /// Mobile Lock: lock entire device for [duration].
  void startMobileLock({required Duration duration}) {
    _lockedPackages = [];
    _activeChallenge = ChallengeType.mobileLock;
    _challengeDuration = duration;
    _remainingTime = duration;
    _emergencyUsesLeft = 0; // no emergency for full lock
    _isPenaltyUnlocked = false;
    _persistState();
    _startCountdown();
    notifyListeners();
  }

  /// Health Challenge: [targetSteps] steps to complete in [duration].
  void startHealthChallenge({
    required Duration duration,
    required int targetSteps,
  }) {
    _activeChallenge = ChallengeType.healthChallenge;
    _challengeDuration = duration;
    _remainingTime = duration;
    _targetSteps = targetSteps;
    _currentSteps = 0;
    _healthCompleted = false;
    _isPenaltyUnlocked = false;
    _persistState();
    _startCountdown();
    notifyListeners();
  }

  // ─── Countdown timer ──────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _onChallengeComplete();
        return;
      }
      _remainingTime -= const Duration(seconds: 1);
      _persistState();
      notifyListeners();
    });
  }

  void _onChallengeComplete() {
    _activeChallenge = ChallengeType.none;
    _lockedPackages = [];
    _isPenaltyUnlocked = false;
    _healthCompleted =
        _activeChallenge == ChallengeType.healthChallenge
            ? _currentSteps >= _targetSteps
            : false;
    _persistState();
    notifyListeners();
  }

  // ─── Emergency unlock (Study Focus only) ─────────────────────────────────
  /// Returns false if no uses left.
  bool activateEmergencyUnlock() {
    if (_emergencyUsesLeft <= 0) return false;
    if (_activeChallenge != ChallengeType.studyFocus) return false;

    _emergencyUsesLeft--;
    _emergencyUnlockActive = true;
    _emergencyRemaining = const Duration(minutes: 2);
    _persistState();
    notifyListeners();

    _emergencyTimer?.cancel();
    _emergencyTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emergencyRemaining.inSeconds <= 0) {
        timer.cancel();
        _deactivateEmergencyUnlock();
        return;
      }
      _emergencyRemaining -= const Duration(seconds: 1);
      notifyListeners();
    });

    return true;
  }

  void _deactivateEmergencyUnlock() {
    _emergencyUnlockActive = false;
    _emergencyRemaining = const Duration(minutes: 2);
    notifyListeners();
  }

  // ─── Billing / penalty unlock ─────────────────────────────────────────────
  /// Called by BillingService after successful ₹99 purchase.
  void unlockAll() {
    _countdownTimer?.cancel();
    _emergencyTimer?.cancel();
    _emergencyUnlockActive = false;
    _isPenaltyUnlocked = true;
    _activeChallenge = ChallengeType.none;
    _lockedPackages = [];
    _remainingTime = Duration.zero;
    _persistState();
    notifyListeners();
  }

  // ─── Step updates from pedometer ─────────────────────────────────────────
  void updateSteps(int steps) {
    if (_activeChallenge != ChallengeType.healthChallenge) return;
    _currentSteps = steps;
    if (_currentSteps >= _targetSteps) {
      _healthCompleted = true;
      _countdownTimer?.cancel();
      _activeChallenge = ChallengeType.none;
      _persistState();
    }
    notifyListeners();
  }

  // ─── Check if a package is locked ────────────────────────────────────────
  bool isPackageLocked(String packageName) {
    if (_emergencyUnlockActive || _isPenaltyUnlocked) return false;
    if (_activeChallenge == ChallengeType.studyFocus) {
      return _lockedPackages.contains(packageName);
    }
    if (_activeChallenge == ChallengeType.mobileLock) return true;
    return false;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emergencyTimer?.cancel();
    super.dispose();
  }
}
