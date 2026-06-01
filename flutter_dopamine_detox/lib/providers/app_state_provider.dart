import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChallengeType { none, studyFocus, mobileLock, healthChallenge }

/// ─────────────────────────────────────────────────────────────────────────────
/// AppStateProvider
///
/// TIMER: Wall-clock based (survives process kill).
///   Start epoch + duration stored → remaining = duration − elapsed(now).
///
/// EMERGENCY USES: 10 per calendar day, reset at midnight.
///   consumeEmergencyUse() is called by HomeScreen when overlay reports bypass.
///
/// BLOCKING: lockedPackages list persisted to SharedPreferences.
///   isPackageLocked() is the single source of truth for HomeScreen.
/// ─────────────────────────────────────────────────────────────────────────────
class AppStateProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  AppStateProvider(this._prefs) {
    _loadState();
  }

  // ── Active challenge ───────────────────────────────────────────────────────
  ChallengeType _activeChallenge = ChallengeType.none;
  ChallengeType get activeChallenge => _activeChallenge;
  bool get isLocked => _activeChallenge != ChallengeType.none;

  // ── Blocked packages ───────────────────────────────────────────────────────
  List<String> _lockedPackages = [];
  List<String> get lockedPackages => List.unmodifiable(_lockedPackages);

  // ── Wall-clock timer ───────────────────────────────────────────────────────
  DateTime? _startTime;
  Duration _challengeDuration = Duration.zero;
  Duration _remainingTime = Duration.zero;
  Duration get remainingTime => _remainingTime;
  Duration get challengeDuration => _challengeDuration;
  Timer? _ticker;

  double get progressFraction {
    if (_challengeDuration.inSeconds == 0 || _startTime == null) return 0.0;
    final elapsed = DateTime.now().difference(_startTime!);
    return (elapsed.inSeconds / _challengeDuration.inSeconds).clamp(0.0, 1.0);
  }

  // ── Emergency uses ─────────────────────────────────────────────────────────
  static const int _maxEmergency = 10;
  int _emergencyUsesToday = 0;
  int get emergencyUsesLeft =>
      (_maxEmergency - _emergencyUsesToday).clamp(0, _maxEmergency);

  // ── Billing ────────────────────────────────────────────────────────────────
  bool _penaltyUnlocked = false;
  bool get isPenaltyUnlocked => _penaltyUnlocked;

  // ── Health ─────────────────────────────────────────────────────────────────
  int _targetSteps = 1500;
  int get targetSteps => _targetSteps;
  int _currentSteps = 0;
  int get currentSteps => _currentSteps;
  bool _healthCompleted = false;
  bool get healthCompleted => _healthCompleted;

  // ── Persist / Load ─────────────────────────────────────────────────────────

  void _loadState() {
    // Emergency uses (daily reset)
    final today = _today();
    if (_prefs.getString('emergencyDate') == today) {
      _emergencyUsesToday = _prefs.getInt('emergencyToday') ?? 0;
    } else {
      _emergencyUsesToday = 0;
      _prefs.setString('emergencyDate', today);
      _prefs.setInt('emergencyToday', 0);
    }

    final idx = _prefs.getInt('activeChallenge') ?? 0;
    _activeChallenge = ChallengeType.values[idx];

    if (_activeChallenge != ChallengeType.none) {
      _lockedPackages = _prefs.getStringList('lockedPackages') ?? [];
      _targetSteps = _prefs.getInt('targetSteps') ?? 1500;
      final dur = _prefs.getInt('durationSecs') ?? 0;
      final startMs = _prefs.getInt('startEpochMs') ?? 0;
      _challengeDuration = Duration(seconds: dur);
      _startTime = DateTime.fromMillisecondsSinceEpoch(startMs);

      final elapsed = DateTime.now().difference(_startTime!);
      _remainingTime = _challengeDuration - elapsed;

      if (_remainingTime.isNegative || _remainingTime == Duration.zero) {
        _completeChallenge(notify: false);
      } else {
        _startTicker();
      }
    }
  }

  void _save() {
    _prefs.setInt('activeChallenge', _activeChallenge.index);
    _prefs.setStringList('lockedPackages', _lockedPackages);
    _prefs.setInt('durationSecs', _challengeDuration.inSeconds);
    _prefs.setInt('targetSteps', _targetSteps);
    if (_startTime != null) {
      _prefs.setInt('startEpochMs', _startTime!.millisecondsSinceEpoch);
    }
    _prefs.setString('emergencyDate', _today());
    _prefs.setInt('emergencyToday', _emergencyUsesToday);
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  // ── Start challenges ───────────────────────────────────────────────────────

  void startStudyFocus({
    required List<String> packages,
    required Duration duration,
  }) {
    _lockedPackages = packages;
    _activeChallenge = ChallengeType.studyFocus;
    _challengeDuration = duration;
    _startTime = DateTime.now();
    _remainingTime = duration;
    _penaltyUnlocked = false;
    _save();
    _startTicker();
    notifyListeners();
  }

  void startMobileLock({required Duration duration}) {
    _lockedPackages = [];
    _activeChallenge = ChallengeType.mobileLock;
    _challengeDuration = duration;
    _startTime = DateTime.now();
    _remainingTime = duration;
    _penaltyUnlocked = false;
    _save();
    _startTicker();
    notifyListeners();
  }

  void startHealthChallenge(
      {required Duration duration, required int targetSteps}) {
    _activeChallenge = ChallengeType.healthChallenge;
    _challengeDuration = duration;
    _startTime = DateTime.now();
    _remainingTime = duration;
    _targetSteps = targetSteps;
    _currentSteps = 0;
    _healthCompleted = false;
    _penaltyUnlocked = false;
    _save();
    _startTicker();
    notifyListeners();
  }

  // ── Wall-clock ticker ──────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime == null) return;
      final elapsed = DateTime.now().difference(_startTime!);
      _remainingTime = _challengeDuration - elapsed;
      if (_remainingTime.isNegative || _remainingTime == Duration.zero) {
        _remainingTime = Duration.zero;
        _ticker?.cancel();
        _completeChallenge();
        return;
      }
      notifyListeners();
    });
  }

  void _completeChallenge({bool notify = true}) {
    final wasHealth = _activeChallenge == ChallengeType.healthChallenge;
    _activeChallenge = ChallengeType.none;
    _lockedPackages = [];
    _penaltyUnlocked = false;
    _startTime = null;
    if (wasHealth) _healthCompleted = _currentSteps >= _targetSteps;
    _save();
    if (notify) notifyListeners();
  }

  // ── Emergency uses ─────────────────────────────────────────────────────────

  /// Called by HomeScreen when the overlay reports an emergency bypass.
  void consumeEmergencyUse() {
    if (emergencyUsesLeft <= 0) return;
    _emergencyUsesToday++;
    _save();
    notifyListeners();
  }

  // ── Penalty unlock ─────────────────────────────────────────────────────────

  void unlockAll() {
    _ticker?.cancel();
    _penaltyUnlocked = true;
    _activeChallenge = ChallengeType.none;
    _lockedPackages = [];
    _remainingTime = Duration.zero;
    _startTime = null;
    _save();
    notifyListeners();
  }

  // ── Package lock check (used by HomeScreen) ────────────────────────────────

  /// Returns true if [packageName] should trigger the overlay right now.
  bool isPackageLocked(String packageName) {
    if (_penaltyUnlocked) return false;
    if (_activeChallenge == ChallengeType.studyFocus) {
      return _lockedPackages.contains(packageName);
    }
    if (_activeChallenge == ChallengeType.mobileLock) return true;
    return false;
  }

  // ── Step updates ───────────────────────────────────────────────────────────

  void updateSteps(int steps) {
    if (_activeChallenge != ChallengeType.healthChallenge) return;
    _currentSteps = steps;
    if (_currentSteps >= _targetSteps) {
      _healthCompleted = true;
      _ticker?.cancel();
      _activeChallenge = ChallengeType.none;
      _save();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
