// @ts-nocheck
import * as THREE from 'three';
import { Water } from 'three/examples/jsm/objects/Water.js';
import { Sky } from 'three/examples/jsm/objects/Sky.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import gsap from 'gsap';

// ─── Types ────────────────────────────────────────────────────────────────────
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

// ─── Mobile detection ─────────────────────────────────────────────────────────
const IS_MOBILE = (
  typeof window !== 'undefined' &&
  ('ontouchstart' in window || navigator.maxTouchPoints > 0 || window.innerWidth < 900)
);

// ─── Texture CDNs ─────────────────────────────────────────────────────────────
const T3 = 'https://cdn.jsdelivr.net/npm/three@0.160.0/examples/textures';
const PH = 'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k';
const TEXTURES = {
  waterNormals: `${T3}/waternormals.jpg`,
  woodDiff:  `${PH}/wood_planks_dirt/wood_planks_dirt_diff_1k.jpg`,
  woodRough: `${PH}/wood_planks_dirt/wood_planks_dirt_rough_1k.jpg`,
  woodNorm:  `${PH}/wood_planks_dirt/wood_planks_dirt_nor_gl_1k.jpg`,
  metalDiff: `${PH}/rusty_metal_02/rusty_metal_02_diff_1k.jpg`,
  metalRough:`${PH}/rusty_metal_02/rusty_metal_02_rough_1k.jpg`,
};

const tLoader = new THREE.TextureLoader();
function loadTex(url: string, rep = 4): THREE.Texture {
  const t = tLoader.load(url);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(rep, rep);
  return t;
}

// Procedural water normals (fallback + always available immediately)
function makeWaterNormal(): THREE.Texture {
  const sz = IS_MOBILE ? 256 : 512;
  const cv = document.createElement('canvas');
  cv.width = cv.height = sz;
  const cx = cv.getContext('2d')!;
  const id = cx.createImageData(sz, sz);
  for (let y = 0; y < sz; y++) {
    for (let x = 0; x < sz; x++) {
      const i = (y * sz + x) * 4;
      const u = x / sz, v = y / sz;
      const w1 = Math.sin(u * Math.PI * 14 + v * Math.PI * 4);
      const w2 = Math.cos(v * Math.PI * 10 - u * Math.PI * 6);
      id.data[i]     = Math.max(0, Math.min(255, (w1 * 0.5 + 0.5) * 255));
      id.data[i + 1] = Math.max(0, Math.min(255, (w2 * 0.5 + 0.5) * 255));
      id.data[i + 2] = 210;
      id.data[i + 3] = 255;
    }
  }
  cx.putImageData(id, 0, 0);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

// ─── Material factory (MeshStandardMaterial — no clearcoat for mobile perf) ──
function stdMat(opts: THREE.MeshStandardMaterialParameters): THREE.MeshStandardMaterial {
  return new THREE.MeshStandardMaterial(opts);
}

// ─── Pirate ship ──────────────────────────────────────────────────────────────
function buildPirateShip(): THREE.Group {
  const g = new THREE.Group();
  const wD = loadTex(TEXTURES.woodDiff, 5);
  const wR = loadTex(TEXTURES.woodRough, 5);
  const wN = loadTex(TEXTURES.woodNorm, 5);
  const mD = loadTex(TEXTURES.metalDiff, 2);
  const mR = loadTex(TEXTURES.metalRough, 2);

  const hull  = stdMat({ color: 0x7A3A10, map: wD, roughnessMap: wR, normalMap: wN, normalScale: new THREE.Vector2(1.4, 1.4), roughness: 0.85, metalness: 0.04 });
  const deck  = stdMat({ color: 0x5C2A08, map: wD, roughnessMap: wR, normalMap: wN, normalScale: new THREE.Vector2(1.1, 1.1), roughness: 0.9, metalness: 0.0 });
  const metal = stdMat({ color: 0x888877, map: mD, roughnessMap: mR, roughness: 0.42, metalness: 0.82 });
  const sail  = stdMat({ color: 0xDDD0A8, roughness: 0.85, side: THREE.DoubleSide });

  const mk = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = !IS_MOBILE; m.receiveShadow = !IS_MOBILE; return m; };

  // Hull
  g.add(mk(new THREE.BoxGeometry(20, 7, 60), hull));

  // Bow
  const bow = mk(new THREE.CylinderGeometry(0, 10, 10, 4), deck);
  bow.position.set(0, 0, -35); bow.rotation.set(Math.PI / 2, 0, Math.PI / 4); g.add(bow);

  // Stern + castle
  const stern = mk(new THREE.BoxGeometry(20, 10, 10), hull); stern.position.set(0, 5, 28); g.add(stern);
  const fore  = mk(new THREE.BoxGeometry(16, 3, 12), hull);  fore.position.set(0, 5.5, -24); g.add(fore);
  const poop  = mk(new THREE.BoxGeometry(16, 3, 14), hull);  poop.position.set(0, 5.5, 22);  g.add(poop);

  // Deck
  const deckMesh = mk(new THREE.BoxGeometry(19, 1, 58), deck); deckMesh.position.y = 4; g.add(deckMesh);

  // Masts + sails
  [{ z: -18, h: 42 }, { z: 2, h: 48 }, { z: 20, h: 36 }].forEach(({ z, h }) => {
    const mast = mk(new THREE.CylinderGeometry(0.45, 0.65, h, 8), deck);
    mast.position.set(0, 4 + h / 2, z); g.add(mast);
    const yard = mk(new THREE.CylinderGeometry(0.22, 0.22, 22, 8), deck);
    yard.position.set(0, 4 + h * 0.78, z); yard.rotation.z = Math.PI / 2; g.add(yard);
    [-1, 1].forEach(s => {
      const sl = mk(new THREE.PlaneGeometry(9.5, h * 0.55), sail);
      sl.position.set(s * 5, 4 + h * 0.78 - h * 0.14, z); g.add(sl);
    });
  });

  // Cannons (fewer on mobile)
  const cannonCount = IS_MOBILE ? 3 : 6;
  [-1, 1].forEach(s => {
    for (let ci = 0; ci < cannonCount; ci++) {
      const barrel = mk(new THREE.CylinderGeometry(0.6, 0.7, 6, IS_MOBILE ? 6 : 10), metal);
      barrel.position.set(s * 11, 1.5, -20 + ci * (IS_MOBILE ? 16 : 8));
      barrel.rotation.z = Math.PI / 2; g.add(barrel);
    }
  });

  // Railings (fewer on mobile)
  const railCount = IS_MOBILE ? 5 : 10;
  [-9, 9].forEach(sx => {
    for (let pi = 0; pi < railCount; pi++) {
      const post = mk(new THREE.CylinderGeometry(0.18, 0.18, 2.5, 5), deck);
      post.position.set(sx, 6.2, -22 + pi * (IS_MOBILE ? 9 : 4.5)); g.add(post);
    }
    const rail = mk(new THREE.BoxGeometry(0.25, 0.25, 48), deck);
    rail.position.set(sx, 7.5, 0); g.add(rail);
  });

  // Flag
  const flag = mk(new THREE.PlaneGeometry(5, 3.5), stdMat({ color: 0x111111, side: THREE.DoubleSide }));
  flag.position.set(2, 56, 2); flag.rotation.y = 0.3; g.add(flag);

  return g;
}

