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

// ─── CC0 Texture CDNs ─────────────────────────────────────────────────────────
const T3 = 'https://cdn.jsdelivr.net/npm/three@0.160.0/examples/textures';
const PH = 'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k';
const TEXTURES = {
  waterNormals: `${T3}/waternormals.jpg`,
  woodDiff:  `${PH}/wood_planks_dirt/wood_planks_dirt_diff_1k.jpg`,
  woodRough: `${PH}/wood_planks_dirt/wood_planks_dirt_rough_1k.jpg`,
  woodNorm:  `${PH}/wood_planks_dirt/wood_planks_dirt_nor_gl_1k.jpg`,
  metalDiff: `${PH}/rusty_metal_02/rusty_metal_02_diff_1k.jpg`,
  metalRough:`${PH}/rusty_metal_02/rusty_metal_02_rough_1k.jpg`,
  metalNorm: `${PH}/rusty_metal_02/rusty_metal_02_nor_gl_1k.jpg`,
};

const tLoader = new THREE.TextureLoader();
function loadTex(url: string, rep = 4): THREE.Texture {
  const t = tLoader.load(url);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(rep, rep);
  return t;
}

// ─── Procedural water normal (1024 px, very detailed) ─────────────────────────
function makeWaterNormal(): THREE.Texture {
  const sz = 512;
  const cv = document.createElement('canvas');
  cv.width = cv.height = sz;
  const cx = cv.getContext('2d')!;
  const id = cx.createImageData(sz, sz);
  for (let y = 0; y < sz; y++) {
    for (let x = 0; x < sz; x++) {
      const i = (y * sz + x) * 4;
      const u = x / sz, v = y / sz;
      const w1 = Math.sin(u * Math.PI * 18 + v * Math.PI * 5);
      const w2 = Math.cos(v * Math.PI * 14 - u * Math.PI * 7);
      const w3 = Math.sin((u + v) * Math.PI * 10);
      const w4 = Math.cos((u * 2 - v) * Math.PI * 22);
      id.data[i]     = Math.max(0, Math.min(255, ((w1 * 0.35 + w3 * 0.15) * 0.5 + 0.5) * 255));
      id.data[i + 1] = Math.max(0, Math.min(255, ((w2 * 0.35 + w4 * 0.15) * 0.5 + 0.5) * 255));
      id.data[i + 2] = 210;
      id.data[i + 3] = 255;
    }
  }
  cx.putImageData(id, 0, 0);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

// ─── Pirate ship ──────────────────────────────────────────────────────────────
function buildPirateShip(): THREE.Group {
  const g = new THREE.Group();

  const wD = loadTex(TEXTURES.woodDiff, 5);
  const wR = loadTex(TEXTURES.woodRough, 5);
  const wN = loadTex(TEXTURES.woodNorm, 5);
  const mD = loadTex(TEXTURES.metalDiff, 2);
  const mR = loadTex(TEXTURES.metalRough, 2);
  const mN = loadTex(TEXTURES.metalNorm, 2);

  const hullMat = new THREE.MeshStandardMaterial({
    color: 0x7A3A10, map: wD, roughnessMap: wR, normalMap: wN,
    normalScale: new THREE.Vector2(1.5, 1.5), roughness: 0.85, metalness: 0.04,
  });
  const deckMat = new THREE.MeshStandardMaterial({
    color: 0x5C2A08, map: wD, roughnessMap: wR, normalMap: wN,
    normalScale: new THREE.Vector2(1.2, 1.2), roughness: 0.9, metalness: 0.0,
  });
  const metalMat = new THREE.MeshStandardMaterial({
    color: 0x888877, map: mD, roughnessMap: mR, normalMap: mN,
    normalScale: new THREE.Vector2(1.0, 1.0), roughness: 0.38, metalness: 0.85,
  });
  const sailMat = new THREE.MeshStandardMaterial({ color: 0xDDD0A8, roughness: 0.85, side: THREE.DoubleSide });

  const mesh = (geo: THREE.BufferGeometry, mat: THREE.Material) => {
    const m = new THREE.Mesh(geo, mat);
    m.castShadow = m.receiveShadow = true;
    return m;
  };

  g.add(mesh(new THREE.BoxGeometry(20, 7, 60), hullMat));                         // hull

  const bow = mesh(new THREE.CylinderGeometry(0, 10, 10, 4), deckMat);
  bow.position.set(0, 0, -35); bow.rotation.set(Math.PI / 2, 0, Math.PI / 4);
  g.add(bow);

  const stern = mesh(new THREE.BoxGeometry(20, 10, 10), hullMat);
  stern.position.set(0, 5, 28); g.add(stern);

  const deck = mesh(new THREE.BoxGeometry(19, 1, 58), deckMat);
  deck.position.y = 4; g.add(deck);

  const fore = mesh(new THREE.BoxGeometry(16, 3, 12), hullMat);
  fore.position.set(0, 5.5, -24); g.add(fore);

  const poop = mesh(new THREE.BoxGeometry(16, 3, 14), hullMat);
  poop.position.set(0, 5.5, 22); g.add(poop);

  // Masts + sails + yards
  [{ z: -18, h: 42 }, { z: 2, h: 48 }, { z: 20, h: 36 }].forEach(({ z, h }) => {
    const mast = mesh(new THREE.CylinderGeometry(0.45, 0.65, h, 8), deckMat);
    mast.position.set(0, 4 + h / 2, z); g.add(mast);
    const yard = mesh(new THREE.CylinderGeometry(0.22, 0.22, 22, 8), deckMat);
    yard.position.set(0, 4 + h * 0.78, z); yard.rotation.z = Math.PI / 2; g.add(yard);
    [-1, 1].forEach(s => {
      const sail = mesh(new THREE.PlaneGeometry(9.5, h * 0.55), sailMat);
      sail.position.set(s * 5, 4 + h * 0.78 - h * 0.14, z); g.add(sail);
    });
  });

  // Cannons
  [-1, 1].forEach(s => {
    for (let ci = 0; ci < 6; ci++) {
      const z = -20 + ci * 8;
      const barrel = mesh(new THREE.CylinderGeometry(0.6, 0.7, 6, 10), metalMat);
      barrel.position.set(s * 11, 1.5, z); barrel.rotation.z = Math.PI / 2; g.add(barrel);
    }
  });

  // Railings
  [-9, 9].forEach(sx => {
    for (let pi = 0; pi < 10; pi++) {
      const post = mesh(new THREE.CylinderGeometry(0.18, 0.18, 2.5, 5), deckMat);
      post.position.set(sx, 6.2, -22 + pi * 5); g.add(post);
    }
    const rail = mesh(new THREE.BoxGeometry(0.25, 0.25, 48), deckMat);
    rail.position.set(sx, 7.5, 0); g.add(rail);
  });

  // Flag
  const flag = mesh(new THREE.PlaneGeometry(5, 3.5), new THREE.MeshStandardMaterial({ color: 0x111111, side: THREE.DoubleSide }));
  flag.position.set(2, 56, 2); flag.rotation.y = 0.3; g.add(flag);

  return g;
}

// ─── Cyborg / Mech character builder ──────────────────────────────────────────
// Returns the group. Weapon arm stored in group.userData.weaponArm
function buildCyborgCharacter(isBoss: boolean, accentColor: number): THREE.Group {
  const g = new THREE.Group();
  const sc = isBoss ? 1.6 : 1.0;

  const chrome = new THREE.MeshPhysicalMaterial({
    color: isBoss ? 0x1a001a : 0x0a0a14,
    metalness: 0.92, roughness: 0.12,
    clearcoat: 1.0, clearcoatRoughness: 0.06,
  });
  const accent = new THREE.MeshPhysicalMaterial({
    color: accentColor, metalness: 0.75, roughness: 0.2, clearcoat: 0.6,
  });
  // *** EMISSIVE INTENSITY FIXED: was 3.5/2.8 now 0.9/0.7 to prevent white screen ***
  const visor = new THREE.MeshPhysicalMaterial({
    color: accentColor, emissive: accentColor,
    emissiveIntensity: isBoss ? 0.9 : 0.7,
    metalness: 0.2, roughness: 0.0, transparent: true, opacity: 0.9,
  });
  const joint = new THREE.MeshPhysicalMaterial({
    color: 0x222233, metalness: 0.88, roughness: 0.25, clearcoat: 0.4,
  });

  const mk = (geo: THREE.BufferGeometry, mat: THREE.Material) => {
    const m = new THREE.Mesh(geo, mat);
    m.castShadow = true;
    return m;
  };

  // Torso
  const torsoY = 3.5 * sc + 3.5 * sc;
  const torso = mk(new THREE.BoxGeometry(2.6 * sc, 3.8 * sc, 1.8 * sc), chrome);
  torso.position.y = 3.5 * sc + 1.9 * sc; g.add(torso);

  const chestPlate = mk(new THREE.BoxGeometry(1.8 * sc, 2.0 * sc, 0.18), accent);
  chestPlate.position.set(0, 3.5 * sc + 1.9 * sc, 0.92 * sc); g.add(chestPlate);

  const core = mk(new THREE.SphereGeometry(0.42 * sc, 16, 16), visor);
  core.position.set(0, 3.5 * sc + 1.9 * sc, 1.0 * sc); g.add(core);

  // Head
  const headY = 3.5 * sc + 3.8 * sc + 1.0 * sc;
  const head = mk(new THREE.BoxGeometry(2.2 * sc, 2.0 * sc, 2.0 * sc), chrome);
  head.position.y = headY; g.add(head);

  const visorMesh = mk(new THREE.BoxGeometry(1.8 * sc, 0.5 * sc, 0.1), visor);
  visorMesh.position.set(0, headY + 0.2 * sc, 1.0 * sc); g.add(visorMesh);

  if (isBoss) {
    const ant = mk(new THREE.CylinderGeometry(0.08, 0.12, 2.0, 6), accent);
    ant.position.set(0, headY + 1.7 * sc, 0); g.add(ant);
    const antTop = mk(new THREE.SphereGeometry(0.22, 8, 8), visor);
    antTop.position.set(0, headY + 2.8 * sc, 0); g.add(antTop);
  }

  // Shoulders + arms
  [-1, 1].forEach((side, sIdx) => {
    const shoulderY = 3.5 * sc + 3.0 * sc;
    const shoulder = mk(new THREE.SphereGeometry(0.85 * sc, 10, 10), accent);
    shoulder.position.set(side * 1.95 * sc, shoulderY, 0); g.add(shoulder);

    const uarm = mk(new THREE.CylinderGeometry(0.38 * sc, 0.32 * sc, 2.4 * sc, 8), chrome);
    uarm.position.set(side * 2.55 * sc, shoulderY - 1.2 * sc, 0);
    uarm.rotation.z = side * 0.18; g.add(uarm);

    const elbow = mk(new THREE.SphereGeometry(0.35 * sc, 8, 8), joint);
    elbow.position.set(side * 2.7 * sc, shoulderY - 2.5 * sc, 0); g.add(elbow);

    const farm = mk(new THREE.CylinderGeometry(0.3 * sc, 0.38 * sc, 2.2 * sc, 8), chrome);
    farm.position.set(side * 3.0 * sc, shoulderY - 3.8 * sc, 0);
    farm.rotation.z = side * 0.28; g.add(farm);

    // Weapon (right arm for gunners) — stored in userData for animation
    const wMat = new THREE.MeshPhysicalMaterial({
      color: accentColor, emissive: accentColor, emissiveIntensity: 0.5,
      metalness: 0.7, roughness: 0.25,
    });
    const weaponGeo = isBoss
      ? new THREE.BoxGeometry(0.5 * sc, 0.5 * sc, 2.6 * sc)
      : new THREE.CylinderGeometry(0.26 * sc, 0.34 * sc, 2.2 * sc, 6);
    const weapon = mk(weaponGeo, wMat);
    weapon.position.set(side * 3.2 * sc, shoulderY - 5.0 * sc, isBoss ? 0.6 * sc : 0);
    weapon.rotation.set(0, 0, side * 0.08);
    g.add(weapon);

    // Store right-side weapon for gun-look animation
    if (side === 1) g.userData.weaponArm = weapon;
  });

  // Pelvis + legs
  const pelvis = mk(new THREE.BoxGeometry(2.3 * sc, 1.1 * sc, 1.5 * sc), accent);
  pelvis.position.y = 3.0 * sc; g.add(pelvis);

  [-1, 1].forEach(side => {
    const thigh = mk(new THREE.CylinderGeometry(0.52 * sc, 0.42 * sc, 3.0 * sc, 8), chrome);
    thigh.position.set(side * 0.88 * sc, 1.5 * sc, 0); g.add(thigh);

    const knee = mk(new THREE.SphereGeometry(0.48 * sc, 8, 8), joint);
    knee.position.set(side * 0.88 * sc, 0.0, 0.1 * sc); g.add(knee);

    const shin = mk(new THREE.CylinderGeometry(0.35 * sc, 0.52 * sc, 2.8 * sc, 8), chrome);
    shin.position.set(side * 0.88 * sc, -1.4 * sc, 0.1 * sc); g.add(shin);

    const foot = mk(new THREE.BoxGeometry(0.88 * sc, 0.58 * sc, 1.7 * sc), accent);
    foot.position.set(side * 0.88 * sc, -2.85 * sc, 0.4 * sc); g.add(foot);
  });

  // Subtle glow point light (intensity lowered from 3.5 to 1.5)
  const gl = new THREE.PointLight(accentColor, 1.5, 10 * sc);
  gl.position.set(0, 3.5 * sc + 1.9 * sc, 1.5); g.add(gl);

  return g;
}

// ─── Helm/navigation console (inside boss UFO) ────────────────────────────────
function buildHelmConsole(color: number): THREE.Group {
  const g = new THREE.Group();
  const panelMat = new THREE.MeshPhysicalMaterial({
    color: 0x111122, metalness: 0.9, roughness: 0.15, clearcoat: 1.0,
  });
  const glowMat = new THREE.MeshPhysicalMaterial({
    color, emissive: color, emissiveIntensity: 0.8, roughness: 0.0, metalness: 0.3,
    transparent: true, opacity: 0.85,
  });
  // Base
  const base = new THREE.Mesh(new THREE.BoxGeometry(10, 1.5, 4), panelMat);
  base.castShadow = true; g.add(base);
  // Glowing display
  const display = new THREE.Mesh(new THREE.BoxGeometry(8, 3, 0.15), glowMat);
  display.position.set(0, 2.2, -1.8); display.rotation.x = -0.4; g.add(display);
  // Buttons / knobs
  [[-3, 0, 2.2], [0, 0, 2.2], [3, 0, 2.2]].forEach(([x, , z]) => {
    const btn = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.5, 8), glowMat);
    btn.position.set(x, 1.1, z); g.add(btn);
  });
  // Side flanges
  [-1, 1].forEach(s => {
    const flange = new THREE.Mesh(new THREE.BoxGeometry(1.5, 2.5, 3.5), panelMat);
    flange.position.set(s * 5.8, 0.8, 0); g.add(flange);
  });
  return g;
}

