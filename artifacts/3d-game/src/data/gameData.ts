export type ObstacleType = "dusty_web" | "locked_crate" | "timed_order" | "black_hole";
export type PhaseTheme = "garage" | "office" | "silicon" | "megacorp" | "universe";

export interface ItemDef {
  id: string;
  name: string;
  emoji: string;
  tier: number;
}

export interface LevelConfig {
  level: number;
  phase: 1 | 2 | 3 | 4 | 5;
  theme: PhaseTheme;
  title: string;
  story: string;
  gridCols: number;
  gridRows: number;
  targetItemId: string;
  targetCount: number;
  baseCoins: number;
  energyCostPerSpawn: number;
  obstacles: ObstacleType[];
  timedOrderSeconds?: number;
  fasterEnergyDrain?: boolean;
  initialItems?: Array<{ itemId: string; col: number; row: number }>;

  // --- Per-level Ad Permission Flags (mirrors Dart LevelModel) ---
  allowLowEnergyBoost: boolean;      // Rule 1: show floating "Low Energy → Watch Ad" button
  allowZeroEnergyLockout: boolean;   // Rule 2: show hard popup when energy == 0
  allowScoreMultiplier: boolean;     // Rule 3: show "Watch Ad for 3X Coins" at level complete
  triggerInterstitialNext: boolean;  // Rule 4: fire interstitial when player taps "Next Level"

  // AdMob unit IDs (real ID provided by user for rewarded; placeholder for interstitial)
  rewardedAdUnitId?: string;
  interstitialAdUnitId?: string;
}

export const PHASE_THEMES: Record<PhaseTheme, {
  bg: string;
  primary: string;
  secondary: string;
  accent: string;
  name: string;
  glow: string;
}> = {
  garage: {
    name: "The Garage Startup",
    bg: "from-[#1a0a00] via-[#2d1200] to-[#0a1a1a]",
    primary: "#FF6B35",
    secondary: "#00E5FF",
    accent: "#FF8C42",
    glow: "shadow-[0_0_20px_#FF6B3588]",
  },
  office: {
    name: "The Office Upgrade",
    bg: "from-[#001a33] via-[#003366] to-[#001040]",
    primary: "#1E90FF",
    secondary: "#FFFFFF",
    accent: "#4FC3F7",
    glow: "shadow-[0_0_20px_#1E90FF88]",
  },
  silicon: {
    name: "Silicon Valley Tycoon",
    bg: "from-[#1a0033] via-[#33003d] to-[#0d001a]",
    primary: "#CC00FF",
    secondary: "#FF0080",
    accent: "#FF69B4",
    glow: "shadow-[0_0_20px_#CC00FF88]",
  },
  megacorp: {
    name: "Global Mega-Corp",
    bg: "from-[#001100] via-[#001a00] to-[#000500]",
    primary: "#00FF41",
    secondary: "#39FF14",
    accent: "#ADFF2F",
    glow: "shadow-[0_0_20px_#00FF4188]",
  },
  universe: {
    name: "Masters of the Universe",
    bg: "from-[#0a0000] via-[#1a1a00] to-[#000010]",
    primary: "#FFD700",
    secondary: "#E5E4E2",
    accent: "#FFF8DC",
    glow: "shadow-[0_0_30px_#FFD70099]",
  },
};

