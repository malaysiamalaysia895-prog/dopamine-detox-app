# Tech Tycoon Merge — Flutter Production Code

Generated: 2026-06-01T17:17:53.030Z

## Files Included
- main.dart
- level_config.dart
- ad_manager.dart
- game_state.dart
- game_screen.dart

---

## level_config.dart

```dart
// ============================================================
// level_config.dart
// Tech Tycoon Merge — 50-Level Configuration Database
// ============================================================

import 'package:flutter/material.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum ObstacleType { none, dustyWeb, lockedCrate, timedOrder, blackHole }

enum GamePhase { garage, office, silicon, megacorp, universe }

// ─── Item Definition ─────────────────────────────────────────────────────────

class ItemDef {
  final String id;
  final String name;
  final String emoji;
  final int tier;

  const ItemDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tier,
  });
}

// ─── Phase Theme ─────────────────────────────────────────────────────────────

class PhaseTheme {
  final String name;
  final Color background;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;

  const PhaseTheme({
    required this.name,
    required this.background,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
  });
}

// ─── Level Model ─────────────────────────────────────────────────────────────

class LevelModel {
  final int levelNumber;
  final String title;
  final String story;
  final String targetItemId;
  final int gridCols;
  final int gridRows;
  final GamePhase phase;
  final int baseCoins;
  final int energyCostPerSpawn;
  final ObstacleType obstacle;
  final bool fasterEnergyDrain;
  final int? timedOrderSeconds;

  // ── Per-level ad permission flags ──────────────────────────────────────────
  // allowLowEnergyBoost:    Rule 1 — show "Watch Ad for +50⚡" when energy ≤ 20
  // allowZeroEnergyLockout: Rule 2 — block spawner + show hard popup at energy == 0
  // allowScoreMultiplier:   Rule 3 — offer "Watch Ad for 3× Coins" on level complete
  // triggerInterstitialNext:Rule 4 — fire interstitial on "Next Level" (every even level)
  final bool allowLowEnergyBoost;
  final bool allowZeroEnergyLockout;
  final bool allowScoreMultiplier;
  final bool triggerInterstitialNext;

  const LevelModel({
    required this.levelNumber,
    required this.title,
    required this.story,
    required this.targetItemId,
    required this.gridCols,
    required this.gridRows,
    required this.phase,
    required this.baseCoins,
    required this.energyCostPerSpawn,
    this.obstacle = ObstacleType.none,
    this.fasterEnergyDrain = false,
    this.timedOrderSeconds,
    this.allowLowEnergyBoost = true,
    this.allowZeroEnergyLockout = true,
    this.allowScoreMultiplier = true,
    this.triggerInterstitialNext = true,
  });
}

// ─── Item Chains ─────────────────────────────────────────────────────────────
// Tier 0 = base spawnable item for that phase.
// Merging two tier-N items → tier-(N+1).

class ItemChains {
  static const List<ItemDef> garage = [
    ItemDef(id: 'g0',  name: 'Wire',              emoji: '🔌', tier: 0),
    ItemDef(id: 'g1',  name: 'USB Cable',         emoji: '🪢', tier: 1),
    ItemDef(id: 'g2',  name: 'Retro Mouse',       emoji: '🖱️', tier: 2),
    ItemDef(id: 'g3',  name: 'Mech. Keyboard',    emoji: '⌨️', tier: 3),
    ItemDef(id: 'g4',  name: 'CRT Monitor',       emoji: '🖥️', tier: 4),
    ItemDef(id: 'g5',  name: 'Motherboard',       emoji: '🔧', tier: 5),
    ItemDef(id: 'g6',  name: '4GB RAM',           emoji: '💾', tier: 6),
    ItemDef(id: 'g7',  name: 'Dual-Core CPU',     emoji: '⚙️', tier: 7),
    ItemDef(id: 'g8',  name: 'CPU Cooler',        emoji: '❄️', tier: 8),
    ItemDef(id: 'g9',  name: 'PSU',               emoji: '🔋', tier: 9),
    ItemDef(id: 'g10', name: 'Basic Desktop',     emoji: '💻', tier: 10),
  ];

  static const List<ItemDef> office = [
    ItemDef(id: 'o0',  name: 'USB Hub',           emoji: '🔌', tier: 0),
    ItemDef(id: 'o1',  name: 'Basic Laptop',      emoji: '💻', tier: 1),
    ItemDef(id: 'o2',  name: 'Graphics Card',     emoji: '🎮', tier: 2),
    ItemDef(id: 'o3',  name: 'Pro Monitor',       emoji: '🖥️', tier: 3),
    ItemDef(id: 'o4',  name: 'Studio Mic',        emoji: '🎙️', tier: 4),
    ItemDef(id: 'o5',  name: '1TB SSD',           emoji: '💿', tier: 5),
    ItemDef(id: 'o6',  name: 'Home Server',       emoji: '🗄️', tier: 6),
    ItemDef(id: 'o7',  name: 'Smart Speaker',     emoji: '📻', tier: 7),
    ItemDef(id: 'o8',  name: 'HW Firewall',       emoji: '🛡️', tier: 8),
    ItemDef(id: 'o9',  name: 'Powerbank',         emoji: '🔋', tier: 9),
    ItemDef(id: 'o10', name: 'RGB Gaming PC',     emoji: '🎯', tier: 10),
  ];

  static const List<ItemDef> silicon = [
    ItemDef(id: 's0',  name: 'Sensor Module',     emoji: '📡', tier: 0),
    ItemDef(id: 's1',  name: 'VR Headset',        emoji: '🥽', tier: 1),
    ItemDef(id: 's2',  name: '4K Drone',          emoji: '🚁', tier: 2),
    ItemDef(id: 's3',  name: 'Holo. Smartwatch',  emoji: '⌚', tier: 3),
    ItemDef(id: 's4',  name: 'Mining Rig',        emoji: '⛏️', tier: 4),
    ItemDef(id: 's5',  name: '3D Printer',        emoji: '🏭', tier: 5),
    ItemDef(id: 's6',  name: 'Cloud Rack',        emoji: '☁️', tier: 6),
    ItemDef(id: 's7',  name: 'AutoPilot Chip',    emoji: '🚗', tier: 7),
    ItemDef(id: 's8',  name: 'Bionic Arm',        emoji: '🦾', tier: 8),
    ItemDef(id: 's9',  name: 'Cyber-Dog',         emoji: '🤖', tier: 9),
    ItemDef(id: 's10', name: 'Data Center',       emoji: '🏢', tier: 10),
  ];

  static const List<ItemDef> megacorp = [
    ItemDef(id: 'm0',  name: 'Photon Cell',       emoji: '💡', tier: 0),
    ItemDef(id: 'm1',  name: 'Hologram Proj.',    emoji: '📽️', tier: 1),
    ItemDef(id: 'm2',  name: 'Neural Headset',    emoji: '🧠', tier: 2),
    ItemDef(id: 'm3',  name: 'Quantum Proc.',     emoji: '⚛️', tier: 3),
    ItemDef(id: 'm4',  name: 'Plasma Shield',     emoji: '🛡️', tier: 4),
    ItemDef(id: 'm5',  name: 'Nanobot Swarm',     emoji: '🔬', tier: 5),
    ItemDef(id: 'm6',  name: 'Laser Dish',        emoji: '📡', tier: 6),
    ItemDef(id: 'm7',  name: 'Hoverboard',        emoji: '🛹', tier: 7),
    ItemDef(id: 'm8',  name: 'Power Exosuit',     emoji: '🦾', tier: 8),
    ItemDef(id: 'm9',  name: 'Sentient AI Core',  emoji: '🤖', tier: 9),
    ItemDef(id: 'm10', name: 'Space Station',     emoji: '🛸', tier: 10),
  ];

  static const List<ItemDef> universe = [
    ItemDef(id: 'u0',  name: 'Dark Energy',       emoji: '🌌', tier: 0),
    ItemDef(id: 'u1',  name: 'Warp Engine',       emoji: '🚀', tier: 1),
    ItemDef(id: 'u2',  name: 'Atm. Generator',    emoji: '🌿', tier: 2),
    ItemDef(id: 'u3',  name: 'Dark Matter React.', emoji: '⚛️', tier: 3),
    ItemDef(id: 'u4',  name: 'Telepad',           emoji: '🔵', tier: 4),
    ItemDef(id: 'u5',  name: 'Chrono-Device',     emoji: '⏱️', tier: 5),
    ItemDef(id: 'u6',  name: 'Star Forge',        emoji: '⭐', tier: 6),
    ItemDef(id: 'u7',  name: 'Soul-Drive',        emoji: '💎', tier: 7),
    ItemDef(id: 'u8',  name: 'Galactic Router',   emoji: '🌐', tier: 8),
    ItemDef(id: 'u9',  name: 'Dimensional Rift',  emoji: '🌀', tier: 9),
    ItemDef(id: 'u10', name: 'Dyson Sphere',      emoji: '☀️', tier: 10),
  ];

  static List<ItemDef> chainForPhase(GamePhase phase) {
    switch (phase) {
      case GamePhase.garage:   return garage;
      case GamePhase.office:   return office;
      case GamePhase.silicon:  return silicon;
      case GamePhase.megacorp: return megacorp;
      case GamePhase.universe: return universe;
    }
  }

  static ItemDef? getById(String id) {
    for (final chain in [garage, office, silicon, megacorp, universe]) {
      try {
        return chain.firstWhere((item) => item.id == id);
      } catch (_) {}
    }
    return null;
  }

  static ItemDef? nextTier(String currentId) {
    for (final chain in [garage, office, silicon, megacorp, universe]) {
      final idx = chain.indexWhere((i) => i.id == currentId);
      if (idx != -1 && idx + 1 < chain.length) return chain[idx + 1];
    }
    return null;
  }
}

// ─── Phase Themes ────────────────────────────────────────────────────────────

class PhaseThemes {
  static const Map<GamePhase, PhaseTheme> themes = {
    GamePhase.garage: PhaseTheme(
      name: 'The Garage Startup',
      background: Color(0xFF1A0500),
      primaryColor: Color(0xFFFF6B35),
      accentColor: Color(0xFF00E5FF),
      textColor: Colors.white,
    ),
    GamePhase.office: PhaseTheme(
      name: 'The Office Upgrade',
      background: Color(0xFF001A33),
      primaryColor: Color(0xFF1E90FF),
      accentColor: Color(0xFFFFFFFF),
      textColor: Colors.white,
    ),
    GamePhase.silicon: PhaseTheme(
      name: 'Silicon Valley Tycoon',
      background: Color(0xFF1A0033),
      primaryColor: Color(0xFFCC00FF),
      accentColor: Color(0xFFFF0080),
      textColor: Colors.white,
    ),
    GamePhase.megacorp: PhaseTheme(
      name: 'Global Mega-Corp',
      background: Color(0xFF001100),
      primaryColor: Color(0xFF00FF41),
      accentColor: Color(0xFF39FF14),
      textColor: Colors.white,
    ),
    GamePhase.universe: PhaseTheme(
      name: 'Masters of the Universe',
      background: Color(0xFF0A0000),
      primaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFFE5E4E2),
      textColor: Colors.white,
    ),
  };

  static PhaseTheme of(GamePhase phase) => themes[phase]!;
}

// ─── TechTycoonLevels ─────────────────────────────────────────────────────────

class TechTycoonLevels {
  // ── Real AdMob IDs ─────────────────────────────────────────────────────────
  //
  // AndroidManifest.xml placement:
  //   Inside <application> tag, add:
  //     <meta-data
  //       android:name="com.google.android.gms.ads.APPLICATION_ID"
  //       android:value="ca-app-pub-8566652140087308~1114269136"/>
  //
  static const String admobAppId         = 'ca-app-pub-8566652140087308~1114269136';
  static const String rewardedAdUnitId   = 'ca-app-pub-8566652140087308/7306930941';
  static const String interstitialAdUnitId = 'ca-app-pub-8566652140087308/3659026052';

  static List<LevelModel> get50Levels() {
    return [
      // ════════════════════════════════════════════════════════════════════════
      // PHASE 1: THE GARAGE STARTUP — Grid 4×4 — Rusty Orange & Cyan
      // Ad strategy: tutorial-friendly low intrusion.
      //   L1: allowLowEnergyBoost=false (no interruption during tutorial)
      //   L1: triggerInterstitialNext=false (no interstitial after level 1; Rule 4 starts at L2)
      // ════════════════════════════════════════════════════════════════════════
      const LevelModel(
        levelNumber: 1, title: 'The Spark',
        story: 'Welcome to the garage! Make some basic connections.',
        targetItemId: 'g1', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 50, energyCostPerSpawn: 5,
        allowLowEnergyBoost: false,   // Tutorial — no ad interruption
        allowZeroEnergyLockout: true,
        allowScoreMultiplier: true,
        triggerInterstitialNext: false, // Rule 4 starts checking from L2
      ),
      const LevelModel(
        levelNumber: 2, title: 'Scraping By',
        story: 'We need input devices to test our junk.',
        targetItemId: 'g2', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 80, energyCostPerSpawn: 5,
        allowLowEnergyBoost: false,   // L2 still gentle — boost starts L3
        triggerInterstitialNext: true, // Level 2 is even → interstitial fires
      ),
      const LevelModel(
        levelNumber: 3, title: 'Click & Clack',
        story: 'Typing on wires hurts. Build a keyboard!',
        targetItemId: 'g3', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 110, energyCostPerSpawn: 6,
      ),
      const LevelModel(
        levelNumber: 4, title: 'Hello World',
        story: 'We need to see what we are doing.',
        targetItemId: 'g4', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 140, energyCostPerSpawn: 6,
        // Level 4 even → interstitial fires (triggerInterstitialNext: true by default)
      ),
      const LevelModel(
        levelNumber: 5, title: 'The Brains',
        story: 'Time to process data.',
        targetItemId: 'g5', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 170, energyCostPerSpawn: 7,
      ),
      const LevelModel(
        levelNumber: 6, title: 'Memory Lane',
        story: 'Your PC keeps crashing. Add memory!',
        targetItemId: 'g6', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 200, energyCostPerSpawn: 7,
        obstacle: ObstacleType.dustyWeb,
        // Dusty Webs introduced — grid-full risk → heavy Rule 1 & 2 ad triggers
      ),
      const LevelModel(
        levelNumber: 7, title: 'Speed It Up',
        story: 'We need a faster processor.',
        targetItemId: 'g7', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 230, energyCostPerSpawn: 8,
        obstacle: ObstacleType.dustyWeb,
      ),
      const LevelModel(
        levelNumber: 8, title: 'Cooling Down',
        story: 'Things are getting hot. Add a fan.',
        targetItemId: 'g8', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 260, energyCostPerSpawn: 8,
        obstacle: ObstacleType.dustyWeb,
      ),
      const LevelModel(
        levelNumber: 9, title: 'Power Up',
        story: 'We need more juice!',
        targetItemId: 'g9', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 290, energyCostPerSpawn: 9,
        obstacle: ObstacleType.dustyWeb,
      ),
      const LevelModel(
        levelNumber: 10, title: 'The First PC',
        story: 'You did it! Your first fully working Desktop PC.',
        targetItemId: 'g10', gridCols: 4, gridRows: 4,
        phase: GamePhase.garage, baseCoins: 500, energyCostPerSpawn: 10,
        obstacle: ObstacleType.dustyWeb,
        // Level 10 even → interstitial fires
      ),

      // ════════════════════════════════════════════════════════════════════════
      // PHASE 2: THE OFFICE UPGRADE — Grid 5×5 — Clean Blue & White
      // Locked Crates at L15 — forces space-clearing → spikes energy ad triggers.
      // ════════════════════════════════════════════════════════════════════════
      const LevelModel(
        levelNumber: 11, title: 'Going Mobile',
        story: 'Customers want portability.',
        targetItemId: 'o1', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 300, energyCostPerSpawn: 8,
      ),
      const LevelModel(
        levelNumber: 12, title: 'Gaming Vibes',
        story: 'Gamers pay well. Give them graphics!',
        targetItemId: 'o2', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 350, energyCostPerSpawn: 9,
      ),
      const LevelModel(
        levelNumber: 13, title: 'The Setup',
        story: 'Streamers need a dual-monitor setup.',
        targetItemId: 'o3', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 400, energyCostPerSpawn: 9,
      ),
      const LevelModel(
        levelNumber: 14, title: 'Sound Check',
        story: 'Audio is key for the streamers.',
        targetItemId: 'o4', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 450, energyCostPerSpawn: 10,
      ),
      const LevelModel(
        levelNumber: 15, title: 'Storage Wars',
        story: 'We need to save massive data.',
        targetItemId: 'o5', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 500, energyCostPerSpawn: 10,
        obstacle: ObstacleType.lockedCrate,
      ),
      const LevelModel(
        levelNumber: 16, title: 'The Server',
        story: "Let's host our own website.",
        targetItemId: 'o6', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 550, energyCostPerSpawn: 11,
        obstacle: ObstacleType.lockedCrate,
      ),
      const LevelModel(
        levelNumber: 17, title: 'Smart Home',
        story: "Let's automate the office lights.",
        targetItemId: 'o7', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 600, energyCostPerSpawn: 11,
        obstacle: ObstacleType.lockedCrate,
      ),
      const LevelModel(
        levelNumber: 18, title: 'Security',
        story: 'Protect the office from hackers.',
        targetItemId: 'o8', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 650, energyCostPerSpawn: 12,
        obstacle: ObstacleType.lockedCrate,
      ),
      const LevelModel(
        levelNumber: 19, title: 'Portable Power',
        story: 'Working on the go needs battery.',
        targetItemId: 'o9', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 700, energyCostPerSpawn: 12,
        obstacle: ObstacleType.lockedCrate,
      ),
      const LevelModel(
        levelNumber: 20, title: 'The Gaming Rig',
        story: 'A masterpiece of RGB and power!',
        targetItemId: 'o10', gridCols: 5, gridRows: 5,
        phase: GamePhase.office, baseCoins: 1000, energyCostPerSpawn: 13,
        obstacle: ObstacleType.lockedCrate,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // PHASE 3: SILICON VALLEY TYCOON — Grid 5×5 — Neon Purple & Pink
      // fasterEnergyDrain=true → high energy use → heavily triggers Rule 1 & 2.
      // ════════════════════════════════════════════════════════════════════════
      const LevelModel(
        levelNumber: 21, title: 'Virtual Reality',
        story: "Let's step into the Metaverse.",
        targetItemId: 's1', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 600, energyCostPerSpawn: 10,
        fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 22, title: 'Flying High',
        story: 'We need aerial footage.',
        targetItemId: 's2', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 700, energyCostPerSpawn: 11,
        fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 23, title: 'Wearables',
        story: 'Tech on your wrist.',
        targetItemId: 's3', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 800, energyCostPerSpawn: 11,
        obstacle: ObstacleType.dustyWeb, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 24, title: 'Crypto Mining',
        story: 'Time to mine some digital gold.',
        targetItemId: 's4', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 900, energyCostPerSpawn: 12,
        obstacle: ObstacleType.dustyWeb, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 25, title: '3D Printing',
        story: 'Why buy parts when you can print them?',
        targetItemId: 's5', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 1000, energyCostPerSpawn: 12,
        obstacle: ObstacleType.lockedCrate, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 26, title: 'Cloud Storage',
        story: 'Move everything to the cloud.',
        targetItemId: 's6', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 1100, energyCostPerSpawn: 13,
        obstacle: ObstacleType.lockedCrate, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 27, title: 'Self-Driving',
        story: 'Cars need brains too.',
        targetItemId: 's7', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 1200, energyCostPerSpawn: 13,
        obstacle: ObstacleType.lockedCrate, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 28, title: 'Bionic Tech',
        story: 'Upgrading the human body.',
        targetItemId: 's8', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 1300, energyCostPerSpawn: 14,
        obstacle: ObstacleType.lockedCrate, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 29, title: 'Robotics',
        story: 'Meet your new robotic assistant.',
        targetItemId: 's9', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 1400, energyCostPerSpawn: 14,
        obstacle: ObstacleType.lockedCrate, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 30, title: 'The Data Center',
        story: 'You now control 10% of the internet!',
        targetItemId: 's10', gridCols: 5, gridRows: 5,
        phase: GamePhase.silicon, baseCoins: 2000, energyCostPerSpawn: 15,
        obstacle: ObstacleType.lockedCrate, fasterEnergyDrain: true,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // PHASE 4: GLOBAL MEGA-CORP — Grid 6×5 — Acid Green & Black
      // Timed Orders: high friction → maximises Rule 4 interstitial value.
      // ════════════════════════════════════════════════════════════════════════
      const LevelModel(
        levelNumber: 31, title: 'Holograms',
        story: 'Screens are dead. Project it in the air.',
        targetItemId: 'm1', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1000, energyCostPerSpawn: 12,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 90,
      ),
      const LevelModel(
        levelNumber: 32, title: 'Neural Link',
        story: 'Control computers with your mind.',
        targetItemId: 'm2', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1100, energyCostPerSpawn: 13,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 85,
      ),
      const LevelModel(
        levelNumber: 33, title: 'Quantum Chip',
        story: 'Computing at the atomic level.',
        targetItemId: 'm3', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1200, energyCostPerSpawn: 13,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 80,
      ),
      const LevelModel(
        levelNumber: 34, title: 'Energy Shield',
        story: 'Protecting cities from impact.',
        targetItemId: 'm4', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1300, energyCostPerSpawn: 14,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 80,
      ),
      const LevelModel(
        levelNumber: 35, title: 'Nanobots',
        story: 'Microscopic robots fixing errors.',
        targetItemId: 'm5', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1400, energyCostPerSpawn: 14,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 75,
      ),
      const LevelModel(
        levelNumber: 36, title: 'Laser Comms',
        story: 'Communicating at the speed of light.',
        targetItemId: 'm6', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1500, energyCostPerSpawn: 15,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 75,
      ),
      const LevelModel(
        levelNumber: 37, title: 'Anti-Gravity',
        story: 'Who needs wheels?',
        targetItemId: 'm7', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1600, energyCostPerSpawn: 15,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 70,
      ),
      const LevelModel(
        levelNumber: 38, title: 'Exosuit',
        story: 'Superhuman strength for workers.',
        targetItemId: 'm8', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1700, energyCostPerSpawn: 16,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 70,
      ),
      const LevelModel(
        levelNumber: 39, title: 'AI Core',
        story: 'It is awake. It is thinking.',
        targetItemId: 'm9', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 1800, energyCostPerSpawn: 17,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 65,
      ),
      const LevelModel(
        levelNumber: 40, title: 'The Orbital Station',
        story: 'Earth is too small for us now.',
        targetItemId: 'm10', gridCols: 6, gridRows: 5,
        phase: GamePhase.megacorp, baseCoins: 3000, energyCostPerSpawn: 18,
        obstacle: ObstacleType.timedOrder, timedOrderSeconds: 60,
      ),

      // ════════════════════════════════════════════════════════════════════════
      // PHASE 5: MASTERS OF THE UNIVERSE — Grid 6×6 — Gold & Deep Space
      // Black Holes + fasterEnergyDrain = peak monetisation. Max Rule 1 & 2.
      // ════════════════════════════════════════════════════════════════════════
      const LevelModel(
        levelNumber: 41, title: 'Warp Drive',
        story: 'Traveling faster than light.',
        targetItemId: 'u1', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 2000, energyCostPerSpawn: 15,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 42, title: 'Terraforming',
        story: 'Making Mars green.',
        targetItemId: 'u2', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 2200, energyCostPerSpawn: 16,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 43, title: 'Dark Matter',
        story: 'Harnessing the unseen universe.',
        targetItemId: 'u3', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 2400, energyCostPerSpawn: 16,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 44, title: 'Teleportation',
        story: 'From here to there, instantly.',
        targetItemId: 'u4', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 2600, energyCostPerSpawn: 17,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 45, title: 'Time Dilation',
        story: 'Slowing down time itself.',
        targetItemId: 'u5', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 2800, energyCostPerSpawn: 18,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 46, title: 'Star Forge',
        story: 'Creating elements from pure energy.',
        targetItemId: 'u6', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 3000, energyCostPerSpawn: 18,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 47, title: 'Mind Upload',
        story: 'Immortality in the digital realm.',
        targetItemId: 'u7', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 3200, energyCostPerSpawn: 19,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 48, title: 'Galaxy Net',
        story: 'Connecting billions of planets.',
        targetItemId: 'u8', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 3400, energyCostPerSpawn: 20,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 49, title: 'The Multiverse',
        story: 'Peeking into parallel worlds.',
        targetItemId: 'u9', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 3600, energyCostPerSpawn: 21,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
      const LevelModel(
        levelNumber: 50, title: 'The Dyson Sphere',
        story: 'You have captured a star. You are a Tech God.',
        targetItemId: 'u10', gridCols: 6, gridRows: 6,
        phase: GamePhase.universe, baseCoins: 5000, energyCostPerSpawn: 22,
        obstacle: ObstacleType.blackHole, fasterEnergyDrain: true,
      ),
    ];
  }
}

```

