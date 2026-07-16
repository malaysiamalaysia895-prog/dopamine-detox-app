// @ts-nocheck
import * as THREE from 'three';
import { Water } from 'three/examples/jsm/objects/Water.js';
import { Sky } from 'three/examples/jsm/objects/Sky.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import gsap from 'gsap';

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

function createWaterNormals(): THREE.Texture {
  const size = 512;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  const img = ctx.createImageData(size, size);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4;
      const w1 = Math.sin((x / size) * Math.PI * 14 + (y / size) * Math.PI * 3);
      const w2 = Math.cos((y / size) * Math.PI * 10 - (x / size) * Math.PI * 5);
      const w3 = Math.sin((x + y) / size * Math.PI * 8);
      const nx = ((w1 * 0.4 + w3 * 0.1) * 0.5 + 0.5) * 255;
      const ny = ((w2 * 0.4 + w3 * 0.1) * 0.5 + 0.5) * 255;
      img.data[i]     = Math.max(0, Math.min(255, nx));
      img.data[i + 1] = Math.max(0, Math.min(255, ny));
      img.data[i + 2] = 200;
      img.data[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  return tex;
}

function buildPirateShip(): THREE.Group {
  const group = new THREE.Group();

  const hullMat = new THREE.MeshStandardMaterial({ color: 0x5c2d0a, roughness: 0.9, metalness: 0.1 });
  const darkWoodMat = new THREE.MeshStandardMaterial({ color: 0x3a1a06, roughness: 0.95 });
  const sailMat = new THREE.MeshStandardMaterial({ color: 0xddd0a8, roughness: 0.8, side: THREE.DoubleSide });
  const metalMat = new THREE.MeshStandardMaterial({ color: 0x888877, roughness: 0.3, metalness: 0.8 });
  const ropeMat = new THREE.MeshStandardMaterial({ color: 0x8B7355, roughness: 1.0 });

  // Main hull
  const hullGeo = new THREE.BoxGeometry(20, 7, 60);
  const hull = new THREE.Mesh(hullGeo, hullMat);
  hull.position.y = 0;
  group.add(hull);

  // Bow (pointed front)
  const bowGeo = new THREE.CylinderGeometry(0, 10, 10, 4);
  const bow = new THREE.Mesh(bowGeo, darkWoodMat);
  bow.position.set(0, 0, -35);
  bow.rotation.x = Math.PI / 2;
  bow.rotation.z = Math.PI / 4;
  group.add(bow);

  // Stern (back structure)
  const sternGeo = new THREE.BoxGeometry(20, 10, 10);
  const stern = new THREE.Mesh(sternGeo, hullMat);
  stern.position.set(0, 5, 28);
  group.add(stern);

  // Deck
  const deckGeo = new THREE.BoxGeometry(19, 1, 58);
  const deck = new THREE.Mesh(deckGeo, darkWoodMat);
  deck.position.y = 4;
  group.add(deck);

  // Forecastle (front raised platform)
  const foreGeo = new THREE.BoxGeometry(16, 3, 12);
  const fore = new THREE.Mesh(foreGeo, hullMat);
  fore.position.set(0, 5.5, -24);
  group.add(fore);

  // Poop deck (rear raised platform)
  const poopGeo = new THREE.BoxGeometry(16, 3, 14);
  const poop = new THREE.Mesh(poopGeo, hullMat);
  poop.position.set(0, 5.5, 22);
  group.add(poop);

  // Masts (3)
  const mastPositionsZ = [-18, 2, 20];
  const mastHeights = [42, 48, 36];
  mastPositionsZ.forEach((z, i) => {
    const mastGeo = new THREE.CylinderGeometry(0.45, 0.6, mastHeights[i], 8);
    const mast = new THREE.Mesh(mastGeo, darkWoodMat);
    mast.position.set(0, 4 + mastHeights[i] / 2, z);
    group.add(mast);

    // Cross-yard (horizontal beam for sail)
    const yardGeo = new THREE.CylinderGeometry(0.25, 0.25, 20, 8);
    const yard = new THREE.Mesh(yardGeo, darkWoodMat);
    yard.position.set(0, 4 + mastHeights[i] * 0.75, z);
    yard.rotation.z = Math.PI / 2;
    group.add(yard);

    // Sail
    const sailGeo = new THREE.PlaneGeometry(18, mastHeights[i] * 0.5);
    const sail = new THREE.Mesh(sailGeo, sailMat);
    sail.position.set(0.2, 4 + mastHeights[i] * 0.5, z);
    group.add(sail);

    // Rigging ropes (diagonals)
    const ropeGeo = new THREE.CylinderGeometry(0.08, 0.08, 22, 4);
    [-8, 8].forEach(xOff => {
      const rope = new THREE.Mesh(ropeGeo, ropeMat);
      rope.position.set(xOff / 2, 4 + mastHeights[i] * 0.4, z + xOff / 2);
      rope.rotation.z = Math.atan2(mastHeights[i] * 0.3, xOff);
      group.add(rope);
    });
  });

  // Bowsprit (diagonal front mast)
  const bspritGeo = new THREE.CylinderGeometry(0.3, 0.4, 28, 8);
  const bsprit = new THREE.Mesh(bspritGeo, darkWoodMat);
  bsprit.position.set(0, 8, -43);
  bsprit.rotation.x = -Math.PI / 6;
  group.add(bsprit);

  // Crow's nest on main mast
  const nestGeo = new THREE.CylinderGeometry(2, 1.5, 1.5, 8);
  const nest = new THREE.Mesh(nestGeo, darkWoodMat);
  nest.position.set(0, 4 + mastHeights[1] * 0.7, 2);
  group.add(nest);

  // Cannons (port and starboard sides)
  const cannonPositionsZ = [-20, -10, 0, 10, 20];
  cannonPositionsZ.forEach(z => {
    [-11, 11].forEach(x => {
      const cannonGeo = new THREE.CylinderGeometry(0.6, 0.7, 4, 8);
      const cannon = new THREE.Mesh(cannonGeo, metalMat);
      cannon.rotation.z = Math.PI / 2;
      cannon.position.set(x, 3.5, z);
      group.add(cannon);

      // Cannon ball pile
      const ballGeo = new THREE.SphereGeometry(0.4, 8, 8);
      const ball = new THREE.Mesh(ballGeo, metalMat);
      ball.position.set(x, 5, z);
      group.add(ball);
    });
  });

  // Jolly Roger flag
  const flagGeo = new THREE.PlaneGeometry(5, 3.5);
  const flagMat = new THREE.MeshStandardMaterial({ color: 0x111111, side: THREE.DoubleSide });
  const flag = new THREE.Mesh(flagGeo, flagMat);
  flag.position.set(0.6, 4 + mastHeights[1] - 1, 2);
  group.add(flag);

  // Windows / portholes on hull
  const portGeo = new THREE.CircleGeometry(0.6, 16);
  const portMat = new THREE.MeshStandardMaterial({ color: 0xffcc88, emissive: 0xffaa44, emissiveIntensity: 0.8 });
  [-20, -8, 8, 20].forEach(z => {
    [-10.1, 10.1].forEach(x => {
      const port = new THREE.Mesh(portGeo, portMat);
      port.position.set(x, 1, z);
      port.rotation.y = x < 0 ? -Math.PI / 2 : Math.PI / 2;
      group.add(port);
    });
  });

  group.castShadow = true;
  group.receiveShadow = true;

  return group;
}

function buildAlienUFO(color: number, emissiveColor: number): THREE.Group {
  const group = new THREE.Group();

  const bodyMat = new THREE.MeshStandardMaterial({ color: 0x0a1520, roughness: 0.2, metalness: 0.9 });
  const domeMat = new THREE.MeshStandardMaterial({
    color,
    emissive: emissiveColor,
    emissiveIntensity: 0.6,
    transparent: true,
    opacity: 0.82,
    roughness: 0.1,
    metalness: 0.3,
  });
  const ringMat = new THREE.MeshStandardMaterial({
    color,
    emissive: emissiveColor,
    emissiveIntensity: 1.2,
    roughness: 0.1,
    metalness: 0.8,
  });
  const glowMat = new THREE.MeshStandardMaterial({
    color: emissiveColor,
    emissive: emissiveColor,
    emissiveIntensity: 3.0,
    transparent: true,
    opacity: 0.5,
  });

  // Main disc body
  const discGeo = new THREE.CylinderGeometry(7, 9, 2.5, 32);
  const disc = new THREE.Mesh(discGeo, bodyMat);
  group.add(disc);

  // Lower skirt
  const skirtGeo = new THREE.CylinderGeometry(9, 7, 1.5, 32);
  const skirt = new THREE.Mesh(skirtGeo, bodyMat);
  skirt.position.y = -1.5;
  group.add(skirt);

  // Dome on top
  const domeGeo = new THREE.SphereGeometry(5, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2);
  const dome = new THREE.Mesh(domeGeo, domeMat);
  dome.position.y = 1.25;
  group.add(dome);

  // Outer rotating ring
  const ringGeo = new THREE.TorusGeometry(11, 0.6, 8, 48);
  const ring = new THREE.Mesh(ringGeo, ringMat);
  ring.rotation.x = Math.PI * 0.12;
  group.add(ring);

  // Inner glow core
  const coreGeo = new THREE.SphereGeometry(2.5, 16, 16);
  const core = new THREE.Mesh(coreGeo, glowMat);
  core.position.y = 2;
  group.add(core);

  // Beam port underneath
  const beamPortGeo = new THREE.CylinderGeometry(0.5, 1.8, 1.5, 16);
  const beamPortMat = new THREE.MeshStandardMaterial({ color: emissiveColor, emissive: emissiveColor, emissiveIntensity: 2.0 });
  const beamPort = new THREE.Mesh(beamPortGeo, beamPortMat);
  beamPort.position.y = -2.8;
  group.add(beamPort);

  // Glow light
  const light = new THREE.PointLight(emissiveColor, 8, 80);
  light.position.y = 2;
  group.add(light);

  (group as any)._ring = ring;
  (group as any)._light = light;

  return group;
}

function buildParticleBurst(position: THREE.Vector3, color: number, count = 24): Particle {
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  const velocities: THREE.Vector3[] = [];

  for (let i = 0; i < count; i++) {
    positions[i * 3] = position.x;
    positions[i * 3 + 1] = position.y;
    positions[i * 3 + 2] = position.z;

    const theta = Math.random() * Math.PI * 2;
    const phi = Math.random() * Math.PI;
    const speed = 8 + Math.random() * 20;
    velocities.push(new THREE.Vector3(
      Math.sin(phi) * Math.cos(theta) * speed,
      Math.abs(Math.cos(phi)) * speed * 0.8 + 4,
      Math.sin(phi) * Math.sin(theta) * speed,
    ));
  }

  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));

  const mat = new THREE.PointsMaterial({ color, size: 1.5, transparent: true, opacity: 1.0, sizeAttenuation: true });
  const points = new THREE.Points(geo, mat);

  return { mesh: points, velocities, lifetime: 0, maxLifetime: 1.8 };
}

