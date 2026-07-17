// @ts-nocheck
import * as THREE from 'three';
import { Water } from 'three/examples/jsm/objects/Water.js';
import { Sky }   from 'three/examples/jsm/objects/Sky.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass }     from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass }     from 'three/examples/jsm/postprocessing/OutputPass.js';
import gsap from 'gsap';

// ─── Types ────────────────────────────────────────────────────────────────────
export type GamePhase = 'intro' | 'combat' | 'victory' | 'defeat';
export interface GameState {
  phase: GamePhase;
  playerHP: number; playerMaxHP: number;
  aliensAlive: number; aliensTotal: number;
  phaseTitle: string; showControls: boolean;
}
export interface GameCallbacks { onStateChange: (s: Partial<GameState>) => void; }

interface Projectile {
  mesh: THREE.Mesh; velocity: THREE.Vector3;
  type: 'cannonball' | 'laser'; lifetime: number;
  trail: THREE.Points; trailPositions: Float32Array;
}
interface AlienShip {
  group: THREE.Group; hp: number; maxHP: number;
  fireTimer: number; alive: boolean;
  ring: THREE.Mesh; glow: THREE.PointLight;
  moveOffset: number; marker: THREE.Mesh;
}
interface Particle {
  mesh: THREE.Points; velocities: THREE.Vector3[];
  lifetime: number; maxLifetime: number;
}

// ─── Mobile detection ─────────────────────────────────────────────────────────
const IS_MOBILE = typeof window !== 'undefined' &&
  ('ontouchstart' in window || navigator.maxTouchPoints > 0 || window.innerWidth < 900);

// ─── CDN textures (fail silently offline — color fallback used) ───────────────
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
  const t = tLoader.load(url, undefined, undefined, () => {/* offline fallback */});
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(rep, rep);
  return t;
}

// ─── Procedural water normal (offline-safe) ───────────────────────────────────
function makeWaterNormal(): THREE.Texture {
  const sz = IS_MOBILE ? 256 : 512;
  const cv = document.createElement('canvas'); cv.width = cv.height = sz;
  const cx = cv.getContext('2d')!;
  const id = cx.createImageData(sz, sz);
  for (let y = 0; y < sz; y++) for (let x = 0; x < sz; x++) {
    const i = (y * sz + x) * 4;
    const u = x/sz, v = y/sz;
    id.data[i]   = ((Math.sin(u*Math.PI*14+v*Math.PI*4)*0.5+0.5)*255)|0;
    id.data[i+1] = ((Math.cos(v*Math.PI*10-u*Math.PI*6)*0.5+0.5)*255)|0;
    id.data[i+2] = 210; id.data[i+3] = 255;
  }
  cx.putImageData(id,0,0);
  const t = new THREE.CanvasTexture(cv);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
}

// ─── Material helpers ─────────────────────────────────────────────────────────
function stdMat(o: THREE.MeshStandardMaterialParameters) { return new THREE.MeshStandardMaterial(o); }
// Safe add-with-position (Object3D.position is non-writable in Three r160)
function addP(g, m, x, y, z) { m.position.set(x,y,z); g.add(m); return m; }
function mk(g, mat) { const m = new THREE.Mesh(g, mat); m.castShadow = !IS_MOBILE; return m; }

// ─── Pirate ship ──────────────────────────────────────────────────────────────
function buildPirateShip(): THREE.Group {
  const g = new THREE.Group();
  const wD = loadTex(TEXTURES.woodDiff, 5); const wR = loadTex(TEXTURES.woodRough, 5);
  const wN = loadTex(TEXTURES.woodNorm, 5); const mD = loadTex(TEXTURES.metalDiff, 2);
  const mR = loadTex(TEXTURES.metalRough, 2);
  const hull  = stdMat({ color:0x7A3A10, map:wD, roughnessMap:wR, normalMap:wN, normalScale:new THREE.Vector2(1.4,1.4), roughness:0.85, metalness:0.04 });
  const deck  = stdMat({ color:0x5C2A08, map:wD, roughnessMap:wR, normalMap:wN, normalScale:new THREE.Vector2(1.1,1.1), roughness:0.9, metalness:0.0 });
  const metal = stdMat({ color:0x888877, map:mD, roughnessMap:mR, roughness:0.42, metalness:0.82 });
  const sail  = stdMat({ color:0xDDD0A8, roughness:0.85, side:THREE.DoubleSide });

  // Hull
  g.add(mk(new THREE.BoxGeometry(20,7,60), hull));
  // Bow
  const bow = mk(new THREE.CylinderGeometry(0,10,10,4), deck);
  bow.position.set(0,0,-35); bow.rotation.set(Math.PI/2,0,Math.PI/4); g.add(bow);
  // Stern
  const stern = mk(new THREE.BoxGeometry(20,10,10), hull); addP(g,stern,0,5,28);
  addP(g, mk(new THREE.BoxGeometry(16,3,12), hull),  0, 5.5, -24);
  addP(g, mk(new THREE.BoxGeometry(16,3,14), hull),  0, 5.5,  22);
  // Deck
  addP(g, mk(new THREE.BoxGeometry(19,1,58), deck), 0, 4, 0);

  // Masts + sails
  [{z:-18,h:42},{z:2,h:48},{z:20,h:36}].forEach(({z,h})=>{
    const mast = mk(new THREE.CylinderGeometry(0.45,0.65,h,8), deck);
    mast.position.set(0,4+h/2,z); g.add(mast);
    const yard = mk(new THREE.CylinderGeometry(0.22,0.22,22,8), deck);
    yard.position.set(0,4+h*0.78,z); yard.rotation.z = Math.PI/2; g.add(yard);
    [-1,1].forEach(s=>{
      const sl = mk(new THREE.PlaneGeometry(9.5,h*0.55), sail);
      sl.position.set(s*5,4+h*0.78-h*0.14,z); g.add(sl);
    });
  });

  // Cannons
  const cc = IS_MOBILE ? 3 : 6;
  [-1,1].forEach(s=>{ for(let ci=0;ci<cc;ci++){
    const b = mk(new THREE.CylinderGeometry(0.6,0.7,6,IS_MOBILE?6:10), metal);
    b.position.set(s*11,1.5,-20+ci*(IS_MOBILE?16:8)); b.rotation.z=Math.PI/2; g.add(b);
  }});

  // Railings
  const rc = IS_MOBILE ? 5 : 10;
  [-9,9].forEach(sx=>{
    for(let pi=0;pi<rc;pi++){
      addP(g, mk(new THREE.CylinderGeometry(0.18,0.18,2.5,5), deck), sx, 6.2, -22+pi*(IS_MOBILE?9:4.5));
    }
    const rail = mk(new THREE.BoxGeometry(0.25,0.25,48), deck);
    rail.position.set(sx,7.5,0); g.add(rail);
  });

  // Flag
  const flag = mk(new THREE.PlaneGeometry(5,3.5), stdMat({color:0x111111, side:THREE.DoubleSide}));
  flag.position.set(2,56,2); flag.rotation.y=0.3; g.add(flag);

  // Engine glow — orange PointLight at stern (back of ship)
  const engGlow = new THREE.PointLight(0xff6600, IS_MOBILE?2.5:3.5, 60);
  engGlow.position.set(0,2,32); g.add(engGlow);
  // Visible glow sphere at stern
  const glowSph = new THREE.Mesh(
    new THREE.SphereGeometry(1.8,8,8),
    stdMat({color:0xff8800, emissive:0xff6600, emissiveIntensity:2.5, transparent:true, opacity:0.55})
  );
  glowSph.position.set(0,2,32); g.add(glowSph);
  // Side trail sparks
  [-7,7].forEach(sx=>{
    const sp = new THREE.Mesh(new THREE.SphereGeometry(0.7,6,6),
      stdMat({color:0xff4400,emissive:0xff3300,emissiveIntensity:2.0,transparent:true,opacity:0.45}));
    sp.position.set(sx,1.5,30); g.add(sp);
  });

  // Lanterns at bow
  const lanternMat = stdMat({color:0xffcc44,emissive:0xffaa00,emissiveIntensity:1.8,transparent:true,opacity:0.9});
  [-8,8].forEach(lx=>{
    const ln = new THREE.Mesh(new THREE.SphereGeometry(0.55,7,7), lanternMat);
    ln.position.set(lx,10,-24); g.add(ln);
    const ll = new THREE.PointLight(0xffaa44, 1.6, 22);
    ll.position.set(lx,10,-24); g.add(ll);
  });

  return g;
}

