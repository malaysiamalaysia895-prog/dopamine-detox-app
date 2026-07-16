// @ts-nocheck
import * as THREE from 'three';
import { Water } from 'three/examples/jsm/objects/Water.js';
import { Sky } from 'three/examples/jsm/objects/Sky.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import gsap from 'gsap';

// ─── Exported types ────────────────────────────────────────────────────────────
export type GamePhase = 'intro' | 'combat' | 'victory' | 'defeat';

export interface GameState {
  phase: GamePhase;
  playerHP: number;
  playerMaxHP: number;
  aliensAlive: number;
  aliensTotal: number;
  phaseTitle: string;
  showControls: boolean;
}

export interface GameCallbacks {
  onStateChange: (state: Partial<GameState>) => void;
}

// ─── Internal types ────────────────────────────────────────────────────────────
interface Projectile {
  mesh: THREE.Mesh;
  velocity: THREE.Vector3;
  type: 'cannonball' | 'laser';
  lifetime: number;
  trail: THREE.Points;
  trailPositions: Float32Array;
}

interface AlienShip {
  group: THREE.Group;
  hp: number;
  maxHP: number;
  fireTimer: number;
  alive: boolean;
  ring: THREE.Mesh;
  glow: THREE.PointLight;
  moveOffset: number;
}

interface Particle {
  mesh: THREE.Points;
  velocities: THREE.Vector3[];
  lifetime: number;
  maxLifetime: number;
}

// ─── Texture CDNs (CC0 / public domain) ───────────────────────────────────────
const T3 = 'https://cdn.jsdelivr.net/npm/three@0.160.0/examples/textures';
const PH = 'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k';

const TEX_URLS = {
  waterNormals: `${T3}/waternormals.jpg`,
  woodDiff:     `${PH}/wood_planks_dirt/wood_planks_dirt_diff_1k.jpg`,
  woodRough:    `${PH}/wood_planks_dirt/wood_planks_dirt_rough_1k.jpg`,
  woodNorm:     `${PH}/wood_planks_dirt/wood_planks_dirt_nor_gl_1k.jpg`,
  metalDiff:    `${PH}/rusty_metal_02/rusty_metal_02_diff_1k.jpg`,
  metalRough:   `${PH}/rusty_metal_02/rusty_metal_02_rough_1k.jpg`,
  metalNorm:    `${PH}/rusty_metal_02/rusty_metal_02_nor_gl_1k.jpg`,
};

// ─── Texture helpers ───────────────────────────────────────────────────────────
const texLoader = new THREE.TextureLoader();

function loadTex(url: string, rep = 4): THREE.Texture {
  const t = texLoader.load(url, undefined, undefined, () => {
    // On CDN error: leave as is — material will show base color
  });
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(rep, rep);
  return t;
}

/** Procedural wood normal map — used as immediate fallback before CDN loads */
function makeWoodNormal(): THREE.Texture {
  const sz = 512;
  const cv = document.createElement('canvas');
  cv.width = cv.height = sz;
  const cx = cv.getContext('2d')!;
  const id = cx.createImageData(sz, sz);
  for (let y = 0; y < sz; y++) {
    for (let x = 0; x < sz; x++) {
      const i = (y * sz + x) * 4;
      const g = Math.sin((y / sz) * Math.PI * 48 + Math.sin(x / sz * Math.PI * 8) * 2) * 0.5 + 0.5;
      id.data[i]     = 128 + (g * 80 - 40);
      id.data[i + 1] = 128 + (g * 80 - 40);
      id.data[i + 2] = 220;
      id.data[i + 3] = 255;
    }
  }
  cx.putImageData(id, 0, 0);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(4, 4);
  return t;
}