function buildProjectileTrail(isLaser: boolean): THREE.Points {
  const count = 20;
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count * 3);
  geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  const color = isLaser ? 0x00ffaa : 0x888877;
  const mat = new THREE.PointsMaterial({ color, size: isLaser ? 0.8 : 0.6, transparent: true, opacity: 0.7, sizeAttenuation: true });
  return new THREE.Points(geo, mat);
}

export class PirateGame {
  private canvas: HTMLCanvasElement;
  private renderer!: THREE.WebGLRenderer;
  private scene!: THREE.Scene;
  private camera!: THREE.PerspectiveCamera;
  private composer!: EffectComposer;
  private water!: Water;
  private sun!: THREE.Vector3;
  private playerShip!: THREE.Group;
  private alienFleet: AlienShip[] = [];
  private projectiles: Projectile[] = [];
  private particles: Particle[] = [];
  private clock = new THREE.Clock();
  private animFrameId = 0;
  private callbacks: GameCallbacks;

  private phase: GamePhase = 'intro';
  private playerHP = 100;
  private readonly playerMaxHP = 100;
  private playerSpeed = 0;
  private playerRotation = 0;
  private canFireTimer = 0;
  private fireFromLeft = true;
  private combatStarted = false;
  private keys: Record<string, boolean> = {};