// ─── Cyborg character (MeshStandardMaterial — fast on mobile) ─────────────────
function buildCyborgCharacter(isBoss: boolean, accentColor: number): THREE.Group {
  const g = new THREE.Group();
  const sc = isBoss ? 1.6 : 1.0;

  const chrome = stdMat({ color: isBoss ? 0x1a001a : 0x0a0a14, metalness: 0.9, roughness: 0.15 });
  const accent = stdMat({ color: accentColor, metalness: 0.7, roughness: 0.25 });
  const visor  = stdMat({ color: accentColor, emissive: accentColor, emissiveIntensity: isBoss ? 0.8 : 0.6, roughness: 0.0, metalness: 0.15, transparent: true, opacity: 0.9 });
  const joint  = stdMat({ color: 0x222233, metalness: 0.85, roughness: 0.3 });

  const mk = (geo, mat) => { const m = new THREE.Mesh(geo, mat); m.castShadow = !IS_MOBILE; return m; };

  const torsoY = 3.5 * sc + 1.9 * sc;
  g.add(Object.assign(mk(new THREE.BoxGeometry(2.6 * sc, 3.8 * sc, 1.8 * sc), chrome), { position: new THREE.Vector3(0, torsoY, 0) }));
  g.add(Object.assign(mk(new THREE.BoxGeometry(1.8 * sc, 2.0 * sc, 0.18), accent),  { position: new THREE.Vector3(0, torsoY, 0.92 * sc) }));
  g.add(Object.assign(mk(new THREE.SphereGeometry(0.42 * sc, 10, 10), visor),        { position: new THREE.Vector3(0, torsoY, 1.0 * sc) }));

  const headY = torsoY + 1.9 * sc + 1.0 * sc;
  g.add(Object.assign(mk(new THREE.BoxGeometry(2.2 * sc, 2.0 * sc, 2.0 * sc), chrome), { position: new THREE.Vector3(0, headY, 0) }));
  g.add(Object.assign(mk(new THREE.BoxGeometry(1.8 * sc, 0.5 * sc, 0.1), visor),        { position: new THREE.Vector3(0, headY + 0.2 * sc, 1.0 * sc) }));

  if (isBoss) {
    g.add(Object.assign(mk(new THREE.CylinderGeometry(0.08, 0.12, 2.0, 6), accent),  { position: new THREE.Vector3(0, headY + 1.7 * sc, 0) }));
    g.add(Object.assign(mk(new THREE.SphereGeometry(0.22, 8, 8), visor),              { position: new THREE.Vector3(0, headY + 2.8 * sc, 0) }));
  }

  const shoulderY = torsoY + 1.1 * sc;
  [-1, 1].forEach(side => {
    g.add(Object.assign(mk(new THREE.SphereGeometry(0.85 * sc, 8, 8), accent), { position: new THREE.Vector3(side * 1.95 * sc, shoulderY, 0) }));

    const uarm = mk(new THREE.CylinderGeometry(0.38 * sc, 0.32 * sc, 2.4 * sc, 7), chrome);
    uarm.position.set(side * 2.55 * sc, shoulderY - 1.2 * sc, 0); uarm.rotation.z = side * 0.18; g.add(uarm);

    g.add(Object.assign(mk(new THREE.SphereGeometry(0.35 * sc, 7, 7), joint), { position: new THREE.Vector3(side * 2.7 * sc, shoulderY - 2.5 * sc, 0) }));

    const farm = mk(new THREE.CylinderGeometry(0.3 * sc, 0.38 * sc, 2.2 * sc, 7), chrome);
    farm.position.set(side * 3.0 * sc, shoulderY - 3.8 * sc, 0); farm.rotation.z = side * 0.28; g.add(farm);

    const wMat = stdMat({ color: accentColor, emissive: accentColor, emissiveIntensity: 0.4, metalness: 0.7, roughness: 0.25 });
    const weaponGeo = isBoss
      ? new THREE.BoxGeometry(0.5 * sc, 0.5 * sc, 2.6 * sc)
      : new THREE.CylinderGeometry(0.26 * sc, 0.34 * sc, 2.2 * sc, 6);
    const weapon = mk(weaponGeo, wMat);
    weapon.position.set(side * 3.2 * sc, shoulderY - 5.0 * sc, isBoss ? 0.6 * sc : 0);
    weapon.rotation.set(0, 0, side * 0.08);
    if (side === 1) g.userData.weaponArm = weapon;
    g.add(weapon);
  });

  const pelvisY = 3.0 * sc;
  g.add(Object.assign(mk(new THREE.BoxGeometry(2.3 * sc, 1.1 * sc, 1.5 * sc), accent), { position: new THREE.Vector3(0, pelvisY, 0) }));

  [-1, 1].forEach(side => {
    g.add(Object.assign(mk(new THREE.CylinderGeometry(0.52 * sc, 0.42 * sc, 3.0 * sc, 7), chrome), { position: new THREE.Vector3(side * 0.88 * sc, 1.5 * sc, 0) }));
    g.add(Object.assign(mk(new THREE.SphereGeometry(0.48 * sc, 7, 7), joint),                       { position: new THREE.Vector3(side * 0.88 * sc, 0, 0.1 * sc) }));
    g.add(Object.assign(mk(new THREE.CylinderGeometry(0.35 * sc, 0.52 * sc, 2.8 * sc, 7), chrome), { position: new THREE.Vector3(side * 0.88 * sc, -1.4 * sc, 0.1 * sc) }));
    g.add(Object.assign(mk(new THREE.BoxGeometry(0.88 * sc, 0.58 * sc, 1.7 * sc), accent),         { position: new THREE.Vector3(side * 0.88 * sc, -2.85 * sc, 0.4 * sc) }));
  });

  // Subtle glow (1 light per character — cheap)
  const gl = new THREE.PointLight(accentColor, 1.2, 8 * sc);
  gl.position.set(0, torsoY, 1.5); g.add(gl);
  return g;
}