---

## ad_manager.dart

```dart
// ============================================================
// ad_manager.dart
// Tech Tycoon Merge — Production AdMob Service
//
// pubspec.yaml dependency:
//   google_mobile_ads: ^5.1.0
//
// AndroidManifest.xml — inside <application> tag:
//   <meta-data
//     android:name="com.google.android.gms.ads.APPLICATION_ID"
//     android:value="ca-app-pub-8566652140087308~1114269136"/>
//
// iOS Info.plist — inside <dict>:
//   <key>GADApplicationIdentifier</key>
//   <string>ca-app-pub-8566652140087308~1114269136</string>
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'level_config.dart';

// ─── Ad Unit IDs ─────────────────────────────────────────────────────────────

class _AdUnitIds {
  // Use test IDs in debug mode; real IDs in release.
  static String get rewarded => kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917'   // Google test rewarded ID
      : TechTycoonLevels.rewardedAdUnitId;          // ca-app-pub-8566652140087308/7306930941

  static String get interstitial => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'   // Google test interstitial ID
      : TechTycoonLevels.interstitialAdUnitId;      // ca-app-pub-8566652140087308/3659026052
}

// ─── AdManagerService (Singleton) ────────────────────────────────────────────

class AdManagerService {
  AdManagerService._();
  static final AdManagerService instance = AdManagerService._();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _rewardedLoading = false;
  bool _interstitialLoading = false;

  // Callbacks stored while ad is being watched
  VoidCallback? _pendingRewardCallback;
  VoidCallback? _pendingInterstitialDismiss;

  // ── Initialise MobileAds SDK ───────────────────────────────────────────────
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Pre-load both ad types so they are ready when needed
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REWARDED AD (Rules 1, 2, 3)
  // ══════════════════════════════════════════════════════════════════════════

  void _loadRewardedAd() {
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;

    RewardedAd.load(
      adUnitId: _AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
          _configureRewardedCallbacks();
          debugPrint('[AdManager] Rewarded ad loaded ✓');
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          debugPrint('[AdManager] Rewarded ad failed to load: $error');
          // Retry after 30 s
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  void _configureRewardedCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) =>
          debugPrint('[AdManager] Rewarded ad showing'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdManager] Rewarded ad dismissed (no reward earned)');
        ad.dispose();
        _rewardedAd = null;
        _pendingRewardCallback = null;
        _loadRewardedAd(); // Pre-load next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdManager] Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _pendingRewardCallback = null;
        _loadRewardedAd();
      },
    );
  }

  /// Show a Rewarded Ad.
  ///
  /// [onReward] is called ONLY when the user earns the reward (full view).
  /// This maps to:
  ///   • Rule 1 — onReward: addEnergy(50)
  ///   • Rule 2 — onReward: addEnergy(50)
  ///   • Rule 3 — onReward: multiplyCoins(3)
  Future<bool> showRewardedAd({required VoidCallback onReward}) async {
    if (_rewardedAd == null) {
      debugPrint('[AdManager] Rewarded ad not ready. Loading now…');
      _loadRewardedAd();
      return false;
    }

    _pendingRewardCallback = onReward;

    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        debugPrint('[AdManager] Reward earned: ${reward.type} x${reward.amount}');
        // ✅ Only fires when the user completes the ad — strict as required
        _pendingRewardCallback?.call();
        _pendingRewardCallback = null;
      },
    );

    _rewardedAd = null; // Mark as consumed; pre-load next
    _loadRewardedAd();
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERSTITIAL AD (Rule 4)
  // ══════════════════════════════════════════════════════════════════════════

  void _loadInterstitialAd() {
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;

    InterstitialAd.load(
      adUnitId: _AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
          _configureInterstitialCallbacks();
          debugPrint('[AdManager] Interstitial ad loaded ✓');
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          debugPrint('[AdManager] Interstitial failed to load: $error');
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  void _configureInterstitialCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdManager] Interstitial dismissed — loading next level');
        ad.dispose();
        _interstitialAd = null;
        // ✅ Rule 4: next level grid loads ONLY here, inside onDismiss
        _pendingInterstitialDismiss?.call();
        _pendingInterstitialDismiss = null;
        _loadInterstitialAd(); // Pre-load for next even level
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdManager] Interstitial failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        // Still load the next level so the player isn't stuck
        _pendingInterstitialDismiss?.call();
        _pendingInterstitialDismiss = null;
        _loadInterstitialAd();
      },
    );
  }

  /// Show an Interstitial Ad (Rule 4 — every even level).
  ///
  /// [onDismiss] is called after the ad is dismissed.
  /// The caller MUST wait for this callback before loading the next level.
  ///
  /// Returns true if the ad was shown, false if not ready.
  Future<bool> showInterstitialAd({required VoidCallback onDismiss}) async {
    if (_interstitialAd == null) {
      debugPrint('[AdManager] Interstitial not ready — loading next level directly');
      onDismiss(); // Fallback: don't block the player
      _loadInterstitialAd();
      return false;
    }

    _pendingInterstitialDismiss = onDismiss;
    _interstitialAd!.show();
    _interstitialAd = null; // Mark as consumed
    _loadInterstitialAd();
    return true;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}

```