// ─── Human Pirate character ────────────────────────────────────────────────────
function buildPirateCharacter(isBoss: boolean, accentColor: number): THREE.Group {
  const g = new THREE.Group();
  const sc = isBoss ? 1.5 : 1.0;

  const skin   = stdMat({color:0x1a0800, roughness:0.85, metalness:0.0});
  const coat   = stdMat({color:isBoss?0x3a0030:0x0a1a3a, roughness:0.75, metalness:0.04});
  const pants  = stdMat({color:isBoss?0x220033:0x0d0d22, roughness:0.8});
  const boot   = stdMat({color:0x150a00, roughness:0.7, metalness:0.05});
  const accent = stdMat({color:accentColor, metalness:0.6, roughness:0.3});
  const hat    = stdMat({color:0x080808, roughness:0.9});
  const visor  = stdMat({color:accentColor,emissive:accentColor,emissiveIntensity:isBoss?1.1:0.75,roughness:0.0,metalness:0.1,transparent:true,opacity:0.85});
  const gold   = stdMat({color:0xd4a017,emissive:0x8b6900,emissiveIntensity:0.3,metalness:0.8,roughness:0.25});
  const gunMat = stdMat({color:0x1a1a1a,metalness:0.88,roughness:0.2});
  const gunAcc = stdMat({color:0xd4a017,metalness:0.85,roughness:0.22});

  const gy = (y) => g.add(mk(new THREE.BoxGeometry(2.4*sc,3.6*sc,1.6*sc), coat)).position.set(0,y,0);

  // Legs
  [-1,1].forEach(side=>{
    const thigh = mk(new THREE.CylinderGeometry(0.55*sc,0.48*sc,2.8*sc,8), pants);
    thigh.position.set(side*0.72*sc,1.4*sc,0); g.add(thigh);
    const knee  = mk(new THREE.SphereGeometry(0.46*sc,7,7), coat);
    knee.position.set(side*0.72*sc,0,0); g.add(knee);
    const shin  = mk(new THREE.CylinderGeometry(0.4*sc,0.46*sc,2.6*sc,8), pants);
    shin.position.set(side*0.72*sc,-1.3*sc,0); g.add(shin);
    const foot  = mk(new THREE.BoxGeometry(0.85*sc,0.55*sc,1.8*sc), boot);
    foot.position.set(side*0.72*sc,-2.7*sc,0.3*sc); g.add(foot);
  });

  // Pelvis
  addP(g, mk(new THREE.BoxGeometry(2.2*sc,1.0*sc,1.4*sc), coat), 0, 3.0*sc, 0);

  // Torso
  const torsoY = 5.2*sc;
  addP(g, mk(new THREE.BoxGeometry(2.4*sc,3.2*sc,1.6*sc), coat), 0, torsoY, 0);
  // Belt
  addP(g, mk(new THREE.BoxGeometry(2.5*sc,0.35*sc,1.65*sc), gold), 0, 3.8*sc, 0);
  // Coat lapels
  addP(g, mk(new THREE.BoxGeometry(0.55*sc,2.4*sc,0.18), gold), -0.5*sc, torsoY-0.2*sc, 0.81*sc);
  addP(g, mk(new THREE.BoxGeometry(0.55*sc,2.4*sc,0.18), gold),  0.5*sc, torsoY-0.2*sc, 0.81*sc);

  // Shoulders
  const shoulderY = torsoY + 1.5*sc;
  [-1,1].forEach(side=>{
    const sph = mk(new THREE.SphereGeometry(0.78*sc,8,8), coat);
    sph.position.set(side*1.75*sc, shoulderY, 0); g.add(sph);

    // Upper arm
    const ua = mk(new THREE.CylinderGeometry(0.36*sc,0.30*sc,2.2*sc,8), coat);
    ua.position.set(side*2.3*sc, shoulderY-1.1*sc, 0); ua.rotation.z=side*0.18; g.add(ua);

    // Forearm
    const fa = mk(new THREE.CylinderGeometry(0.28*sc,0.34*sc,2.0*sc,8), coat);
    fa.position.set(side*2.75*sc, shoulderY-2.8*sc, 0.1*sc); fa.rotation.z=side*0.22; g.add(fa);

    // Hand
    const hand = mk(new THREE.SphereGeometry(0.3*sc,7,7), skin);
    hand.position.set(side*3.0*sc, shoulderY-3.9*sc, 0.15*sc); g.add(hand);

    // WEAPON (right side = side 1)
    if(side===1){
      const weaponGroup = new THREE.Group();
      // Flintlock pistol body
      const gBody = mk(new THREE.BoxGeometry(0.28*sc, 0.22*sc, 1.8*sc), gunMat);
      gBody.position.set(0,0,0); weaponGroup.add(gBody);
      // Barrel
      const barrel = mk(new THREE.CylinderGeometry(0.07*sc,0.07*sc,1.6*sc,8), gunMat);
      barrel.rotation.x = Math.PI/2; barrel.position.set(0,0.1*sc,-0.5*sc);
      weaponGroup.add(barrel);
      // Trigger guard
      const tg = mk(new THREE.TorusGeometry(0.15*sc,0.04*sc,5,8,Math.PI), gunMat);
      tg.position.set(0,-0.12*sc,0.3*sc); tg.rotation.z=Math.PI/2; weaponGroup.add(tg);
      // Gold accents
      const flint = mk(new THREE.BoxGeometry(0.12*sc,0.12*sc,0.25*sc), gunAcc);
      flint.position.set(0,0.12*sc,0.55*sc); weaponGroup.add(flint);
      // Muzzle
      const muzzle = mk(new THREE.CylinderGeometry(0.09*sc,0.07*sc,0.18*sc,8), gunAcc);
      muzzle.rotation.x=Math.PI/2; muzzle.position.set(0,0.1*sc,-1.3*sc); weaponGroup.add(muzzle);

      weaponGroup.position.set(side*3.0*sc, shoulderY-4.6*sc, 0.2*sc);
      weaponGroup.rotation.set(0,0,side*0.08);
      g.userData.weaponArm = weaponGroup;
      g.add(weaponGroup);

      // Muzzle flash point for firing
      g.userData.muzzleOffset = new THREE.Vector3(side*3.0*sc, shoulderY-4.6*sc, -1.5*sc);
    }

    // Epaulette
    const ep = mk(new THREE.CylinderGeometry(0.6*sc,0.75*sc,0.3*sc,8), gold);
    ep.position.set(side*1.9*sc, shoulderY+0.2*sc, 0); g.add(ep);
  });

  // Neck
  addP(g, mk(new THREE.CylinderGeometry(0.28*sc,0.32*sc,0.8*sc,8), skin), 0, torsoY+1.65*sc, 0);

  // Head
  const headY = torsoY+2.7*sc;
  addP(g, mk(new THREE.BoxGeometry(1.9*sc,1.8*sc,1.85*sc), skin), 0, headY, 0);
  // Face features
  addP(g, mk(new THREE.BoxGeometry(0.7*sc,0.18*sc,0.08), visor), 0, headY+0.25*sc, 0.93*sc); // visor strip
  addP(g, mk(new THREE.SphereGeometry(0.18*sc,7,7), visor), -0.35*sc, headY+0.1*sc, 0.92*sc);
  addP(g, mk(new THREE.SphereGeometry(0.18*sc,7,7), visor),  0.35*sc, headY+0.1*sc, 0.92*sc);
  // Chin beard
  addP(g, mk(new THREE.BoxGeometry(0.6*sc,0.45*sc,0.15), stdMat({color:0x080808,roughness:0.9})), 0, headY-0.7*sc, 0.9*sc);

  // Pirate hat
  const hatBrim = mk(new THREE.CylinderGeometry(1.5*sc,1.5*sc,0.18*sc,12), hat);
  hatBrim.position.set(0, headY+0.92*sc, 0); g.add(hatBrim);
  const hatTop = mk(new THREE.BoxGeometry(1.4*sc,1.2*sc,1.4*sc), hat);
  hatTop.position.set(0, headY+1.4*sc, -0.1*sc); g.add(hatTop);
  // Hat skull emblem
  const skull = mk(new THREE.SphereGeometry(0.22*sc,7,7), stdMat({color:0xddddcc,emissive:0x888877,emissiveIntensity:0.3}));
  skull.position.set(0, headY+1.42*sc, 0.71*sc); g.add(skull);
  // Gold band
  addP(g, mk(new THREE.TorusGeometry(0.72*sc,0.07*sc,6,10), gold), 0, headY+0.82*sc, 0);

  if(isBoss){
    // Boss crown horns
    [-0.55*sc,0.55*sc].forEach(hx=>{
      const h2 = mk(new THREE.ConeGeometry(0.18*sc,0.9*sc,6), accent);
      h2.position.set(hx, headY+2.0*sc, 0); g.add(h2);
    });
    // Boss cape
    const cape = mk(new THREE.PlaneGeometry(3.2*sc,4.0*sc), stdMat({color:0x2a0040,side:THREE.DoubleSide,roughness:0.85}));
    cape.position.set(0, torsoY-0.3*sc, -0.9*sc); cape.rotation.x=0.22; g.add(cape);
  }

  // Glow light from character
  const gl = new THREE.PointLight(accentColor, isBoss?1.5:1.0, 10*sc);
  gl.position.set(0, headY, 1.5); g.add(gl);

  return g;
}