// ─── Helm console ─────────────────────────────────────────────────────────────
function buildHelmConsole(color: number): THREE.Group {
  const g = new THREE.Group();
  const pMat = stdMat({ color: 0x111122, metalness: 0.88, roughness: 0.2 });
  const gMat = stdMat({ color, emissive: color, emissiveIntensity: 0.7, roughness: 0.0, metalness: 0.3, transparent: true, opacity: 0.85 });
  g.add(Object.assign(new THREE.Mesh(new THREE.BoxGeometry(10, 1.5, 4), pMat), { castShadow: false }));
  const disp = new THREE.Mesh(new THREE.BoxGeometry(8, 3, 0.15), gMat);
  disp.position.set(0, 2.2, -1.8); disp.rotation.x = -0.4; g.add(disp);
  [[-3, 0, 2.2], [0, 0, 2.2], [3, 0, 2.2]].forEach(([x, , z]) => {
    const btn = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.5, 7), gMat);
    btn.position.set(x, 1.1, z); g.add(btn);
  });
  return g;
}

// ─── UFO ──────────────────────────────────────────────────────────────────────
function buildUFO(isBoss: boolean, color: number): { group: THREE.Group; ring: THREE.Mesh; glow: THREE.PointLight } {
  const g = new THREE.Group();
  const sc = isBoss ? 1.5 : 1.0;

  const bodyMat = stdMat({ color: isBoss ? 0x110022 : 0x0a1822, metalness: 0.92, roughness: 0.1, side: THREE.DoubleSide });
  const glowMat = stdMat({ color, emissive: color, emissiveIntensity: isBoss ? 1.0 : 0.7, roughness: 0.0, metalness: 0.3, transparent: true, opacity: 0.88 });

  const segs = IS_MOBILE ? 18 : 32;
  g.add(new THREE.Mesh(new THREE.SphereGeometry(10 * sc, segs, 12, 0, Math.PI * 2, 0, Math.PI / 2.2), bodyMat));
  const bot = new THREE.Mesh(new THREE.SphereGeometry(10 * sc, segs, 12, 0, Math.PI * 2, Math.PI / 2.2, Math.PI / 2.2), bodyMat);
  bot.position.y = -0.5; g.add(bot);

  const ring = new THREE.Mesh(new THREE.TorusGeometry(11.5 * sc, isBoss ? 1.3 : 0.9, 10, IS_MOBILE ? 32 : 56), glowMat);
  ring.position.y = -2 * sc; g.add(ring);

  [0.65, 0.4].forEach((rf, ri) => {
    const r2 = new THREE.Mesh(new THREE.TorusGeometry(rf * 11.5 * sc, 0.32 * sc, 7, IS_MOBILE ? 20 : 32), glowMat);
    r2.position.y = -1.5 * sc + ri * 1.5 * sc; g.add(r2);
  });

  const domeMat = stdMat({ color, emissive: color, emissiveIntensity: 0.25, transparent: true, opacity: 0.32, roughness: 0.0, metalness: 0.2 });
  const dome = new THREE.Mesh(new THREE.SphereGeometry(4.5 * sc, 18, 10, 0, Math.PI * 2, 0, Math.PI / 2), domeMat);
  dome.position.y = 3 * sc; g.add(dome);

  const glow = new THREE.PointLight(color, isBoss ? 3.5 : 2.0, 55 * sc);
  glow.position.y = -4; g.add(glow);

  if (isBoss) {
    const beamMat = stdMat({ color, transparent: true, opacity: 0.03, side: THREE.BackSide });
    const beam = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 8, 80, 10, 1, true), beamMat);
    beam.position.y = -42; g.add(beam);
  }
  return { group: g, ring, glow };
}