/** Procedural high-detail water normal map */
function makeWaterNormal(): THREE.Texture {
  const sz = 1024;
  const cv = document.createElement('canvas');
  cv.width = cv.height = sz;
  const cx = cv.getContext('2d')!;
  const id = cx.createImageData(sz, sz);
  for (let y = 0; y < sz; y++) {
    for (let x = 0; x < sz; x++) {
      const i = (y * sz + x) * 4;
      const u = x / sz; const v = y / sz;
      const w1 = Math.sin(u * Math.PI * 18 + v * Math.PI * 5);
      const w2 = Math.cos(v * Math.PI * 14 - u * Math.PI * 7);
      const w3 = Math.sin((u + v) * Math.PI * 10);
      const w4 = Math.cos((u * 2 - v) * Math.PI * 22);
      const nx = (w1 * 0.35 + w3 * 0.15) * 0.5 + 0.5;
      const ny = (w2 * 0.35 + w4 * 0.15) * 0.5 + 0.5;
      id.data[i]     = Math.max(0, Math.min(255, nx * 255));
      id.data[i + 1] = Math.max(0, Math.min(255, ny * 255));
      id.data[i + 2] = 210;
      id.data[i + 3] = 255;
    }
  }
  cx.putImageData(id, 0, 0);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

// ─── Pirate ship builder ───────────────────────────────────────────────────────
function buildPirateShip(): THREE.Group {
  const group = new THREE.Group();

  // Textures (load from CDN, fallback to color)
  const woodD = loadTex(TEX_URLS.woodDiff, 5);
  const woodR = loadTex(TEX_URLS.woodRough, 5);
  const woodN = loadTex(TEX_URLS.woodNorm, 5);
  const metD  = loadTex(TEX_URLS.metalDiff, 2);
  const metR  = loadTex(TEX_URLS.metalRough, 2);
  const metN  = loadTex(TEX_URLS.metalNorm, 2);
  const woodFallbackN = makeWoodNormal();

  const hullMat = new THREE.MeshStandardMaterial({
    color: 0x7A3A10,
    map: woodD,
    roughnessMap: woodR,
    normalMap: woodN,
    normalScale: new THREE.Vector2(1.8, 1.8),
    roughness: 0.88,
    metalness: 0.04,
  });
  const deckMat = new THREE.MeshStandardMaterial({
    color: 0x5C2A08,
    map: woodD,
    roughnessMap: woodR,
    normalMap: woodFallbackN,
    normalScale: new THREE.Vector2(1.4, 1.4),
    roughness: 0.92,
    metalness: 0.0,
  });
  const metalMat = new THREE.MeshStandardMaterial({
    color: 0x888877,
    map: metD,
    roughnessMap: metR,
    normalMap: metN,
    normalScale: new THREE.Vector2(1.2, 1.2),
    roughness: 0.35,
    metalness: 0.88,
  });
  const sailMat = new THREE.MeshStandardMaterial({
    color: 0xDDD0A8,
    roughness: 0.85,
    metalness: 0.0,
    side: THREE.DoubleSide,
  });
  const ropeMatl = new THREE.MeshStandardMaterial({ color: 0x8B7355, roughness: 1.0 });

  // ── Hull ──────────────────────────────────────────────────────────────────
  const hull = new THREE.Mesh(new THREE.BoxGeometry(20, 7, 60), hullMat);
  hull.castShadow = hull.receiveShadow = true;
  group.add(hull);

  // Bow
  const bow = new THREE.Mesh(new THREE.CylinderGeometry(0, 10, 10, 4), deckMat);
  bow.position.set(0, 0, -35);
  bow.rotation.set(Math.PI / 2, 0, Math.PI / 4);
  bow.castShadow = true;
  group.add(bow);

  // Stern
  const stern = new THREE.Mesh(new THREE.BoxGeometry(20, 10, 10), hullMat);
  stern.position.set(0, 5, 28);
  stern.castShadow = true;
  group.add(stern);

  // Deck planks
  const deck = new THREE.Mesh(new THREE.BoxGeometry(19, 1, 58), deckMat);
  deck.position.y = 4;
  deck.receiveShadow = deck.castShadow = true;
  group.add(deck);

  // Forecastle
  const fore = new THREE.Mesh(new THREE.BoxGeometry(16, 3, 12), hullMat);
  fore.position.set(0, 5.5, -24);
  fore.castShadow = true;
  group.add(fore);

  // Poop deck
  const poop = new THREE.Mesh(new THREE.BoxGeometry(16, 3, 14), hullMat);
  poop.position.set(0, 5.5, 22);
  poop.castShadow = true;
  group.add(poop);

  // ── Masts ─────────────────────────────────────────────────────────────────
  [{ z: -18, h: 42 }, { z: 2, h: 48 }, { z: 20, h: 36 }].forEach(({ z, h }) => {
    const mast = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.65, h, 8), deckMat);
    mast.position.set(0, 4 + h / 2, z);
    mast.castShadow = true;
    group.add(mast);

    // Cross yard
    const yard = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 22, 8), deckMat);
    yard.position.set(0, 4 + h * 0.78, z);
    yard.rotation.z = Math.PI / 2;
    group.add(yard);

    // Sail (two panels per yard)
    [-1, 1].forEach(side => {
      const sailGeo = new THREE.PlaneGeometry(9.5, h * 0.55);
      const sail = new THREE.Mesh(sailGeo, sailMat);
      sail.position.set(side * 5, 4 + h * 0.78 - h * 0.14, z);
      sail.castShadow = true;
      group.add(sail);
    });

    // Ropes from mast top to deck sides
    [-8, 8].forEach(sx => {
      const ropeGeo = new THREE.CylinderGeometry(0.1, 0.1, Math.hypot(sx, 4 + h), 4);
      const rope = new THREE.Mesh(ropeGeo, ropeMatl);
      const angle = Math.atan2(sx, -(4 + h));
      rope.rotation.z = angle;
      rope.position.set(sx / 2, 4 + h / 2, z);
      group.add(rope);
    });
  });

  // ── Cannons (8 per side, protruding from gun deck) ────────────────────────
  [-1, 1].forEach(side => {
    for (let ci = 0; ci < 6; ci++) {
      const z = -20 + ci * 8;
      const barrelGeo = new THREE.CylinderGeometry(0.6, 0.7, 6, 10);
      const barrel = new THREE.Mesh(barrelGeo, metalMat);
      barrel.position.set(side * 11, 1.5, z);
      barrel.rotation.z = Math.PI / 2;
      barrel.castShadow = true;
      group.add(barrel);

      // Cannon wheel
      const wheelGeo = new THREE.TorusGeometry(0.9, 0.15, 6, 8);
      const wheel = new THREE.Mesh(wheelGeo, metalMat);
      wheel.position.set(side * 9, 0.8, z);
      wheel.rotation.y = Math.PI / 2;
      group.add(wheel);
    }
  });

  // ── Figurehead ────────────────────────────────────────────────────────────
  const fhGeo = new THREE.ConeGeometry(2, 5, 5);
  const fh = new THREE.Mesh(fhGeo, metalMat);
  fh.position.set(0, 3, -38);
  fh.rotation.x = Math.PI / 2;
  group.add(fh);

  // ── Railings ──────────────────────────────────────────────────────────────
  [-9, 9].forEach(sx => {
    for (let pi = 0; pi < 10; pi++) {
      const post = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.18, 2.5, 5), deckMat);
      post.position.set(sx, 6.2, -22 + pi * 5);
      group.add(post);
    }
    const rail = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 48), deckMat);
    rail.position.set(sx, 7.5, 0);
    group.add(rail);
  });

  // ── Skull flag ────────────────────────────────────────────────────────────
  const flagGeo = new THREE.PlaneGeometry(5, 3.5);
  const flagMat = new THREE.MeshStandardMaterial({ color: 0x111111, side: THREE.DoubleSide, roughness: 1 });
  const flag = new THREE.Mesh(flagGeo, flagMat);
  flag.position.set(0, 4 + 48 + 2, 2);
  flag.rotation.y = 0.4;
  group.add(flag);

  // Skull emblem (emissive white)
  const skullGeo = new THREE.SphereGeometry(1.0, 6, 6);
  const skullMat = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xaaaaaa, emissiveIntensity: 0.4 });
  const skull = new THREE.Mesh(skullGeo, skullMat);
  skull.position.set(0, 4 + 48 + 2, 2.1);
  group.add(skull);

  return group;
}

