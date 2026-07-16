// Ambient declarations for three.js 0.185 (no bundled .d.ts)
declare module 'three' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const THREE: any;
  export = THREE;
  export as namespace THREE;
}

declare module 'three/examples/jsm/objects/Water.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class Water { constructor(geo: any, opts?: any); [k: string]: any; }
}

declare module 'three/examples/jsm/objects/Sky.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class Sky { [k: string]: any; }
}

declare module 'three/examples/jsm/postprocessing/EffectComposer.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class EffectComposer { constructor(renderer: any, rt?: any); [k: string]: any; }
}

declare module 'three/examples/jsm/postprocessing/Pass.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class Pass { [k: string]: any; }
}

declare module 'three/examples/jsm/postprocessing/RenderPass.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class RenderPass { constructor(scene: any, camera: any); [k: string]: any; }
}

declare module 'three/examples/jsm/postprocessing/UnrealBloomPass.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class UnrealBloomPass { constructor(resolution: any, strength: number, radius: number, threshold: number); [k: string]: any; }
}

declare module 'three/examples/jsm/postprocessing/OutputPass.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class OutputPass { [k: string]: any; }
}

declare module 'three/examples/jsm/loaders/GLTFLoader.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class GLTFLoader { [k: string]: any; }
}

declare module 'three/examples/jsm/loaders/DRACOLoader.js' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export class DRACOLoader { [k: string]: any; }
}
