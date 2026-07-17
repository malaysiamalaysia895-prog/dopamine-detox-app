import { useEffect, useRef, useState, useCallback, useLayoutEffect } from 'react';
import { PirateGame, GamePhase, GameState } from './game/PirateGame';

interface HUD {
  phase: GamePhase;
  playerHP: number;
  playerMaxHP: number;
  aliensAlive: number;
  aliensTotal: number;
  phaseTitle: string;
  showControls: boolean;
}

// ─── Touch joystick ────────────────────────────────────────────────────────────
function useJoystick(gameRef: React.MutableRefObject<PirateGame | null>) {
  const stickRef = useRef<HTMLDivElement>(null);
  const knobRef  = useRef<HTMLDivElement>(null);
  const touchId  = useRef<number | null>(null);
  const base     = useRef({ x: 0, y: 0 });
  const RADIUS   = 48;

  useLayoutEffect(() => {
    const el = stickRef.current;
    if (!el) return;

    const onStart = (e: TouchEvent) => {
      e.preventDefault();
      if (touchId.current !== null) return;
      const t = e.changedTouches[0];
      touchId.current = t.identifier;
      const r = el.getBoundingClientRect();
      base.current = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    };

    const onMove = (e: TouchEvent) => {
      e.preventDefault();
      if (touchId.current === null) return;
      let touch: Touch | null = null;
      for (let i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === touchId.current) { touch = e.changedTouches[i]; break; }
      }
      if (!touch) return;
      const dx = touch.clientX - base.current.x;
      const dy = touch.clientY - base.current.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const clamp = Math.min(dist, RADIUS);
      const angle = Math.atan2(dy, dx);
      const cx = Math.cos(angle) * clamp;
      const cy = Math.sin(angle) * clamp;
      if (knobRef.current) knobRef.current.style.transform = `translate(${cx}px,${cy}px)`;
      gameRef.current?.setJoystickInput(cx / RADIUS, cy / RADIUS);
    };

    const onEnd = (e: TouchEvent) => {
      let found = false;
      for (let i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === touchId.current) { found = true; break; }
      }
      if (!found) return;
      touchId.current = null;
      if (knobRef.current) knobRef.current.style.transform = 'translate(0px,0px)';
      gameRef.current?.setJoystickInput(0, 0);
    };

    el.addEventListener('touchstart', onStart, { passive: false });
    window.addEventListener('touchmove', onMove, { passive: false });
    window.addEventListener('touchend', onEnd, { passive: false });
    return () => {
      el.removeEventListener('touchstart', onStart);
      window.removeEventListener('touchmove', onMove);
      window.removeEventListener('touchend', onEnd);
    };
  }, [gameRef]);

  return { stickRef, knobRef };
}

