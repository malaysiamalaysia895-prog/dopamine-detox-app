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