// ─── UFO builder ──────────────────────────────────────────────────────────────
function buildUFO(isBoss: boolean, color: number): { group: THREE.Group; ring: THREE.Mesh; glow: THREE.PointLight } {
  const g = new THREE.Group();
  const sc = isBoss ? 1.5 : 1.0;

  // *** EMISSIVE INTENSITY FIXED: was 4.0/3.0 now 1.2/0.8 ***
  const bodyMat = new THREE.MeshPhysicalMaterial({
    color: isBoss ? 0x110022 : 0x0a1822,
    metalness: 0.95, roughness: 0.06,
    clearcoat: 1.0, clearcoatRoughness: 0.03,
    side: THREE.DoubleSide,      // interior visible for cinematic shot
  });
  const glowMat = new THREE.MeshPhysicalMaterial({
    color, emissive: color,
    emissiveIntensity: isBoss ? 1.2 : 0.8,   // was 4.0/3.0 — fixed!
    roughness: 0.0, metalness: 0.3,
    transparent: true, opacity: 0.88,
  });

  // Disc body
  const topGeo = new THREE.SphereGeometry(10 * sc, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2.2);
  g.add(new THREE.Mesh(topGeo, bodyMat));

  const botGeo = new THREE.SphereGeometry(10 * sc, 32, 16, 0, Math.PI * 2, Math.PI / 2.2, Math.PI / 2.2);
  const bot = new THREE.Mesh(botGeo, bodyMat); bot.position.y = -0.5; g.add(bot);

  // Main ring
  const ring = new THREE.Mesh(new THREE.TorusGeometry(11.5 * sc, isBoss ? 1.3 : 0.9, 14, 60), glowMat);
  ring.position.y = -2 * sc; g.add(ring);

  // Inner rings
  [0.65, 0.4].forEach((rf, ri) => {
    const r = new THREE.Mesh(new THREE.TorusGeometry(rf * 11.5 * sc, 0.35 * sc, 8, 32), glowMat);
    r.position.y = -1.5 * sc + ri * 1.5 * sc; g.add(r);
  });

  // Cockpit dome — semi-transparent
  const domeGeo = new THREE.SphereGeometry(4.5 * sc, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2);
  const domeMat = new THREE.MeshPhysicalMaterial({
    color, emissive: color, emissiveIntensity: 0.3,
    transparent: true, opacity: 0.35,
    roughness: 0.0, metalness: 0.2, transmission: 0.5,
  });
  const dome = new THREE.Mesh(domeGeo, domeMat);
  dome.position.y = 3 * sc; g.add(dome);

  // Interior lighting (lowered from 12/8 to 4/2.5)
  const glow = new THREE.PointLight(color, isBoss ? 4 : 2.5, 60 * sc);
  glow.position.y = -4; g.add(glow);

  // Downward beam (boss only) — very faint
  if (isBoss) {
    const beamMat = new THREE.MeshBasicMaterial({
      color, transparent: true, opacity: 0.04, side: THREE.BackSide,
    });
    const beam = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 8, 80, 12, 1, true), beamMat);
    beam.position.y = -42; g.add(beam);
  }

  return { group: g, ring, glow };
}