// ─── Cyborg/Mech Character Builder ────────────────────────────────────────────
function buildCyborgCharacter(isBoss: boolean, accentColor: number): THREE.Group {
  const g = new THREE.Group();
  const scale = isBoss ? 1.7 : 1.0;

  const chromeMat = new THREE.MeshPhysicalMaterial({
    color: isBoss ? 0x1a0033 : 0x0d0d1a,
    metalness: 0.95,
    roughness: 0.08,
    clearcoat: 1.0,
    clearcoatRoughness: 0.05,
    reflectivity: 1.0,
  });

  const accentMat = new THREE.MeshPhysicalMaterial({
    color: accentColor,
    metalness: 0.8,
    roughness: 0.15,
    clearcoat: 0.8,
  });

  const visorMat = new THREE.MeshPhysicalMaterial({
    color: accentColor,
    emissive: accentColor,
    emissiveIntensity: isBoss ? 3.5 : 2.8,
    metalness: 0.2,
    roughness: 0.0,
    transparent: true,
    opacity: 0.92,
    transmission: 0.2,
  });

  const jointMat = new THREE.MeshPhysicalMaterial({
    color: 0x222233,
    metalness: 0.9,
    roughness: 0.2,
    clearcoat: 0.5,
  });

  // ── Torso ─────────────────────────────────────────────────────────────────
  const torsoH = 3.8 * scale;
  const torso = new THREE.Mesh(new THREE.BoxGeometry(2.6 * scale, torsoH, 1.8 * scale), chromeMat);
  torso.position.y = torsoH / 2 + 3.5 * scale;
  torso.castShadow = true;
  g.add(torso);

  // Chest plate accent
  const chestPlate = new THREE.Mesh(new THREE.BoxGeometry(1.8 * scale, 2 * scale, 0.2), accentMat);
  chestPlate.position.set(0, torsoH / 2 + 3.5 * scale, 0.9 * scale);
  g.add(chestPlate);

  // Core orb (glowing)
  const coreGeo = new THREE.SphereGeometry(0.45 * scale, 16, 16);
  const core = new THREE.Mesh(coreGeo, visorMat);
  core.position.set(0, torsoH / 2 + 3.5 * scale, 1.0 * scale);
  g.add(core);

  // ── Head ──────────────────────────────────────────────────────────────────
  const headY = torsoH + 3.5 * scale + 1.1 * scale;
  const head = new THREE.Mesh(new THREE.BoxGeometry(2.2 * scale, 2.0 * scale, 2.0 * scale), chromeMat);
  head.position.y = headY;
  head.castShadow = true;
  g.add(head);

  // Visor slit
  const visor = new THREE.Mesh(new THREE.BoxGeometry(1.8 * scale, 0.5 * scale, 0.12), visorMat);
  visor.position.set(0, headY + 0.2 * scale, 1.0 * scale);
  g.add(visor);

  // Antenna (boss only)
  if (isBoss) {
    const antennaGeo = new THREE.CylinderGeometry(0.08, 0.12, 2.0, 6);
    const antenna = new THREE.Mesh(antennaGeo, accentMat);
    antenna.position.set(0, headY + 1.8 * scale, 0);
    g.add(antenna);
    const antennaTop = new THREE.Mesh(new THREE.SphereGeometry(0.25, 8, 8), visorMat);
    antennaTop.position.set(0, headY + 2.9 * scale, 0);
    g.add(antennaTop);
  }

  // ── Shoulders ─────────────────────────────────────────────────────────────
  [-1, 1].forEach(side => {
    const shoulderY = torsoH + 3.0 * scale;
    const shoulder = new THREE.Mesh(new THREE.SphereGeometry(0.9 * scale, 12, 12), accentMat);
    shoulder.position.set(side * 2.0 * scale, shoulderY, 0);
    g.add(shoulder);

    // Upper arm
    const uarmGeo = new THREE.CylinderGeometry(0.4 * scale, 0.35 * scale, 2.5 * scale, 8);
    const uarm = new THREE.Mesh(uarmGeo, chromeMat);
    uarm.position.set(side * 2.6 * scale, shoulderY - 1.2 * scale, 0);
    uarm.rotation.z = side * 0.2;
    uarm.castShadow = true;
    g.add(uarm);

    // Elbow joint
    const elbow = new THREE.Mesh(new THREE.SphereGeometry(0.38 * scale, 8, 8), jointMat);
    elbow.position.set(side * 2.8 * scale, shoulderY - 2.6 * scale, 0);
    g.add(elbow);

    // Forearm
    const farmGeo = new THREE.CylinderGeometry(0.32 * scale, 0.42 * scale, 2.2 * scale, 8);
    const farm = new THREE.Mesh(farmGeo, chromeMat);
    farm.position.set(side * (isBoss ? 3.2 : 3.1) * scale, shoulderY - 3.8 * scale, 0);
    farm.rotation.z = side * 0.35;
    farm.castShadow = true;
    g.add(farm);

    // Weapon / hand
    const weaponMat = new THREE.MeshPhysicalMaterial({ color: accentColor, emissive: accentColor, emissiveIntensity: 1.5, metalness: 0.7, roughness: 0.2 });
    const weaponGeo = isBoss
      ? new THREE.BoxGeometry(0.5 * scale, 0.5 * scale, 2.8 * scale)
      : new THREE.CylinderGeometry(0.28 * scale, 0.35 * scale, 2.0 * scale, 6);
    const weapon = new THREE.Mesh(weaponGeo, weaponMat);
    weapon.position.set(side * (isBoss ? 3.5 : 3.3) * scale, shoulderY - 5.1 * scale, isBoss ? 0.6 * scale : 0);
    weapon.rotation.set(isBoss ? -0.3 : 0, 0, side * 0.1);
    g.add(weapon);
  });

  // ── Pelvis & legs ─────────────────────────────────────────────────────────
  const pelvis = new THREE.Mesh(new THREE.BoxGeometry(2.4 * scale, 1.2 * scale, 1.6 * scale), accentMat);
  pelvis.position.y = 3.1 * scale;
  g.add(pelvis);

  [-1, 1].forEach(side => {
    // Thigh
    const thighGeo = new THREE.CylinderGeometry(0.55 * scale, 0.45 * scale, 3.0 * scale, 8);
    const thigh = new THREE.Mesh(thighGeo, chromeMat);
    thigh.position.set(side * 0.9 * scale, 1.5 * scale, 0);
    thigh.castShadow = true;
    g.add(thigh);

    // Knee
    const knee = new THREE.Mesh(new THREE.SphereGeometry(0.52 * scale, 8, 8), jointMat);
    knee.position.set(side * 0.9 * scale, 0.0 * scale, 0.1 * scale);
    g.add(knee);

    // Shin
    const shinGeo = new THREE.CylinderGeometry(0.38 * scale, 0.55 * scale, 2.8 * scale, 8);
    const shin = new THREE.Mesh(shinGeo, chromeMat);
    shin.position.set(side * 0.9 * scale, -1.4 * scale, 0.1 * scale);
    shin.castShadow = true;
    g.add(shin);

    // Boot / foot
    const footGeo = new THREE.BoxGeometry(0.9 * scale, 0.6 * scale, 1.8 * scale);
    const foot = new THREE.Mesh(footGeo, accentMat);
    foot.position.set(side * 0.9 * scale, -2.9 * scale, 0.4 * scale);
    g.add(foot);
  });

  // Glow light
  const glow = new THREE.PointLight(accentColor, 3.5, 12 * scale);
  glow.position.set(0, torsoH / 2 + 3.5 * scale, 1.5);
  g.add(glow);

  return g;
}