  private directionalLight!: THREE.DirectionalLight;

  constructor(canvas: HTMLCanvasElement, callbacks: GameCallbacks) {
    this.canvas = canvas;
    this.callbacks = callbacks;
    this.init();
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
    // Test WebGL availability first
    const testCtx = this.canvas.getContext('webgl2') || this.canvas.getContext('webgl');
    if (!testCtx) {
      throw new Error('WebGL is not supported in this browser.');
    }

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: window.devicePixelRatio < 2,
      powerPreference: 'default',
      failIfMajorPerformanceCaveat: false,
      logarithmicDepthBuffer: false,
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(this.canvas.clientWidth, this.canvas.clientHeight);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.9;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    window.addEventListener('resize', this.onResize);
  }

  private setupScene() {
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.FogExp2(0x223344, 0.0008);

    this.camera = new THREE.PerspectiveCamera(
      65,
      this.canvas.clientWidth / this.canvas.clientHeight,
      0.5,
      8000,
    );
    this.camera.position.set(0, 400, 0);
    this.camera.lookAt(0, 0, 0);

    // Ambient
    const ambient = new THREE.AmbientLight(0x334466, 0.6);
    this.scene.add(ambient);

    // Hemisphere
    const hemi = new THREE.HemisphereLight(0xff8844, 0x223355, 0.5);
    this.scene.add(hemi);

    // Directional (sun)
    this.directionalLight = new THREE.DirectionalLight(0xff9955, 2.5);
    this.directionalLight.position.set(300, 200, -500);
    this.directionalLight.castShadow = true;
    this.directionalLight.shadow.mapSize.set(2048, 2048);
    this.directionalLight.shadow.camera.near = 1;
    this.directionalLight.shadow.camera.far = 2000;
    this.directionalLight.shadow.camera.left = -300;
    this.directionalLight.shadow.camera.right = 300;
    this.directionalLight.shadow.camera.top = 300;
    this.directionalLight.shadow.camera.bottom = -300;
    this.scene.add(this.directionalLight);
  }