---

## game_state.dart

```dart
// ============================================================
// game_state.dart
// Tech Tycoon Merge — Riverpod State Management
//
// pubspec.yaml:
//   flutter_riverpod: ^2.5.1
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'level_config.dart';
import 'ad_manager.dart';

// ─── Grid Cell ───────────────────────────────────────────────────────────────

class GridCell {
  final String? itemId;       // null = empty
  final ObstacleType obstacle;
  final bool isLocked;        // true = obstacle is blocking, cannot place items

  const GridCell({
    this.itemId,
    this.obstacle = ObstacleType.none,
    this.isLocked = false,
  });

  bool get isEmpty => itemId == null && !isLocked;
  bool get hasItem  => itemId != null;
  bool get isBlackHole => obstacle == ObstacleType.blackHole;

  GridCell copyWith({
    Object? itemId = _sentinel,
    ObstacleType? obstacle,
    bool? isLocked,
  }) {
    return GridCell(
      itemId:   itemId == _sentinel ? this.itemId : itemId as String?,
      obstacle: obstacle  ?? this.obstacle,
      isLocked: isLocked  ?? this.isLocked,
    );
  }

  static const Object _sentinel = Object();
}

// ─── App Phase ───────────────────────────────────────────────────────────────

enum AppPhase { menu, playing, levelComplete, gameOver }

// ─── Game State ──────────────────────────────────────────────────────────────

@immutable
class GameState {
  final int currentLevelIndex;   // 0-based index into LEVELS list
  final List<List<GridCell>> grid; // grid[col][row]
  final int energy;
  final int maxEnergy;
  final int totalCoins;
  final int levelCompleteCoins;  // base coins for this level (may be ×3 after ad)
  final AppPhase appPhase;
  final bool showEnergyWarning;  // Rule 2 hard popup
  final int timerSeconds;
  final bool timerActive;

  const GameState({
    this.currentLevelIndex = 0,
    this.grid = const [],
    this.energy = 100,
    this.maxEnergy = 100,
    this.totalCoins = 0,
    this.levelCompleteCoins = 0,
    this.appPhase = AppPhase.menu,
    this.showEnergyWarning = false,
    this.timerSeconds = 0,
    this.timerActive = false,
  });

  LevelModel get currentLevel => TechTycoonLevels.get50Levels()[currentLevelIndex];

  /// Rule 1 condition — expose to UI
  bool get shouldShowLowEnergyButton =>
      currentLevel.allowLowEnergyBoost && energy <= 20 && energy > 0;

  /// Rule 2 condition — expose to UI
  bool get isSpawnerBlocked => energy == 0;

  GameState copyWith({
    int? currentLevelIndex,
    List<List<GridCell>>? grid,
    int? energy,
    int? maxEnergy,
    int? totalCoins,
    int? levelCompleteCoins,
    AppPhase? appPhase,
    bool? showEnergyWarning,
    int? timerSeconds,
    bool? timerActive,
  }) {
    return GameState(
      currentLevelIndex:  currentLevelIndex  ?? this.currentLevelIndex,
      grid:               grid               ?? this.grid,
      energy:             energy             ?? this.energy,
      maxEnergy:          maxEnergy          ?? this.maxEnergy,
      totalCoins:         totalCoins         ?? this.totalCoins,
      levelCompleteCoins: levelCompleteCoins ?? this.levelCompleteCoins,
      appPhase:           appPhase           ?? this.appPhase,
      showEnergyWarning:  showEnergyWarning  ?? this.showEnergyWarning,
      timerSeconds:       timerSeconds       ?? this.timerSeconds,
      timerActive:        timerActive        ?? this.timerActive,
    );
  }
}

// ─── Game Notifier ───────────────────────────────────────────────────────────

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(const GameState());

  Timer? _timer;
  final List<LevelModel> _levels = TechTycoonLevels.get50Levels();

  // ── Start Level ───────────────────────────────────────────────────────────

  void startLevel(int levelIndex) {
    _timer?.cancel();
    final cfg = _levels[levelIndex];
    final grid = _buildGrid(cfg);

    state = state.copyWith(
      currentLevelIndex: levelIndex,
      grid: grid,
      appPhase: AppPhase.playing,
      showEnergyWarning: false,
      levelCompleteCoins: 0,
      timerActive: cfg.obstacle == ObstacleType.timedOrder,
      timerSeconds: cfg.timedOrderSeconds ?? 0,
    );

    if (cfg.obstacle == ObstacleType.timedOrder) {
      _startTimer();
    }
  }

  // ── Grid Construction ─────────────────────────────────────────────────────

  List<List<GridCell>> _buildGrid(LevelModel cfg) {
    final rng = DateTime.now().millisecondsSinceEpoch;
    final grid = List.generate(
      cfg.gridCols,
      (c) => List.generate(cfg.gridRows, (r) => const GridCell()),
    );

    // Place obstacles
    int obsCount = 0;
    final maxObs = cfg.obstacle == ObstacleType.blackHole ? 3 : 1;
    outer:
    for (int c = 0; c < cfg.gridCols && obsCount < maxObs; c++) {
      for (int r = 0; r < cfg.gridRows && obsCount < maxObs; r++) {
        // Stagger positions using pseudo-random offset
        if ((c + r + rng) % (cfg.gridCols + 2) == 0) {
          grid[c][r] = GridCell(
            obstacle: cfg.obstacle,
            isLocked: cfg.obstacle != ObstacleType.timedOrder,
          );
          obsCount++;
        }
      }
    }

    // Seed starter items (base tier of current phase)
    final baseItem = ItemChains.chainForPhase(cfg.phase).first;
    int seeded = 0;
    final targetSeeds = ((cfg.gridCols * cfg.gridRows) * 0.18).round().clamp(2, 8);
    for (int c = 0; c < cfg.gridCols && seeded < targetSeeds; c++) {
      for (int r = 0; r < cfg.gridRows && seeded < targetSeeds; r++) {
        if (grid[c][r].isEmpty) {
          grid[c][r] = GridCell(itemId: baseItem.id);
          seeded++;
        }
      }
    }

    return grid;
  }

  // ── Spawn Item ────────────────────────────────────────────────────────────

  /// Called when the player taps an empty cell (spawner interaction).
  void spawnItem(int col, int row) {
    final cfg = state.currentLevel;
    final cell = state.grid[col][row];

    if (cell.isLocked || cell.isBlackHole || cell.hasItem) return;

    // ── Rule 2: energy == 0 — block and optionally show wall ────────────────
    if (state.energy == 0) {
      if (cfg.allowZeroEnergyLockout) {
        state = state.copyWith(showEnergyWarning: true);
      }
      return;
    }

    final energyCost = (cfg.energyCostPerSpawn * (cfg.fasterEnergyDrain ? 1.5 : 1.0)).round();
    final baseItem = ItemChains.chainForPhase(cfg.phase).first;

    final newGrid = _cloneGrid();
    newGrid[col][row] = GridCell(itemId: baseItem.id);

    state = state.copyWith(
      grid: newGrid,
      energy: (state.energy - energyCost).clamp(0, state.maxEnergy),
      showEnergyWarning: false,
    );
  }

  // ── Move / Merge ──────────────────────────────────────────────────────────
  // Called by the UI drag-and-drop gesture.
  // Level(X) + Level(X) = Level(X+1)

  void moveItem(int fromCol, int fromRow, int toCol, int toRow) {
    final fromCell = state.grid[fromCol][fromRow];
    final toCell   = state.grid[toCol][toRow];
    final cfg = state.currentLevel;

    if (fromCell.itemId == null) return;

    final newGrid = _cloneGrid();

    // Dragging into a black hole destroys the item
    if (toCell.isBlackHole) {
      newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: null);
      state = state.copyWith(grid: newGrid);
      return;
    }

    if (toCell.isLocked) return;

    if (toCell.itemId == null) {
      // ── Simple move ──────────────────────────────────────────────────────
      newGrid[toCol][toRow]     = newGrid[toCol][toRow].copyWith(itemId: fromCell.itemId);
      newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: null);
      _tryUnlockAdjacent(newGrid, toCol, toRow, cfg);
    } else if (toCell.itemId == fromCell.itemId) {
      // ── Merge: Level(X) + Level(X) → Level(X+1) ─────────────────────────
      final merged = ItemChains.nextTier(fromCell.itemId!);
      if (merged != null) {
        newGrid[toCol][toRow]     = newGrid[toCol][toRow].copyWith(itemId: merged.id);
        newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: null);
        _tryUnlockAdjacent(newGrid, toCol, toRow, cfg);

        state = state.copyWith(grid: newGrid);
        _checkWinCondition(newGrid, cfg);
        return;
      }
    } else {
      // ── Swap ─────────────────────────────────────────────────────────────
      newGrid[toCol][toRow]     = newGrid[toCol][toRow].copyWith(itemId: fromCell.itemId);
      newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: toCell.itemId);
    }

    state = state.copyWith(grid: newGrid);
  }

  void _tryUnlockAdjacent(List<List<GridCell>> grid, int col, int row, LevelModel cfg) {
    const dirs = [[-1,0],[1,0],[0,-1],[0,1]];
    for (final d in dirs) {
      final nc = col + d[0], nr = row + d[1];
      if (nc < 0 || nc >= cfg.gridCols || nr < 0 || nr >= cfg.gridRows) continue;
      final cell = grid[nc][nr];
      if (cell.obstacle == ObstacleType.dustyWeb ||
          cell.obstacle == ObstacleType.lockedCrate) {
        grid[nc][nr] = cell.copyWith(obstacle: ObstacleType.none, isLocked: false);
      }
    }
  }

  void _checkWinCondition(List<List<GridCell>> grid, LevelModel cfg) {
    for (final col in grid) {
      for (final cell in col) {
        if (cell.itemId == cfg.targetItemId) {
          _completeLevel(cfg);
          return;
        }
      }
    }
  }

  void _completeLevel(LevelModel cfg) {
    _timer?.cancel();
    state = state.copyWith(
      appPhase: AppPhase.levelComplete,
      levelCompleteCoins: cfg.baseCoins,
      timerActive: false,
    );
  }

  // ── Energy Management ─────────────────────────────────────────────────────

  /// Called inside the rewarded ad onReward callback (Rules 1 & 2).
  void addEnergy(int amount) {
    state = state.copyWith(
      energy: (state.energy + amount).clamp(0, state.maxEnergy),
      showEnergyWarning: false,
    );
  }

  void dismissEnergyWarning() {
    state = state.copyWith(showEnergyWarning: false);
  }

  // ── Coin Multiplier ───────────────────────────────────────────────────────

  /// Called inside the rewarded ad onReward callback (Rule 3).
  void multiplyCoins(int factor) {
    state = state.copyWith(levelCompleteCoins: state.levelCompleteCoins * factor);
  }

  // ── Next Level ────────────────────────────────────────────────────────────

  /// Handles Rule 4: interstitial fires on even levels, then loads next level
  /// ONLY inside the onDismiss callback.
  Future<void> goToNextLevel() async {
    // Collect coins
    state = state.copyWith(
      totalCoins: state.totalCoins + state.levelCompleteCoins,
    );

    final nextIndex = state.currentLevelIndex + 1;
    if (nextIndex >= _levels.length) {
      state = state.copyWith(appPhase: AppPhase.menu);
      return;
    }

    final currentLevel = state.currentLevel;

    // ── Rule 4: fire interstitial on even levels if flag is set ─────────────
    if (currentLevel.triggerInterstitialNext &&
        currentLevel.levelNumber % 2 == 0) {
      // Grid does NOT load until onDismiss fires
      await AdManagerService.instance.showInterstitialAd(
        onDismiss: () => startLevel(nextIndex),
      );
    } else {
      // Odd levels: load immediately
      startLevel(nextIndex);
    }
  }

  // ── Timed Order ───────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.timerSeconds <= 1) {
        _timer?.cancel();
        state = state.copyWith(timerSeconds: 0, timerActive: false, appPhase: AppPhase.gameOver);
      } else {
        state = state.copyWith(timerSeconds: state.timerSeconds - 1);
      }
    });
  }

  // ── Restart Level ─────────────────────────────────────────────────────────

  void restartLevel() => startLevel(state.currentLevelIndex);

  void goToMenu() {
    _timer?.cancel();
    state = state.copyWith(appPhase: AppPhase.menu);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<List<GridCell>> _cloneGrid() {
    return state.grid
        .map((col) => col.map((cell) => cell.copyWith()).toList())
        .toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─── Riverpod Providers ──────────────────────────────────────────────────────

final gameProvider = StateNotifierProvider<GameNotifier, GameState>(
  (ref) => GameNotifier(),
);

// Convenient derived providers — only rebuild widgets that depend on them.

final appPhaseProvider = Provider<AppPhase>(
  (ref) => ref.watch(gameProvider).appPhase,
);

final energyProvider = Provider<int>(
  (ref) => ref.watch(gameProvider).energy,
);

final gridProvider = Provider<List<List<GridCell>>>(
  (ref) => ref.watch(gameProvider).grid,
);

final currentLevelProvider = Provider<LevelModel>(
  (ref) => ref.watch(gameProvider).currentLevel,
);

final showEnergyWarningProvider = Provider<bool>(
  (ref) => ref.watch(gameProvider).showEnergyWarning,
);

```