// ─── UFO builder ──────────────────────────────────────────────────────────────
function buildUFO(isBoss: boolean, ringColor: number): { group: THREE.Group; ring: THREE.Mesh; glow: THREE.PointLight } {
  const g = new THREE.Group();
  const sc = isBoss ? 1.5 : 1.0;

  const bodyMat = new THREE.MeshPhysicalMaterial({
    color: isBoss ? 0x110022 : 0x0a1a22,
    metalness: 0.95,
    roughness: 0.05,
    clearcoat: 1.0,
    clearcoatRoughness: 0.02,
    reflectivity: 1.0,
  });

  const glowMat = new THREE.MeshPhysicalMaterial({
    color: ringColor,
    emissive: ringColor,
    emissiveIntensity: isBoss ? 4.0 : 3.0,
    roughness: 0.0,
    metalness: 0.3,
    transparent: true,
    opacity: 0.85,
  });

  // Disc body (top dome + bottom)
  const topGeo = new THREE.SphereGeometry(10 * sc, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2.2);
  const top = new THREE.Mesh(topGeo, bodyMat);
  top.castShadow = top.receiveShadow = true;
  g.add(top);

  const botGeo = new THREE.SphereGeometry(10 * sc, 32, 16, 0, Math.PI * 2, Math.PI / 2.2, Math.PI / 2.2);
  const bot = new THREE.Mesh(botGeo, bodyMat);
  bot.position.y = -0.5;
  g.add(bot);

  // Main glow ring
  const ringGeo = new THREE.TorusGeometry(11.5 * sc, isBoss ? 1.4 : 1.0, 16, 64);
  const ring = new THREE.Mesh(ringGeo, glowMat);
  ring.position.y = -2 * sc;
  ring.receiveShadow = false;
  g.add(ring);

  // Secondary rings
  [0.65, 0.4].forEach((rfrac, ri) => {
    const r2 = new THREE.Mesh(
      new THREE.TorusGeometry(rfrac * 11.5 * sc, 0.4 * sc, 8, 32),
      glowMat
    );
    r2.position.y = -1.5 * sc + ri * 1.5 * sc;
    g.add(r2);
  });

  // Cockpit dome
  const cockpitGeo = new THREE.SphereGeometry(4.5 * sc, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2);
  const cockpitMat = new THREE.MeshPhysicalMaterial({
    color: ringColor,
    emissive: ringColor,
    emissiveIntensity: 1.5,
    transparent: true,
    opacity: 0.5,
    roughness: 0.0,
    metalness: 0.3,
    transmission: 0.4,
  });
  const cockpit = new THREE.Mesh(cockpitGeo, cockpitMat);
  cockpit.position.y = 3 * sc;
  g.add(cockpit);

  // Point light inside UFO
  const glow = new THREE.PointLight(ringColor, isBoss ? 12 : 8, 80 * sc);
  glow.position.y = -4;
  g.add(glow);

  // Beam of light downward (boss only)
  if (isBoss) {
    const beamGeo = new THREE.CylinderGeometry(1.5, 8, 80, 12, 1, true);
    const beamMat = new THREE.MeshBasicMaterial({
      color: ringColor,
      transparent: true,
      opacity: 0.06,
      side: THREE.BackSide,
    });
    const beam = new THREE.Mesh(beamGeo, beamMat);
    beam.position.y = -42;
    g.add(beam);
  }

  return { group: g, ring, glow };
}

// ─── Particle burst ────────────────────────────────────────────────────────────
function buildParticleBurst(position: THREE.Vector3, color: number, count = 28): Particle {
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  const velocities: THREE.Vector3[] = [];

  for (let i = 0; i < count; i++) {
    positions[i * 3] = position.x;
    positions[i * 3 + 1] = position.y;
    positions[i * 3 + 2] = position.z;
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.random() * Math.PI;
    const speed = 10 + Math.random() * 22;
    velocities.push(new THREE.Vector3(
      Math.sin(phi) * Math.cos(theta) * speed,
      Math.abs(Math.cos(phi)) * speed * 0.9 + 5,
      Math.sin(phi) * Math.sin(theta) * speed,
    ));
  }

  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const mat = new THREE.PointsMaterial({ color, size: 1.6, transparent: true, opacity: 1.0, sizeAttenuation: true });
  return { mesh: new THREE.Points(geo, mat), velocities, lifetime: 0, maxLifetime: 1.8 };
}

// ─── Projectile trail ─────────────────────────────────────────────────────────
function buildProjectileTrail(isLaser: boolean): THREE.Points {
  const count = 20;
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const color = isLaser ? 0x00ffaa : 0x888877;
  const mat = new THREE.PointsMaterial({ color, size: isLaser ? 0.9 : 0.6, transparent: true, opacity: 0.75, sizeAttenuation: true });
  return new THREE.Points(geo, mat);
}

// ─── Main Game Class ───────────────────────────────────────────────────────────
export class PirateGame {
  private canvas: HTMLCanvasElement;
  private renderer!: THREE.WebGLRenderer;
  private scene!: THREE.Scene;
  private camera!: THREE.PerspectiveCamera;
  private composer!: EffectComposer;
  private water!: Water;
  private sun!: THREE.Vector3;
  private playerShip!: THREE.Group;
  private playerChar!: THREE.Group;    // Cyborg hero on deck
  private alienFleet: AlienShip[] = [];
  private projectiles: Projectile[] = [];
  private particles: Particle[] = [];
  private clock = new THREE.Clock();
  private animFrameId = 0;
  private callbacks: GameCallbacks;

  // State
  private phase: GamePhase = 'intro';
  private playerHP = 100;
  private readonly playerMaxHP = 100;
  private playerSpeed = 0;
  private playerRotation = 0;
  private canFireTimer = 0;
  private fireFromLeft = true;
  private combatStarted = false;
  private cinematicDone = false;
  private keys: Record<string, boolean> = {};
  private joystickX = 0;
  private joystickY = 0;

  private directionalLight!: THREE.DirectionalLight;
  private ambientLight!: THREE.THREE.AmbientLight;

  constructor(canvas: HTMLCanvasElement, callbacks: GameCallbacks) {
    this.canvas = canvas;
    this.callbacks = callbacks;
    this.init();
  }