  private buildWaterAndSky() {
    this.sun = new THREE.Vector3();

    // Sky setup
    const sky = new Sky();
    sky.scale.setScalar(10000);
    this.scene.add(sky);

    const skyUniforms = (sky.material as THREE.ShaderMaterial).uniforms;
    skyUniforms['turbidity'].value = 8;
    skyUniforms['rayleigh'].value = 3;
    skyUniforms['mieCoefficient'].value = 0.008;
    skyUniforms['mieDirectionalG'].value = 0.82;

    // Golden sunset — sun low on the horizon
    const phi = THREE.MathUtils.degToRad(90 - 4);
    const theta = THREE.MathUtils.degToRad(190);
    this.sun.setFromSphericalCoords(1, phi, theta);
    skyUniforms['sunPosition'].value.copy(this.sun);

    // Water
    const waterGeo = new THREE.PlaneGeometry(10000, 10000);
    this.water = new Water(waterGeo, {
      textureWidth: 512,
      textureHeight: 512,
      waterNormals: createWaterNormals(),
      sunDirection: this.sun.clone().normalize(),
      sunColor: 0xff9944,
      waterColor: 0x002233,
      distortionScale: 4.5,
      fog: true,
    });
    this.water.rotation.x = -Math.PI / 2;
    this.water.position.y = -1;
    this.scene.add(this.water);
  }

  private buildEnvironment() {
    // Distant rock formations
    const rockMat = new THREE.MeshStandardMaterial({ color: 0x2a2a2a, roughness: 0.95 });
    const rockPositions = [
      [-600, 0, -800], [700, 0, -600], [-400, 0, 600], [800, 0, 400],
    ];
    rockPositions.forEach(([x, , z]) => {
      const h = 30 + Math.random() * 60;
      const rockGeo = new THREE.CylinderGeometry(15 + Math.random() * 20, 30 + Math.random() * 20, h, 6);
      const rock = new THREE.Mesh(rockGeo, rockMat);
      rock.position.set(x, h / 2 - 1, z);
      rock.rotation.y = Math.random() * Math.PI;
      this.scene.add(rock);
    });

    // Floating debris
    const debrisMat = new THREE.MeshStandardMaterial({ color: 0x4a2c0a, roughness: 0.9 });
    for (let i = 0; i < 12; i++) {
      const debGeo = new THREE.BoxGeometry(
        2 + Math.random() * 4, 0.4, 1 + Math.random() * 3,
      );
      const deb = new THREE.Mesh(debGeo, debrisMat);
      deb.position.set(
        (Math.random() - 0.5) * 400,
        -0.5,
        (Math.random() - 0.5) * 400,
      );
      deb.rotation.y = Math.random() * Math.PI;
      this.scene.add(deb);
    }
  }