---

## game_screen.dart

```dart
// ============================================================
// game_screen.dart
// Tech Tycoon Merge — Flutter UI
// Adapts to all 5 grid sizes (4×4, 5×5, 6×5, 6×6)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'level_config.dart';
import 'game_state.dart';
import 'ad_manager.dart';

// ─── Root game view ──────────────────────────────────────────────────────────

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPhase = ref.watch(appPhaseProvider);

    return switch (appPhase) {
      AppPhase.menu         => const _MenuView(),
      AppPhase.playing      => const _PlayingView(),
      AppPhase.levelComplete => const _LevelCompleteOverlay(),
      AppPhase.gameOver     => const _GameOverOverlay(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MENU VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _MenuView extends ConsumerWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameNotifier = ref.read(gameProvider.notifier);
    final totalCoins   = ref.watch(gameProvider).totalCoins;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0A000F), Color(0xFF000510)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text('🖥️', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFCC00FF)],
                ).createShader(r),
                child: const Text('Tech Tycoon Merge',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text('50 Levels · 5 Phases · From Garage to Galaxy',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
              if (totalCoins > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                  ),
                  child: Text('💰 ${totalCoins.toStringAsFixed(0)} coins',
                    style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                ),
              ],
              const Spacer(),
              // Phase quick-start buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _MenuButton('▶  Start Game (Level 1)',
                      color: const Color(0xFF00E5FF),
                      onTap: () => gameNotifier.startLevel(0)),
                    const SizedBox(height: 10),
                    ...['🔌 Phase 1: Garage (L1)', '💻 Phase 2: Office (L11)',
                        '🥽 Phase 3: Silicon (L21)', '🧠 Phase 4: Corp (L31)',
                        '☀️ Phase 5: Universe (L41)']
                      .asMap()
                      .entries
                      .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MenuButton(e.value,
                          color: const Color(0xFF444455),
                          onTap: () => gameNotifier.startLevel(e.key * 10),
                          small: true),
                      )),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool small;

  const _MenuButton(this.label, {required this.color, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: small ? 12 : 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: small ? 13 : 16),
        ),
        child: Text(label),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAYING VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _PlayingView extends ConsumerWidget {
  const _PlayingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state  = ref.watch(gameProvider);
    final cfg    = state.currentLevel;
    final theme  = PhaseThemes.of(cfg.phase);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [theme.background, theme.background.withOpacity(0.6), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _GameHUD(cfg: cfg, theme: theme),
                  Expanded(child: _GameGrid(cfg: cfg, theme: theme)),
                  _Spawner(cfg: cfg, theme: theme),
                ],
              ),
              // Rule 2 — hard energy lockout wall
              if (state.showEnergyWarning)
                _ZeroEnergyWall(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HUD ──────────────────────────────────────────────────────────────────────

class _GameHUD extends ConsumerWidget {
  final LevelModel cfg;
  final PhaseTheme theme;

  const _GameHUD({required this.cfg, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final target = ItemChains.getById(cfg.targetItemId);
    final energyPct = state.energy / state.maxEnergy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          // Top row
          Row(
            children: [
              // Back
              GestureDetector(
                onTap: () => ref.read(gameProvider.notifier).goToMenu(),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white38, size: 18),
              ),
              const SizedBox(width: 8),
              // Level info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level ${cfg.levelNumber}: ${cfg.title}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(cfg.story, style: const TextStyle(color: Colors.white38, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Timer (Phase 4 timed orders)
              if (state.timerActive)
                _TimerBadge(seconds: state.timerSeconds),
              const SizedBox(width: 8),
              // Coins
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('COINS', style: TextStyle(color: Colors.white38, fontSize: 9)),
                Text('💰 ${state.totalCoins}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 16)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          // Target
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Text('Target: ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                Text(target?.emoji ?? '?', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(target?.name ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                Text('+${cfg.baseCoins} 💰',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Energy bar
          Row(
            children: [
              Text('⚡${state.energy}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: energyPct,
                    minHeight: 10,
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
              Text('${state.maxEnergy}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          // Rule 1 — low energy ad button
          if (ref.watch(gameProvider).shouldShowLowEnergyButton) ...[
            const SizedBox(height: 8),
            _LowEnergyAdButton(theme: theme),
          ],
        ],
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final int seconds;
  const _TimerBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final urgent = seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: urgent ? Colors.red.withOpacity(0.3) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: urgent ? Colors.red : Colors.white24),
      ),
      child: Text(
        '${(seconds ~/ 60).toString().padLeft(1, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
        style: TextStyle(
          color: urgent ? Colors.red : Colors.white,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          fontSize: 16,
        ),
      ),
    );
  }
}

// ── Rule 1: Low Energy Ad Button ─────────────────────────────────────────────

class _LowEnergyAdButton extends ConsumerWidget {
  final PhaseTheme theme;
  const _LowEnergyAdButton({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await AdManagerService.instance.showRewardedAd(
          // onReward fires ONLY after full ad completion
          onReward: () => ref.read(gameProvider.notifier).addEnergy(50),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFFFFD700), Colors.orange]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 12)],
        ),
        child: const Center(
          child: Text('⚡ Low Energy! Watch Ad for +50 ⚡',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ),
    );
  }
}

// ── Rule 2: Zero Energy Hard Lockout Popup ────────────────────────────────────

class _ZeroEnergyWall extends ConsumerWidget {
  final PhaseTheme theme;
  const _ZeroEnergyWall({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF2A0000), Color(0xFF0A0010)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AdUnit ID badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Text(
                  'REWARDED AD · ${TechTycoonLevels.rewardedAdUnitId}',
                  style: const TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              const Text('⚡', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 10),
              const Text('Energy Depleted!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('You cannot spawn items.\nWatch a Video to recharge.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 20),
              // Watch ad button — onReward callback adds energy
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    ref.read(gameProvider.notifier).dismissEnergyWarning();
                    await AdManagerService.instance.showRewardedAd(
                      onReward: () => ref.read(gameProvider.notifier).addEnergy(50),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  child: const Text('📺 Watch Video to Recharge +50 ⚡'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => ref.read(gameProvider.notifier).dismissEnergyWarning(),
                child: const Text('Dismiss', style: TextStyle(color: Colors.white30)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game Grid ─────────────────────────────────────────────────────────────────

class _GameGrid extends ConsumerStatefulWidget {
  final LevelModel cfg;
  final PhaseTheme theme;
  const _GameGrid({required this.cfg, required this.theme});

  @override
  ConsumerState<_GameGrid> createState() => _GameGridState();
}

class _GameGridState extends ConsumerState<_GameGrid> {
  int? _dragFromCol;
  int? _dragFromRow;

  @override
  Widget build(BuildContext context) {
    final grid = ref.watch(gridProvider);
    if (grid.isEmpty) return const SizedBox.shrink();

    final cfg = widget.cfg;
    final theme = widget.theme;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cellW = (constraints.maxWidth  - (cfg.gridCols - 1) * 6) / cfg.gridCols;
          final cellH = (constraints.maxHeight - (cfg.gridRows - 1) * 6) / cfg.gridRows;
          final cellSize = cellW < cellH ? cellW : cellH;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cfg.gridRows, (r) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(cfg.gridCols, (c) {
                    return Padding(
                      padding: const EdgeInsets.all(3),
                      child: _GridCellWidget(
                        cell: grid[c][r],
                        col: c, row: r,
                        size: cellSize,
                        theme: theme,
                        isDragSource: _dragFromCol == c && _dragFromRow == r,
                        isDragging: _dragFromCol != null,
                        onDragStart: () => setState(() {
                          _dragFromCol = c;
                          _dragFromRow = r;
                        }),
                        onDrop: () {
                          if (_dragFromCol != null && _dragFromRow != null) {
                            ref.read(gameProvider.notifier)
                                .moveItem(_dragFromCol!, _dragFromRow!, c, r);
                          }
                          setState(() { _dragFromCol = null; _dragFromRow = null; });
                        },
                        onTap: () {
                          if (_dragFromCol != null) {
                            ref.read(gameProvider.notifier)
                                .moveItem(_dragFromCol!, _dragFromRow!, c, r);
                            setState(() { _dragFromCol = null; _dragFromRow = null; });
                          } else {
                            ref.read(gameProvider.notifier).spawnItem(c, r);
                          }
                        },
                      ),
                    );
                  }),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _GridCellWidget extends StatelessWidget {
  final GridCell cell;
  final int col, row;
  final double size;
  final PhaseTheme theme;
  final bool isDragSource;
  final bool isDragging;
  final VoidCallback onDragStart;
  final VoidCallback onDrop;
  final VoidCallback onTap;

  const _GridCellWidget({
    required this.cell, required this.col, required this.row,
    required this.size, required this.theme,
    required this.isDragSource, required this.isDragging,
    required this.onDragStart, required this.onDrop, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = cell.itemId != null ? ItemChains.getById(cell.itemId!) : null;
    final isBlackHole = cell.obstacle == ObstacleType.blackHole;

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: item != null ? (_) => onDragStart() : null,
      onLongPressEnd: item != null ? (_) => onDrop() : null,
      child: DragTarget<String>(
        onAcceptWithDetails: (_) => onDrop(),
        builder: (ctx, candidateData, __) {
          return Draggable<String>(
            data: '${col}_$row',
            feedback: _CellFeedback(item: item, size: size),
            childWhenDragging: _CellBody(
              item: null, cell: cell, theme: theme, size: size,
              isDragSource: true, isDragging: false, isCandidate: false, isBlackHole: isBlackHole,
            ),
            onDragStarted: onDragStart,
            onDragEnd: (_) {},
            child: _CellBody(
              item: item, cell: cell, theme: theme, size: size,
              isDragSource: isDragSource,
              isDragging: isDragging && !isDragSource,
              isCandidate: candidateData.isNotEmpty,
              isBlackHole: isBlackHole,
            ),
          );
        },
      ),
    );
  }
}

class _CellBody extends StatelessWidget {
  final ItemDef? item;
  final GridCell cell;
  final PhaseTheme theme;
  final double size;
  final bool isDragSource, isDragging, isCandidate, isBlackHole;

  const _CellBody({
    required this.item, required this.cell, required this.theme,
    required this.size, required this.isDragSource, required this.isDragging,
    required this.isCandidate, required this.isBlackHole,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;

    if (isBlackHole) {
      bg = Colors.black;
      border = Colors.purple.withOpacity(0.5);
    } else if (cell.isLocked) {
      bg = Colors.black26;
      border = Colors.white10;
    } else if (isCandidate) {
      bg = theme.primaryColor.withOpacity(0.3);
      border = theme.primaryColor;
    } else if (isDragSource) {
      bg = Colors.white.withOpacity(0.2);
      border = const Color(0xFFFFD700);
    } else if (item != null) {
      bg = Colors.white.withOpacity(0.1);
      border = Colors.white24;
    } else {
      bg = Colors.white.withOpacity(0.04);
      border = Colors.white10;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: isCandidate ? 2 : 1),
        boxShadow: isDragSource
          ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 10)]
          : null,
      ),
      child: Center(
        child: isBlackHole
          ? Text('🕳️', style: TextStyle(fontSize: size * 0.42))
          : cell.isLocked
            ? _ObstacleIcon(type: cell.obstacle, size: size)
            : item != null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(item!.emoji, style: TextStyle(fontSize: size * 0.4)),
                  const SizedBox(height: 2),
                  Text(item!.name,
                    style: TextStyle(color: Colors.white70, fontSize: size * 0.11,
                        fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                ])
              : null,
      ),
    );
  }
}

class _CellFeedback extends StatelessWidget {
  final ItemDef? item;
  final double size;
  const _CellFeedback({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.white30, blurRadius: 16)],
        ),
        child: Center(
          child: Text(item?.emoji ?? '?', style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }
}

class _ObstacleIcon extends StatelessWidget {
  final ObstacleType type;
  final double size;
  const _ObstacleIcon({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    final emoji = switch (type) {
      ObstacleType.dustyWeb    => '🕸️',
      ObstacleType.lockedCrate => '📦',
      ObstacleType.timedOrder  => '⏱️',
      ObstacleType.blackHole   => '🕳️',
      ObstacleType.none        => '',
    };
    return Text(emoji, style: TextStyle(fontSize: size * 0.4));
  }
}

// ── Spawner ───────────────────────────────────────────────────────────────────

class _Spawner extends ConsumerWidget {
  final LevelModel cfg;
  final PhaseTheme theme;
  const _Spawner({required this.cfg, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(gameProvider);
    final baseItem = ItemChains.chainForPhase(cfg.phase).first;
    final canSpawn = state.energy > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('SPAWNER', style: TextStyle(color: Colors.white24, fontSize: 9,
              letterSpacing: 3)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              // Find first empty cell and spawn there
              final grid = ref.read(gridProvider);
              for (int c = 0; c < cfg.gridCols; c++) {
                for (int r = 0; r < cfg.gridRows; r++) {
                  if (grid[c][r].isEmpty) {
                    ref.read(gameProvider.notifier).spawnItem(c, r);
                    return;
                  }
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: canSpawn
                  ? LinearGradient(colors: [theme.primaryColor.withOpacity(0.4), theme.accentColor.withOpacity(0.2)])
                  : null,
                color: canSpawn ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: canSpawn ? theme.primaryColor : Colors.white12,
                  width: canSpawn ? 2 : 1,
                ),
                boxShadow: canSpawn
                  ? [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 14)]
                  : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(baseItem.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Spawn ${baseItem.name}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    Text('-${cfg.energyCostPerSpawn}${cfg.fasterEnergyDrain ? " ⚡ (fast drain)" : " ⚡"}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                  const SizedBox(width: 14),
                  Text('⚡${state.energy}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LEVEL COMPLETE OVERLAY (Rules 3 & 4)
// ═══════════════════════════════════════════════════════════════════════════

class _LevelCompleteOverlay extends ConsumerStatefulWidget {
  const _LevelCompleteOverlay();

  @override
  ConsumerState<_LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends ConsumerState<_LevelCompleteOverlay> {
  bool _adWatched = false;
  bool _awaitingInterstitial = false;

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(gameProvider);
    final cfg    = state.currentLevel;
    final theme  = PhaseThemes.of(cfg.phase);
    final target = ItemChains.getById(cfg.targetItemId);
    final isLast = state.currentLevelIndex == TechTycoonLevels.get50Levels().length - 1;

    // Rule 4: interstitial only fires on even levels
    final willShowInterstitial = cfg.triggerInterstitialNext && cfg.levelNumber % 2 == 0;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [theme.primaryColor.withOpacity(0.15), Colors.black],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text('Level ${cfg.levelNumber} Complete!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                const SizedBox(height: 6),
                Text(cfg.story, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 20),
                // Target item
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(target?.emoji ?? '?', style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(target?.name ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text('Built!', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 20),
                // Coin display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(children: [
                    const Text('Coins Earned', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('💰 ${state.levelCompleteCoins}',
                      style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 38)),
                    if (_adWatched)
                      const Text('✓ 3× MULTIPLIER APPLIED!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Rule 3 — 3× ad button (only if allowScoreMultiplier is true)
                if (cfg.allowScoreMultiplier && !_adWatched) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final shown = await AdManagerService.instance.showRewardedAd(
                          // onReward fires ONLY after full ad completion
                          onReward: () {
                            ref.read(gameProvider.notifier).multiplyCoins(3);
                            setState(() => _adWatched = true);
                          },
                        );
                        if (!shown) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ad not ready. Try again shortly.')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      child: const Text('📺 Watch Ad to get 3× Coins!'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Rule 4 — Next Level button (fires interstitial on even levels)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _awaitingInterstitial ? null : () async {
                      setState(() => _awaitingInterstitial = true);
                      // goToNextLevel() handles Rule 4 internally:
                      //   - even levels: showInterstitialAd → startLevel in onDismiss
                      //   - odd levels: startLevel immediately
                      await ref.read(gameProvider.notifier).goToNextLevel();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    child: Text(
                      _awaitingInterstitial ? '⏳ Loading ad…'
                        : isLast ? '🎉 Back to Menu'
                        : willShowInterstitial ? 'Next Level → (Ad)'
                        : 'Next Level →',
                    ),
                  ),
                ),
                if (willShowInterstitial && !_awaitingInterstitial) ...[
                  const SizedBox(height: 4),
                  Text('Interstitial · ${TechTycoonLevels.interstitialAdUnitId}',
                    style: const TextStyle(color: Colors.white12, fontSize: 8)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GAME OVER OVERLAY (Timed Order expired)
// ═══════════════════════════════════════════════════════════════════════════

class _GameOverOverlay extends ConsumerWidget {
  const _GameOverOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(currentLevelProvider);

    return Scaffold(
      backgroundColor: Colors.black90,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A0000), Color(0xFF0A000A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 10),
              const Text("Time's Up!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
              const SizedBox(height: 8),
              Text('Level ${cfg.levelNumber}: ${cfg.title}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              // Watch ad to retry
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await AdManagerService.instance.showRewardedAd(
                      onReward: () {
                        ref.read(gameProvider.notifier).addEnergy(50);
                        ref.read(gameProvider.notifier).restartLevel();
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  child: const Text('📺 Watch Ad to Retry'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ref.read(gameProvider.notifier).restartLevel(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Restart Level'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => ref.read(gameProvider.notifier).goToMenu(),
                child: const Text('Main Menu', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

```