// ─── UFO ──────────────────────────────────────────────────────────────────────
function buildUFO(isBoss: boolean, color: number): {group:THREE.Group; ring:THREE.Mesh; glow:THREE.PointLight} {
  const g = new THREE.Group();
  const sc = isBoss ? 1.5 : 1.0;
  const segs = IS_MOBILE ? 18 : 32;

  const bodyMat = stdMat({color:isBoss?0x110022:0x0a1822, metalness:0.92, roughness:0.1, side:THREE.DoubleSide});
  const glowMat = stdMat({color, emissive:color, emissiveIntensity:isBoss?1.1:0.75, roughness:0.0, metalness:0.3, transparent:true, opacity:0.9});

  // Body shells
  g.add(new THREE.Mesh(new THREE.SphereGeometry(10*sc,segs,12,0,Math.PI*2,0,Math.PI/2.2), bodyMat));
  const bot = new THREE.Mesh(new THREE.SphereGeometry(10*sc,segs,12,0,Math.PI*2,Math.PI/2.2,Math.PI/2.2), bodyMat);
  bot.position.y = -0.5; g.add(bot);

  // Glow ring
  const ring = new THREE.Mesh(new THREE.TorusGeometry(11.5*sc, isBoss?1.4:1.0, 10, IS_MOBILE?32:56), glowMat);
  ring.position.y = -2*sc; g.add(ring);

  // Sub-rings
  [0.65,0.4].forEach((rf,ri)=>{
    const r2 = new THREE.Mesh(new THREE.TorusGeometry(rf*11.5*sc,0.32*sc,7,IS_MOBILE?20:32), glowMat);
    r2.position.y = -1.5*sc+ri*1.5*sc; g.add(r2);
  });

  // Dome (transparent top)
  const domeMat = stdMat({color,emissive:color,emissiveIntensity:0.3,transparent:true,opacity:0.38,roughness:0.0,metalness:0.2,side:THREE.DoubleSide});
  const dome = new THREE.Mesh(new THREE.SphereGeometry(4.8*sc,18,10,0,Math.PI*2,0,Math.PI/2), domeMat);
  dome.position.y = 3*sc; g.add(dome);

  // Interior lights — MULTIPLE so aliens are clearly visible
  const interiorColors = [color, 0xffffff, 0xffffff];
  const interiorIntensities = [isBoss?4.5:3.0, isBoss?3.5:2.5, isBoss?2.5:1.8];
  const interiorPositions = [[0,0,0],[0,4,4],[0,4,-4]];
  interiorPositions.forEach(([lx,ly,lz],i)=>{
    const il = new THREE.PointLight(interiorColors[i], interiorIntensities[i], 40*sc);
    il.position.set(lx,ly,lz); g.add(il);
  });

  // Under-glow
  const glow = new THREE.PointLight(color, isBoss?4.0:2.5, 65*sc);
  glow.position.y = -6; g.add(glow);

  if(isBoss){
    // Tractor beam
    const beamMat = stdMat({color,transparent:true,opacity:0.035,side:THREE.BackSide});
    const beam = new THREE.Mesh(new THREE.CylinderGeometry(2,9,90,10,1,true), beamMat);
    beam.position.y = -46; g.add(beam);
    // Boss accent panels
    [0,1,2,3].forEach(i=>{
      const panel = mk(new THREE.BoxGeometry(4*sc,1.5*sc,0.3*sc), glowMat);
      const ang = i * Math.PI/2;
      panel.position.set(Math.sin(ang)*9*sc,-1.5*sc,Math.cos(ang)*9*sc);
      panel.rotation.y = ang; g.add(panel);
    });
  }

  return {group:g, ring, glow};
}