  private buildPlayerShip() {
    this.playerShip = buildPirateShip();
    this.playerShip.position.set(0, 2.5, 180);
    this.playerShip.rotation.y = Math.PI;
    this.scene.add(this.playerShip);

    // Ship light
    const shipLight = new THREE.PointLight(0xffcc88, 4, 60);
    shipLight.position.set(0, 15, 0);
    this.playerShip.add(shipLight);
  }

  private buildAlienFleet() {
    const alienColors = [
      [0x00ccff, 0x0088ff],
      [0x00ff88, 0x00cc55],
      [0xff44cc, 0xff00aa],
      [0xffaa00, 0xff7700],
      [0xaa44ff, 0x8800ff],
    ];

    const positions = [
      [-200, 15, -550],
      [-80, 18, -620],
      [0, 22, -680],
      [80, 18, -620],
      [200, 15, -550],
    ];

    alienColors.forEach(([color, emissive], i) => {
      const group = buildAlienUFO(color, emissive);
      const [x, y, z] = positions[i];
      group.position.set(x, y, z);
      this.scene.add(group);

      this.alienFleet.push({
        group,
        hp: 100,
        maxHP: 100,
        fireTimer: 3 + i * 1.2,
        alive: true,
        ring: (group as any)._ring as THREE.Mesh,
        glow: (group as any)._light as THREE.PointLight,
        moveOffset: Math.random() * Math.PI * 2,
      });
    });
  }

  private setupPostprocessing() {
    this.composer = new EffectComposer(this.renderer);
    const renderPass = new RenderPass(this.scene, this.camera);
    this.composer.addPass(renderPass);

    const bloomPass = new UnrealBloomPass(
      new THREE.Vector2(this.canvas.clientWidth, this.canvas.clientHeight),
      0.8,
      0.5,
      0.75,
    );
    this.composer.addPass(bloomPass);

    const outputPass = new OutputPass();
    this.composer.addPass(outputPass);
  }

  private setupInput() {
    window.addEventListener('keydown', (e) => { this.keys[e.code] = true; });
    window.addEventListener('keyup', (e) => { this.keys[e.code] = false; });
    this.canvas.addEventListener('click', () => {
      if (this.phase === 'combat') this.fireCannonball();
    });
  }

  private startIntroSequence() {
    this.callbacks.onStateChange({ phase: 'intro', phaseTitle: 'ALIEN INVASION', showControls: false });

    const cam = this.camera;
    const tl = gsap.timeline();

    // Phase 1: High aerial view
    tl.set(cam.position, { x: 0, y: 500, z: 0 });
    tl.set(cam.rotation, { x: -Math.PI / 2, y: 0, z: 0 });

    // Phase 2: Dive toward ship bow
    tl.to(cam.position, {
      x: 60, y: 60, z: 280,
      duration: 2.5,
      ease: 'power2.in',
      onUpdate: () => cam.lookAt(0, 2.5, 180),
    });

    // Phase 3: Slide along broadside — cannons visible
    tl.to(cam.position, {
      x: -80, y: 18, z: 150,
      duration: 2.0,
      ease: 'power1.inOut',
      onUpdate: () => cam.lookAt(0, 8, 180),
    });

    // Phase 4: Pull back — alien fleet revealed on horizon
    tl.to(cam.position, {
      x: 0, y: 35, z: 350,
      duration: 2.2,
      ease: 'power2.out',
      onUpdate: () => cam.lookAt(0, 10, -400),
      onStart: () => {
        this.callbacks.onStateChange({ phaseTitle: 'THE FLEET APPROACHES…' });
      },
    });

    // Phase 5: Zoom in behind ship — combat position
    tl.to(cam.position, {
      x: 0, y: 28, z: 260,
      duration: 1.8,
      ease: 'power2.inOut',
      onUpdate: () => cam.lookAt(0, 10, -400),
    });

    // Phase 6: Combat begins
    tl.call(() => {
      this.phase = 'combat';
      this.combatStarted = true;
      this.callbacks.onStateChange({
        phase: 'combat',
        phaseTitle: 'BATTLE STATIONS!',
        showControls: true,
      });
      setTimeout(() => this.callbacks.onStateChange({ phaseTitle: '' }), 2500);
    });
  }