// ─── Particles ────────────────────────────────────────────────────────────────
function buildParticleBurst(pos: THREE.Vector3, color: number, count = 28): Particle {
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  const velocities: THREE.Vector3[] = [];
  for (let i = 0; i < count; i++) {
    positions[i * 3] = pos.x; positions[i * 3 + 1] = pos.y; positions[i * 3 + 2] = pos.z;
    const theta = Math.random() * Math.PI * 2, phi = Math.random() * Math.PI;
    const spd = 10 + Math.random() * 22;
    velocities.push(new THREE.Vector3(
      Math.sin(phi) * Math.cos(theta) * spd,
      Math.abs(Math.cos(phi)) * spd * 0.9 + 5,
      Math.sin(phi) * Math.sin(theta) * spd,
    ));
  }
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const mat = new THREE.PointsMaterial({ color, size: 1.5, transparent: true, opacity: 1.0, sizeAttenuation: true });
  return { mesh: new THREE.Points(geo, mat), velocities, lifetime: 0, maxLifetime: 1.8 };
}

function buildProjectileTrail(isLaser: boolean): THREE.Points {
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(20 * 3);
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const mat = new THREE.PointsMaterial({
    color: isLaser ? 0x00ffaa : 0x888877,
    size: isLaser ? 0.9 : 0.6, transparent: true, opacity: 0.7, sizeAttenuation: true,
  });
  return new THREE.Points(geo, mat);
}