// Item chains per phase — tier 0 is the spawnable base item
export const ITEM_CHAINS: Record<PhaseTheme, ItemDef[]> = {
  garage: [
    { id: "g0", name: "Wire",             emoji: "🔌", tier: 0 },
    { id: "g1", name: "USB Cable",        emoji: "🪢", tier: 1 },
    { id: "g2", name: "Retro Mouse",      emoji: "🖱️",  tier: 2 },
    { id: "g3", name: "Mech. Keyboard",   emoji: "⌨️",  tier: 3 },
    { id: "g4", name: "CRT Monitor",      emoji: "🖥️",  tier: 4 },
    { id: "g5", name: "Motherboard",      emoji: "🔧",  tier: 5 },
    { id: "g6", name: "4GB RAM",          emoji: "💾",  tier: 6 },
    { id: "g7", name: "Dual-Core CPU",    emoji: "⚙️",  tier: 7 },
    { id: "g8", name: "CPU Cooler",       emoji: "❄️",  tier: 8 },
    { id: "g9", name: "PSU",              emoji: "🔋",  tier: 9 },
    { id: "g10", name: "Basic Desktop",   emoji: "🖥️",  tier: 10 },
  ],
  office: [
    { id: "o0", name: "USB Hub",          emoji: "🔌",  tier: 0 },
    { id: "o1", name: "Basic Laptop",     emoji: "💻",  tier: 1 },
    { id: "o2", name: "Graphics Card",    emoji: "🎮",  tier: 2 },
    { id: "o3", name: "Pro Monitor",      emoji: "🖥️",  tier: 3 },
    { id: "o4", name: "Studio Mic",       emoji: "🎙️",  tier: 4 },
    { id: "o5", name: "1TB SSD",          emoji: "💿",  tier: 5 },
    { id: "o6", name: "Home Server",      emoji: "🗄️",  tier: 6 },
    { id: "o7", name: "Smart Speaker",    emoji: "📻",  tier: 7 },
    { id: "o8", name: "HW Firewall",      emoji: "🛡️",  tier: 8 },
    { id: "o9", name: "Powerbank",        emoji: "🔋",  tier: 9 },
    { id: "o10", name: "RGB Gaming PC",   emoji: "🎯",  tier: 10 },
  ],
  silicon: [
    { id: "s0", name: "Sensor",           emoji: "📡",  tier: 0 },
    { id: "s1", name: "VR Headset",       emoji: "🥽",  tier: 1 },
    { id: "s2", name: "4K Drone",         emoji: "🚁",  tier: 2 },
    { id: "s3", name: "Holo. Smartwatch", emoji: "⌚",  tier: 3 },
    { id: "s4", name: "Mining Rig",       emoji: "⛏️",  tier: 4 },
    { id: "s5", name: "3D Printer",       emoji: "🏭",  tier: 5 },
    { id: "s6", name: "Cloud Rack",       emoji: "☁️",  tier: 6 },
    { id: "s7", name: "AutoPilot Chip",   emoji: "🚗",  tier: 7 },
    { id: "s8", name: "Bionic Arm",       emoji: "🦾",  tier: 8 },
    { id: "s9", name: "Cyber-Dog",        emoji: "🤖",  tier: 9 },
    { id: "s10", name: "Data Center",     emoji: "🏢",  tier: 10 },
  ],
  megacorp: [
    { id: "m0", name: "Photon",           emoji: "💡",  tier: 0 },
    { id: "m1", name: "Hologram Proj.",   emoji: "📽️",  tier: 1 },
    { id: "m2", name: "Neural Headset",   emoji: "🧠",  tier: 2 },
    { id: "m3", name: "Quantum Proc.",    emoji: "⚛️",  tier: 3 },
    { id: "m4", name: "Plasma Shield",    emoji: "🛡️",  tier: 4 },
    { id: "m5", name: "Nanobot Swarm",    emoji: "🔬",  tier: 5 },
    { id: "m6", name: "Laser Dish",       emoji: "📡",  tier: 6 },
    { id: "m7", name: "Hoverboard",       emoji: "🛹",  tier: 7 },
    { id: "m8", name: "Power Exosuit",    emoji: "🦾",  tier: 8 },
    { id: "m9", name: "Sentient AI Core", emoji: "🤖",  tier: 9 },
    { id: "m10", name: "Space Station",   emoji: "🛸",  tier: 10 },
  ],
  universe: [
    { id: "u0", name: "Dark Energy",      emoji: "🌌",  tier: 0 },
    { id: "u1", name: "Warp Engine",      emoji: "🚀",  tier: 1 },
    { id: "u2", name: "Atm. Generator",   emoji: "🌿",  tier: 2 },
    { id: "u3", name: "Dark Matter React.", emoji: "⚛️", tier: 3 },
    { id: "u4", name: "Telepad",          emoji: "🔵",  tier: 4 },
    { id: "u5", name: "Chrono-Device",    emoji: "⏱️",  tier: 5 },
    { id: "u6", name: "Star Forge",       emoji: "⭐",  tier: 6 },
    { id: "u7", name: "Soul-Drive",       emoji: "💎",  tier: 7 },
    { id: "u8", name: "Galactic Router",  emoji: "🌐",  tier: 8 },
    { id: "u9", name: "Dimensional Rift", emoji: "🌀",  tier: 9 },
    { id: "u10", name: "Dyson Sphere",    emoji: "☀️",  tier: 10 },
  ],
};

