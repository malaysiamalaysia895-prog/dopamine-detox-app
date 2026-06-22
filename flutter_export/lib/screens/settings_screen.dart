// ============================================================
// settings_screen.dart — In-Game Settings Modal Sheet
// Tech Tycoon Merge
//
// Shown as a bottom sheet from both the Level Map header
// and the in-game HUD. Controls BGM/SFX volumes and mute,
// with a Restore Purchases placeholder for Play Store
// compliance.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/audio_manager.dart';

// ─── Public entry point ───────────────────────────────────────────────────────
// Call this from any screen to show the settings sheet.

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SettingsSheet(),
  );
}

// ─── Sheet shell ──────────────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A2E), Color(0xFF0A0014)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top:   BorderSide(color: Color(0x4000E5FF), width: 1.5),
          left:  BorderSide(color: Color(0x2000E5FF), width: 1),
          right: BorderSide(color: Color(0x2000E5FF), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(children: [
                const Text('⚙️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Text('Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
              ]),
              const SizedBox(height: 28),

              // ── Audio Section ──────────────────────────────────────────────
              _SectionLabel('🎵  Audio'),
              const SizedBox(height: 16),
              const _AudioPanel(),
              const SizedBox(height: 30),

              // ── Purchases Section ──────────────────────────────────────────
              _SectionLabel('💳  Purchases'),
              const SizedBox(height: 14),
              const _RestorePurchasesButton(),
              const SizedBox(height: 30),

              // ── Credits Section ────────────────────────────────────────────
              _SectionLabel('ℹ️  Credits'),
              const SizedBox(height: 14),
              const _CreditsPanel(),
              const SizedBox(height: 16),

              // Version
              Center(
                child: Text('Tech Tycoon Merge  •  v1.0.0',
                  style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

Widget _SectionLabel(String text) => Text(
  text,
  style: const TextStyle(
    color: Color(0xFF00E5FF),
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  ),
);

// ─── Audio Panel ──────────────────────────────────────────────────────────────

class _AudioPanel extends ConsumerWidget {
  const _AudioPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s      = ref.watch(settingsProvider);
    final notify = ref.read(settingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // ── Mute toggle ──────────────────────────────────────────────────
          Row(
            children: [
              Text(s.muted ? '🔇' : '🔊', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('All Sound',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Switch(
                value: !s.muted,
                activeColor: const Color(0xFF00E5FF),
                onChanged: (on) => notify.setMuted(!on),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),

          // ── BGM volume ───────────────────────────────────────────────────
          _VolumeRow(
            icon: '🎶',
            label: 'Music',
            subtitle: 'Background track volume',
            value: s.bgmVolume,
            enabled: !s.muted,
            onChanged: (v) {
              notify.setBgmVolume(v);
              // Play a small preview tone so player hears change live.
              AudioManager.instance.playUnlock();
            },
          ),
          const SizedBox(height: 16),

          // ── SFX volume ───────────────────────────────────────────────────
          _VolumeRow(
            icon: '🔔',
            label: 'Sound FX',
            subtitle: 'Spawn, merge & alert sounds',
            value: s.sfxVolume,
            enabled: !s.muted,
            onChanged: (v) {
              notify.setSfxVolume(v);
              AudioManager.instance.playMergeSnap();
            },
          ),
        ],
      ),
    );
  }
}

// ─── Volume row ───────────────────────────────────────────────────────────────

class _VolumeRow extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final double value;
  final bool   enabled;
  final ValueChanged<double> onChanged;

  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
              const Spacer(),
              Text('${(value * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF), fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
              thumbColor:         const Color(0xFF00E5FF),
              overlayColor:       const Color(0x2200E5FF),
              trackHeight:        3,
              thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 0.0, max: 1.0,
              divisions: 20,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restore Purchases button ─────────────────────────────────────────────────

class _RestorePurchasesButton extends StatelessWidget {
  const _RestorePurchasesButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Text('🔑', style: TextStyle(fontSize: 16)),
        label: const Text('Restore Purchases',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFD700),
          side: const BorderSide(color: Color(0x66FFD700), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Text('🔍', style: TextStyle(fontSize: 16)),
                SizedBox(width: 10),
                Text('No previous purchases found.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
              backgroundColor: const Color(0xFF1A0A2E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }
}

// ─── Credits Panel ────────────────────────────────────────────────────────────

class _CreditsPanel extends StatelessWidget {
  const _CreditsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CreditRow(
            emoji: '🎵',
            title: '"Floating Cities"',
            body: 'Kevin MacLeod · incompetech.com\nLicensed under CC-BY 4.0',
          ),
          const Divider(color: Colors.white10, height: 20),
          _CreditRow(
            emoji: '🎮',
            title: 'Tech Tycoon Merge',
            body: 'Puzzle game — all rights reserved.',
          ),
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _CreditRow({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body,
                style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
