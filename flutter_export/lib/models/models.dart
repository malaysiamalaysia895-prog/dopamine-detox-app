// ============================================================
// models.dart — Items, Levels, Grid State, Obstacles
// Tech Tycoon Merge
// ============================================================

import 'dart:math';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum GamePhase { garage, office, silicon, megacorp, universe }

enum ObstacleType { none, dustyWeb, lockedCrate, blackHole }

enum AppScreen { map, game }

// ─── Item Definition ──────────────────────────────────────────────────────────
// Items are numbered 1–51. Item N + Item N = Item N+1.

class ItemDef {
  final int id;        // 1-based
  final String name;
  final String emoji;
  final GamePhase phase; // which phase this item belongs to

  const ItemDef({required this.id, required this.name, required this.emoji, required this.phase});
}

class ItemDictionary {
  static const List<ItemDef> all = [
    ItemDef(id:  1, name: 'Copper Wire',         emoji: '🔌', phase: GamePhase.garage),
    ItemDef(id:  2, name: 'USB Cable',            emoji: '🪢', phase: GamePhase.garage),
    ItemDef(id:  3, name: 'Retro Mouse',          emoji: '🖱️', phase: GamePhase.garage),
    ItemDef(id:  4, name: 'Mech. Keyboard',       emoji: '⌨️', phase: GamePhase.garage),
    ItemDef(id:  5, name: 'CRT Monitor',          emoji: '🖥️', phase: GamePhase.garage),
    ItemDef(id:  6, name: 'Basic Motherboard',    emoji: '🔧', phase: GamePhase.garage),
    ItemDef(id:  7, name: '4GB RAM Stick',        emoji: '💾', phase: GamePhase.garage),
    ItemDef(id:  8, name: 'Dual-Core CPU',        emoji: '⚙️', phase: GamePhase.garage),
    ItemDef(id:  9, name: 'CPU Cooler',           emoji: '❄️', phase: GamePhase.garage),
    ItemDef(id: 10, name: 'Power Supply (PSU)',   emoji: '🔋', phase: GamePhase.garage),
    ItemDef(id: 11, name: 'Basic Desktop PC',     emoji: '💻', phase: GamePhase.garage),
    ItemDef(id: 12, name: 'Basic Laptop',         emoji: '🖥️', phase: GamePhase.garage),
    // Phase 2 additions
    ItemDef(id: 13, name: 'Graphics Card',        emoji: '🎮', phase: GamePhase.office),
    ItemDef(id: 14, name: 'Pro Monitor',          emoji: '🖥️', phase: GamePhase.office),
    ItemDef(id: 15, name: 'Studio Mic',           emoji: '🎙️', phase: GamePhase.office),
    ItemDef(id: 16, name: '1TB SSD',              emoji: '💿', phase: GamePhase.office),
    ItemDef(id: 17, name: 'Mini Home Server',     emoji: '🗄️', phase: GamePhase.office),
    ItemDef(id: 18, name: 'Smart Speaker',        emoji: '📻', phase: GamePhase.office),
    ItemDef(id: 19, name: 'Hardware Firewall',    emoji: '🛡️', phase: GamePhase.office),
    ItemDef(id: 20, name: 'Heavy Powerbank',      emoji: '🔋', phase: GamePhase.office),
    ItemDef(id: 21, name: 'RGB Gaming PC',        emoji: '🎯', phase: GamePhase.office),
    ItemDef(id: 22, name: 'VR Headset',           emoji: '🥽', phase: GamePhase.office),
    // Phase 3 additions
    ItemDef(id: 23, name: '4K Drone',             emoji: '🚁', phase: GamePhase.silicon),
    ItemDef(id: 24, name: 'Holo. Smartwatch',     emoji: '⌚', phase: GamePhase.silicon),
    ItemDef(id: 25, name: 'Crypto Mining Rig',    emoji: '⛏️', phase: GamePhase.silicon),
    ItemDef(id: 26, name: 'Industrial 3D Printer',emoji: '🏭', phase: GamePhase.silicon),
    ItemDef(id: 27, name: 'Cloud Server Rack',    emoji: '☁️', phase: GamePhase.silicon),
    ItemDef(id: 28, name: 'Auto-Pilot Chip',      emoji: '🚗', phase: GamePhase.silicon),
    ItemDef(id: 29, name: 'Bionic Arm',           emoji: '🦾', phase: GamePhase.silicon),
    ItemDef(id: 30, name: 'Cyber-Dog',            emoji: '🤖', phase: GamePhase.silicon),
    ItemDef(id: 31, name: 'Massive Data Center',  emoji: '🏢', phase: GamePhase.silicon),
    ItemDef(id: 32, name: 'Hologram Projector',   emoji: '📽️', phase: GamePhase.silicon),
    // Phase 4 additions
    ItemDef(id: 33, name: 'Neural Headset',       emoji: '🧠', phase: GamePhase.megacorp),
    ItemDef(id: 34, name: 'Quantum CPU',          emoji: '⚛️', phase: GamePhase.megacorp),
    ItemDef(id: 35, name: 'Plasma Shield',        emoji: '🛡️', phase: GamePhase.megacorp),
    ItemDef(id: 36, name: 'Nanobots',             emoji: '🔬', phase: GamePhase.megacorp),
    ItemDef(id: 37, name: 'Laser Dish',           emoji: '📡', phase: GamePhase.megacorp),
    ItemDef(id: 38, name: 'Hoverboard',           emoji: '🛹', phase: GamePhase.megacorp),
    ItemDef(id: 39, name: 'Power Exosuit',        emoji: '🦾', phase: GamePhase.megacorp),
    ItemDef(id: 40, name: 'Sentient AI Core',     emoji: '🤖', phase: GamePhase.megacorp),
    ItemDef(id: 41, name: 'Space Station',        emoji: '🛸', phase: GamePhase.megacorp),
    ItemDef(id: 42, name: 'Warp Engine',          emoji: '🚀', phase: GamePhase.megacorp),
    // Phase 5 additions
    ItemDef(id: 43, name: 'Atmosphere Generator', emoji: '🌿', phase: GamePhase.universe),
    ItemDef(id: 44, name: 'Dark Matter Reactor',  emoji: '⚛️', phase: GamePhase.universe),
    ItemDef(id: 45, name: 'Telepad',              emoji: '🔵', phase: GamePhase.universe),
    ItemDef(id: 46, name: 'Chrono-Device',        emoji: '⏱️', phase: GamePhase.universe),
    ItemDef(id: 47, name: 'Star Forge',           emoji: '⭐', phase: GamePhase.universe),
    ItemDef(id: 48, name: 'Soul-Drive',           emoji: '💎', phase: GamePhase.universe),
    ItemDef(id: 49, name: 'Galactic Router',      emoji: '🌐', phase: GamePhase.universe),
    ItemDef(id: 50, name: 'Dimensional Rift',     emoji: '🌀', phase: GamePhase.universe),
    ItemDef(id: 51, name: 'The Dyson Sphere',     emoji: '☀️', phase: GamePhase.universe),
  ];