  private fireCannonball() {
    if (this.canFireTimer > 0) return;
    this.canFireTimer = 0.55;

    const side = this.fireFromLeft ? -1 : 1;
    this.fireFromLeft = !this.fireFromLeft;

    const shipPos = this.playerShip.position;
    const shipRot = this.playerShip.rotation.y;

    const offsetX = side * 12 * Math.cos(shipRot + Math.PI / 2);
    const offsetZ = side * 12 * Math.sin(shipRot + Math.PI / 2);

    const origin = new THREE.Vector3(
      shipPos.x + offsetX,
      shipPos.y + 4,
      shipPos.z + offsetZ,
    );

    // Fire toward nearest alien
    let target = new THREE.Vector3(0, 10, -600);
    let nearestDist = Infinity;
    this.alienFleet.forEach(a => {
      if (!a.alive) return;
      const d = origin.distanceTo(a.group.position);
      if (d < nearestDist) { nearestDist = d; target = a.group.position.clone(); }
    });

    const dir = target.clone().sub(origin).normalize();
    const speed = 120;

    const geo = new THREE.SphereGeometry(0.7, 8, 8);
    const mat = new THREE.MeshStandardMaterial({ color: 0x444433, metalness: 0.9 });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.copy(origin);
    this.scene.add(mesh);

    const trail = buildProjectileTrail(false);
    this.scene.add(trail);

    const trailPositions = trail.geometry.attributes.position.array as Float32Array;

    this.projectiles.push({
      mesh,
      velocity: dir.multiplyScalar(speed),
      type: 'cannonball',
      lifetime: 0,
      trail,
      trailPositions,
    });

    // Muzzle flash
    const flash = new THREE.PointLight(0xffaa44, 30, 20);
    flash.position.copy(origin);
    this.scene.add(flash);
    setTimeout(() => this.scene.remove(flash), 100);

    // Smoke particle
    const smoke = buildParticleBurst(origin, 0x888888, 12);
    this.scene.add(smoke.mesh);
    this.particles.push(smoke);
  }

  private fireAlienLaser(alien: AlienShip) {
    const origin = alien.group.position.clone();
    origin.y -= 3;

    const target = this.playerShip.position.clone();
    target.y += 5;

    const dir = target.clone().sub(origin).normalize();
    const speed = 90;

    const laserGeo = new THREE.CylinderGeometry(0.3, 0.3, 6, 8);
    const laserMat = new THREE.MeshStandardMaterial({
      color: alien.glow.color,
      emissive: alien.glow.color,
      emissiveIntensity: 4.0,
    });
    const mesh = new THREE.Mesh(laserGeo, laserMat);
    mesh.position.copy(origin);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
    this.scene.add(mesh);

    const trail = buildProjectileTrail(true);
    this.scene.add(trail);
    const trailPositions = trail.geometry.attributes.position.array as Float32Array;

    this.projectiles.push({
      mesh,
      velocity: dir.multiplyScalar(speed),
      type: 'laser',
      lifetime: 0,
      trail,
      trailPositions,
    });

    // Alien fire flash
    alien.glow.intensity = 25;
    setTimeout(() => { alien.glow.intensity = 8; }, 150);
  }

  private spawnExplosion(position: THREE.Vector3, isAlien: boolean) {
    const color = isAlien ? 0x00ff88 : 0xff6600;
    const burst = buildParticleBurst(position, color, 32);
    this.scene.add(burst.mesh);
    this.particles.push(burst);

    // Secondary flash
    const flash = buildParticleBurst(position, isAlien ? 0x00ccff : 0xffcc44, 16);
    flash.maxLifetime = 0.8;
    this.scene.add(flash.mesh);
    this.particles.push(flash);

    // Light flash
    const light = new THREE.PointLight(color, 50, 100);
    light.position.copy(position);
    this.scene.add(light);
    gsap.to(light, { intensity: 0, duration: 0.6, onComplete: () => this.scene.remove(light) });
  }

  private onResize = () => {
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
  };