// ─── App ──────────────────────────────────────────────────────────────────────
export default function App() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const gameRef   = useRef<PirateGame | null>(null);
  const [webglErr, setWebglErr] = useState<string | null>(null);
  const { stickRef, knobRef } = useJoystick(gameRef);

  const [hud, setHud] = useState<HUD>({
    phase: 'intro',
    playerHP: 100,
    playerMaxHP: 100,
    aliensAlive: 3,
    aliensTotal: 3,
    phaseTitle: 'ALIEN INVASION',
    showControls: false,
  });

  const onStateChange = useCallback((state: Partial<GameState>) => {
    setHud(prev => ({ ...prev, ...state }));
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    try {
      gameRef.current = new PirateGame(canvas, { onStateChange });
    } catch (err) {
      setWebglErr(err instanceof Error ? err.message : String(err));
    }
    return () => { gameRef.current?.destroy(); gameRef.current = null; };
  }, [onStateChange]);

  // Reliable fire: both pointer AND touch handlers
  const handleFire = useCallback((e: React.PointerEvent | React.TouchEvent) => {
    e.preventDefault();
    e.stopPropagation();
    gameRef.current?.triggerFire();
  }, []);

  const hpPct   = Math.max(0, (hud.playerHP / hud.playerMaxHP) * 100);
  const hpColor = hpPct > 60 ? '#22c55e' : hpPct > 30 ? '#f59e0b' : '#ef4444';
  const isOver  = hud.phase === 'victory' || hud.phase === 'defeat';

  if (webglErr) {
    return (
      <div style={{ width: '100vw', height: '100vh', background: '#060d1a', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', fontFamily: 'Georgia, serif', color: '#fff' }}>
        <div style={{ fontSize: 64, marginBottom: 12 }}>⚓</div>
        <div style={{ fontSize: 26, fontWeight: 900, color: '#ffd580', letterSpacing: '0.15em', textTransform: 'uppercase', marginBottom: 10 }}>Pirate Boss Fight</div>
        <div style={{ fontSize: 13, color: '#888', maxWidth: 360, textAlign: 'center', lineHeight: 1.7 }}>
          {webglErr?.includes('WebGL') || webglErr?.includes('webgl')
            ? 'WebGL not supported on this device.'
            : 'Startup error — tap to retry.'}
        </div>
        <div style={{ marginTop: 20, fontSize: 11, color: '#555', fontFamily: 'monospace', maxWidth: 340, textAlign: 'center', wordBreak: 'break-all', lineHeight: 1.5 }}>{webglErr}</div>
        <button
          onClick={() => window.location.reload()}
          style={{ marginTop: 28, padding: '10px 28px', borderRadius: 24, background: 'rgba(255,200,80,0.12)', border: '1.5px solid rgba(255,200,80,0.4)', color: '#ffd580', fontFamily: 'Georgia, serif', fontSize: 13, fontWeight: 700, cursor: 'pointer', letterSpacing: '0.12em' }}>
          ↺ RETRY
        </button>
      </div>
    );
  }

  return (
    <div style={{ position: 'relative', width: '100vw', height: '100vh', background: '#000', overflow: 'hidden', touchAction: 'none' }}>

      {/* Three.js Canvas */}
      <canvas
        ref={canvasRef}
        style={{ width: '100%', height: '100%', display: 'block', cursor: hud.phase === 'combat' ? 'crosshair' : 'default' }}
      />

      {/* Vignette overlay */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none', background: 'radial-gradient(ellipse at center, transparent 48%, rgba(0,0,0,0.55) 100%)' }} />

      {/* Phase title */}
      {hud.phaseTitle && !isOver && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none' }}>
          <div style={{
            fontFamily: 'Georgia, serif',
            fontSize: 'clamp(24px, 5.5vw, 52px)',
            fontWeight: 900,
            color: '#ffd580',
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            textShadow: '0 0 36px rgba(255,160,50,0.85), 0 2px 10px rgba(0,0,0,0.95)',
            animation: 'fadeTitle 0.38s ease both',
            padding: '0 24px',
            textAlign: 'center',
          }}>
            {hud.phaseTitle}
          </div>
        </div>
      )}

      {/* Victory / Defeat */}
      {isOver && (
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          pointerEvents: 'none',
          background: hud.phase === 'victory' ? 'rgba(0,40,20,0.70)' : 'rgba(40,0,0,0.70)',
        }}>
          <div style={{
            fontFamily: 'Georgia, serif',
            fontSize: 'clamp(48px, 14vw, 80px)',
            fontWeight: 900,
            color: hud.phase === 'victory' ? '#00ff88' : '#ff4444',
            textShadow: `0 0 55px ${hud.phase === 'victory' ? '#00ff88' : '#ff0000'}`,
            letterSpacing: '0.12em',
            textTransform: 'uppercase',
          }}>
            {hud.phase === 'victory' ? '⚓ VICTORY!' : '💀 DEFEAT'}
          </div>
        </div>
      )}

      {/* HUD during combat */}
      {hud.phase === 'combat' && !isOver && (
        <>
          {/* HP — top left */}
          <div style={{ position: 'absolute', top: 16, left: 16, userSelect: 'none', fontFamily: 'Georgia, serif' }}>
            <div style={{ fontSize: 10, color: '#999', textTransform: 'uppercase', letterSpacing: '0.14em', marginBottom: 4 }}>Hull Integrity</div>
            <div style={{ width: 160, height: 9, background: 'rgba(255,255,255,0.08)', borderRadius: 5, border: '1px solid rgba(255,255,255,0.12)', overflow: 'hidden' }}>
              <div style={{ width: `${hpPct}%`, height: '100%', background: hpColor, borderRadius: 5, boxShadow: `0 0 7px ${hpColor}`, transition: 'width 0.3s, background 0.3s' }} />
            </div>
            <div style={{ fontSize: 12, color: hpColor, marginTop: 4 }}>{hud.playerHP} / {hud.playerMaxHP}</div>
          </div>

          {/* Enemies — top right */}
          <div style={{ position: 'absolute', top: 16, right: 16, textAlign: 'right', userSelect: 'none', fontFamily: 'Georgia, serif' }}>
            <div style={{ fontSize: 10, color: '#999', textTransform: 'uppercase', letterSpacing: '0.14em', marginBottom: 6 }}>Enemies</div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 5 }}>
              {Array.from({ length: hud.aliensTotal }).map((_, i) => (
                <div key={i} style={{ width: 13, height: 13, borderRadius: '50%', background: i < hud.aliensAlive ? '#00ff88' : 'rgba(255,255,255,0.06)', boxShadow: i < hud.aliensAlive ? '0 0 7px #00ff88' : 'none', border: '1px solid rgba(255,255,255,0.18)', transition: 'all 0.4s' }} />
              ))}
            </div>
            <div style={{ fontSize: 12, color: '#00ff88', marginTop: 4 }}>{hud.aliensAlive} / {hud.aliensTotal}</div>
          </div>
        </>
      )}

      {/* Mobile controls — unlocked only after cinematic */}
      {hud.showControls && hud.phase === 'combat' && (
        <>
          {/* Virtual Joystick — bottom left */}
          <div
            ref={stickRef}
            style={{
              position: 'absolute',
              bottom: 32, left: 32,
              width: 112, height: 112,
              borderRadius: '50%',
              background: 'rgba(0,0,0,0.38)',
              border: '2px solid rgba(0,220,255,0.32)',
              boxShadow: '0 0 22px rgba(0,200,255,0.15), inset 0 0 14px rgba(0,0,0,0.42)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              touchAction: 'none',
              userSelect: 'none',
              backdropFilter: 'blur(3px)',
              WebkitBackdropFilter: 'blur(3px)',
            }}
          >
            {/* Guide cross */}
            <div style={{ position: 'absolute', width: 1, height: '65%', background: 'rgba(0,200,255,0.15)' }} />
            <div style={{ position: 'absolute', height: 1, width: '65%', background: 'rgba(0,200,255,0.15)' }} />
            {/* Knob */}
            <div
              ref={knobRef}
              style={{
                width: 42, height: 42,
                borderRadius: '50%',
                background: 'radial-gradient(circle at 38% 35%, rgba(0,220,255,0.90), rgba(0,100,180,0.80))',
                border: '2px solid rgba(0,220,255,0.6)',
                boxShadow: '0 0 16px rgba(0,200,255,0.48)',
                transition: 'transform 0.04s linear',
                pointerEvents: 'none',
                willChange: 'transform',
              }}
            />
          </div>

          {/* FIRE button — bottom right */}
          <button
            onPointerDown={handleFire}
            onTouchStart={handleFire as any}
            style={{
              position: 'absolute',
              bottom: 38, right: 38,
              width: 88, height: 88,
              borderRadius: '50%',
              background: 'radial-gradient(circle at 40% 35%, rgba(255,80,0,0.96), rgba(180,20,0,0.88))',
              border: '2.5px solid rgba(255,120,0,0.68)',
              boxShadow: '0 0 26px rgba(255,70,0,0.50), inset 0 -4px 10px rgba(0,0,0,0.32)',
              color: '#fff',
              fontFamily: 'Georgia, serif',
              fontSize: 12,
              fontWeight: 900,
              letterSpacing: '0.1em',
              textTransform: 'uppercase',
              cursor: 'pointer',
              touchAction: 'manipulation',
              userSelect: 'none',
              outline: 'none',
              WebkitTapHighlightColor: 'transparent',
              // Prevent ghost clicks on mobile
              WebkitUserSelect: 'none',
            }}
          >
            🔥<br />FIRE
          </button>

          {/* Desktop keyboard hint */}
          <div style={{
            position: 'absolute', bottom: 14, left: '50%', transform: 'translateX(-50%)',
            fontFamily: 'monospace', color: 'rgba(255,255,255,0.28)', fontSize: 11,
            letterSpacing: '0.08em', userSelect: 'none', textAlign: 'center', pointerEvents: 'none',
            display: window.matchMedia('(pointer:coarse)').matches ? 'none' : 'block',
          }}>
            WASD / ↑↓←→ &nbsp;·&nbsp; Move &nbsp;&nbsp; CLICK &nbsp;·&nbsp; Fire
          </div>
        </>
      )}

      {/* Cinematic label */}
      {hud.phase === 'intro' && (
        <div style={{ position: 'absolute', bottom: 14, left: '50%', transform: 'translateX(-50%)', fontFamily: 'Georgia, serif', color: 'rgba(255,200,100,0.38)', fontSize: 11, letterSpacing: '0.18em', textTransform: 'uppercase', userSelect: 'none', pointerEvents: 'none', whiteSpace: 'nowrap' }}>
          Pirate Boss Fight · Cinematic Opening
        </div>
      )}

      <style>{`
        @keyframes fadeTitle {
          from { opacity: 0; transform: scale(0.93) translateY(8px); }
          to   { opacity: 1; transform: scale(1)    translateY(0);   }
        }
        * { -webkit-tap-highlight-color: transparent; }
      `}</style>
    </div>
  );
}