// Helper to get item by id
export function getItemById(id: string): ItemDef | undefined {
  for (const chain of Object.values(ITEM_CHAINS)) {
    const found = chain.find(i => i.id === id);
    if (found) return found;
  }
  return undefined;
}

export function getNextItem(currentId: string): ItemDef | undefined {
  for (const chain of Object.values(ITEM_CHAINS)) {
    const idx = chain.findIndex(i => i.id === currentId);
    if (idx !== -1 && idx + 1 < chain.length) return chain[idx + 1];
  }
  return undefined;
}

export function getBaseItemForPhase(theme: PhaseTheme): ItemDef {
  return ITEM_CHAINS[theme][0];
}

// ─── AdMob Unit IDs ──────────────────────────────────────────────────────────
// Real rewarded video ID mapped from the user's AdMob account
export const ADMOB_REWARDED_ID    = "ca-app-pub-8566652140087308/7306930941";
// Interstitial placeholder — replace with real ID before shipping
export const ADMOB_INTERSTITIAL_ID = "ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx";

// ─── lvl() helper ────────────────────────────────────────────────────────────
// adFlags param mirrors Dart LevelModel booleans in order:
//   [allowLowEnergyBoost, allowZeroEnergyLockout, allowScoreMultiplier, triggerInterstitialNext]
function lvl(
  level: number,
  phase: 1 | 2 | 3 | 4 | 5,
  theme: PhaseTheme,
  title: string,
  story: string,
  gridCols: number,
  gridRows: number,
  targetItemId: string,
  baseCoins: number,
  energyCost: number,
  obstacles: ObstacleType[] = [],
  adFlags: [boolean, boolean, boolean, boolean] = [true, true, true, true],
  extras: Partial<LevelConfig> = {}
): LevelConfig {
  const [allowLowEnergyBoost, allowZeroEnergyLockout, allowScoreMultiplier, triggerInterstitialNext] = adFlags;
  return {
    level, phase, theme, title, story,
    gridCols, gridRows, targetItemId,
    targetCount: 1,
    baseCoins, energyCostPerSpawn: energyCost,
    obstacles,
    allowLowEnergyBoost,
    allowZeroEnergyLockout,
    allowScoreMultiplier,
    triggerInterstitialNext,
    rewardedAdUnitId: ADMOB_REWARDED_ID,
    interstitialAdUnitId: ADMOB_INTERSTITIAL_ID,
    ...extras,
  };
}

// adFlags key: [allowLowEnergyBoost, allowZeroEnergyLockout, allowScoreMultiplier, triggerInterstitialNext]
// Phase 1 ad strategy: low intrusion / high retention.
//   Levels 1-2: allowLowEnergyBoost=false (tutorial — don't interrupt with ads)
//   Level 3+:   all four flags enabled