  static ItemDef? getById(int id) {
    if (id < 1 || id > all.length) return null;
    return all[id - 1];
  }

  static ItemDef? nextItem(int currentId) {
    if (currentId >= all.length) return null;
    return all[currentId]; // id is 1-based, index = id-1, nextIndex = id
  }
}

// ─── Quota Item ───────────────────────────────────────────────────────────────

class QuotaItem {
  final int itemId; // 1-based
  final int count;
  const QuotaItem(this.itemId, this.count);
}

// ─── Obstacle Placement ───────────────────────────────────────────────────────

class ObstaclePlacement {
  final int col;
  final int row;
  final ObstacleType type;
  const ObstaclePlacement(this.col, this.row, this.type);
}

// ─── Level Definition ─────────────────────────────────────────────────────────

class LevelDefinition {
  final int number;          // 1-50
  final String title;
  final String story;
  final int gridCols;
  final int gridRows;
  final GamePhase phase;
  final List<QuotaItem> quota;
  final int timeLimitSeconds; // 0 = no timer
  final int blackHoleCount;   // random placement
  final int dustyWebCount;
  final int lockedCrateCount;
  final bool allowGridRescue;  // Phase 3+
  final bool allowTimeExtension; // Phase 4+

  const LevelDefinition({
    required this.number,
    required this.title,
    required this.story,
    required this.gridCols,
    required this.gridRows,
    required this.phase,
    required this.quota,
    this.timeLimitSeconds = 0,
    this.blackHoleCount = 0,
    this.dustyWebCount = 0,
    this.lockedCrateCount = 0,
    this.allowGridRescue = false,
    this.allowTimeExtension = false,
  });

