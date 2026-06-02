// ============================================================
// settings_provider.dart — Persistent Audio & App Settings
// Tech Tycoon Merge
// Persists via SharedPreferences. Applies changes to
// AudioManager immediately so the player hears feedback
// while dragging sliders.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_manager.dart';

// ─── Keys ────────────────────────────────────────────────────────────────────

const _kBgmVolKey  = 'settings_bgm_volume';
const _kSfxVolKey  = 'settings_sfx_volume';
const _kMutedKey   = 'settings_muted';

// ─── State ────────────────────────────────────────────────────────────────────

@immutable
class SettingsState {
  final double bgmVolume; // 0.0 – 1.0
  final double sfxVolume; // 0.0 – 1.0
  final bool   muted;
  final bool   loaded;    // false until SharedPreferences finishes loading

  const SettingsState({
    this.bgmVolume = 0.20,
    this.sfxVolume = 1.00,
    this.muted     = false,
    this.loaded    = false,
  });

  SettingsState copyWith({
    double? bgmVolume,
    double? sfxVolume,
    bool?   muted,
    bool?   loaded,
  }) => SettingsState(
    bgmVolume: bgmVolume ?? this.bgmVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
    muted:     muted     ?? this.muted,
    loaded:    loaded    ?? this.loaded,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  // ── Load saved preferences on startup ─────────────────────────────────────

  Future<void> _load() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final bgm    = prefs.getDouble(_kBgmVolKey) ?? 0.20;
      final sfx    = prefs.getDouble(_kSfxVolKey) ?? 1.00;
      final muted  = prefs.getBool(_kMutedKey)    ?? false;

      state = SettingsState(
        bgmVolume: bgm,
        sfxVolume: sfx,
        muted:     muted,
        loaded:    true,
      );

      // Apply to AudioManager
      AudioManager.instance.setBgmVolume(bgm);
      AudioManager.instance.setSfxVolume(sfx);
      AudioManager.instance.setMuted(muted);
    } catch (e) {
      debugPrint('[Settings] _load() failed: $e');
      state = state.copyWith(loaded: true);
    }
  }

  // ── BGM Volume ────────────────────────────────────────────────────────────

  Future<void> setBgmVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    state = state.copyWith(bgmVolume: clamped);
    AudioManager.instance.setBgmVolume(clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kBgmVolKey, clamped);
    } catch (e) {
      debugPrint('[Settings] setBgmVolume save failed: $e');
    }
  }

  // ── SFX Volume ────────────────────────────────────────────────────────────

  Future<void> setSfxVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    state = state.copyWith(sfxVolume: clamped);
    AudioManager.instance.setSfxVolume(clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kSfxVolKey, clamped);
    } catch (e) {
      debugPrint('[Settings] setSfxVolume save failed: $e');
    }
  }

  // ── Mute toggle ───────────────────────────────────────────────────────────

  Future<void> setMuted(bool muted) async {
    state = state.copyWith(muted: muted);
    AudioManager.instance.setMuted(muted);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMutedKey, muted);
    } catch (e) {
      debugPrint('[Settings] setMuted save failed: $e');
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