// ─── Particles ────────────────────────────────────────────────────────────────
function makeBurst(pos: THREE.Vector3, color: number, count = 20): Particle {
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  const velocities: THREE.Vector3[] = [];
  for (let i = 0; i < count; i++) {
    positions[i * 3] = pos.x; positions[i * 3 + 1] = pos.y; positions[i * 3 + 2] = pos.z;
    const theta = Math.random() * Math.PI * 2, phi = Math.random() * Math.PI;
    const spd = 10 + Math.random() * 20;
    velocities.push(new THREE.Vector3(Math.sin(phi) * Math.cos(theta) * spd, Math.abs(Math.cos(phi)) * spd + 4, Math.sin(phi) * Math.sin(theta) * spd));
  }
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  return { mesh: new THREE.Points(geo, new THREE.PointsMaterial({ color, size: 1.4, transparent: true, opacity: 1.0, sizeAttenuation: true })), velocities, lifetime: 0, maxLifetime: 1.6 };
}
function makeTrail(isLaser: boolean): THREE.Points {
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(20 * 3), 3));
  return new THREE.Points(geo, new THREE.PointsMaterial({ color: isLaser ? 0x00ffaa : 0x888877, size: isLaser ? 0.8 : 0.5, transparent: true, opacity: 0.7 }));
}

// ─── MAIN GAME CLASS ──────────────────────────────────────────────────────────
export class PirateGame {
  private canvas: HTMLCanvasElement;
  private renderer!: THREE.WebGLRenderer;
  private scene!: THREE.Scene;
  private camera!: THREE.PerspectiveCamera;
  private composer: EffectComposer | null = null;
  private water!: Water;
  private sun!: THREE.Vector3;

  private playerShip!: THREE.Group;
  private playerChar!: THREE.Group;
  private alienFleet: AlienShip[] = [];
  private projectiles: Projectile[] = [];
  private particles: Particle[] = [];
  private clock = new THREE.Clock();
  private animId = 0;
  private callbacks: GameCallbacks;

  private phase: GamePhase = 'intro';
  private playerHP = 100;
  readonly playerMaxHP = 100;
  private playerSpeed = 0;
  private playerRotation = 0;
  private canFireTimer = 0;
  private fireFromLeft = true;
  private combatStarted = false;
  private joystickX = 0;
  private joystickY = 0;

  // Camera follow lerp target
  private camLookTarget = new THREE.Vector3(0, 10, -200);

  constructor(canvas: HTMLCanvasElement, callbacks: GameCallbacks) {
    this.canvas = canvas;
    this.callbacks = callbacks;
    this.init();
  }

