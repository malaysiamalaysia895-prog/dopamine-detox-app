import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChallengeType { none, studyFocus, mobileLock, healthChallenge }

/// ─────────────────────────────────────────────────────────────────────────────
/// AppStateProvider
///
/// TIMER PERSISTENCE STRATEGY (survives process kill):
///   • On challenge start  → save `challengeStartEpochMs` + `durationSecs`
///   • On restore          → remaining = duration − (now − savedStartEpoch)
///   • Old `remainingSecs` approach breaks when the process is killed because
///     the countdown timer stops; wall-clock approach never loses time.
///
/// EMERGENCY USES:
///   • Max 10 uses per calendar day (resets at midnight).
///   • Stored as `emergencyUsesDate` (yyyy-MM-dd) + `emergencyUsesToday`.
/// ─────────────────────────────────────────────────────────────────────────────
class AppStateProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  AppStateProvider(this._prefs) {
    _loadPersistedState();
  }

  // ── Active challenge ───────────────────────────────────────────────────────
  ChallengeType _activeChallenge = ChallengeType.none;
  ChallengeType get activeChallenge => _activeChallenge;
  bool get isLocked => _activeChallenge != ChallengeType.none;

  // ── Locked packages (Study Focus) ─────────────────────────────────────────
  List<String> _lockedPackages = [];
  List<String> get lockedPackages => List.unmodifiable(_lockedPackages);

  // ── Wall-clock timer ───────────────────────────────────────────────────────
  // We persist the START time + total duration so that even if the process
  // is killed and restarted, remaining time is recalculated from the wall clock.
  DateTime? _challengeStartTime;
  Duration _challengeDuration = Duration.zero;
  Duration _remainingTime = Duration.zero;
  Duration get remainingTime => _remainingTime;
  Duration get challengeDuration => _challengeDuration;
  Timer? _countdownTimer;

  double get progressFraction {
    if (_challengeDuration.inSeconds == 0) return 0.0;
    final elapsed = DateTime.now().difference(_challengeStartTime!);
    final fraction = elapsed.inSeconds / _challengeDuration.inSeconds;
    return fraction.clamp(0.0, 1.0);
  }

  // ── Emergency unlock — 10 uses per day ────────────────────────────────────
  static const int maxEmergencyUsesPerDay = 10;

  int _emergencyUsesToday = 0;
  int get emergencyUsesToday => _emergencyUsesToday;
  int get emergencyUsesLeft =>
      (maxEmergencyUsesPerDay - _emergencyUsesToday).clamp(0, maxEmergencyUsesPerDay);

  bool _emergencyUnlockActive = false;
  bool get emergencyUnlockActive => _emergencyUnlockActive;

  Timer? _emergencyTimer;
  Duration _emergencyRemaining = const Duration(minutes: 2);
  Duration get emergencyRemaining => _emergencyRemaining;

  // ── Billing unlock ─────────────────────────────────────────────────────────
  bool _isPenaltyUnlocked = false;
  bool get isPenaltyUnlocked => _isPenaltyUnlocked;

  // ── Health challenge ───────────────────────────────────────────────────────
  int _targetSteps = 1500;
  int get targetSteps => _targetSteps;
  int _currentSteps = 0;
  int get currentSteps => _currentSteps;
  bool _healthCompleted = false;
  bool get healthCompleted => _healthCompleted;

  // ── Load persisted state ───────────────────────────────────────────────────
  void _loadPersistedState() {
    // Emergency uses — reset if date changed
    final today = _todayString();
    final savedDate = _prefs.getString('emergencyUsesDate') ?? '';
    if (savedDate == today) {
      _emergencyUsesToday = _prefs.getInt('emergencyUsesToday') ?? 0;
    } else {
      // New day → reset counter
      _emergencyUsesToday = 0;
      _prefs.setString('emergencyUsesDate', today);
      _prefs.setInt('emergencyUsesToday', 0);
    }

    // Active challenge
    final challengeIndex = _prefs.getInt('activeChallenge') ?? 0;
    _activeChallenge = ChallengeType.values[challengeIndex];

    if (_activeChallenge != ChallengeType.none) {
      _lockedPackages = _prefs.getStringList('lockedPackages') ?? [];
      final durationSecs = _prefs.getInt('durationSecs') ?? 0;
      final startEpochMs = _prefs.getInt('challengeStartEpochMs') ?? 0;
      _targetSteps = _prefs.getInt('targetSteps') ?? 1500;

      _challengeDuration = Duration(seconds: durationSecs);
      _challengeStartTime =
          DateTime.fromMillisecondsSinceEpoch(startEpochMs);

      // Recalculate remaining from wall clock — survives process kill
      final elapsed = DateTime.now().difference(_challengeStartTime!);
      _remainingTime = _challengeDuration - elapsed;

      if (_remainingTime.isNegative || _remainingTime == Duration.zero) {
        // Challenge already expired while app was closed
        _onChallengeComplete(notify: false);
      } else {
        _startCountdown();
      }
    }
  }

  void _persistState() {
    _prefs.setInt('activeChallenge', _activeChallenge.index);
    _prefs.setStringList('lockedPackages', _lockedPackages);
    _prefs.setInt('durationSecs', _challengeDuration.inSeconds);
    _prefs.setInt('targetSteps', _targetSteps);
    if (_challengeStartTime != null) {
      _prefs.setInt('challengeStartEpochMs',
          _challengeStartTime!.millisecondsSinceEpoch);
    }
    // Emergency
    _prefs.setString('emergencyUsesDate', _todayString());
    _prefs.setInt('emergencyUsesToday', _emergencyUsesToday);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Start challenges ───────────────────────────────────────────────────────

  void startStudyFocus({
    required List<String> packages,
    required Duration duration,
  }) {
    // Guard: prevent overwriting an already-running session.
    if (_activeChallenge != ChallengeType.none) return;
    _lockedPackages = packages;
    _activeChallenge = ChallengeType.studyFocus;
    _challengeDuration = duration;
    _challengeStartTime = DateTime.now();
    _remainingTime = duration;
    _isPenaltyUnlocked = false;
    _persistState();
    _startCountdown();
    notifyListeners();
  }

  void startMobileLock({required Duration duration}) {
    _lockedPackages = [];
    _activeChallenge = ChallengeType.mobileLock;
    _challengeDuration = duration;
    _challengeStartTime = DateTime.now();
    _remainingTime = duration;
    _isPenaltyUnlocked = false;
    _persistState();
    _startCountdown();
    notifyListeners();
  }

  void startHealthChallenge({
    required Duration duration,
    required int targetSteps,
  }) {
    _activeChallenge = ChallengeType.healthChallenge;
    _challengeDuration = duration;
    _challengeStartTime = DateTime.now();
    _remainingTime = duration;
    _targetSteps = targetSteps;
    _currentSteps = 0;
    _healthCompleted = false;
    _isPenaltyUnlocked = false;
    _persistState();
    _startCountdown();
    notifyListeners();
  }

  // ── Countdown (recalculates from wall clock every tick) ───────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_challengeStartTime == null) {
        timer.cancel();
        return;
      }
      // Always recompute from wall clock — immune to drift or process kill gaps
      final elapsed = DateTime.now().difference(_challengeStartTime!);
      _remainingTime = _challengeDuration - elapsed;

      if (_remainingTime.isNegative || _remainingTime == Duration.zero) {
        _remainingTime = Duration.zero;
        timer.cancel();
        _onChallengeComplete();
        return;
      }
      notifyListeners();
    });
  }

  void _onChallengeComplete({bool notify = true}) {
    final wasHealth = _activeChallenge == ChallengeType.healthChallenge;
    _activeChallenge = ChallengeType.none;
    _lockedPackages = [];
    _isPenaltyUnlocked = false;
    _challengeStartTime = null;
    if (wasHealth) _healthCompleted = _currentSteps >= _targetSteps;
    _persistState();
    if (notify) notifyListeners();
  }

  // ── Emergency unlock (10 per day, 2-min window, auto-relock) ─────────────

  /// Returns false if daily limit reached or wrong challenge type.
  bool activateEmergencyUnlock() {
    if (emergencyUsesLeft <= 0) return false;
    if (_activeChallenge == ChallengeType.none) return false;
    // Mobile lock does NOT support emergency unlock
    if (_activeChallenge == ChallengeType.mobileLock) return false;

    _emergencyUsesToday++;
    _emergencyUnlockActive = true;
    _emergencyRemaining = const Duration(minutes: 2);

    // Persist the wall-clock end time so AppMonitorService can enforce the
    // 2-minute window natively — no Dart timer dependency.
    // Key: "flutter.emergencyEndEpochMs" in FlutterSharedPreferences.
    final endMs = DateTime.now()
        .add(const Duration(minutes: 2))
        .millisecondsSinceEpoch;
    _prefs.setInt('emergencyEndEpochMs', endMs);

    _persistState();
    notifyListeners();

    _emergencyTimer?.cancel();
    _emergencyTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emergencyRemaining.inSeconds <= 1) {
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
    // Clear the native emergency window so AppMonitorService resumes blocking
    _prefs.setInt('emergencyEndEpochMs', 0);
    notifyListeners();
  }

  // ── Penalty unlock — called by BillingService on successful purchase ───────
  void unlockAll() {
    _countdownTimer?.cancel();
    _emergencyTimer?.cancel();
    _emergencyUnlockActive = false;
    _isPenaltyUnlocked = true;
    _activeChallenge = ChallengeType.none;
    _lockedPackages = [];
    _remainingTime = Duration.zero;
    _challengeStartTime = null;
    // Clear native emergency window flag on full unlock
    _prefs.setInt('emergencyEndEpochMs', 0);
    _persistState();
    notifyListeners();
  }

  // ── Step updates ───────────────────────────────────────────────────────────
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

  // ── Package lock check ─────────────────────────────────────────────────────
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