export const LEVELS: LevelConfig[] = [
  // ─── PHASE 1: The Garage Startup (4×4 grid, Rusty Orange & Cyan) ──────────
  // L1 tutorial: zero energy lockout ON, low-energy boost OFF (per Dart config)
  lvl(1,1,"garage","The Spark",
    "Welcome to the garage! Let's make some basic connections.",
    4,4,"g1",50,5,[],[false,true,true,true]),

  lvl(2,1,"garage","Scraping By",
    "We need input devices to test our junk.",
    4,4,"g2",80,5,[],[false,true,true,true]),

  // L3+ all ad flags ON
  lvl(3,1,"garage","Click & Clack",
    "Typing on wires hurts. Build a keyboard!",
    4,4,"g3",110,6,[],[true,true,true,true]),

  lvl(4,1,"garage","Hello World",
    "We need to see what we are doing.",
    4,4,"g4",140,6,[],[true,true,true,true]),

  lvl(5,1,"garage","The Brains",
    "Time to process data.",
    4,4,"g5",170,7,[],[true,true,true,true]),

  // Dusty Webs obstacle introduced at L6 — grid-full risk triggers energy boost ads
  lvl(6,1,"garage","Memory Lane",
    "Your PC keeps crashing. Add memory!",
    4,4,"g6",200,7,["dusty_web"],[true,true,true,true]),

  lvl(7,1,"garage","Speed It Up",
    "We need a faster processor for basic tasks.",
    4,4,"g7",230,8,["dusty_web"],[true,true,true,true]),

  lvl(8,1,"garage","Cooling Down",
    "Things are getting hot. Add a fan.",
    4,4,"g8",260,8,["dusty_web"],[true,true,true,true]),

  lvl(9,1,"garage","Power Up",
    "We need more juice!",
    4,4,"g9",290,9,["dusty_web"],[true,true,true,true]),

  lvl(10,1,"garage","The First PC",
    "You did it! Your first fully working Desktop PC.",
    4,4,"g10",500,10,["dusty_web"],[true,true,true,true]),

  // ─── PHASE 2: The Office Upgrade (4×5 grid, Blue & White) ────────────────
  // Locked Crates obstacle introduced at L15 — forces space-clearing; ads spike.
  lvl(11,2,"office","Going Mobile",
    "Customers want portability.",
    4,5,"o1",300,8,[],[true,true,true,true]),

  lvl(12,2,"office","Gaming Vibes",
    "Gamers pay well. Give them graphics!",
    4,5,"o2",350,9,[],[true,true,true,true]),

  lvl(13,2,"office","The Setup",
    "Streamers need a dual-monitor setup.",
    4,5,"o3",400,9,[],[true,true,true,true]),

  lvl(14,2,"office","Sound Check",
    "Audio is key for the streamers.",
    4,5,"o4",450,10,[],[true,true,true,true]),

  lvl(15,2,"office","Storage Wars",
    "We need to save massive data.",
    4,5,"o5",500,10,["locked_crate"],[true,true,true,true]),

  lvl(16,2,"office","The Server",
    "Let's host our own website.",
    4,5,"o6",550,11,["locked_crate"],[true,true,true,true]),

  lvl(17,2,"office","Smart Home",
    "Let's automate the office lights.",
    4,5,"o7",600,11,["locked_crate"],[true,true,true,true]),

  lvl(18,2,"office","Security",
    "Protect the office from hackers.",
    4,5,"o8",650,12,["locked_crate"],[true,true,true,true]),

  lvl(19,2,"office","Portable Power",
    "Working on the go needs battery.",
    4,5,"o9",700,12,["locked_crate"],[true,true,true,true]),

  lvl(20,2,"office","The Gaming Rig",
    "A masterpiece of RGB and power!",
    4,5,"o10",1000,13,["locked_crate"],[true,true,true,true]),

  // ─── PHASE 3: Silicon Valley Tycoon (5×5, Neon Purple & Pink) ────────────
  // fasterEnergyDrain=true → heavy energy consumption → maximises Rule 1 & 2 ad triggers
  lvl(21,3,"silicon","Virtual Reality",
    "Let's step into the Metaverse.",
    5,5,"s1",600,10,[],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(22,3,"silicon","Flying High",
    "We need aerial footage.",
    5,5,"s2",700,11,[],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(23,3,"silicon","Wearables",
    "Tech on your wrist.",
    5,5,"s3",800,11,["dusty_web"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(24,3,"silicon","Crypto Mining",
    "Time to mine some digital gold.",
    5,5,"s4",900,12,["dusty_web"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(25,3,"silicon","3D Printing",
    "Why buy parts when you can print them?",
    5,5,"s5",1000,12,["locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(26,3,"silicon","Cloud Storage",
    "Move everything to the cloud.",
    5,5,"s6",1100,13,["locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(27,3,"silicon","Self-Driving",
    "Cars need brains too.",
    5,5,"s7",1200,13,["dusty_web","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(28,3,"silicon","Bionic Tech",
    "Upgrading the human body.",
    5,5,"s8",1300,14,["dusty_web","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(29,3,"silicon","Robotics",
    "Meet your new robotic assistant.",
    5,5,"s9",1400,14,["locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(30,3,"silicon","The Data Center",
    "You now control 10% of the internet!",
    5,5,"s10",2000,15,["locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  // ─── PHASE 4: Global Mega-Corp (6×5, Acid Green & Black) ─────────────────
  // Timed Orders: high friction → maximise interstitial & multiplier ad value
  lvl(31,4,"megacorp","Holograms",
    "Screens are dead. Project it in the air.",
    6,5,"m1",1000,12,["timed_order"],[true,true,true,true],{timedOrderSeconds:90}),

  lvl(32,4,"megacorp","Neural Link",
    "Control computers with your mind.",
    6,5,"m2",1100,13,["timed_order"],[true,true,true,true],{timedOrderSeconds:85}),

  lvl(33,4,"megacorp","Quantum Chip",
    "Computing at the atomic level.",
    6,5,"m3",1200,13,["timed_order"],[true,true,true,true],{timedOrderSeconds:80}),

  lvl(34,4,"megacorp","Energy Shield",
    "Protecting cities from impact.",
    6,5,"m4",1300,14,["timed_order","locked_crate"],[true,true,true,true],{timedOrderSeconds:80}),

  lvl(35,4,"megacorp","Nanobots",
    "Microscopic robots fixing errors.",
    6,5,"m5",1400,14,["timed_order","locked_crate"],[true,true,true,true],{timedOrderSeconds:75}),

  lvl(36,4,"megacorp","Laser Comms",
    "Communicating at the speed of light.",
    6,5,"m6",1500,15,["timed_order","dusty_web"],[true,true,true,true],{timedOrderSeconds:75}),

  lvl(37,4,"megacorp","Anti-Gravity",
    "Who needs wheels?",
    6,5,"m7",1600,15,["timed_order","dusty_web"],[true,true,true,true],{timedOrderSeconds:70}),

  lvl(38,4,"megacorp","Exosuit",
    "Superhuman strength for workers.",
    6,5,"m8",1700,16,["timed_order","locked_crate"],[true,true,true,true],{timedOrderSeconds:70}),

  lvl(39,4,"megacorp","AI Core",
    "It is awake. It is thinking.",
    6,5,"m9",1800,17,["timed_order","locked_crate"],[true,true,true,true],{timedOrderSeconds:65}),

  lvl(40,4,"megacorp","The Orbital Station",
    "Earth is too small for us now.",
    6,5,"m10",3000,18,["timed_order","locked_crate"],[true,true,true,true],{timedOrderSeconds:60}),

  // ─── PHASE 5: Masters of the Universe (6×6, Gold & Deep Space) ───────────
  // Black Holes + fasterEnergyDrain = peak monetisation phase (max Rule 1 & 2 triggers)
  lvl(41,5,"universe","Warp Drive",
    "Traveling faster than light.",
    6,6,"u1",2000,15,["black_hole"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(42,5,"universe","Terraforming",
    "Making Mars green.",
    6,6,"u2",2200,16,["black_hole"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(43,5,"universe","Dark Matter",
    "Harnessing the unseen universe.",
    6,6,"u3",2400,16,["black_hole","dusty_web"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(44,5,"universe","Teleportation",
    "From here to there, instantly.",
    6,6,"u4",2600,17,["black_hole"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(45,5,"universe","Time Dilation",
    "Slowing down time itself.",
    6,6,"u5",2800,18,["black_hole","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(46,5,"universe","Star Forge",
    "Creating elements from pure energy.",
    6,6,"u6",3000,18,["black_hole","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(47,5,"universe","Mind Upload",
    "Immortality in the digital realm.",
    6,6,"u7",3200,19,["black_hole","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(48,5,"universe","Galaxy Net",
    "Connecting billions of planets.",
    6,6,"u8",3400,20,["black_hole","dusty_web","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(49,5,"universe","The Multiverse",
    "Peeking into parallel worlds.",
    6,6,"u9",3600,21,["black_hole","dusty_web","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),

  lvl(50,5,"universe","The Dyson Sphere",
    "You have captured a star. You are a Tech God.",
    6,6,"u10",5000,22,["black_hole","locked_crate"],[true,true,true,true],{fasterEnergyDrain:true}),
];