  /** Called by App.tsx from mobile joystick touch events */
  public setJoystickInput(dx: number, dy: number) {
    this.joystickX = dx;
    this.joystickY = dy;
  }

  /** Called by App.tsx FIRE button */
  public triggerFire() {
    if (this.phase === 'combat') this.fireCannonball();
  }

  private init() {
    this.setupRenderer();
    this.setupScene();
    this.buildWaterAndSky();
    this.buildEnvironment();
    this.buildPlayerShip();
    this.buildAlienFleet();
    this.setupPostprocessing();
    this.setupInput();
    this.startIntroSequence();
    this.animate();
  }

  private setupRenderer() {
    const testCtx = this.canvas.getContext('webgl2') || this.canvas.getContext('webgl');
    if (!testCtx) throw new Error('WebGL is not supported in this browser.');

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: window.devicePixelRatio < 2,
      powerPreference: 'high-performance',
      failIfMajorPerformanceCaveat: false,
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(this.canvas.clientWidth, this.canvas.clientHeight);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    window.addEventListener('resize', this.onResize);
  }

  private setupScene() {
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.FogExp2(0x1a2a44, 0.0006);

    this.camera = new THREE.PerspectiveCamera(65, this.canvas.clientWidth / this.canvas.clientHeight, 0.5, 10000);
    this.camera.position.set(0, 400, 0);
    this.camera.lookAt(0, 0, 0);

    // Ambient — moody blue-teal
    this.ambientLight = new THREE.AmbientLight(0x334466, 0.7);
    this.scene.add(this.ambientLight);

    // Hemisphere
    const hemi = new THREE.HemisphereLight(0xff8844, 0x223355, 0.55);
    this.scene.add(hemi);

    // Sun directional (golden hour)
    this.directionalLight = new THREE.DirectionalLight(0xff9955, 2.8);
    this.directionalLight.position.set(300, 200, -500);
    this.directionalLight.castShadow = true;
    this.directionalLight.shadow.mapSize.set(2048, 2048);
    this.directionalLight.shadow.camera.near = 1;
    this.directionalLight.shadow.camera.far = 2000;
    this.directionalLight.shadow.camera.left = -300;
    this.directionalLight.shadow.camera.right = 300;
    this.directionalLight.shadow.camera.top = 300;
    this.directionalLight.shadow.camera.bottom = -300;
    this.directionalLight.shadow.bias = -0.0004;
    this.scene.add(this.directionalLight);

    // Neon fill from alien side
    const alienFill = new THREE.DirectionalLight(0x8833ff, 0.8);
    alienFill.position.set(0, 100, -400);
    this.scene.add(alienFill);
  }

  private buildWaterAndSky() {
    this.sun = new THREE.Vector3();
    const sky = new Sky();
    sky.scale.setScalar(10000);
    this.scene.add(sky);

    const skyU = (sky.material as THREE.ShaderMaterial).uniforms;
    skyU['turbidity'].value = 7;
    skyU['rayleigh'].value = 3.2;
    skyU['mieCoefficient'].value = 0.007;
    skyU['mieDirectionalG'].value = 0.84;

    // Golden sunset
    const phi = THREE.MathUtils.degToRad(90 - 4);
    const theta = THREE.MathUtils.degToRad(190);
    this.sun.setFromSphericalCoords(1, phi, theta);
    skyU['sunPosition'].value.copy(this.sun);

    // Water — use CDN normals first, then procedural as fallback texture
    const waterNormals = loadTex(TEX_URLS.waterNormals, 1);
    waterNormals.wrapS = waterNormals.wrapT = THREE.RepeatWrapping;

    const waterGeo = new THREE.PlaneGeometry(12000, 12000, 128, 128);
    this.water = new Water(waterGeo, {
      textureWidth: 1024,
      textureHeight: 1024,
      waterNormals,
      sunDirection: this.sun.clone().normalize(),
      sunColor: 0xff9944,
      waterColor: 0x001a2e,
      distortionScale: 6.0,
      fog: true,
    });
    this.water.rotation.x = -Math.PI / 2;
    this.water.position.y = -1;
    this.scene.add(this.water);

    // Put the procedural high-detail normal map in as a second layer fallback
    // (will be ready immediately, CDN one replaces it once loaded)
    const procNorm = makeWaterNormal();
    (this.water.material as THREE.ShaderMaterial).uniforms['tWaterNormals'] =
      (this.water.material as THREE.ShaderMaterial).uniforms['tWaterNormals'] ||
      { value: procNorm };
  }

  private buildEnvironment() {
    const rockMat = new THREE.MeshStandardMaterial({ color: 0x2a2820, roughness: 0.96 });
    [[-600, 0, -800], [750, 0, -600], [-420, 0, 620], [820, 0, 420]].forEach(([x, , z]) => {
      const h = 35 + Math.random() * 65;
      const r = new THREE.Mesh(new THREE.CylinderGeometry(15 + Math.random() * 25, 30 + Math.random() * 25, h, 6), rockMat);
      r.position.set(x, h / 2 - 1, z);
      r.rotation.y = Math.random() * Math.PI;
      r.castShadow = true;
      this.scene.add(r);
    });

    const debMat = new THREE.MeshStandardMaterial({ color: 0x4a2c0a, roughness: 0.92 });
    for (let i = 0; i < 14; i++) {
      const d = new THREE.Mesh(new THREE.BoxGeometry(2 + Math.random() * 4, 0.4, 1 + Math.random() * 3), debMat);
      d.position.set((Math.random() - 0.5) * 500, -0.5, (Math.random() - 0.5) * 500);
      d.rotation.y = Math.random() * Math.PI;
      this.scene.add(d);
    }
  }

  private buildPlayerShip() {
    this.playerShip = buildPirateShip();
    this.playerShip.position.set(0, 2.5, 180);
    this.playerShip.rotation.y = Math.PI;
    this.scene.add(this.playerShip);

    // Lantern lights on ship
    const shipLight = new THREE.PointLight(0xffcc88, 5, 70);
    shipLight.position.set(0, 15, 0);
    this.playerShip.add(shipLight);

    const bowLight = new THREE.PointLight(0xffaa44, 3, 40);
    bowLight.position.set(0, 8, -38);
    this.playerShip.add(bowLight);

    // ── Hero cyborg character on deck ──────────────────────────────────────
    this.playerChar = buildCyborgCharacter(false, 0x00eeff);
    // Place on poop deck
    this.playerChar.position.set(0, 9.5, 202); // on deck behind main mast
    this.playerChar.rotation.y = Math.PI; // face forward (toward bow)
    this.scene.add(this.playerChar);
  }