  public setJoystickInput(dx: number, dy: number) {
    this.joystickX = dx; this.joystickY = dy;
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
    const ctx = this.canvas.getContext('webgl2') || this.canvas.getContext('webgl');
    if (!ctx) throw new Error('WebGL not supported.');
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: !IS_MOBILE,
      powerPreference: 'high-performance',
    });
    // *** MOBILE: pixel ratio capped at 1.0 (was 2) — major perf win ***
    this.renderer.setPixelRatio(IS_MOBILE ? 1.0 : Math.min(window.devicePixelRatio, 1.5));
    this.renderer.setSize(this.canvas.clientWidth, this.canvas.clientHeight);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.85;
    // *** MOBILE: shadows disabled — major perf win ***
    this.renderer.shadowMap.enabled = !IS_MOBILE;
    if (!IS_MOBILE) this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    window.addEventListener('resize', this.onResize);
  }

  private setupScene() {
    this.scene = new THREE.Scene();
    // Lighter fog so sky isn't washed out
    this.scene.fog = new THREE.FogExp2(0x1a2a44, IS_MOBILE ? 0.00035 : 0.0005);

    this.camera = new THREE.PerspectiveCamera(65, this.canvas.clientWidth / this.canvas.clientHeight, 0.5, 8000);
    this.camera.position.set(0, 280, 600);

    // Lights — moderate intensities
    this.scene.add(new THREE.AmbientLight(0x334466, IS_MOBILE ? 0.55 : 0.45));
    this.scene.add(new THREE.HemisphereLight(0xff8844, 0x223355, 0.38));

    const sun = new THREE.DirectionalLight(0xff9955, IS_MOBILE ? 1.1 : 1.4);
    sun.position.set(300, 200, -500);
    if (!IS_MOBILE) {
      sun.castShadow = true;
      sun.shadow.mapSize.set(1024, 1024);
      sun.shadow.camera.near = 1; sun.shadow.camera.far = 1500;
      sun.shadow.camera.left = -250; sun.shadow.camera.right = 250;
      sun.shadow.camera.top = 250;   sun.shadow.camera.bottom = -250;
      sun.shadow.bias = -0.0004;
    }
    this.scene.add(sun);

    const fill = new THREE.DirectionalLight(0x8833ff, 0.3);
    fill.position.set(0, 100, -400); this.scene.add(fill);
  }

  private buildWaterAndSky() {
    this.sun = new THREE.Vector3();
    const sky = new Sky();
    sky.scale.setScalar(8000);
    this.scene.add(sky);

    const skyU = (sky.material as THREE.ShaderMaterial).uniforms;
    skyU['turbidity'].value = 4.5;          // was 7 — cleaner sky
    skyU['rayleigh'].value = 1.1;           // was 3.0 — less white horizon glow
    skyU['mieCoefficient'].value = 0.005;
    skyU['mieDirectionalG'].value = 0.82;

    // *** KEY FIX: Sun moved from phi=86° (near horizon) to phi=62° (higher up) ***
    // phi=86° causes massive white horizon glow — phi=62° is golden hour, looks great
    const phi   = THREE.MathUtils.degToRad(90 - 28);  // 62° elevation
    const theta = THREE.MathUtils.degToRad(195);
    this.sun.setFromSphericalCoords(1, phi, theta);
    skyU['sunPosition'].value.copy(this.sun);

    // Use procedural normals immediately (CDN might be slow)
    const waterNormals = makeWaterNormal();

    // *** MOBILE: water geometry 8×8 segments (was 64×64 = 64× fewer vertices) ***
    const wSeg = IS_MOBILE ? 8 : 24;
    this.water = new Water(new THREE.PlaneGeometry(8000, 8000, wSeg, wSeg), {
      textureWidth:  IS_MOBILE ? 256 : 512,
      textureHeight: IS_MOBILE ? 256 : 512,
      waterNormals,
      sunDirection: this.sun.clone().normalize(),
      sunColor: 0xff9944,
      waterColor: 0x001a2e,
      distortionScale: IS_MOBILE ? 3.0 : 5.0,
      fog: true,
    });
    this.water.rotation.x = -Math.PI / 2;
    this.water.position.y = -1;
    this.scene.add(this.water);

    // Also try to load CDN water normals in background
    const cdnNorm = loadTex(TEXTURES.waterNormals, 1);
    cdnNorm.wrapS = cdnNorm.wrapT = THREE.RepeatWrapping;
    cdnNorm.addEventListener('load', () => {
      (this.water.material as THREE.ShaderMaterial).uniforms['tWaterNormals'].value = cdnNorm;
    });
  }

  private buildEnvironment() {
    if (IS_MOBILE) return; // skip decorative rocks on mobile
    const rMat = stdMat({ color: 0x2a2820, roughness: 0.96 });
    [[-600, -800], [750, -600], [-420, 620], [820, 420]].forEach(([x, z]) => {
      const h = 35 + Math.random() * 65;
      const r = new THREE.Mesh(new THREE.CylinderGeometry(20, 35, h, 6), rMat);
      r.position.set(x, h / 2 - 1, z); r.rotation.y = Math.random() * Math.PI;
      this.scene.add(r);
    });
  }

  private buildPlayerShip() {
    this.playerShip = buildPirateShip();
    this.playerShip.position.set(0, 2.5, 180);
    this.playerShip.rotation.y = Math.PI;
    this.scene.add(this.playerShip);

    const l = new THREE.PointLight(0xffcc88, 2.5, 55);
    l.position.set(0, 15, 0); this.playerShip.add(l);

    this.playerChar = buildCyborgCharacter(false, 0x00eeff);
    this.playerChar.position.set(0, 10, 202);
    this.playerChar.rotation.y = Math.PI;
    this.scene.add(this.playerChar);
  }

  private buildAlienFleet() {
    const bossColor = 0xff00ff;
    const bossPos   = new THREE.Vector3(0, 190, -280);

    const { group: bG, ring: bRing, glow: bGlow } = buildUFO(true, bossColor);
    bG.position.copy(bossPos);
    this.scene.add(bG);
    bG.userData.isBoss = true;
    bG.userData.baseY  = bossPos.y;

    // Boss inside UFO
    const bossChar = buildCyborgCharacter(true, bossColor);
    bossChar.position.set(0, -2, -2); bossChar.rotation.y = Math.PI; bG.add(bossChar);

    // Helm
    const helm = buildHelmConsole(bossColor);
    helm.position.set(0, -4, -10); helm.rotation.y = Math.PI; bG.add(helm);

    // 2 gunner aliens inside boss UFO
    [{ x: -8, c: 0x00ffaa, gi: 0 }, { x: 8, c: 0xff4400, gi: 1 }].forEach(({ x, c, gi }) => {
      const gn = buildCyborgCharacter(false, c);
      gn.position.set(x, -4, 10); gn.rotation.y = Math.PI;
      gn.userData.gunnerIdx = gi; bG.add(gn);
    });

    // Interior cockpit light
    const ckL = new THREE.PointLight(bossColor, 2.0, 45);
    ckL.position.set(0, -3, 0); bG.add(ckL);

    this.alienFleet.push({ group: bG, hp: 60, maxHP: 60, fireTimer: 5.5, alive: true, ring: bRing, glow: bGlow, moveOffset: 0 });

    // Minion UFOs
    [
      { pos: new THREE.Vector3(-130, 155, -250), color: 0x00ff88 },
      { pos: new THREE.Vector3( 130, 155, -250), color: 0xff4400 },
    ].forEach(({ pos, color }, idx) => {
      const { group, ring, glow } = buildUFO(false, color);
      group.position.copy(pos); group.userData.baseY = pos.y;
      this.scene.add(group);
      const ch = buildCyborgCharacter(false, color);
      ch.position.set(0, 8, 0); ch.rotation.y = Math.PI; group.add(ch);
      this.alienFleet.push({ group, hp: 30, maxHP: 30, fireTimer: 4.0 + idx * 1.5, alive: true, ring, glow, moveOffset: (idx + 1) * 2.1 });
    });

    // Atmosphere lights for alien section
    [0xff00ff, 0x00ff88, 0xff4400].forEach((c, i) => {
      const l = new THREE.PointLight(c, 1.2, 180);
      l.position.set([-130, 0, 130][i], 150 + i * 20, -250); this.scene.add(l);
    });

    this.callbacks.onStateChange({ aliensAlive: this.alienFleet.length, aliensTotal: this.alienFleet.length });
  }

  private setupPostprocessing() {
    // *** MOBILE: NO bloom composer — use renderer.render() directly ***
    // Bloom on mobile = 3-4x render time → causes lag
    if (IS_MOBILE) {
      this.composer = null;
      return;
    }
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.composer.addPass(new UnrealBloomPass(
      new THREE.Vector2(this.canvas.clientWidth, this.canvas.clientHeight),
      0.28, 0.4, 0.88,  // strength, radius, threshold
    ));
    this.composer.addPass(new OutputPass());
  }

  private setupInput() {
    window.addEventListener('keydown', e => { this.keys[e.code] = true; });
    window.addEventListener('keyup',   e => { this.keys[e.code] = false; });
    this.canvas.addEventListener('click', () => { if (this.phase === 'combat') this.fireCannonball(); });
  }
  private keys: Record<string, boolean> = {};

  // ─── 10.5 s Cinematic ──────────────────────────────────────────────────────
  private startIntroSequence() {
    this.callbacks.onStateChange({ phase: 'intro', phaseTitle: 'ALIEN INVASION', showControls: false });
    const cam = this.camera;
    const shipC  = new THREE.Vector3(0, 4, 180);
    const charC  = new THREE.Vector3(0, 12, 202);
    const bossC  = new THREE.Vector3(0, 190, -280);
    const ufoIn  = new THREE.Vector3(0, 192, -252);  // "inside" UFO
    const ufoAt  = new THREE.Vector3(0, 187, -282);  // looking at boss

    const tl = gsap.timeline();

    // 0s: place camera
    tl.set(cam.position, { x: 0, y: 280, z: 600 });
    tl.call(() => cam.lookAt(shipC.x, shipC.y, shipC.z));

    // 0→2.5s: wide aerial → ship deck
    tl.to(cam.position, { x: 30, y: 28, z: 235, duration: 2.5, ease: 'power3.in',
      onUpdate: () => cam.lookAt(shipC.x, shipC.y, shipC.z) });

    // 2.5→4s: slide to player character face
    tl.to(cam.position, { x: 5, y: 12.5, z: 222, duration: 1.5, ease: 'power2.inOut',
      onUpdate: () => cam.lookAt(charC.x, charC.y, charC.z),
      onStart:  () => this.callbacks.onStateChange({ phaseTitle: '' }) });

    // 4→4.2s: player looks up (head tilt)
    tl.to(this.playerChar.rotation, { x: -0.5, duration: 0.2, ease: 'power4.out' }, '<0.8');

    // 4→5s: VIOLENT upward pan to sky
    tl.to(cam.position, { x: 0, y: 170, z: 260, duration: 1.0, ease: 'power4.in',
      onUpdate: () => cam.lookAt(bossC.x, bossC.y, bossC.z),
      onStart: () => this.callbacks.onStateChange({ phaseTitle: 'ALIEN FLEET INCOMING…' }) });

    // 5→7s: rush toward boss UFO — fill frame
    tl.to(cam.position, { x: 0, y: bossC.y + 5, z: bossC.z + 80, duration: 2.0, ease: 'power2.in',
      onUpdate: () => cam.lookAt(bossC.x, bossC.y, bossC.z) });

    // 7→9s: enter UFO interior — boss at helm + gunners
    tl.to(cam.position, { x: ufoIn.x, y: ufoIn.y, z: ufoIn.z, duration: 2.0, ease: 'power3.out',
      onUpdate: () => cam.lookAt(ufoAt.x, ufoAt.y, ufoAt.z),
      onStart: () => this.callbacks.onStateChange({ phaseTitle: 'THE COMMAND DECK' }) });

    // 9→10.5s: pull back → 3rd-person
    tl.to(cam.position, { x: 0, y: 35, z: 270, duration: 1.5, ease: 'power2.inOut',
      onUpdate: () => cam.lookAt(0, 12, -150),
      onStart: () => {
        this.callbacks.onStateChange({ phaseTitle: '' });
        gsap.to(this.playerChar.rotation, { x: 0, duration: 0.7, ease: 'back.out(1.4)' });
      },
      onComplete: () => {
        this.phase = 'combat';
        this.combatStarted = true;
        this.camLookTarget.set(0, 12, -150);
        this.callbacks.onStateChange({ phase: 'combat', phaseTitle: 'BATTLE STATIONS!', showControls: true });
        setTimeout(() => this.callbacks.onStateChange({ phaseTitle: '' }), 2600);
      },
    });
  }

  private fireCannonball() {
    if (this.canFireTimer > 0) return;
    this.canFireTimer = 0.55;
    const side = this.fireFromLeft ? -1 : 1;
    this.fireFromLeft = !this.fireFromLeft;
    const sp = this.playerShip.position, sr = this.playerShip.rotation.y;
    const origin = new THREE.Vector3(
      sp.x + side * 12 * Math.cos(sr + Math.PI / 2),
      sp.y + 5,
      sp.z + side * 12 * Math.sin(sr + Math.PI / 2),
    );
    let target = new THREE.Vector3(0, 10, -600); let nd = Infinity;
    this.alienFleet.forEach(a => { if (!a.alive) return; const d = origin.distanceTo(a.group.position); if (d < nd) { nd = d; target = a.group.position.clone(); } });

    const dir = target.clone().sub(origin).normalize();
    const ball = new THREE.Mesh(new THREE.SphereGeometry(0.75, 7, 7), stdMat({ color: 0x333322, metalness: 0.9, roughness: 0.2 }));
    ball.position.copy(origin); this.scene.add(ball);
    const trail = makeTrail(false); this.scene.add(trail);
    this.projectiles.push({ mesh: ball, velocity: dir.multiplyScalar(125), type: 'cannonball', lifetime: 0, trail, trailPositions: trail.geometry.attributes.position.array as Float32Array });

    const flash = new THREE.PointLight(0xffaa44, 28, 20);
    flash.position.copy(origin); this.scene.add(flash);
    setTimeout(() => this.scene.remove(flash), 90);
    const smoke = makeBurst(origin, 0x777777, IS_MOBILE ? 8 : 14);
    this.scene.add(smoke.mesh); this.particles.push(smoke);
  }

  private fireAlienLaser(alien: AlienShip) {
    const origin = alien.group.position.clone(); origin.y -= 4;
    const target = this.playerShip.position.clone(); target.y += 6;
    const dir = target.clone().sub(origin).normalize();
    const laser = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 7, 7), stdMat({ color: alien.glow.color, emissive: alien.glow.color, emissiveIntensity: 2.2 }));
    laser.position.copy(origin); laser.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
    this.scene.add(laser);
    const trail = makeTrail(true); this.scene.add(trail);
    this.projectiles.push({ mesh: laser, velocity: dir.multiplyScalar(90), type: 'laser', lifetime: 0, trail, trailPositions: trail.geometry.attributes.position.array as Float32Array });
    alien.glow.intensity = 18;
    setTimeout(() => { if (alien.alive) alien.glow.intensity = alien.group.userData.isBoss ? 3.5 : 2.0; }, 160);
  }

  private spawnExplosion(pos: THREE.Vector3, isAlien: boolean) {
    const c = isAlien ? 0x00ff88 : 0xff6600;
    const b = makeBurst(pos, c, IS_MOBILE ? 14 : 28); this.scene.add(b.mesh); this.particles.push(b);
    const l = new THREE.PointLight(c, 45, 90); l.position.copy(pos); this.scene.add(l);
    gsap.to(l, { intensity: 0, duration: 0.55, onComplete: () => this.scene.remove(l) });
  }

  private onResize = () => {
    const w = this.canvas.clientWidth, h = this.canvas.clientHeight;
    this.camera.aspect = w / h; this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer?.setSize(w, h);
  };

  // ─── Third-person follow camera ───────────────────────────────────────────
  private updateCombatCamera(dt: number) {
    if (!this.combatStarted) return;
    const rotY = this.playerRotation;
    // Position: behind and above the ship
    const targetPos = new THREE.Vector3(
      this.playerShip.position.x - Math.sin(rotY) * 75,
      this.playerShip.position.y + 32,
      this.playerShip.position.z - Math.cos(rotY) * 75,
    );
    // Smooth lerp — faster on mobile (less expensive) 
    const lerpSpeed = IS_MOBILE ? 4 : 5;
    this.camera.position.lerp(targetPos, lerpSpeed * dt);

    // Look target: forward from ship toward enemies
    const newLook = new THREE.Vector3(
      this.playerShip.position.x + Math.sin(rotY) * 180,
      10,
      this.playerShip.position.z + Math.cos(rotY) * 180,
    );
    this.camLookTarget.lerp(newLook, 4 * dt);
    this.camera.lookAt(this.camLookTarget);
  }

  private updatePlayerShip(dt: number) {
    if (!this.combatStarted) return;
    const fwd  = this.keys['KeyW'] || this.keys['ArrowUp']    || this.joystickY < -0.28;
    const bwd  = this.keys['KeyS'] || this.keys['ArrowDown']  || this.joystickY >  0.28;
    const rotL = this.keys['KeyA'] || this.keys['ArrowLeft']  || this.joystickX < -0.28;
    const rotR = this.keys['KeyD'] || this.keys['ArrowRight'] || this.joystickX >  0.28;

    if (fwd)      this.playerSpeed = Math.min(this.playerSpeed + 40 * dt, 55);
    else if (bwd) this.playerSpeed = Math.max(this.playerSpeed - 40 * dt, -27);
    else          this.playerSpeed *= 0.96;

    if (rotL) this.playerRotation += 0.9 * dt;
    if (rotR) this.playerRotation -= 0.9 * dt;

    this.playerShip.rotation.y = this.playerRotation + Math.PI;
    this.playerShip.position.x += Math.sin(this.playerRotation) * this.playerSpeed * dt;
    this.playerShip.position.z += Math.cos(this.playerRotation) * this.playerSpeed * dt;

    const t = this.clock.getElapsedTime();
    this.playerShip.position.y = 2.5 + Math.sin(t * 0.6) * 0.35;
    this.playerShip.rotation.x = Math.sin(t * 0.5) * 0.015;
    this.playerShip.rotation.z = Math.cos(t * 0.7) * 0.010;

    // Move hero char with ship
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
      const spd   = idx === 0 ? 0.2 : 0.3;
      alien.group.position.x += Math.sin(t * spd + alien.moveOffset) * 10 * dt;
      alien.group.position.y  = baseY + Math.sin(t * 0.5 + alien.moveOffset) * 6;
      alien.group.position.z += Math.cos(t * spd * 0.7 + alien.moveOffset) * 4 * dt;
      if (alien.ring) { alien.ring.rotation.y += dt * (idx === 0 ? 0.9 : 0.7); alien.ring.rotation.x += dt * 0.1; }
      alien.glow.intensity = (idx === 0 ? 3.5 : 2.0) + Math.sin(t * 2.2 + idx) * 0.8;
      alien.group.lookAt(this.playerShip.position.x, alien.group.position.y, this.playerShip.position.z);
      alien.fireTimer -= dt;
      if (alien.fireTimer <= 0) { this.fireAlienLaser(alien); alien.fireTimer = 3.0 + Math.random() * 2.0; }
    });
    if (alive === 0 && this.phase === 'combat') {
      this.phase = 'victory';
      this.callbacks.onStateChange({ phase: 'victory', phaseTitle: 'VICTORY!' });
    }
    this.callbacks.onStateChange({ aliensAlive: alive, aliensTotal: this.alienFleet.length });
  }

  private updateProjectiles(dt: number) {
    const rm: Projectile[] = [];
    this.projectiles.forEach(p => {
      p.lifetime += dt;
      if (p.lifetime > (p.type === 'cannonball' ? 6 : 4)) { rm.push(p); return; }
      if (p.type === 'cannonball') p.velocity.y -= 18 * dt;
      p.mesh.position.addScaledVector(p.velocity, dt);
      const pos = p.trailPositions;
      for (let i = 19; i > 0; i--) { pos[i*3]=pos[(i-1)*3]; pos[i*3+1]=pos[(i-1)*3+1]; pos[i*3+2]=pos[(i-1)*3+2]; }
      pos[0]=p.mesh.position.x; pos[1]=p.mesh.position.y; pos[2]=p.mesh.position.z;
      p.trail.geometry.attributes.position.needsUpdate = true;

      if (p.type === 'cannonball') {
        this.alienFleet.forEach(a => {
          if (!a.alive || p.mesh.position.distanceTo(a.group.position) > 16) return;
          rm.push(p); a.hp -= 15;
          if (a.hp <= 0) { a.alive = false; this.spawnExplosion(a.group.position.clone(), true); this.scene.remove(a.group); }
          else { a.glow.intensity = 32; setTimeout(() => { if (a.alive) a.glow.intensity = a.group.userData.isBoss ? 3.5 : 2.0; }, 200); }
        });
      } else {
        if (p.mesh.position.distanceTo(this.playerShip.position) < 16) {
          rm.push(p); this.playerHP = Math.max(0, this.playerHP - 8);
          this.callbacks.onStateChange({ playerHP: this.playerHP });
          this.spawnExplosion(p.mesh.position.clone(), false);
          if (this.playerHP === 0 && this.phase === 'combat') { this.phase = 'defeat'; this.callbacks.onStateChange({ phase: 'defeat', phaseTitle: 'DEFEAT…' }); }
        }
        if (p.mesh.position.y < -2) rm.push(p);
      }
    });
    rm.forEach(p => { this.scene.remove(p.mesh); this.scene.remove(p.trail); const i = this.projectiles.indexOf(p); if (i !== -1) this.projectiles.splice(i, 1); });
  }

  private updateParticles(dt: number) {
    const rm: Particle[] = [];
    this.particles.forEach(p => {
      p.lifetime += dt;
      if (p.lifetime > p.maxLifetime) { rm.push(p); return; }
      (p.mesh.material as THREE.PointsMaterial).opacity = 1 - p.lifetime / p.maxLifetime;
      const pos = p.mesh.geometry.attributes.position.array as Float32Array;
      for (let i = 0; i < p.velocities.length; i++) {
        const v = p.velocities[i];
        pos[i*3] += v.x*dt; pos[i*3+1] += (v.y - 12*dt)*dt; pos[i*3+2] += v.z*dt; v.y -= 12*dt;
      }
      p.mesh.geometry.attributes.position.needsUpdate = true;
    });
    rm.forEach(p => { this.scene.remove(p.mesh); const i = this.particles.indexOf(p); if (i !== -1) this.particles.splice(i, 1); });
  }

  private animate = () => {
    this.animId = requestAnimationFrame(this.animate);
    // Cap dt — prevents spiral of death on tab unfocus / slow frames
    const dt = Math.min(this.clock.getDelta(), 0.05);
    const t  = this.clock.getElapsedTime();

    // Water animation
    (this.water.material as THREE.ShaderMaterial).uniforms['time'].value += dt * 0.4;

    // Breathing (only during cinematic — combat uses ship position for char)
    if (!this.combatStarted && this.playerChar) {
      this.playerChar.position.y = 10 + Math.sin(t * 1.6) * 0.1;
    }

    // Gunner gun-look animation
    const boss = this.alienFleet[0];
    if (boss) {
      boss.group.children.forEach(child => {
        const gi = child.userData?.gunnerIdx;
        if (gi === undefined || !(child instanceof THREE.Group)) return;
        const wa = child.userData.weaponArm;
        if (!wa) return;
        const look = Math.sin(t * 0.72 + gi * 2.0) > 0.35;
        wa.rotation.x = look ? -0.65 : 0.05;
        wa.rotation.y = look ? (gi === 0 ? 0.4 : -0.4) : 0;
      });
    }

    this.updatePlayerShip(dt);
    this.updateCombatCamera(dt);    // smooth follow camera
    this.updateAlienFleet(dt);
    this.updateProjectiles(dt);
    this.updateParticles(dt);

    // *** MOBILE: direct render (no composer) — 4x faster ***
    if (this.composer) {
      this.composer.render();
    } else {
      this.renderer.render(this.scene, this.camera);
    }
  };

  destroy() {
    cancelAnimationFrame(this.animId);
    window.removeEventListener('resize', this.onResize);
    this.renderer.dispose();
  }
}