// ─── MAIN GAME CLASS ──────────────────────────────────────────────────────────
export class PirateGame {
  private canvas: HTMLCanvasElement;
  private renderer!: THREE.WebGLRenderer;
  private scene!: THREE.Scene;
  private camera!: THREE.PerspectiveCamera;
  private composer!: EffectComposer;
  private water!: Water;
  private sun!: THREE.Vector3;

  private playerShip!: THREE.Group;
  private playerChar!: THREE.Group;
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
  private keys: Record<string, boolean> = {};
  private joystickX = 0;
  private joystickY = 0;

  // Stored base Y for stable breathing
  private playerCharBaseY = 0;

  // Boss UFO world position (static during cinematic)
  private bossUFOPos = new THREE.Vector3(0, 190, -280);

  constructor(canvas: HTMLCanvasElement, callbacks: GameCallbacks) {
    this.canvas = canvas;
    this.callbacks = callbacks;
    this.init();
  }

  public setJoystickInput(dx: number, dy: number) {
    this.joystickX = dx;
    this.joystickY = dy;
  }

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
    if (!testCtx) throw new Error('WebGL not supported.');

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: window.devicePixelRatio < 2,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(this.canvas.clientWidth, this.canvas.clientHeight);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.85;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    window.addEventListener('resize', this.onResize);
  }

  private setupScene() {
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.FogExp2(0x1a2a44, 0.0006);

    this.camera = new THREE.PerspectiveCamera(
      65, this.canvas.clientWidth / this.canvas.clientHeight, 0.5, 10000,
    );
    this.camera.position.set(0, 400, 0);
    this.camera.lookAt(0, 0, 0);

    // *** LIGHT INTENSITIES REDUCED (was 0.7, 2.8, 0.8 — now 0.45, 1.4, 0.35) ***
    const ambient = new THREE.AmbientLight(0x334466, 0.45);
    this.scene.add(ambient);

    const hemi = new THREE.HemisphereLight(0xff8844, 0x223355, 0.4);
    this.scene.add(hemi);

    const sun = new THREE.DirectionalLight(0xff9955, 1.4);
    sun.position.set(300, 200, -500);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.near = 1;   sun.shadow.camera.far = 2000;
    sun.shadow.camera.left = -300; sun.shadow.camera.right = 300;
    sun.shadow.camera.top = 300;   sun.shadow.camera.bottom = -300;
    sun.shadow.bias = -0.0004;
    this.scene.add(sun);

    const alienFill = new THREE.DirectionalLight(0x8833ff, 0.35);
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
    skyU['rayleigh'].value = 3.0;
    skyU['mieCoefficient'].value = 0.007;
    skyU['mieDirectionalG'].value = 0.84;

    const phi = THREE.MathUtils.degToRad(86);
    const theta = THREE.MathUtils.degToRad(190);
    this.sun.setFromSphericalCoords(1, phi, theta);
    skyU['sunPosition'].value.copy(this.sun);

    const waterNormals = loadTex(TEXTURES.waterNormals, 1);
    waterNormals.wrapS = waterNormals.wrapT = THREE.RepeatWrapping;

    this.water = new Water(new THREE.PlaneGeometry(12000, 12000, 64, 64), {
      textureWidth: 512,
      textureHeight: 512,
      waterNormals,
      sunDirection: this.sun.clone().normalize(),
      sunColor: 0xff9944,
      waterColor: 0x001a2e,
      distortionScale: 5.0,
      fog: true,
    });
    this.water.rotation.x = -Math.PI / 2;
    this.water.position.y = -1;
    this.scene.add(this.water);
  }

  private buildEnvironment() {
    const rockMat = new THREE.MeshStandardMaterial({ color: 0x2a2820, roughness: 0.96 });
    [[-600, -800], [750, -600], [-420, 620], [820, 420]].forEach(([x, z]) => {
      const h = 35 + Math.random() * 65;
      const r = new THREE.Mesh(new THREE.CylinderGeometry(15 + Math.random() * 25, 32, h, 6), rockMat);
      r.position.set(x, h / 2 - 1, z);
      r.rotation.y = Math.random() * Math.PI;
      r.castShadow = true;
      this.scene.add(r);
    });
  }

  private buildPlayerShip() {
    this.playerShip = buildPirateShip();
    this.playerShip.position.set(0, 2.5, 180);
    this.playerShip.rotation.y = Math.PI;
    this.scene.add(this.playerShip);

    const shipLight = new THREE.PointLight(0xffcc88, 3, 60);
    shipLight.position.set(0, 15, 0);
    this.playerShip.add(shipLight);

    // Hero on deck (facing bow = facing -z in ship local space)
    this.playerChar = buildCyborgCharacter(false, 0x00eeff);
    // Place on poop deck — world position (ship at z=180, rotation.y=PI so local -z = world +z)
    this.playerChar.position.set(0, 10, 202);
    this.playerChar.rotation.y = Math.PI; // face forward toward bow
    this.scene.add(this.playerChar);
    this.playerCharBaseY = 10;
  }

  private buildAlienFleet() {
    // ── Boss UFO ──────────────────────────────────────────────────────────────
    const bossColor = 0xff00ff;
    const { group: bossGroup, ring: bossRing, glow: bossGlow } = buildUFO(true, bossColor);
    bossGroup.position.copy(this.bossUFOPos);
    this.scene.add(bossGroup);

    // Boss alien character INSIDE the UFO cockpit (local pos)
    const bossChar = buildCyborgCharacter(true, bossColor);
    bossChar.position.set(0, -2, -2);  // inside the disc, center
    bossChar.rotation.y = Math.PI;     // facing toward player
    bossGroup.add(bossChar);

    // Helm console in front of boss
    const helm = buildHelmConsole(bossColor);
    helm.position.set(0, -4, -10);
    helm.rotation.y = Math.PI;
    bossGroup.add(helm);

    // 2 Gunner alien minions INSIDE boss UFO (behind boss)
    [{ x: -8, color: 0x00ffaa }, { x: 8, color: 0xff4400 }].forEach(({ x, color: gc }, gi) => {
      const gunner = buildCyborgCharacter(false, gc);
      gunner.position.set(x, -4, 10);   // behind boss
      gunner.rotation.y = Math.PI;
      gunner.userData.gunnerIdx = gi;
      bossGroup.add(gunner);
    });

    // Interior lighting for boss UFO cockpit
    const cockpitLight = new THREE.PointLight(bossColor, 2.5, 50);
    cockpitLight.position.set(0, -3, 0);
    bossGroup.add(cockpitLight);

    const bossAlien: AlienShip = {
      group: bossGroup,
      hp: 60, maxHP: 60,
      fireTimer: 5.5,
      alive: true,
      ring: bossRing,
      glow: bossGlow,
      moveOffset: 0,
    };
    bossGroup.userData.isBoss = true;
    bossGroup.userData.baseY = this.bossUFOPos.y;
    this.alienFleet.push(bossAlien);

    // ── Minion UFOs ────────────────────────────────────────────────────────────
    [
      { pos: new THREE.Vector3(-130, 155, -250), color: 0x00ff88 },
      { pos: new THREE.Vector3(130,  155, -250), color: 0xff4400 },
    ].forEach((cfg, idx) => {
      const { group, ring, glow } = buildUFO(false, cfg.color);
      group.position.copy(cfg.pos);
      this.scene.add(group);

      // Minion char on top of UFO
      const ch = buildCyborgCharacter(false, cfg.color);
      ch.position.set(0, 8, 0);
      ch.rotation.y = Math.PI;
      group.add(ch);

      group.userData.baseY = cfg.pos.y;
      this.alienFleet.push({
        group, hp: 30, maxHP: 30,
        fireTimer: 4.0 + idx * 1.5,
        alive: true, ring, glow, moveOffset: (idx + 1) * 2.1,
      });
    });

    // Sky atmosphere lights
    [0xff00ff, 0x00ff88, 0xff4400].forEach((c, i) => {
      const l = new THREE.PointLight(c, 1.5, 200);
      l.position.set([-130, 0, 130][i], 150 + i * 20, -250);
      this.scene.add(l);
    });

    this.callbacks.onStateChange({ aliensAlive: this.alienFleet.length, aliensTotal: this.alienFleet.length });
  }

  private setupPostprocessing() {
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));

    // *** BLOOM STRENGTH FIXED: was 1.1 now 0.3 — this was causing WHITE SCREEN ***
    const bloom = new UnrealBloomPass(
      new THREE.Vector2(this.canvas.clientWidth, this.canvas.clientHeight),
      0.3,   // strength  (was 1.1)
      0.45,  // radius
      0.88,  // threshold (was 0.72)
    );
    this.composer.addPass(bloom);
    this.composer.addPass(new OutputPass());
  }

  private setupInput() {
    window.addEventListener('keydown', e => { this.keys[e.code] = true; });
    window.addEventListener('keyup',   e => { this.keys[e.code] = false; });
    this.canvas.addEventListener('click', () => {
      if (this.phase === 'combat') this.fireCannonball();
    });
  }

  // ─── 9-second Cinematic ───────────────────────────────────────────────────
  // Sequence:
  //   0→2.5s  Wide aerial view → swoop to ship deck
  //   2.5→4s  Slide to player character face level
  //   4→5s    VIOLENT pan UP to sky; player looks up
  //   5→7s    Rush toward boss UFO — reveal alien fleet
  //   7→9s    Enter boss UFO interior: boss at helm + gunners with guns
  //   9→10.5s Pull back → 3rd-person combat; controls UNLOCK
  private startIntroSequence() {
    this.callbacks.onStateChange({ phase: 'intro', phaseTitle: 'ALIEN INVASION', showControls: false });
    const cam = this.camera;

    // Key world positions
    const shipCenter   = new THREE.Vector3(0, 4,  180);
    const playerFace   = new THREE.Vector3(0, 12, 202);
    const bossUFO      = this.bossUFOPos.clone();
    const ufoInterior  = bossUFO.clone().add(new THREE.Vector3(0, 2, 28));  // inside/front of UFO
    const ufoLookAt    = bossUFO.clone().add(new THREE.Vector3(0, -3, -2)); // look at boss char

    const tl = gsap.timeline();

    // ── 0s: Place camera high and wide ──────────────────────────────────────
    tl.set(cam.position, { x: 0, y: 280, z: 600 });
    tl.call(() => cam.lookAt(shipCenter.x, shipCenter.y, shipCenter.z));

    // ── 0→2.5s: Fast swoop down to ship deck ────────────────────────────────
    tl.to(cam.position, {
      x: 30, y: 28, z: 230,
      duration: 2.5,
      ease: 'power3.in',
      onUpdate: () => cam.lookAt(shipCenter.x, shipCenter.y, shipCenter.z),
    });

    // ── 2.5→4s: Slide smoothly to player character face ───────────────────
    tl.to(cam.position, {
      x: 6, y: 12.5, z: 220,
      duration: 1.5,
      ease: 'power2.inOut',
      onUpdate: () => cam.lookAt(playerFace.x, playerFace.y, playerFace.z),
      onStart: () => this.callbacks.onStateChange({ phaseTitle: '' }),
    });

    // ── 4s: Player looks up (rotate char) ───────────────────────────────────
    tl.to(this.playerChar.rotation, { x: -0.5, duration: 0.2, ease: 'power4.out' }, '<0.8');

    // ── 4→5s: VIOLENT upward pan — camera rockets up to sky ─────────────────
    tl.to(cam.position, {
      x: 0, y: 160, z: 250,
      duration: 1.0,
      ease: 'power4.in',
      onUpdate: () => cam.lookAt(bossUFO.x, bossUFO.y, bossUFO.z),
      onStart: () => this.callbacks.onStateChange({ phaseTitle: 'ALIEN FLEET INCOMING…' }),
    });

    // ── 5→7s: Rush toward boss UFO — fill the frame ─────────────────────────
    tl.to(cam.position, {
      x: 0, y: bossUFO.y + 5, z: bossUFO.z + 80,
      duration: 2.0,
      ease: 'power2.in',
      onUpdate: () => cam.lookAt(bossUFO.x, bossUFO.y, bossUFO.z),
    });

    // ── 7→9s: Enter UFO interior — boss at helm + gunners visible ────────────
    tl.to(cam.position, {
      x: ufoInterior.x,
      y: ufoInterior.y,
      z: ufoInterior.z,
      duration: 2.0,
      ease: 'power3.out',
      onUpdate: () => cam.lookAt(ufoLookAt.x, ufoLookAt.y, ufoLookAt.z),
      onStart: () => this.callbacks.onStateChange({ phaseTitle: 'THE COMMAND DECK' }),
    });

    // ── 9→10.5s: Pull back → perfect 3rd-person behind player ────────────────
    tl.to(cam.position, {
      x: 0, y: 32, z: 270,
      duration: 1.5,
      ease: 'power2.inOut',
      onUpdate: () => cam.lookAt(0, 12, -200),
      onStart: () => {
        this.callbacks.onStateChange({ phaseTitle: '' });
        gsap.to(this.playerChar.rotation, { x: 0, duration: 0.7, ease: 'back.out(1.4)' });
      },
      onComplete: () => {
        this.phase = 'combat';
        this.combatStarted = true;
        this.callbacks.onStateChange({
          phase: 'combat',
          phaseTitle: 'BATTLE STATIONS!',
          showControls: true,
        });
        setTimeout(() => this.callbacks.onStateChange({ phaseTitle: '' }), 2600);
      },
    });
  }

  // ─── Fire cannonball ──────────────────────────────────────────────────────
  private fireCannonball() {
    if (this.canFireTimer > 0) return;
    this.canFireTimer = 0.55;
    const s = this.fireFromLeft ? -1 : 1;
    this.fireFromLeft = !this.fireFromLeft;
    const sp = this.playerShip.position, sr = this.playerShip.rotation.y;
    const origin = new THREE.Vector3(
      sp.x + s * 12 * Math.cos(sr + Math.PI / 2),
      sp.y + 5,
      sp.z + s * 12 * Math.sin(sr + Math.PI / 2),
    );
    let target = new THREE.Vector3(0, 10, -600);
    let nd = Infinity;
    this.alienFleet.forEach(a => {
      if (!a.alive) return;
      const d = origin.distanceTo(a.group.position);
      if (d < nd) { nd = d; target = a.group.position.clone(); }
    });
    const dir = target.clone().sub(origin).normalize();
    const mesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.75, 8, 8),
      new THREE.MeshStandardMaterial({ color: 0x333322, metalness: 0.9 }),
    );
    mesh.position.copy(origin);
    this.scene.add(mesh);
    const trail = buildProjectileTrail(false);
    this.scene.add(trail);
    this.projectiles.push({ mesh, velocity: dir.multiplyScalar(125), type: 'cannonball', lifetime: 0, trail, trailPositions: trail.geometry.attributes.position.array as Float32Array });

    const flash = new THREE.PointLight(0xffaa44, 30, 20);
    flash.position.copy(origin); this.scene.add(flash);
    setTimeout(() => this.scene.remove(flash), 100);
    const smoke = buildParticleBurst(origin, 0x777777, 12);
    this.scene.add(smoke.mesh); this.particles.push(smoke);
  }

  // ─── Fire alien laser ─────────────────────────────────────────────────────
  private fireAlienLaser(alien: AlienShip) {
    const origin = alien.group.position.clone(); origin.y -= 4;
    const target = this.playerShip.position.clone(); target.y += 6;
    const dir = target.clone().sub(origin).normalize();
    const mesh = new THREE.Mesh(
      new THREE.CylinderGeometry(0.3, 0.3, 7, 8),
      new THREE.MeshStandardMaterial({ color: alien.glow.color, emissive: alien.glow.color, emissiveIntensity: 2.5 }),
    );
    mesh.position.copy(origin);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
    this.scene.add(mesh);
    const trail = buildProjectileTrail(true);
    this.scene.add(trail);
    this.projectiles.push({ mesh, velocity: dir.multiplyScalar(90), type: 'laser', lifetime: 0, trail, trailPositions: trail.geometry.attributes.position.array as Float32Array });
    alien.glow.intensity = 20;
    setTimeout(() => { if (alien.alive) alien.glow.intensity = isBossAlien(alien) ? 4 : 2.5; }, 160);
  }

  private spawnExplosion(pos: THREE.Vector3, isAlien: boolean) {
    const col = isAlien ? 0x00ff88 : 0xff6600;
    [buildParticleBurst(pos, col, 36), buildParticleBurst(pos, isAlien ? 0x00ccff : 0xffcc44, 18)].forEach(b => {
      this.scene.add(b.mesh); this.particles.push(b);
    });
    const l = new THREE.PointLight(col, 50, 100);
    l.position.copy(pos); this.scene.add(l);
    gsap.to(l, { intensity: 0, duration: 0.6, onComplete: () => this.scene.remove(l) });
  }

  private onResize = () => {
    const w = this.canvas.clientWidth, h = this.canvas.clientHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
  };

  private updatePlayerShip(dt: number) {
    if (!this.combatStarted) return;
    const fwd  = this.keys['KeyW'] || this.keys['ArrowUp']    || this.joystickY < -0.28;
    const bwd  = this.keys['KeyS'] || this.keys['ArrowDown']  || this.joystickY >  0.28;
    const rotL = this.keys['KeyA'] || this.keys['ArrowLeft']  || this.joystickX < -0.28;
    const rotR = this.keys['KeyD'] || this.keys['ArrowRight'] || this.joystickX >  0.28;
    const maxSpd = 55, accel = 40, rotSpd = 0.9;

    if (fwd)      this.playerSpeed = Math.min(this.playerSpeed + accel * dt, maxSpd);
    else if (bwd) this.playerSpeed = Math.max(this.playerSpeed - accel * dt, -maxSpd * 0.5);
    else          this.playerSpeed *= 0.96;

    if (rotL) this.playerRotation += rotSpd * dt;
    if (rotR) this.playerRotation -= rotSpd * dt;

    this.playerShip.rotation.y = this.playerRotation + Math.PI;
    this.playerShip.position.x += Math.sin(this.playerRotation) * this.playerSpeed * dt;
    this.playerShip.position.z += Math.cos(this.playerRotation) * this.playerSpeed * dt;

    const t = this.clock.getElapsedTime();
    this.playerShip.position.y = 2.5 + Math.sin(t * 0.6) * 0.4;
    this.playerShip.rotation.x = Math.sin(t * 0.5) * 0.016;
    this.playerShip.rotation.z = Math.cos(t * 0.7) * 0.010;

    // Move player char with ship
    this.playerChar.position.set(
      this.playerShip.position.x,
      this.playerShip.position.y + 7.5,
      this.playerShip.position.z + 22 * Math.cos(this.playerShip.rotation.y),
    );
    this.playerChar.rotation.y = this.playerShip.rotation.y;

    this.canFireTimer = Math.max(0, this.canFireTimer - dt);
  }

  private updateAlienFleet(dt: number) {
    if (!this.combatStarted) return;
    const t = this.clock.getElapsedTime();
    let alive = 0;

    this.alienFleet.forEach((alien, idx) => {
      if (!alien.alive) return;
      alive++;
      const baseY = alien.group.userData.baseY ?? alien.group.position.y;
      const spd = idx === 0 ? 0.22 : 0.32;
      alien.group.position.x += Math.sin(t * spd + alien.moveOffset) * 10 * dt;
      alien.group.position.y  = baseY + Math.sin(t * 0.5 + alien.moveOffset) * 7;
      alien.group.position.z += Math.cos(t * spd * 0.7 + alien.moveOffset) * 5 * dt;

      if (alien.ring) {
        alien.ring.rotation.y += dt * (idx === 0 ? 1.0 : 0.75);
        alien.ring.rotation.x += dt * 0.12;
      }
      alien.glow.intensity = (idx === 0 ? 4 : 2.5) + Math.sin(t * 2.5 + idx) * 1.0;
      alien.group.lookAt(this.playerShip.position.x, alien.group.position.y, this.playerShip.position.z);

      alien.fireTimer -= dt;
      if (alien.fireTimer <= 0) {
        this.fireAlienLaser(alien);
        alien.fireTimer = 3.0 + Math.random() * 2.0;
      }
    });

    if (alive === 0 && this.phase === 'combat') {
      this.phase = 'victory';
      this.callbacks.onStateChange({ phase: 'victory', phaseTitle: 'VICTORY!' });
    }
    this.callbacks.onStateChange({ aliensAlive: alive, aliensTotal: this.alienFleet.length });
  }

  private updateProjectiles(dt: number) {
    const toRemove: Projectile[] = [];
    this.projectiles.forEach(proj => {
      proj.lifetime += dt;
      if (proj.lifetime > (proj.type === 'cannonball' ? 6 : 4)) { toRemove.push(proj); return; }
      if (proj.type === 'cannonball') proj.velocity.y -= 18 * dt;
      proj.mesh.position.addScaledVector(proj.velocity, dt);

      const pos = proj.trailPositions;
      for (let i = 19; i > 0; i--) { pos[i * 3] = pos[(i-1)*3]; pos[i*3+1] = pos[(i-1)*3+1]; pos[i*3+2] = pos[(i-1)*3+2]; }
      pos[0] = proj.mesh.position.x; pos[1] = proj.mesh.position.y; pos[2] = proj.mesh.position.z;
      proj.trail.geometry.attributes.position.needsUpdate = true;

      if (proj.type === 'cannonball') {
        this.alienFleet.forEach(a => {
          if (!a.alive || proj.mesh.position.distanceTo(a.group.position) > 16) return;
          toRemove.push(proj);
          a.hp -= 15;
          if (a.hp <= 0) {
            a.alive = false;
            this.spawnExplosion(a.group.position.clone(), true);
            this.scene.remove(a.group);
          } else {
            a.glow.intensity = 35;
            setTimeout(() => { if (a.alive) a.glow.intensity = isBossAlien(a) ? 4 : 2.5; }, 200);
          }
        });
      } else {
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
      this.scene.remove(p.mesh); this.scene.remove(p.trail);
      const i = this.projectiles.indexOf(p); if (i !== -1) this.projectiles.splice(i, 1);
    });
  }

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
      const i = this.particles.indexOf(p); if (i !== -1) this.particles.splice(i, 1);
    });
  }

  private animate = () => {
    this.animFrameId = requestAnimationFrame(this.animate);
    const dt = Math.min(this.clock.getDelta(), 0.05);
    const t  = this.clock.getElapsedTime();

    // Water
    (this.water.material as THREE.ShaderMaterial).uniforms['time'].value += dt * 0.45;
    const sd = this.sun.clone(); sd.y += Math.sin(t * 0.3) * 0.01;
    (this.water.material as THREE.ShaderMaterial).uniforms['sunDirection'].value.copy(sd.normalize());

    // ── Breathing animations (absolute Y — no drift) ──────────────────────
    if (this.playerChar && !this.combatStarted) {
      // Only animate during cinematic; during combat updatePlayerShip controls position
      this.playerChar.position.y = this.playerCharBaseY + Math.sin(t * 1.6) * 0.12;
    }
    if (this.playerChar) {
      this.playerChar.scale.setScalar(1.0 + Math.sin(t * 1.6) * 0.016);
    }

    // ── Gunner gun-look animation (inside boss UFO) ───────────────────────
    // Find gunners in boss UFO group
    const bossAlienShip = this.alienFleet[0];
    if (bossAlienShip) {
      bossAlienShip.group.children.forEach(child => {
        if (!child.userData.gunnerIdx === undefined) return;
        const gi = child.userData.gunnerIdx;
        if (gi === undefined) return;
        const weaponArm = child.userData.weaponArm as THREE.Object3D;
        if (!weaponArm) return;
        // Periodically look at gun, then look forward
        const phase = Math.sin(t * 0.7 + gi * 2.0);
        weaponArm.rotation.x = phase > 0.4 ? -0.65 : 0.05;
        weaponArm.rotation.y = phase > 0.4 ? (gi === 0 ? 0.4 : -0.4) : 0;
      });
    }

    // ── Alien cyborg breathing ────────────────────────────────────────────
    this.alienFleet.forEach((alien, idx) => {
      if (!alien.alive) return;
      alien.group.children.forEach(child => {
        if (child instanceof THREE.Group && !child.userData.isHelm) {
          child.scale.setScalar(1.0 + Math.sin(t * 1.3 + idx * 0.9) * 0.022);
        }
      });
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

// Helper
function isBossAlien(a: AlienShip): boolean {
  return !!a.group.userData.isBoss;
}