---

## main.dart

```dart
// ============================================================
// main.dart
// Tech Tycoon Merge — App Entry Point
//
// ════════════════════════════════════════════════════════════
// SETUP INSTRUCTIONS
// ════════════════════════════════════════════════════════════
//
// 1. pubspec.yaml — add these dependencies:
//
//    dependencies:
//      flutter:
//        sdk: flutter
//      flutter_riverpod: ^2.5.1
//      google_mobile_ads: ^5.1.0
//
// 2. android/app/src/main/AndroidManifest.xml
//    Inside the <manifest> tag, ensure INTERNET permission:
//      <uses-permission android:name="android.permission.INTERNET"/>
//
//    Inside the <application> tag, add the AdMob App ID:
//      <meta-data
//        android:name="com.google.android.gms.ads.APPLICATION_ID"
//        android:value="ca-app-pub-8566652140087308~1114269136"/>
//
// 3. ios/Runner/Info.plist — inside the root <dict>:
//      <key>GADApplicationIdentifier</key>
//      <string>ca-app-pub-8566652140087308~1114269136</string>
//      <key>SKAdNetworkItems</key>
//      <array>
//        <dict>
//          <key>SKAdNetworkIdentifier</key>
//          <string>cstr6suwn9.skadnetwork</string>
//        </dict>
//      </array>
//
// 4. android/app/build.gradle — ensure minSdkVersion >= 21:
//      defaultConfig {
//        minSdkVersion 21
//      }
//
// 5. Run: flutter pub get
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_manager.dart';
import 'game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for the merge grid
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set immersive full-screen mode
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialise AdMob SDK and pre-load ads
  await AdManagerService.instance.initialize();

  runApp(
    // ProviderScope is the Riverpod root — must wrap the entire app
    const ProviderScope(
      child: TechTycoonMergeApp(),
    ),
  );
}

class TechTycoonMergeApp extends StatelessWidget {
  const TechTycoonMergeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tech Tycoon Merge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

```

---

