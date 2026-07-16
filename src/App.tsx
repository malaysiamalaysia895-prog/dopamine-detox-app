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

// ─── Virtual Joystick Hook ────────────────────────────────────────────────────
function useJoystick(gameRef: React.MutableRefObject<PirateGame | null>) {
  const stickRef   = useRef<HTMLDivElement>(null);
  const knobRef    = useRef<HTMLDivElement>(null);
  const touchId    = useRef<number | null>(null);
  const basePos    = useRef({ x: 0, y: 0 });

  useLayoutEffect(() => {
    const stick = stickRef.current;
    if (!stick) return;
    const RADIUS = 52;

    const onStart = (e: TouchEvent) => {
      if (touchId.current !== null) return;
      const t = e.changedTouches[0];
      touchId.current = t.identifier;
      const rect = stick.getBoundingClientRect();
      basePos.current = { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
      e.preventDefault();
    };

    const onMove = (e: TouchEvent) => {
      if (touchId.current === null) return;
      let touch: Touch | null = null;
      for (let i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === touchId.current) { touch = e.changedTouches[i]; break; }
      }
      if (!touch) return;
      e.preventDefault();

      const dx = touch.clientX - basePos.current.x;
      const dy = touch.clientY - basePos.current.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const clamp = Math.min(dist, RADIUS);
      const angle = Math.atan2(dy, dx);
      const cx = Math.cos(angle) * clamp;
      const cy = Math.sin(angle) * clamp;

      if (knobRef.current) {
        knobRef.current.style.transform = `translate(${cx}px, ${cy}px)`;
      }

      const normX = cx / RADIUS;
      const normY = cy / RADIUS;
      gameRef.current?.setJoystickInput(normX, normY);
    };

    const onEnd = (e: TouchEvent) => {
      let found = false;
      for (let i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === touchId.current) { found = true; break; }
      }
      if (!found) return;
      touchId.current = null;
      if (knobRef.current) knobRef.current.style.transform = 'translate(0px, 0px)';
      gameRef.current?.setJoystickInput(0, 0);
    };

    stick.addEventListener('touchstart', onStart, { passive: false });
    window.addEventListener('touchmove', onMove, { passive: false });
    window.addEventListener('touchend', onEnd, { passive: false });
    return () => {
      stick.removeEventListener('touchstart', onStart);
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
  const [webglError, setWebglError] = useState<string | null>(null);
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
      const game = new PirateGame(canvas, { onStateChange });
      gameRef.current = game;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      setWebglError(msg);
    }
    return () => {
      gameRef.current?.destroy();
      gameRef.current = null;
    };
  }, [onStateChange]);

  const hpPct   = Math.max(0, (hud.playerHP / hud.playerMaxHP) * 100);
  const hpColor = hpPct > 60 ? '#22c55e' : hpPct > 30 ? '#f59e0b' : '#ef4444';
  const isOver  = hud.phase === 'victory' || hud.phase === 'defeat';
  const isMobile = typeof window !== 'undefined' && ('ontouchstart' in window || navigator.maxTouchPoints > 0);

  // ── WebGL error ────────────────────────────────────────────────────────────
  if (webglError) {
    return (
      <div style={{ width: '100vw', height: '100vh', background: '#060d1a', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', fontFamily: 'Georgia, serif', color: '#fff' }}>
        <div style={{ fontSize: 72, marginBottom: 16 }}>⚓</div>
        <div style={{ fontSize: 28, fontWeight: 900, letterSpacing: '0.15em', color: '#ffd580', marginBottom: 12, textTransform: 'uppercase' }}>Pirate Boss Fight</div>
        <div style={{ fontSize: 14, color: '#888', maxWidth: 380, textAlign: 'center', lineHeight: 1.7 }}>
          This game requires WebGL. Open the preview in a full browser tab to play.
        </div>
        <div style={{ marginTop: 24, fontSize: 11, color: '#444', fontFamily: 'monospace' }}>{webglError}</div>
      </div>
    );
  }

  return (
    <div style={{ position: 'relative', width: '100vw', height: '100vh', background: '#000', overflow: 'hidden' }}>

      {/* ── Three.js Canvas ── */}
      <canvas
        ref={canvasRef}
        style={{ width: '100%', height: '100%', display: 'block', cursor: hud.phase === 'combat' ? 'crosshair' : 'default' }}
      />

      {/* ── Phase title ── */}
      {hud.phaseTitle && !isOver && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none' }}>
          <div style={{
            fontFamily: 'Georgia, serif',
            fontSize: 'clamp(28px, 6vw, 56px)',
            fontWeight: 900,
            color: '#ffd580',
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            textShadow: '0 0 40px rgba(255,160,50,0.9), 0 2px 12px rgba(0,0,0,0.95)',
            animation: 'fadeInTitle 0.4s ease',
          }}>
            {hud.phaseTitle}
          </div>
        </div>
      )}

      {/* ── Victory / Defeat overlay ── */}
      {isOver && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none', background: hud.phase === 'victory' ? 'rgba(0,40,20,0.72)' : 'rgba(40,0,0,0.72)' }}>
          <div style={{ fontFamily: 'Georgia, serif', fontSize: 72, fontWeight: 900, color: hud.phase === 'victory' ? '#00ff88' : '#ff4444', textShadow: `0 0 60px ${hud.phase === 'victory' ? '#00ff88' : '#ff0000'}`, letterSpacing: '0.15em', textTransform: 'uppercase' }}>
            {hud.phase === 'victory' ? '⚓ VICTORY!' : '💀 DEFEAT'}
          </div>
        </div>
      )}

      {/* ── HUD (shown during combat) ── */}
      {hud.phase === 'combat' && !isOver && (
        <>
          {/* HP bar — top left */}
          <div style={{ position: 'absolute', top: 20, left: 20, userSelect: 'none', fontFamily: 'Georgia, serif' }}>
            <div style={{ fontSize: 11, color: '#aaa', textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: 5 }}>Hull Integrity</div>
            <div style={{ width: 180, height: 10, background: 'rgba(255,255,255,0.1)', borderRadius: 5, border: '1px solid rgba(255,255,255,0.15)', overflow: 'hidden' }}>
              <div style={{ width: `${hpPct}%`, height: '100%', background: hpColor, borderRadius: 5, boxShadow: `0 0 8px ${hpColor}`, transition: 'width 0.3s, background 0.3s' }} />
            </div>
            <div style={{ fontSize: 13, color: hpColor, marginTop: 5, fontVariantNumeric: 'tabular-nums' }}>{hud.playerHP} / {hud.playerMaxHP}</div>
          </div>

          {/* Enemy count — top right */}
          <div style={{ position: 'absolute', top: 20, right: 20, textAlign: 'right', userSelect: 'none', fontFamily: 'Georgia, serif' }}>
            <div style={{ fontSize: 11, color: '#aaa', textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: 6 }}>Enemies</div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
              {Array.from({ length: hud.aliensTotal }).map((_, i) => (
                <div key={i} style={{ width: 14, height: 14, borderRadius: '50%', background: i < hud.aliensAlive ? '#00ff88' : 'rgba(255,255,255,0.08)', boxShadow: i < hud.aliensAlive ? '0 0 8px #00ff88' : 'none', border: '1px solid rgba(255,255,255,0.2)', transition: 'all 0.4s' }} />
              ))}
            </div>
            <div style={{ fontSize: 13, color: '#00ff88', marginTop: 5 }}>{hud.aliensAlive} / {hud.aliensTotal} remaining</div>
          </div>
        </>
      )}

      {/* ── MOBILE CONTROLS (unlocked after 9s cinematic) ── */}
      {hud.showControls && hud.phase === 'combat' && (
        <>
          {/* Virtual Joystick — bottom left */}
          <div
            ref={stickRef}
            style={{
              position: 'absolute',
              bottom: 36,
              left: 36,
              width: 120,
              height: 120,
              borderRadius: '50%',
              background: 'rgba(0,0,0,0.35)',
              border: '2px solid rgba(0,230,255,0.35)',
              boxShadow: '0 0 24px rgba(0,200,255,0.18), inset 0 0 16px rgba(0,0,0,0.4)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              touchAction: 'none',
              userSelect: 'none',
              backdropFilter: 'blur(4px)',
            }}
          >
            {/* Crosshair guides */}
            <div style={{ position: 'absolute', width: 1, height: '70%', background: 'rgba(0,200,255,0.18)' }} />
            <div style={{ position: 'absolute', height: 1, width: '70%', background: 'rgba(0,200,255,0.18)' }} />

            {/* Knob */}
            <div
              ref={knobRef}
              style={{
                width: 46,
                height: 46,
                borderRadius: '50%',
                background: 'radial-gradient(circle at 38% 35%, rgba(0,220,255,0.85), rgba(0,100,180,0.75))',
                border: '2px solid rgba(0,220,255,0.6)',
                boxShadow: '0 0 18px rgba(0,200,255,0.5)',
                transition: 'transform 0.04s linear',
                pointerEvents: 'none',
              }}
            />
          </div>

          {/* FIRE button — bottom right */}
          <button
            onPointerDown={(e) => {
              e.preventDefault();
              gameRef.current?.triggerFire();
            }}
            style={{
              position: 'absolute',
              bottom: 42,
              right: 42,
              width: 92,
              height: 92,
              borderRadius: '50%',
              background: 'radial-gradient(circle at 40% 35%, rgba(255,80,0,0.95), rgba(180,20,0,0.85))',
              border: '2.5px solid rgba(255,120,0,0.7)',
              boxShadow: '0 0 28px rgba(255,80,0,0.55), inset 0 -4px 12px rgba(0,0,0,0.35)',
              color: '#fff',
              fontFamily: 'Georgia, serif',
              fontSize: 13,
              fontWeight: 900,
              letterSpacing: '0.12em',
              textTransform: 'uppercase',
              cursor: 'pointer',
              touchAction: 'manipulation',
              userSelect: 'none',
              backdropFilter: 'blur(4px)',
              outline: 'none',
            }}
            onPointerEnter={e => (e.currentTarget.style.boxShadow = '0 0 40px rgba(255,80,0,0.85), inset 0 -4px 12px rgba(0,0,0,0.35)')}
            onPointerLeave={e => (e.currentTarget.style.boxShadow = '0 0 28px rgba(255,80,0,0.55), inset 0 -4px 12px rgba(0,0,0,0.35)')}
          >
            🔥<br />FIRE
          </button>

          {/* Desktop hint */}
          {!isMobile && (
            <div style={{ position: 'absolute', bottom: 20, left: '50%', transform: 'translateX(-50%)', fontFamily: 'monospace', color: 'rgba(255,255,255,0.35)', fontSize: 12, letterSpacing: '0.08em', userSelect: 'none', textAlign: 'center', pointerEvents: 'none' }}>
              WASD / ↑↓←→ &nbsp;·&nbsp; Move &nbsp;&nbsp; CLICK &nbsp;·&nbsp; Fire Cannons
            </div>
          )}
        </>
      )}

      {/* ── Cinematic label ── */}
      {hud.phase === 'intro' && (
        <div style={{ position: 'absolute', bottom: 18, left: '50%', transform: 'translateX(-50%)', fontFamily: 'Georgia, serif', color: 'rgba(255,200,100,0.42)', fontSize: 12, letterSpacing: '0.18em', textTransform: 'uppercase', userSelect: 'none', pointerEvents: 'none' }}>
          Pirate Boss Fight · Cinematic Opening
        </div>
      )}

      {/* ── Vignette ── */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none', background: 'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.62) 100%)' }} />

      {/* ── Keyframe styles ── */}
      <style>{`
        @keyframes fadeInTitle {
          from { opacity: 0; transform: scale(0.92) translateY(6px); }
          to   { opacity: 1; transform: scale(1)    translateY(0);   }
        }
      `}</style>
    </div>
  );
}