// ─── Helm console ─────────────────────────────────────────────────────────────
function buildHelmConsole(color: number): THREE.Group {
  const g = new THREE.Group();
  const pMat = stdMat({color:0x111122,metalness:0.88,roughness:0.2});
  const gMat = stdMat({color,emissive:color,emissiveIntensity:0.9,roughness:0.0,metalness:0.3,transparent:true,opacity:0.88});
  const base = new THREE.Mesh(new THREE.BoxGeometry(10,1.5,4),pMat);
  base.position.set(0,0,0); g.add(base);
  const disp = mk(new THREE.BoxGeometry(8,3,0.15), gMat);
  disp.position.set(0,2.2,-1.8); disp.rotation.x=-0.4; g.add(disp);
  [[-3,0,2.2],[0,0,2.2],[3,0,2.2]].forEach(([x,,z])=>{
    const btn = new THREE.Mesh(new THREE.CylinderGeometry(0.4,0.4,0.5,7),gMat);
    btn.position.set(x,1.1,z); g.add(btn);
  });
  // Console glow
  const cl = new THREE.PointLight(color,2.5,18); cl.position.set(0,3,0); g.add(cl);
  return g;
}

// ─── Particles ────────────────────────────────────────────────────────────────
function makeBurst(pos: THREE.Vector3, color: number, count=20): Particle {
  const geo = new THREE.BufferGeometry();
  const positions = new Float32Array(count*3);
  const velocities: THREE.Vector3[] = [];
  for(let i=0;i<count;i++){
    positions[i*3]=pos.x; positions[i*3+1]=pos.y; positions[i*3+2]=pos.z;
    const theta=Math.random()*Math.PI*2, phi=Math.random()*Math.PI;
    const spd=12+Math.random()*22;
    velocities.push(new THREE.Vector3(Math.sin(phi)*Math.cos(theta)*spd,Math.abs(Math.cos(phi))*spd+5,Math.sin(phi)*Math.sin(theta)*spd));
  }
  geo.setAttribute('position',new THREE.BufferAttribute(positions,3));
  return {mesh:new THREE.Points(geo,new THREE.PointsMaterial({color,size:1.8,transparent:true,opacity:1.0,sizeAttenuation:true})),velocities,lifetime:0,maxLifetime:1.8};
}
function makeTrail(isLaser: boolean): THREE.Points {
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position',new THREE.BufferAttribute(new Float32Array(24*3),3));
  return new THREE.Points(geo,new THREE.PointsMaterial({color:isLaser?0x00ffaa:0xff8800,size:isLaser?0.9:1.2,transparent:true,opacity:0.8}));
}