  private buildAlienFleet() {
    // Colors: boss = purple, minion1 = green, minion2 = red
    const configs = [
      { pos: new THREE.Vector3(0,   190, -280), color: 0xff00ff, isBoss: true,  hp: 60, delay: 4.5 },
      { pos: new THREE.Vector3(-130, 155, -240), color: 0x00ff88, isBoss: false, hp: 30, delay: 5.2 },
      { pos: new THREE.Vector3( 130, 155, -240), color: 0xff4400, isBoss: false, hp: 30, delay: 5.8 },
    ];

    configs.forEach((cfg, idx) => {
      const { group, ring, glow } = buildUFO(cfg.isBoss, cfg.color);
      group.position.copy(cfg.pos);
      this.scene.add(group);

      // Alien mech character sitting on top of UFO
      const char = buildCyborgCharacter(cfg.isBoss, cfg.color);
      char.position.set(0, cfg.isBoss ? 10 : 7, 0);
      char.rotation.y = Math.PI;
      group.add(char);

      const alien: AlienShip = {
        group,
        hp: cfg.hp,
        maxHP: cfg.hp,
        fireTimer: cfg.delay + idx * 1.2,
        alive: true,
        ring,
        glow,
        moveOffset: idx * 2.1,
      };
      this.alienFleet.push(alien);
    });

    // UFO formation neon strip lights in sky
    for (let i = 0; i < 6; i++) {
      const strip = new THREE.PointLight(
        [0xff00ff, 0x00ff88, 0xff4400, 0x00aaff, 0xffaa00, 0xff00aa][i],
        2.5, 150
      );
      strip.position.set((Math.random() - 0.5) * 400, 120 + Math.random() * 80, -200 + (Math.random() - 0.5) * 200);
      this.scene.add(strip);
    }

    this.callbacks.onStateChange({ aliensAlive: this.alienFleet.length, aliensTotal: this.alienFleet.length });
  }