  private updatePlayerShip(dt: number) {
    if (!this.combatStarted) return;

    const maxSpeed = 55;
    const acceleration = 40;
    const rotSpeed = 0.9;

    if (this.keys['KeyW'] || this.keys['ArrowUp']) {
      this.playerSpeed = Math.min(this.playerSpeed + acceleration * dt, maxSpeed);
    } else if (this.keys['KeyS'] || this.keys['ArrowDown']) {
      this.playerSpeed = Math.max(this.playerSpeed - acceleration * dt, -maxSpeed * 0.5);
    } else {
      this.playerSpeed *= 0.96;
    }

    if (this.keys['KeyA'] || this.keys['ArrowLeft']) {
      this.playerShip.rotation.y -= rotSpeed * dt;
    }
    if (this.keys['KeyD'] || this.keys['ArrowRight']) {
      this.playerShip.rotation.y += rotSpeed * dt;
    }

    const angle = this.playerShip.rotation.y;
    this.playerShip.position.x -= Math.sin(angle) * this.playerSpeed * dt;
    this.playerShip.position.z -= Math.cos(angle) * this.playerSpeed * dt;

    // Keep ship in bounds
    this.playerShip.position.x = Math.max(-800, Math.min(800, this.playerShip.position.x));
    this.playerShip.position.z = Math.max(-800, Math.min(800, this.playerShip.position.z));

    // Gentle bob
    const t = this.clock.getElapsedTime();
    this.playerShip.position.y = 2.5 + Math.sin(t * 0.6) * 0.4;
    this.playerShip.rotation.z = Math.sin(t * 0.5) * 0.015;
    this.playerShip.rotation.x = Math.sin(t * 0.7 + 1) * 0.01;

    // Camera follows ship in combat
    if (this.phase === 'combat') {
      const camOffset = new THREE.Vector3(
        Math.sin(this.playerShip.rotation.y) * 110,
        28,
        Math.cos(this.playerShip.rotation.y) * 110,
      );
      this.camera.position.lerp(
        this.playerShip.position.clone().add(camOffset),
        dt * 3.5,
      );
      const lookTarget = this.playerShip.position.clone().add(
        new THREE.Vector3(
          -Math.sin(this.playerShip.rotation.y) * 200,
          0,
          -Math.cos(this.playerShip.rotation.y) * 200,
        ),
      );
      this.camera.lookAt(lookTarget);
    }

    if (this.canFireTimer > 0) this.canFireTimer -= dt;
  }

  private updateAlienFleet(dt: number) {
    if (!this.combatStarted) return;
    const t = this.clock.getElapsedTime();

    let aliensAlive = 0;

    this.alienFleet.forEach((alien, idx) => {
      if (!alien.alive) return;
      aliensAlive++;

      // Rotate ring
      alien.ring.rotation.z += dt * (0.8 + idx * 0.15);

      // Bob
      alien.group.position.y = (15 + idx * 1.5) + Math.sin(t * 0.8 + alien.moveOffset) * 3;

      // Strafe
      alien.group.position.x += Math.sin(t * 0.4 + alien.moveOffset) * dt * 6;

      // Advance toward player
      const toPlayer = this.playerShip.position.clone().sub(alien.group.position);
      const dist = toPlayer.length();
      if (dist > 120) {
        toPlayer.normalize().multiplyScalar(dt * 18);
        alien.group.position.add(toPlayer);
      }

      // Face toward player
      alien.group.lookAt(this.playerShip.position.x, alien.group.position.y, this.playerShip.position.z);

      // Glow pulse
      alien.glow.intensity = 8 + Math.sin(t * 2 + idx) * 2;

      // Fire timer
      alien.fireTimer -= dt;
      if (alien.fireTimer <= 0) {
        this.fireAlienLaser(alien);
        alien.fireTimer = 3.5 + Math.random() * 2;
      }
    });

    if (aliensAlive === 0 && this.phase === 'combat') {
      this.phase = 'victory';
      this.callbacks.onStateChange({ phase: 'victory', phaseTitle: 'VICTORY!' });
    }

    this.callbacks.onStateChange({ aliensAlive, aliensTotal: this.alienFleet.length });
  }