// ─── Target marker (floating arrow above alien) ───────────────────────────────
function buildTargetMarker(color: number): THREE.Mesh {
  const mat = stdMat({color,emissive:color,emissiveIntensity:1.2,transparent:true,opacity:0.85});
  const geo = new THREE.ConeGeometry(2.5,5,6);
  const m = new THREE.Mesh(geo,mat);
  return m;
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
  private skyUniforms: any = null;
  private lensFlareEl: HTMLDivElement|null = null;

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
  private joystickX = 0; private joystickY = 0;
  private camLookTarget = new THREE.Vector3(0,10,-200);
  private combatFallbackTimer: any = null;

  constructor(canvas: HTMLCanvasElement, callbacks: GameCallbacks) {
    this.canvas = canvas; this.callbacks = callbacks;
    this.init();
  }

  public setJoystickInput(dx: number, dy: number) { this.joystickX=dx; this.joystickY=dy; }
  public triggerFire() { if(this.phase==='combat') this.fireCannonball(); }

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
    // Fallback: if GSAP fails, force combat start at 13s
    this.combatFallbackTimer = setTimeout(()=>{
      if(this.phase==='intro'){ this.forceCombatStart(); }
    }, 15500);
  }

  private forceCombatStart(){
    this.phase='combat'; this.combatStarted=true;
    this.camLookTarget.set(0,12,-150);
    this.callbacks.onStateChange({phase:'combat',phaseTitle:'BATTLE STATIONS!',showControls:true});
    setTimeout(()=>this.callbacks.onStateChange({phaseTitle:''}),2600);
    // cleanup lens flare overlay if still in DOM
    if(this.lensFlareEl?.parentNode){ this.lensFlareEl.parentNode.removeChild(this.lensFlareEl); this.lensFlareEl=null; }
    // restore sun + exposure in case cinematic was interrupted
    if(this.skyUniforms){ this.skyUniforms['sunPosition'].value.copy(this.sun); }
    this.renderer.toneMappingExposure = 0.88;
  }

  private setupRenderer() {
    const ctx = this.canvas.getContext('webgl2')||this.canvas.getContext('webgl');
    if(!ctx) throw new Error('WebGL not supported on this device.');
    this.renderer = new THREE.WebGLRenderer({canvas:this.canvas,antialias:!IS_MOBILE,powerPreference:'high-performance'});
    this.renderer.setPixelRatio(IS_MOBILE?1.0:Math.min(window.devicePixelRatio,1.5));
    this.renderer.setSize(this.canvas.clientWidth,this.canvas.clientHeight);
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 0.88;
    this.renderer.shadowMap.enabled = !IS_MOBILE;
    if(!IS_MOBILE) this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    window.addEventListener('resize',this.onResize);
  }

  private setupScene() {
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.FogExp2(0x1a2a44, IS_MOBILE?0.00035:0.0005);
    this.camera = new THREE.PerspectiveCamera(65,this.canvas.clientWidth/this.canvas.clientHeight,0.5,8000);
    this.camera.position.set(0,280,600);

    this.scene.add(new THREE.AmbientLight(0x445566, IS_MOBILE?0.65:0.55));
    this.scene.add(new THREE.HemisphereLight(0xff8844,0x223355,0.42));
    const sun = new THREE.DirectionalLight(0xff9955, IS_MOBILE?1.2:1.5);
    sun.position.set(300,200,-500);
    if(!IS_MOBILE){
      sun.castShadow=true; sun.shadow.mapSize.set(1024,1024);
      sun.shadow.camera.near=1; sun.shadow.camera.far=1500;
      sun.shadow.camera.left=-250; sun.shadow.camera.right=250;
      sun.shadow.camera.top=250; sun.shadow.camera.bottom=-250;
      sun.shadow.bias=-0.0004;
    }
    this.scene.add(sun);
    const fill = new THREE.DirectionalLight(0x8833ff,0.3);
    fill.position.set(0,100,-400); this.scene.add(fill);
  }

  private buildWaterAndSky(){
    this.sun = new THREE.Vector3();
    const sky = new Sky(); sky.scale.setScalar(8000); this.scene.add(sky);
    const skyU = (sky.material as THREE.ShaderMaterial).uniforms;
    this.skyUniforms = skyU;
    skyU['turbidity'].value=5.5; skyU['rayleigh'].value=1.8;
    skyU['mieCoefficient'].value=0.006; skyU['mieDirectionalG'].value=0.88;
    const phi=THREE.MathUtils.degToRad(90-28);
    const theta=THREE.MathUtils.degToRad(195);
    this.sun.setFromSphericalCoords(1,phi,theta);
    skyU['sunPosition'].value.copy(this.sun);

    const waterNormals=makeWaterNormal();
    const wSeg=IS_MOBILE?8:24;
    this.water=new Water(new THREE.PlaneGeometry(8000,8000,wSeg,wSeg),{
      textureWidth:IS_MOBILE?256:512, textureHeight:IS_MOBILE?256:512,
      waterNormals, sunDirection:this.sun.clone().normalize(),
      sunColor:0xff9944, waterColor:0x001a2e,
      distortionScale:IS_MOBILE?3.0:5.0, fog:true,
    });
    this.water.rotation.x=-Math.PI/2; this.water.position.y=-1;
    this.scene.add(this.water);
    // CDN water normals (background, offline-safe)
    const cdnNorm=loadTex(TEXTURES.waterNormals,1);
    cdnNorm.wrapS=cdnNorm.wrapT=THREE.RepeatWrapping;
    cdnNorm.addEventListener('load',()=>{
      (this.water.material as THREE.ShaderMaterial).uniforms['tWaterNormals'].value=cdnNorm;
    });
  }

  private buildEnvironment(){
    if(IS_MOBILE) return;
    const rMat=stdMat({color:0x2a2820,roughness:0.96});
    [[-600,-800],[750,-600],[-420,620],[820,420]].forEach(([x,z])=>{
      const h=35+Math.random()*65;
      const r=mk(new THREE.CylinderGeometry(20,35,h,6),rMat);
      r.position.set(x,h/2-1,z); r.rotation.y=Math.random()*Math.PI;
      this.scene.add(r);
    });
  }

  private buildPlayerShip(){
    this.playerShip=buildPirateShip();
    this.playerShip.position.set(0,2.5,180);
    this.playerShip.rotation.y=Math.PI;
    this.scene.add(this.playerShip);

    // Player character — human pirate
    this.playerChar=buildPirateCharacter(false,0x00eeff);
    this.playerChar.position.set(0,10,202);
    this.playerChar.rotation.y=Math.PI;
    this.scene.add(this.playerChar);
  }

  private buildAlienFleet(){
    const bossColor=0xff00ff;
    const bossPos=new THREE.Vector3(0,190,-280);

    // Boss UFO
    const {group:bG,ring:bRing,glow:bGlow}=buildUFO(true,bossColor);
    bG.position.copy(bossPos); this.scene.add(bG);
    bG.userData.isBoss=true; bG.userData.baseY=bossPos.y;

    // Boss interior characters — positioned so camera at (0,192,-252) looking at (0,187,-282) sees them
    const bossChar=buildPirateCharacter(true,bossColor);
    bossChar.position.set(0,2,-4); bossChar.rotation.y=Math.PI; bG.add(bossChar);
    const helm=buildHelmConsole(bossColor);
    helm.position.set(0,-2,-12); helm.rotation.y=Math.PI; bG.add(helm);

    // 2 gunner aliens — visible from camera
    [{x:-9,c:0x00ffaa,gi:0},{x:9,c:0xff4400,gi:1}].forEach(({x,c,gi})=>{
      const gn=buildPirateCharacter(false,c);
      gn.position.set(x,0,8); gn.rotation.y=Math.PI;
      gn.userData.gunnerIdx=gi; bG.add(gn);
    });

    // Interior cockpit light
    const ckL=new THREE.PointLight(bossColor,5.0,60); ckL.position.set(0,4,0); bG.add(ckL);
    const ckW=new THREE.PointLight(0xffffff,4.0,55); ckW.position.set(0,8,0); bG.add(ckW);

    // Target marker above boss
    const bMarker=buildTargetMarker(bossColor);
    bMarker.position.set(0,22,0); bG.add(bMarker);

    this.alienFleet.push({group:bG,hp:60,maxHP:60,fireTimer:5.5,alive:true,ring:bRing,glow:bGlow,moveOffset:0,marker:bMarker});

    // Minion UFOs
    [{pos:new THREE.Vector3(-130,155,-250),color:0x00ff88},{pos:new THREE.Vector3(130,155,-250),color:0xff4400}]
    .forEach(({pos,color},idx)=>{
      const {group,ring,glow}=buildUFO(false,color);
      group.position.copy(pos); group.userData.baseY=pos.y;
      this.scene.add(group);
      const ch=buildPirateCharacter(false,color);
      ch.position.set(0,6,0); ch.rotation.y=Math.PI; group.add(ch);
      // Interior light
      const il=new THREE.PointLight(0xffffff,3.0,45); il.position.set(0,5,0); group.add(il);
      const il2=new THREE.PointLight(color,2.5,40); il2.position.set(0,0,0); group.add(il2);
      // Target marker
      const marker=buildTargetMarker(color);
      marker.position.set(0,18,0); group.add(marker);
      this.alienFleet.push({group,hp:30,maxHP:30,fireTimer:4.0+idx*1.5,alive:true,ring,glow,moveOffset:(idx+1)*2.1,marker});
    });

    // Atmosphere lights
    [0xff00ff,0x00ff88,0xff4400].forEach((c,i)=>{
      const l=new THREE.PointLight(c,1.4,200);
      l.position.set([-130,0,130][i],150+i*20,-250); this.scene.add(l);
    });

    this.callbacks.onStateChange({aliensAlive:this.alienFleet.length,aliensTotal:this.alienFleet.length});
  }

  private setupPostprocessing(){
    if(IS_MOBILE){ this.composer=null; return; }
    this.composer=new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene,this.camera));
    this.composer.addPass(new UnrealBloomPass(
      new THREE.Vector2(this.canvas.clientWidth,this.canvas.clientHeight),
      0.32,0.42,0.86
    ));
    this.composer.addPass(new OutputPass());
  }

  private setupInput(){
    window.addEventListener('keydown',e=>{this.keys[e.code]=true;});
    window.addEventListener('keyup',e=>{this.keys[e.code]=false;});
    this.canvas.addEventListener('click',()=>{if(this.phase==='combat')this.fireCannonball();});
  }
  private keys: Record<string,boolean>={};

  // ─── 13s Cinematic: overhead zenith glow → dive → pirate → boss → combat ─────
  private startIntroSequence(){
    this.callbacks.onStateChange({phase:'intro',phaseTitle:'ALIEN INVASION',showControls:false});
    const cam=this.camera;
    const shipC=new THREE.Vector3(0,4,180);
    const charC=new THREE.Vector3(0,12,202);
    const bossC=new THREE.Vector3(0,190,-280);
    const ufoIn=new THREE.Vector3(0,195,-248);
    const ufoAt=new THREE.Vector3(0,190,-280);

    // Golden-hour sun position (stored on class at buildWaterAndSky time)
    const sunGolden=this.sun.clone();

    // Zenith sun — almost directly above, creates the white divine glow
    const sunZenith=new THREE.Vector3();
    sunZenith.setFromSphericalCoords(1,THREE.MathUtils.degToRad(90-87),THREE.MathUtils.degToRad(195));

    // ─── CSS Lens Flare overlay ────────────────────────────────────────────────
    const lf=document.createElement('div');
    lf.style.cssText='position:fixed;inset:0;z-index:50;pointer-events:none;'+
      'background:radial-gradient(ellipse 80% 55% at 50% 18%,'+
      'rgba(255,252,240,0.94) 0%,rgba(210,228,255,0.62) 22%,'+
      'rgba(140,185,220,0.22) 52%,transparent 74%);opacity:0;';
    document.body.appendChild(lf);
    this.lensFlareEl=lf;

    const tl=gsap.timeline({onComplete:()=>this.forceCombatStart()});

    // ── SHOT 0 (0s): camera overhead, sun at zenith — GOD'S EYE view ──────────
    tl.set(cam.position,{x:0,y:520,z:250});
    tl.call(()=>{
      cam.lookAt(0,0,180);
      // Move sky sun to near-zenith for the white blowout effect
      if(this.skyUniforms) this.skyUniforms['sunPosition'].value.copy(sunZenith);
      this.renderer.toneMappingExposure=1.38;
      // Lens flare bursts in
      gsap.to(lf,{opacity:1,duration:0.55,ease:'power2.in'});
    });

    // 0→2.8s: slow overhead drift — "God looks down at the ship"
    tl.to(cam.position,{x:-18,y:490,z:220,duration:2.8,ease:'sine.inOut',
      onUpdate:()=>cam.lookAt(0,2,180)});

    // ── SHOT 1 (2.8s): DIVE — sun animates back to golden hour as we fall ─────
    tl.to(cam.position,{x:30,y:28,z:235,duration:2.6,ease:'power4.in',
      onUpdate:()=>cam.lookAt(shipC.x,shipC.y,shipC.z),
      onStart:()=>{
        // Fade out lens flare as camera dives into the scene
        gsap.to(lf,{opacity:0,duration:2.0,ease:'power2.out'});
        // Sky sun sweeps back to golden hour during the dive
        if(this.skyUniforms){
          gsap.to(this.skyUniforms['sunPosition'].value,{
            x:sunGolden.x,y:sunGolden.y,z:sunGolden.z,
            duration:2.4,ease:'sine.inOut'
          });
        }
        // Exposure back to cinematic normal
        gsap.to(this.renderer,{toneMappingExposure:0.88,duration:2.2,ease:'sine.out'});
      }
    });

    // ── SHOT 2 (5.4s): PIRATE FACE — gun raised ──────────────────────────────
    tl.to(cam.position,{x:5,y:14,z:222,duration:1.5,ease:'power2.inOut',
      onUpdate:()=>cam.lookAt(charC.x,charC.y,charC.z),
      onStart:()=>{
        this.callbacks.onStateChange({phaseTitle:''});
        const wa=this.playerChar?.userData?.weaponArm;
        if(wa) gsap.to(wa.rotation,{x:-1.1,z:-0.5,duration:0.8,ease:'power2.out'});
      }
    });

    // Character looks up at the sky
    tl.to(this.playerChar.rotation,{x:-0.55,duration:0.5,ease:'power3.out'},'<0.9');

    // ── SHOT 3 (6.9s): VIOLENT upward pan — sky reveal ───────────────────────
    tl.to(cam.position,{x:0,y:170,z:260,duration:1.0,ease:'power4.in',
      onUpdate:()=>cam.lookAt(bossC.x,bossC.y,bossC.z),
      onStart:()=>this.callbacks.onStateChange({phaseTitle:'ALIEN FLEET INCOMING…'})
    });

    // ── SHOT 4 (7.9s): RUSH at boss UFO ──────────────────────────────────────
    tl.to(cam.position,{x:0,y:bossC.y+8,z:bossC.z+85,duration:2.0,ease:'power2.in',
      onUpdate:()=>cam.lookAt(bossC.x,bossC.y,bossC.z)});

    // ── SHOT 5 (9.9s): UFO INTERIOR — boss at helm ───────────────────────────
    tl.to(cam.position,{x:ufoIn.x,y:ufoIn.y,z:ufoIn.z,duration:2.0,ease:'power3.out',
      onUpdate:()=>cam.lookAt(ufoAt.x,ufoAt.y,ufoAt.z),
      onStart:()=>this.callbacks.onStateChange({phaseTitle:'THE COMMAND DECK'})
    });

    // ── SHOT 6 (11.9s): PULL BACK to 3rd-person combat position ─────────────
    tl.to(cam.position,{x:0,y:38,z:275,duration:1.6,ease:'power2.inOut',
      onUpdate:()=>cam.lookAt(0,12,-150),
      onStart:()=>{
        this.callbacks.onStateChange({phaseTitle:''});
        gsap.to(this.playerChar.rotation,{x:0,duration:0.7,ease:'back.out(1.4)'});
        const wa=this.playerChar?.userData?.weaponArm;
        if(wa) gsap.to(wa.rotation,{x:0,z:0.08,duration:0.7,ease:'power2.out'});
        if(lf.parentNode){ lf.parentNode.removeChild(lf); this.lensFlareEl=null; }
      },
    });
  }

  // ─── Cannonball — fiery orange ─────────────────────────────────────────────
  private fireCannonball(){
    if(this.canFireTimer>0) return;
    this.canFireTimer=0.55;
    const side=this.fireFromLeft?-1:1; this.fireFromLeft=!this.fireFromLeft;
    const sp=this.playerShip.position, sr=this.playerShip.rotation.y;
    const origin=new THREE.Vector3(
      sp.x+side*12*Math.cos(sr+Math.PI/2), sp.y+5, sp.z+side*12*Math.sin(sr+Math.PI/2)
    );
    let target=new THREE.Vector3(0,10,-600); let nd=Infinity;
    this.alienFleet.forEach(a=>{if(!a.alive)return; const d=origin.distanceTo(a.group.position); if(d<nd){nd=d;target=a.group.position.clone();}});
    const dir=target.clone().sub(origin).normalize();

    // Fiery cannonball — bigger, orange
    const ballMat=stdMat({color:0xff6600,emissive:0xff3300,emissiveIntensity:1.5,metalness:0.3,roughness:0.2});
    const ball=new THREE.Mesh(new THREE.SphereGeometry(1.4,IS_MOBILE?6:9,IS_MOBILE?6:9),ballMat);
    ball.position.copy(origin); this.scene.add(ball);
    // Orange fire glow
    const fireL=new THREE.PointLight(0xff6600,8,18);
    fireL.position.copy(origin); this.scene.add(fireL);
    // Trail
    const trail=makeTrail(false); this.scene.add(trail);
    this.projectiles.push({mesh:ball,velocity:dir.multiplyScalar(130),type:'cannonball',lifetime:0,trail,trailPositions:trail.geometry.attributes.position.array as Float32Array});

    // Muzzle flash
    const flash=new THREE.PointLight(0xffaa44,35,24);
    flash.position.copy(origin); this.scene.add(flash);
    setTimeout(()=>{this.scene.remove(flash);this.scene.remove(fireL);},120);
    // Cannon smoke
    const smoke=makeBurst(origin,0x666655,IS_MOBILE?8:14);
    this.scene.add(smoke.mesh); this.particles.push(smoke);
    // Fire burst
    const fire=makeBurst(origin,0xff5500,IS_MOBILE?6:10);
    this.scene.add(fire.mesh); this.particles.push(fire);
  }

  private fireAlienLaser(alien: AlienShip){
    const origin=alien.group.position.clone(); origin.y-=4;
    const target=this.playerShip.position.clone(); target.y+=6;
    const dir=target.clone().sub(origin).normalize();
    const laser=new THREE.Mesh(new THREE.CylinderGeometry(0.35,0.35,8,7),
      stdMat({color:alien.glow.color,emissive:alien.glow.color,emissiveIntensity:2.5}));
    laser.position.copy(origin); laser.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),dir);
    this.scene.add(laser);
    const trail=makeTrail(true); this.scene.add(trail);
    this.projectiles.push({mesh:laser,velocity:dir.multiplyScalar(95),type:'laser',lifetime:0,trail,trailPositions:trail.geometry.attributes.position.array as Float32Array});
    alien.glow.intensity=22;
    setTimeout(()=>{if(alien.alive)alien.glow.intensity=alien.group.userData.isBoss?4.0:2.5;},180);
  }

  private spawnExplosion(pos: THREE.Vector3, isAlien: boolean){
    const c=isAlien?0x00ff88:0xff6600;
    const b=makeBurst(pos,c,IS_MOBILE?14:28); this.scene.add(b.mesh); this.particles.push(b);
    const b2=makeBurst(pos,0xffaa00,IS_MOBILE?8:16); this.scene.add(b2.mesh); this.particles.push(b2);
    const l=new THREE.PointLight(c,55,100); l.position.copy(pos); this.scene.add(l);
    gsap.to(l,{intensity:0,duration:0.65,onComplete:()=>this.scene.remove(l)});
  }

  private onResize=()=>{
    const w=this.canvas.clientWidth, h=this.canvas.clientHeight;
    this.camera.aspect=w/h; this.camera.updateProjectionMatrix();
    this.renderer.setSize(w,h); this.composer?.setSize(w,h);
  };

  // ─── Third-person follow camera ───────────────────────────────────────────
  private updateCombatCamera(dt: number){
    if(!this.combatStarted) return;
    const rotY=this.playerRotation;
    const targetPos=new THREE.Vector3(
      this.playerShip.position.x-Math.sin(rotY)*80,
      this.playerShip.position.y+36,
      this.playerShip.position.z-Math.cos(rotY)*80,
    );
    this.camera.position.lerp(targetPos,(IS_MOBILE?4:5)*dt);
    const newLook=new THREE.Vector3(
      this.playerShip.position.x+Math.sin(rotY)*200,10,
      this.playerShip.position.z+Math.cos(rotY)*200,
    );
    this.camLookTarget.lerp(newLook,4*dt);
    this.camera.lookAt(this.camLookTarget);
  }

  private updatePlayerShip(dt: number){
    if(!this.combatStarted) return;
    const fwd=this.keys['KeyW']||this.keys['ArrowUp']  ||this.joystickY<-0.28;
    const bwd=this.keys['KeyS']||this.keys['ArrowDown'] ||this.joystickY> 0.28;
    const rotL=this.keys['KeyA']||this.keys['ArrowLeft']||this.joystickX<-0.28;
    const rotR=this.keys['KeyD']||this.keys['ArrowRight']||this.joystickX>0.28;
    if(fwd)      this.playerSpeed=Math.min(this.playerSpeed+40*dt,55);
    else if(bwd) this.playerSpeed=Math.max(this.playerSpeed-40*dt,-27);
    else         this.playerSpeed*=0.96;
    if(rotL) this.playerRotation+=0.9*dt;
    if(rotR) this.playerRotation-=0.9*dt;
    this.playerShip.rotation.y=this.playerRotation+Math.PI;
    this.playerShip.position.x+=Math.sin(this.playerRotation)*this.playerSpeed*dt;
    this.playerShip.position.z+=Math.cos(this.playerRotation)*this.playerSpeed*dt;
    const t=this.clock.getElapsedTime();
    this.playerShip.position.y=2.5+Math.sin(t*0.6)*0.35;
    this.playerShip.rotation.x=Math.sin(t*0.5)*0.015;
    this.playerShip.rotation.z=Math.cos(t*0.7)*0.010;
    this.playerChar.position.set(
      this.playerShip.position.x, this.playerShip.position.y+7.5,
      this.playerShip.position.z+22*Math.cos(this.playerShip.rotation.y),
    );
    this.playerChar.rotation.y=this.playerShip.rotation.y;
    this.canFireTimer=Math.max(0,this.canFireTimer-dt);
  }

  private updateAlienFleet(dt: number){
    if(!this.combatStarted) return;
    const t=this.clock.getElapsedTime(); let alive=0;
    this.alienFleet.forEach((alien,idx)=>{
      if(!alien.alive) return; alive++;
      const baseY=alien.group.userData.baseY??alien.group.position.y;
      const spd=idx===0?0.2:0.3;
      alien.group.position.x+=Math.sin(t*spd+alien.moveOffset)*10*dt;
      alien.group.position.y=baseY+Math.sin(t*0.5+alien.moveOffset)*6;
      alien.group.position.z+=Math.cos(t*spd*0.7+alien.moveOffset)*4*dt;
      if(alien.ring){alien.ring.rotation.y+=dt*(idx===0?0.9:0.7);alien.ring.rotation.x+=dt*0.1;}
      alien.glow.intensity=(idx===0?4.0:2.5)+Math.sin(t*2.2+idx)*0.9;
      alien.group.lookAt(this.playerShip.position.x,alien.group.position.y,this.playerShip.position.z);
      // Target marker pulse
      if(alien.marker){
        alien.marker.position.y=20+Math.sin(t*3+idx)*3;
        (alien.marker.material as THREE.MeshStandardMaterial).emissiveIntensity=0.8+Math.sin(t*4)*0.5;
      }
      alien.fireTimer-=dt;
      if(alien.fireTimer<=0){this.fireAlienLaser(alien);alien.fireTimer=3.0+Math.random()*2.0;}
    });
    if(alive===0&&this.phase==='combat'){
      this.phase='victory';
      this.callbacks.onStateChange({phase:'victory',phaseTitle:'VICTORY!'});
    }
    this.callbacks.onStateChange({aliensAlive:alive,aliensTotal:this.alienFleet.length});
  }

  private updateProjectiles(dt: number){
    const rm: Projectile[]=[];
    this.projectiles.forEach(p=>{
      p.lifetime+=dt;
      if(p.lifetime>(p.type==='cannonball'?6:4)){rm.push(p);return;}
      if(p.type==='cannonball') p.velocity.y-=18*dt;
      p.mesh.position.addScaledVector(p.velocity,dt);
      const pos=p.trailPositions;
      for(let i=23;i>0;i--){pos[i*3]=pos[(i-1)*3];pos[i*3+1]=pos[(i-1)*3+1];pos[i*3+2]=pos[(i-1)*3+2];}
      pos[0]=p.mesh.position.x;pos[1]=p.mesh.position.y;pos[2]=p.mesh.position.z;
      p.trail.geometry.attributes.position.needsUpdate=true;
      if(p.type==='cannonball'){
        this.alienFleet.forEach(a=>{
          if(!a.alive||p.mesh.position.distanceTo(a.group.position)>18)return;
          rm.push(p); a.hp-=15;
          if(a.hp<=0){a.alive=false;a.marker&&(a.marker.visible=false);this.spawnExplosion(a.group.position.clone(),true);this.scene.remove(a.group);}
          else{a.glow.intensity=38;setTimeout(()=>{if(a.alive)a.glow.intensity=a.group.userData.isBoss?4.0:2.5;},220);}
        });
      } else {
        if(p.mesh.position.distanceTo(this.playerShip.position)<16){
          rm.push(p); this.playerHP=Math.max(0,this.playerHP-8);
          this.callbacks.onStateChange({playerHP:this.playerHP});
          this.spawnExplosion(p.mesh.position.clone(),false);
          if(this.playerHP===0&&this.phase==='combat'){this.phase='defeat';this.callbacks.onStateChange({phase:'defeat',phaseTitle:'DEFEAT…'});}
        }
        if(p.mesh.position.y<-2)rm.push(p);
      }
    });
    rm.forEach(p=>{this.scene.remove(p.mesh);this.scene.remove(p.trail);const i=this.projectiles.indexOf(p);if(i!==-1)this.projectiles.splice(i,1);});
  }

  private updateParticles(dt: number){
    const rm: Particle[]=[];
    this.particles.forEach(p=>{
      p.lifetime+=dt;
      if(p.lifetime>p.maxLifetime){rm.push(p);return;}
      (p.mesh.material as THREE.PointsMaterial).opacity=1-p.lifetime/p.maxLifetime;
      const pos=p.mesh.geometry.attributes.position.array as Float32Array;
      for(let i=0;i<p.velocities.length;i++){
        const v=p.velocities[i];
        pos[i*3]+=v.x*dt;pos[i*3+1]+=(v.y-12*dt)*dt;pos[i*3+2]+=v.z*dt;v.y-=12*dt;
      }
      p.mesh.geometry.attributes.position.needsUpdate=true;
    });
    rm.forEach(p=>{this.scene.remove(p.mesh);const i=this.particles.indexOf(p);if(i!==-1)this.particles.splice(i,1);});
  }

  private animate=()=>{
    this.animId=requestAnimationFrame(this.animate);
    const dt=Math.min(this.clock.getDelta(),0.05);
    const t=this.clock.getElapsedTime();
    (this.water.material as THREE.ShaderMaterial).uniforms['time'].value+=dt*0.4;
    // Character idle breathing
    if(!this.combatStarted&&this.playerChar){
      this.playerChar.position.y=10+Math.sin(t*1.6)*0.1;
      // Idle weapon sway
      const wa=this.playerChar?.userData?.weaponArm;
      if(wa){ wa.rotation.z=0.08+Math.sin(t*0.8)*0.04; }
    }
    // Gunner aim animation
    const boss=this.alienFleet[0];
    if(boss&&boss.alive){
      boss.group.children.forEach(child=>{
        const gi=child.userData?.gunnerIdx;
        if(gi===undefined||!(child instanceof THREE.Group))return;
        const wa=child.userData?.weaponArm;
        if(!wa)return;
        const look=Math.sin(t*0.72+gi*2.0)>0.3;
        wa.rotation.x=look?-1.0:0.05; wa.rotation.y=look?(gi===0?0.5:-0.5):0;
      });
    }
    this.updatePlayerShip(dt);
    this.updateCombatCamera(dt);
    this.updateAlienFleet(dt);
    this.updateProjectiles(dt);
    this.updateParticles(dt);
    if(this.composer){this.composer.render();}
    else{this.renderer.render(this.scene,this.camera);}
  };

  destroy(){
    clearTimeout(this.combatFallbackTimer);
    cancelAnimationFrame(this.animId);
    window.removeEventListener('resize',this.onResize);
    this.renderer.dispose();
  }
}