  private setupPostprocessing() {
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));

    const bloom = new UnrealBloomPass(
      new THREE.Vector2(this.canvas.clientWidth, this.canvas.clientHeight),
      1.1,   // strength
      0.55,  // radius
      0.72,  // threshold
    );
    this.composer.addPass(bloom);
    this.composer.addPass(new OutputPass());
  }

  private setupInput() {
    window.addEventListener('keydown', (e) => { this.keys[e.code] = true; });
    window.addEventListener('keyup', (e) => { this.keys[e.code] = false; });
    this.canvas.addEventListener('click', () => {
      if (this.phase === 'combat') this.fireCannonball();
    });
  }

  // ─── Cinematic sequence (exactly 9 seconds) ────────────────────────────────
  private startIntroSequence() {
    this.callbacks.onStateChange({ phase: 'intro', phaseTitle: 'ALIEN INVASION', showControls: false });

    const cam = this.camera;
    // Key world positions
    const playerPos   = new THREE.Vector3(0, 10.5, 202); // player char center
    const deckPos     = new THREE.Vector3(0, 5, 180);
    const bossPos     = this.alienFleet[0]?.group.position.clone() ?? new THREE.Vector3(0, 190, -280);
    const fleetCenter = new THREE.Vector3(0, 168, -260);

    const tl = gsap.timeline();

    // ── 0s: Start wide, high, behind ──────────────────────────────────────
    tl.set(cam.position, { x: 0, y: 220, z: 550 });
    tl.call(() => cam.lookAt(deckPos.x, deckPos.y, deckPos.z));

    // ── 0 → 3s: ULTRA-FAST SWOOP to player face-level ─────────────────────
    tl.to(cam.position, {
      x: 0, y: 10.5, z: 222,
      duration: 3.0,
      ease: 'power3.in',
      onUpdate: () => {
        // Smoothly blend look target from deck to player char
        cam.lookAt(playerPos.x, playerPos.y, playerPos.z);
      },
    });

    // ── 3 → 4s: Hold tight on player; ambient beat ────────────────────────
    tl.to(cam.position, {
      x: 3, y: 11, z: 225,
      duration: 1.0,
      ease: 'sine.inOut',
      onUpdate: () => cam.lookAt(playerPos.x, playerPos.y, playerPos.z),
    });

    // ── 4s: Player "looks up" — rotate character head/torso ───────────────
    tl.to(this.playerChar.rotation, {
      x: -0.55,
      duration: 0.18,
      ease: 'power4.out',
    }, '<0.8');

    // ── 4 → 7s: VIOLENT PAN UP → reveal alien fleet ───────────────────────
    tl.to(cam.position, {
      x: -60, y: 130, z: 320,
      duration: 3.0,
      ease: 'power2.inOut',
      onUpdate: () => cam.lookAt(fleetCenter.x, fleetCenter.y, fleetCenter.z),
      onStart: () => {
        this.callbacks.onStateChange({ phaseTitle: 'THE ALIEN FLEET ARRIVES…' });
      },
    });

    // Mid-alien-reveal: push tighter toward boss UFO
    tl.to(cam.position, {
      x: 20, y: 160, z: 180,
      duration: 1.5,
      ease: 'power1.inOut',
      onUpdate: () => cam.lookAt(bossPos.x, bossPos.y, bossPos.z),
    }, '-=1.2');

    // ── 7 → 9s: Camera DROPS back to perfect 3rd-person behind player ──────
    tl.to(cam.position, {
      x: 0, y: 32, z: 275,
      duration: 2.0,
      ease: 'power3.inOut',
      onUpdate: () => cam.lookAt(0, 12, -200),
      onStart: () => {
        this.callbacks.onStateChange({ phaseTitle: '' });
        // Snap player char back upright
        gsap.to(this.playerChar.rotation, { x: 0, duration: 0.6, ease: 'back.out(1.5)' });
      },
      onComplete: () => {
        // ── 9s: UNLOCK mobile controls ─────────────────────────────────────
        this.phase = 'combat';
        this.combatStarted = true;
        this.cinematicDone = true;
        this.callbacks.onStateChange({
          phase: 'combat',
          phaseTitle: 'BATTLE STATIONS!',
          showControls: true,
        });
        setTimeout(() => this.callbacks.onStateChange({ phaseTitle: '' }), 2800);
      },
    });
  }

  // ─── Combat: fire cannonball ───────────────────────────────────────────────
  private fireCannonball() {
    if (this.canFireTimer > 0) return;
    this.canFireTimer = 0.55;
    const side = this.fireFromLeft ? -1 : 1;
    this.fireFromLeft = !this.fireFromLeft;
    const sp = this.playerShip.position;
    const sr = this.playerShip.rotation.y;
    const ox = side * 12 * Math.cos(sr + Math.PI / 2);
    const oz = side * 12 * Math.sin(sr + Math.PI / 2);
    const origin = new THREE.Vector3(sp.x + ox, sp.y + 5, sp.z + oz);

    let target = new THREE.Vector3(0, 10, -600);
    let nearestDist = Infinity;
    this.alienFleet.forEach(a => {
      if (!a.alive) return;
      const d = origin.distanceTo(a.group.position);
      if (d < nearestDist) { nearestDist = d; target = a.group.position.clone(); }
    });

    const dir = target.clone().sub(origin).normalize();
    const geo = new THREE.SphereGeometry(0.75, 8, 8);
    const mat = new THREE.MeshStandardMaterial({ color: 0x333322, metalness: 0.92, roughness: 0.15 });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.copy(origin);
    this.scene.add(mesh);
    const trail = buildProjectileTrail(false);
    this.scene.add(trail);
    this.projectiles.push({ mesh, velocity: dir.multiplyScalar(130), type: 'cannonball', lifetime: 0, trail, trailPositions: trail.geometry.attributes.position.array as Float32Array });

    const flash = new THREE.PointLight(0xffaa44, 35, 22);
    flash.position.copy(origin);
    this.scene.add(flash);
    setTimeout(() => this.scene.remove(flash), 110);
    const smoke = buildParticleBurst(origin, 0x777777, 14);
    this.scene.add(smoke.mesh);
    this.particles.push(smoke);
  }

  // ─── Combat: alien fires laser ────────────────────────────────────────────
  private fireAlienLaser(alien: AlienShip) {
    const origin = alien.group.position.clone();
    origin.y -= 4;
    const target = this.playerShip.position.clone();
    target.y += 6;
    const dir = target.clone().sub(origin).normalize();
    const laserGeo = new THREE.CylinderGeometry(0.32, 0.32, 7, 8);
    const laserMat = new THREE.MeshStandardMaterial({ color: alien.glow.color, emissive: alien.glow.color, emissiveIntensity: 5.0 });
    const mesh = new THREE.Mesh(laserGeo, laserMat);
    mesh.position.copy(origin);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
    this.scene.add(mesh);
    const trail = buildProjectileTrail(true);
    this.scene.add(trail);
    this.projectiles.push({ mesh, velocity: dir.multiplyScalar(95), type: 'laser', lifetime: 0, trail, trailPositions: trail.geometry.attributes.position.array as Float32Array });
    alien.glow.intensity = 28;
    setTimeout(() => { if (alien.alive) alien.glow.intensity = 9; }, 160);
  }

  // ─── Explosion ────────────────────────────────────────────────────────────
  private spawnExplosion(position: THREE.Vector3, isAlien: boolean) {
    const col = isAlien ? 0x00ff88 : 0xff6600;
    const b1 = buildParticleBurst(position, col, 36);
    const b2 = buildParticleBurst(position, isAlien ? 0x00ccff : 0xffcc44, 18);
    b2.maxLifetime = 0.9;
    [b1, b2].forEach(b => { this.scene.add(b.mesh); this.particles.push(b); });
    const light = new THREE.PointLight(col, 55, 110);
    light.position.copy(position);
    this.scene.add(light);
    gsap.to(light, { intensity: 0, duration: 0.65, onComplete: () => this.scene.remove(light) });
  }

  // ─── Resize ───────────────────────────────────────────────────────────────
  private onResize = () => {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
  };

  // ─── Update: player ship movement ─────────────────────────────────────────
  private updatePlayerShip(dt: number) {
    if (!this.combatStarted) return;

    const maxSpeed   = 55;
    const accel      = 40;
    const rotSpeed   = 0.9;

    const fwd  = this.keys['KeyW'] || this.keys['ArrowUp']    || this.joystickY < -0.28;
    const bwd  = this.keys['KeyS'] || this.keys['ArrowDown']  || this.joystickY >  0.28;
    const rotL = this.keys['KeyA'] || this.keys['ArrowLeft']  || this.joystickX < -0.28;
    const rotR = this.keys['KeyD'] || this.keys['ArrowRight'] || this.joystickX >  0.28;

    if (fwd)  this.playerSpeed = Math.min(this.playerSpeed + accel * dt, maxSpeed);
    else if (bwd) this.playerSpeed = Math.max(this.playerSpeed - accel * dt, -maxSpeed * 0.5);
    else this.playerSpeed *= 0.96;

    if (rotL) this.playerRotation += rotSpeed * dt;
    if (rotR) this.playerRotation -= rotSpeed * dt;

    this.playerShip.rotation.y = this.playerRotation + Math.PI;
    const fwdX = Math.sin(this.playerRotation);
    const fwdZ = Math.cos(this.playerRotation);
    this.playerShip.position.x += fwdX * this.playerSpeed * dt;
    this.playerShip.position.z += fwdZ * this.playerSpeed * dt;

    // Keep ship on water surface with gentle bob
    const t = this.clock.getElapsedTime();
    this.playerShip.position.y = 2.5 + Math.sin(t * 0.6) * 0.4;
    this.playerShip.rotation.x = Math.sin(t * 0.5) * 0.018;
    this.playerShip.rotation.z = Math.cos(t * 0.7) * 0.012;

    // Move player char with ship
    this.playerChar.position.set(
      this.playerShip.position.x,
      this.playerShip.position.y + 7.0,
      this.playerShip.position.z + 22 * Math.cos(this.playerShip.rotation.y),
    );
    this.playerChar.rotation.y = this.playerShip.rotation.y;

    this.canFireTimer = Math.max(0, this.canFireTimer - dt);
  }

  // ─── Update: alien fleet ──────────────────────────────────────────────────
  private updateAlienFleet(dt: number) {
    if (!this.combatStarted) return;
    const t = this.clock.getElapsedTime();
    let aliensAlive = 0;

    this.alienFleet.forEach((alien, idx) => {
      if (!alien.alive) return;
      aliensAlive++;

      // Hovering figure-8 orbit
      const spd = alien.group.userData.isBoss ? 0.25 : 0.35;
      alien.group.position.x += Math.sin(t * spd + alien.moveOffset) * 12 * dt;
      alien.group.position.y  = alien.group.userData.baseY + Math.sin(t * 0.55 + alien.moveOffset) * 8;
      alien.group.position.z += Math.cos(t * spd * 0.7 + alien.moveOffset) * 6 * dt;

      // Ring spin
      if (alien.ring) {
        alien.ring.rotation.y += dt * (idx === 0 ? 1.1 : 0.8);
        alien.ring.rotation.x += dt * 0.15;
      }

      // Glow pulse
      alien.glow.intensity = 9 + Math.sin(t * 2.5 + idx) * 2.5;

      // Face player ship
      alien.group.lookAt(this.playerShip.position.x, alien.group.position.y, this.playerShip.position.z);

      // Fire
      alien.fireTimer -= dt;
      if (alien.fireTimer <= 0) {
        this.fireAlienLaser(alien);
        alien.fireTimer = 3.2 + Math.random() * 2.0;
      }
    });

    if (aliensAlive === 0 && this.phase === 'combat') {
      this.phase = 'victory';
      this.callbacks.onStateChange({ phase: 'victory', phaseTitle: 'VICTORY!' });
    }
    this.callbacks.onStateChange({ aliensAlive, aliensTotal: this.alienFleet.length });
  }

  // ─── Update: projectiles ──────────────────────────────────────────────────
  private updateProjectiles(dt: number) {
    const toRemove: Projectile[] = [];

    this.projectiles.forEach(proj => {
      proj.lifetime += dt;
      if (proj.lifetime > (proj.type === 'cannonball' ? 6 : 4)) { toRemove.push(proj); return; }
      if (proj.type === 'cannonball') proj.velocity.y -= 18 * dt;
      proj.mesh.position.addScaledVector(proj.velocity, dt);

      // Update trail
      const positions = proj.trailPositions;
      for (let i = 19; i > 0; i--) {
        positions[i * 3]     = positions[(i - 1) * 3];
        positions[i * 3 + 1] = positions[(i - 1) * 3 + 1];
        positions[i * 3 + 2] = positions[(i - 1) * 3 + 2];
      }
      positions[0] = proj.mesh.position.x;
      positions[1] = proj.mesh.position.y;
      positions[2] = proj.mesh.position.z;
      proj.trail.geometry.attributes.position.needsUpdate = true;

      // Hit detection
      if (proj.type === 'cannonball') {
        this.alienFleet.forEach(a => {
          if (!a.alive) return;
          if (proj.mesh.position.distanceTo(a.group.position) < 14) {
            toRemove.push(proj);
            a.hp -= 15;
            if (a.hp <= 0) {
              a.alive = false;
              this.spawnExplosion(a.group.position.clone(), true);
              this.scene.remove(a.group);
            } else {
              // Hit flash
              a.glow.intensity = 40;
              setTimeout(() => { if (a.alive) a.glow.intensity = 9; }, 200);
            }
          }
        });
      } else {
        // Laser hits player ship
        if (proj.mesh.position.distanceTo(this.playerShip.position) < 16) {
          toRemove.push(proj);
          this.playerHP = Math.max(0, this.playerHP - 8);
          this.callbacks.onStateChange({ playerHP: this.playerHP });
          this.spawnExplosion(proj.mesh.position.clone(), false);
          if (this.playerHP === 0 && this.phase === 'combat') {
            this.phase = 'defeat';
            this.callbacks.onStateChange({ phase: 'defeat', phaseTitle: 'DEFEAT…' });
          }
        }
        if (proj.mesh.position.y < -2) toRemove.push(proj);
      }
    });

    toRemove.forEach(p => {
      this.scene.remove(p.mesh);
      this.scene.remove(p.trail);
      const idx = this.projectiles.indexOf(p);
      if (idx !== -1) this.projectiles.splice(idx, 1);
    });
  }

  // ─── Update: particles ────────────────────────────────────────────────────
  private updateParticles(dt: number) {
    const toRemove: Particle[] = [];
    this.particles.forEach(p => {
      p.lifetime += dt;
      if (p.lifetime > p.maxLifetime) { toRemove.push(p); return; }
      (p.mesh.material as THREE.PointsMaterial).opacity = 1 - p.lifetime / p.maxLifetime;
      const positions = p.mesh.geometry.attributes.position.array as Float32Array;
      for (let i = 0; i < p.velocities.length; i++) {
        const v = p.velocities[i];
        positions[i * 3]     += v.x * dt;
        positions[i * 3 + 1] += (v.y - 12 * dt) * dt;
        positions[i * 3 + 2] += v.z * dt;
        v.y -= 12 * dt;
      }
      p.mesh.geometry.attributes.position.needsUpdate = true;
    });
    toRemove.forEach(p => {
      this.scene.remove(p.mesh);
      const idx = this.particles.indexOf(p);
      if (idx !== -1) this.particles.splice(idx, 1);
    });
  }

  // ─── Main loop ────────────────────────────────────────────────────────────
  private animate = () => {
    this.animFrameId = requestAnimationFrame(this.animate);
    const dt = Math.min(this.clock.getDelta(), 0.05);
    const t = this.clock.getElapsedTime();

    // Water animation
    (this.water.material as THREE.ShaderMaterial).uniforms['time'].value += dt * 0.5;
    const sunDir = this.sun.clone();
    sunDir.y += Math.sin(t * 0.3) * 0.01;
    (this.water.material as THREE.ShaderMaterial).uniforms['sunDirection'].value.copy(sunDir.normalize());

    // ── Breathing animations (always active) ─────────────────────────────
    // Player cyborg
    if (this.playerChar) {
      const breathY = Math.sin(t * 1.6) * 0.12;
      const breathS = 1.0 + Math.sin(t * 1.6) * 0.018;
      this.playerChar.position.y += breathY * dt;      // continuous drift
      this.playerChar.scale.setScalar(breathS);
    }

    // Alien cyborg breathe
    this.alienFleet.forEach((alien, idx) => {
      if (!alien.alive) return;
      // Store base Y on first frame
      if (!alien.group.userData.baseY) alien.group.userData.baseY = alien.group.position.y;
      const charGroup = alien.group.children.find(c => c instanceof THREE.Group) as THREE.Group;
      if (charGroup) {
        charGroup.scale.setScalar(1.0 + Math.sin(t * 1.4 + idx * 0.8) * 0.025);
      }
    });

    this.updatePlayerShip(dt);
    this.updateAlienFleet(dt);
    this.updateProjectiles(dt);
    this.updateParticles(dt);

    this.composer.render();
  };

  destroy() {
    cancelAnimationFrame(this.animFrameId);
    window.removeEventListener('resize', this.onResize);
    this.renderer.dispose();
  }
}