  int get totalCells => gridCols * gridRows;
  int get baseCoins => number * 100;
  bool get hasTimer => timeLimitSeconds > 0;

  /// The tier of item the spawner drops for this level.
  /// = max(1, lowestQuotaItemId - 3)
  /// This keeps the merge chain to ~3 steps, which is viable on any grid size.
  int get spawnerItemId {
    if (quota.isEmpty) return 1;
    final lowestQuota = quota.map((q) => q.itemId).reduce(min);
    return max(1, lowestQuota - 3);
  }

  Map<int, int> get quotaMap {
    final m = <int, int>{};
    for (final q in quota) {
      m[q.itemId] = (m[q.itemId] ?? 0) + q.count;
    }
    return m;
  }
}

// ─── All 50 Level Definitions ─────────────────────────────────────────────────

const List<LevelDefinition> kLevels = [

  // ══════════════════════════════════════════════════════════════════
  // PHASE 1: THE DUSTY GARAGE — Grid 4×4 — Rusty Orange
  // ══════════════════════════════════════════════════════════════════
  LevelDefinition(
    number: 1, title: 'The Spark', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'Welcome to the garage, rookie! Let\'s make some basic connections. '
           'Tap the Spawner to get Wires, and drag them together.',
    quota: [QuotaItem(2, 4), QuotaItem(3, 2)], // 4x USB Cable + 2x Retro Mouse
  ),
  LevelDefinition(
    number: 2, title: 'Scraping By', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'Good job. But we can\'t code with just cables. '
           'We need input devices to test our junk.',
    quota: [QuotaItem(3, 3), QuotaItem(4, 2)], // 3x Mouse + 2x Keyboard
  ),
  LevelDefinition(
    number: 3, title: 'Click & Clack', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'Typing on bare wires hurts. Let\'s build a proper mechanical keyboard and get a screen!',
    quota: [QuotaItem(4, 4), QuotaItem(5, 2)], // 4x Keyboard + 2x CRT Monitor
  ),
  LevelDefinition(
    number: 4, title: 'Hello World', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'We need to actually see what we are doing. Power up the monitors and start building the brains.',
    quota: [QuotaItem(5, 3), QuotaItem(6, 2)], // 3x Monitor + 2x Motherboard
  ),
  LevelDefinition(
    number: 5, title: 'The Brains', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'Time to process real data. Build the motherboards and get some memory sticks.',
    quota: [QuotaItem(6, 4), QuotaItem(7, 2)], // 4x Motherboard + 2x RAM
  ),
  LevelDefinition(
    number: 6, title: 'Memory Lane', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'Your PC keeps crashing! Add more memory. Watch out, the garage is getting messy!',
    quota: [QuotaItem(7, 4), QuotaItem(8, 2)], // 4x RAM + 2x CPU
    dustyWebCount: 2,
  ),
  LevelDefinition(
    number: 7, title: 'Speed It Up', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'We need a faster processor for basic tasks. Keep merging!',
    quota: [QuotaItem(8, 5), QuotaItem(9, 2)], // 5x CPU + 2x Cooler
  ),
  LevelDefinition(
    number: 8, title: 'Cooling Down', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'Things are getting hot in this garage! Add a fan before it melts.',
    quota: [QuotaItem(9, 4), QuotaItem(10, 3)], // 4x Cooler + 3x PSU
  ),
  LevelDefinition(
    number: 9, title: 'Power Up', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'We need more juice! Build power supplies. Space is extremely tight, plan your merges!',
    quota: [QuotaItem(10, 6), QuotaItem(11, 2)], // 6x PSU + 2x Desktop
  ),
  LevelDefinition(
    number: 10, title: 'The First PC', phase: GamePhase.garage,
    gridCols: 4, gridRows: 4,
    story: 'You did it! Your first fully working Desktop PC. '
           'Let\'s finish this order and move to a real office!',
    quota: [QuotaItem(11, 5), QuotaItem(12, 1)], // 5x Desktop + 1x Laptop
  ),

  // ══════════════════════════════════════════════════════════════════
  // PHASE 2: THE OFFICE UPGRADE — Grid 4×5 — Corporate Blue
  // ══════════════════════════════════════════════════════════════════
  LevelDefinition(
    number: 11, title: 'Going Mobile', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Welcome to your new office! Customers want portability now. Let\'s build laptops.',
    quota: [QuotaItem(12, 4), QuotaItem(13, 2)],
  ),
  LevelDefinition(
    number: 12, title: 'Gaming Vibes', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Gamers pay well. Give them high-end graphics cards!',
    quota: [QuotaItem(13, 3), QuotaItem(14, 3)],
  ),
  LevelDefinition(
    number: 13, title: 'The Setup', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Streamers need a dual-monitor setup. Space is expanding, but so are the requirements.',
    quota: [QuotaItem(14, 5), QuotaItem(15, 2)],
  ),
  LevelDefinition(
    number: 14, title: 'Sound Check', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Audio is key for our new clients. Build those studio microphones!',
    quota: [QuotaItem(15, 4), QuotaItem(16, 3)],
  ),
  LevelDefinition(
    number: 15, title: 'Storage Wars', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'We need to save massive data. Wait, who left these locked crates here?',
    quota: [QuotaItem(16, 3), QuotaItem(17, 4)],
    lockedCrateCount: 3,
  ),
  LevelDefinition(
    number: 16, title: 'The Server', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Let\'s host our own websites. Build home servers and smart speakers.',
    quota: [QuotaItem(17, 5), QuotaItem(18, 2)],
    lockedCrateCount: 2,
  ),
  LevelDefinition(
    number: 17, title: 'Smart Home', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Automate the office lights! Build the smart speakers, but watch your energy levels.',
    quota: [QuotaItem(18, 4), QuotaItem(19, 3)],
  ),
  LevelDefinition(
    number: 18, title: 'Security', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Hackers are trying to breach our systems! Protect the office with hardware firewalls.',
    quota: [QuotaItem(19, 3), QuotaItem(20, 4)],
  ),
  LevelDefinition(
    number: 19, title: 'Portable Power', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'Working on the go needs massive batteries. This order is huge, manage your grid space!',
    quota: [QuotaItem(20, 6), QuotaItem(21, 2)],
  ),
  LevelDefinition(
    number: 20, title: 'The Gaming Rig', phase: GamePhase.office,
    gridCols: 4, gridRows: 5,
    story: 'A masterpiece of RGB and raw power! Fulfill this ultimate gaming order '
           'to become a Silicon Valley CEO!',
    quota: [QuotaItem(21, 4), QuotaItem(22, 2)],
    lockedCrateCount: 4,
  ),

  // ══════════════════════════════════════════════════════════════════
  // PHASE 3: SILICON VALLEY TYCOON — Grid 5×5 — Neon Cyberpunk
  // ══════════════════════════════════════════════════════════════════
  LevelDefinition(
    number: 21, title: 'Virtual Reality', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Let\'s step into the Metaverse. Build high-end VR gear!',
    quota: [QuotaItem(22, 5), QuotaItem(23, 3)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 22, title: 'Flying High', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'We need aerial footage for the new promo. Mass produce drones!',
    quota: [QuotaItem(23, 4), QuotaItem(24, 4)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 23, title: 'Wearables', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Tech on your wrist. Holographic smartwatches are the new trend.',
    quota: [QuotaItem(24, 6), QuotaItem(25, 2)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 24, title: 'Crypto Mining', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Time to mine some digital gold. Build extreme crypto rigs!',
    quota: [QuotaItem(25, 5), QuotaItem(26, 3)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 25, title: '3D Printing', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Why buy parts when you can print them? Space is getting extremely tight here!',
    quota: [QuotaItem(26, 4), QuotaItem(27, 4)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 26, title: 'Cloud Storage', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Move everything to the cloud. We need massive server racks.',
    quota: [QuotaItem(27, 6), QuotaItem(28, 2)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 27, title: 'Self-Driving', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Cars need brains too. Develop the new Auto-Pilot Chips.',
    quota: [QuotaItem(28, 5), QuotaItem(29, 3)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 28, title: 'Bionic Tech', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Upgrading the human body. Deliver these Bionic Arms immediately.',
    quota: [QuotaItem(29, 4), QuotaItem(30, 4)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 29, title: 'Robotics', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'Meet your new robotic assistant. Cyber-Dogs are ready for deployment.',
    quota: [QuotaItem(30, 6), QuotaItem(31, 2)],
    allowGridRescue: true,
  ),
  LevelDefinition(
    number: 30, title: 'The Data Center', phase: GamePhase.silicon,
    gridCols: 5, gridRows: 5,
    story: 'You now control 10% of the internet! Build the Massive Data Center to secure your monopoly!',
    quota: [QuotaItem(31, 5), QuotaItem(32, 3)],
    allowGridRescue: true,
  ),

  // ══════════════════════════════════════════════════════════════════
  // PHASE 4: GLOBAL MEGA-CORP — Grid 6×5 — Matrix Green, Timed Orders
  // ══════════════════════════════════════════════════════════════════
  LevelDefinition(
    number: 31, title: 'Holograms', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Screens are dead. Project it in the air. Timed Orders begin now. Work fast!',
    quota: [QuotaItem(32, 6), QuotaItem(33, 4)],
    timeLimitSeconds: 180, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 32, title: 'Neural Link', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Control computers with your mind. Mass produce the Neural Headsets.',
    quota: [QuotaItem(33, 5), QuotaItem(34, 5)],
    timeLimitSeconds: 210, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 33, title: 'Quantum Chip', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Computing at the atomic level. The world relies on us now.',
    quota: [QuotaItem(34, 7), QuotaItem(35, 3)],
    timeLimitSeconds: 240, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 34, title: 'Energy Shield', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Protecting cities from impact. Assemble the Plasma Shields.',
    quota: [QuotaItem(35, 6), QuotaItem(36, 4)],
    timeLimitSeconds: 270, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 35, title: 'Nanobots', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Microscopic robots fixing errors. Space is massive, but the demands are higher.',
    quota: [QuotaItem(36, 5), QuotaItem(37, 5)],
    timeLimitSeconds: 300, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 36, title: 'Laser Comms', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Communicating at the speed of light. Launch those satellites!',
    quota: [QuotaItem(37, 8), QuotaItem(38, 2)],
    timeLimitSeconds: 300, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 37, title: 'Anti-Gravity', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Who needs wheels? The hoverboard era is here.',
    quota: [QuotaItem(38, 6), QuotaItem(39, 4)],
    timeLimitSeconds: 330, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 38, title: 'Exosuit', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Superhuman strength for workers. Construct the Power Exosuits.',
    quota: [QuotaItem(39, 5), QuotaItem(40, 5)],
    timeLimitSeconds: 360, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 39, title: 'AI Core', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'It is awake. It is thinking. Keep merging to feed the Sentient AI.',
    quota: [QuotaItem(40, 7), QuotaItem(41, 3)],
    timeLimitSeconds: 390, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 40, title: 'The Orbital Station', phase: GamePhase.megacorp,
    gridCols: 6, gridRows: 5,
    story: 'Earth is too small for us now. Finish the Low-Orbit Space Station to reach the stars!',
    quota: [QuotaItem(41, 6), QuotaItem(42, 4)],
    timeLimitSeconds: 480, allowGridRescue: true, allowTimeExtension: true,
  ),

  // ══════════════════════════════════════════════════════════════════
  // PHASE 5: MASTERS OF THE UNIVERSE — Grid 6×6 — Gold/Cosmos + Black Holes
  // ══════════════════════════════════════════════════════════════════
  LevelDefinition(
    number: 41, title: 'Warp Drive', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Traveling faster than light. Avoid the Black Holes!',
    quota: [QuotaItem(42, 7), QuotaItem(43, 5)],
    timeLimitSeconds: 360, blackHoleCount: 2, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 42, title: 'Terraforming', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Making Mars green. The universe bends to your will.',
    quota: [QuotaItem(43, 6), QuotaItem(44, 6)],
    timeLimitSeconds: 390, blackHoleCount: 3, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 43, title: 'Dark Matter', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Harnessing the unseen universe. Build Dark Matter Reactors.',
    quota: [QuotaItem(44, 8), QuotaItem(45, 4)],
    timeLimitSeconds: 420, blackHoleCount: 3, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 44, title: 'Teleportation', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'From here to there, instantly. Telepads are online. Space is extremely tight!',
    quota: [QuotaItem(45, 7), QuotaItem(46, 5)],
    timeLimitSeconds: 450, blackHoleCount: 4, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 45, title: 'Time Dilation', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Slowing down time itself. Construct the Chrono-Devices.',
    quota: [QuotaItem(46, 6), QuotaItem(47, 6)],
    timeLimitSeconds: 480, blackHoleCount: 4, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 46, title: 'Star Forge', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Creating elements from pure energy. The Star Forges are burning bright.',
    quota: [QuotaItem(47, 9), QuotaItem(48, 3)],
    timeLimitSeconds: 510, blackHoleCount: 5, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 47, title: 'Mind Upload', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Immortality in the digital realm. The Soul-Drives are initializing.',
    quota: [QuotaItem(48, 7), QuotaItem(49, 5)],
    timeLimitSeconds: 540, blackHoleCount: 5, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 48, title: 'Galaxy Net', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Connecting billions of planets. Galactic Routers online.',
    quota: [QuotaItem(49, 6), QuotaItem(50, 6)],
    timeLimitSeconds: 570, blackHoleCount: 6, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 49, title: 'The Multiverse', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'Peeking into parallel worlds. Rip open the Dimensional Rifts!',
    quota: [QuotaItem(50, 8), QuotaItem(51, 4)],
    timeLimitSeconds: 600, blackHoleCount: 6, allowGridRescue: true, allowTimeExtension: true,
  ),
  LevelDefinition(
    number: 50, title: 'The Dyson Sphere', phase: GamePhase.universe,
    gridCols: 6, gridRows: 6,
    story: 'You have captured a star. You are a Tech God. '
           'Build the ultimate Dyson Spheres to beat the game!',
    quota: [QuotaItem(51, 10)],
    timeLimitSeconds: 900, blackHoleCount: 7, allowGridRescue: true, allowTimeExtension: true,
  ),
];

// ─── Grid Cell Model ─────────────────────────────────────────────────────────

class GridCell {
  final int? itemId;          // 1-based; null = empty
  final ObstacleType obstacle;
  final bool isUnlocking;     // animation: crate just broke open

  const GridCell({
    this.itemId,
    this.obstacle = ObstacleType.none,
    this.isUnlocking = false,
  });

  bool get isEmpty => itemId == null && obstacle == ObstacleType.none;
  bool get hasItem  => itemId != null;
  bool get isBlocked =>
      obstacle == ObstacleType.dustyWeb ||
      obstacle == ObstacleType.lockedCrate ||
      obstacle == ObstacleType.blackHole;

  GridCell clearItem() => GridCell(obstacle: obstacle);
  GridCell withItem(int id) => GridCell(itemId: id, obstacle: obstacle);

  GridCell copyWith({
    Object? itemId = _sentinel,
    ObstacleType? obstacle,
    bool? isUnlocking,
  }) {
    return GridCell(
      itemId:      itemId == _sentinel ? this.itemId : itemId as int?,
      obstacle:    obstacle     ?? this.obstacle,
      isUnlocking: isUnlocking  ?? this.isUnlocking,
    );
  }

  static const Object _sentinel = Object();
}