  private updateProjectiles(dt: number) {
    const toRemove: Projectile[] = [];

    this.projectiles.forEach(proj => {
      proj.lifetime += dt;
      const maxLife = proj.type === 'cannonball' ? 6 : 4;
      if (proj.lifetime > maxLife) {
        toRemove.push(proj);
        return;
      }

      // Gravity for cannonballs
      if (proj.type === 'cannonball') {
        proj.velocity.y -= 18 * dt;
      }

      proj.mesh.position.addScaledVector(proj.velocity, dt);

      // Update trail
      const trailCount = 20;
      const positions = proj.trailPositions;
      for (let i = trailCount - 1; i > 0; i--) {
        positions[i * 3] = positions[(i - 1) * 3];
        positions[i * 3 + 1] = positions[(i - 1) * 3 + 1];
        positions[i * 3 + 2] = positions[(i - 1) * 3 + 2];
      }
      positions[0] = proj.mesh.position.x;
      positions[1] = proj.mesh.position.y;
      positions[2] = proj.mesh.position.z;
      proj.trail.geometry.attributes.position.needsUpdate = true;

      // Hit water
      if (proj.mesh.position.y < -0.5) {
        this.spawnExplosion(proj.mesh.position.clone(), false);
        toRemove.push(proj);
        return;
      }

      if (proj.type === 'cannonball') {
        // Check alien hits
        this.alienFleet.forEach(alien => {
          if (!alien.alive) return;
          if (proj.mesh.position.distanceTo(alien.group.position) < 12) {
            alien.hp -= 34;
            this.spawnExplosion(proj.mesh.position.clone(), true);
            if (alien.hp <= 0) {
              alien.alive = false;
              this.scene.remove(alien.group);
              this.spawnExplosion(alien.group.position.clone(), true);
              this.spawnExplosion(alien.group.position.clone().add(new THREE.Vector3(0, 10, 0)), true);
            }
            toRemove.push(proj);
          }
        });
      } else {
        // Check player hit
        if (proj.mesh.position.distanceTo(this.playerShip.position) < 18) {
          this.playerHP = Math.max(0, this.playerHP - 12);
          this.callbacks.onStateChange({ playerHP: this.playerHP });
          this.spawnExplosion(proj.mesh.position.clone(), false);
          if (this.playerHP <= 0 && this.phase === 'combat') {
            this.phase = 'defeat';
            this.callbacks.onStateChange({ phase: 'defeat', phaseTitle: 'SHIP DESTROYED!' });
          }
          toRemove.push(proj);
        }
      }
    });

    toRemove.forEach(p => {
      this.scene.remove(p.mesh);
      this.scene.remove(p.trail);
      const idx = this.projectiles.indexOf(p);
      if (idx !== -1) this.projectiles.splice(idx, 1);
    });
  }

  private updateParticles(dt: number) {
    const toRemove: Particle[] = [];

    this.particles.forEach(particle => {
      particle.lifetime += dt;
      const progress = particle.lifetime / particle.maxLifetime;
      if (progress >= 1) { toRemove.push(particle); return; }

      const mat = particle.mesh.material as THREE.PointsMaterial;
      mat.opacity = 1.0 - progress;

      const positions = particle.mesh.geometry.attributes.position.array as Float32Array;
      const count = positions.length / 3;
      for (let i = 0; i < count; i++) {
        const v = particle.velocities[i];
        positions[i * 3] += v.x * dt;
        positions[i * 3 + 1] += (v.y - 12 * dt) * dt;
        positions[i * 3 + 2] += v.z * dt;
        v.y -= 12 * dt;
      }
      particle.mesh.geometry.attributes.position.needsUpdate = true;
    });

    toRemove.forEach(p => {
      this.scene.remove(p.mesh);
      const idx = this.particles.indexOf(p);
      if (idx !== -1) this.particles.splice(idx, 1);
    });
  }

  private animate = () => {
    this.animFrameId = requestAnimationFrame(this.animate);
    const dt = Math.min(this.clock.getDelta(), 0.05);
    const t = this.clock.getElapsedTime();

    // Animate water
    (this.water.material as THREE.ShaderMaterial).uniforms['time'].value += dt * 0.4;

    this.updatePlayerShip(dt);
    this.updateAlienFleet(dt);
    this.updateProjectiles(dt);
    this.updateParticles(dt);

    // Sun shimmer on water
    const sunShimmer = this.sun.clone();
    sunShimmer.y += Math.sin(t * 0.3) * 0.01;
    (this.water.material as THREE.ShaderMaterial).uniforms['sunDirection'].value.copy(sunShimmer.normalize());

    this.composer.render();
  };

  destroy() {
    cancelAnimationFrame(this.animFrameId);
    window.removeEventListener('resize', this.onResize);
    window.removeEventListener('keydown', () => {});
    window.removeEventListener('keyup', () => {});
    this.renderer.dispose();
  }
}
