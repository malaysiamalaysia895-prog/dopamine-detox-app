import { useEffect, useRef, useState, useCallback } from 'react';
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

export default function App() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const gameRef = useRef<PirateGame | null>(null);
  const [webglError, setWebglError] = useState<string | null>(null);

  const [hud, setHud] = useState<HUD>({
    phase: 'intro',
    playerHP: 100,
    playerMaxHP: 100,
    aliensAlive: 5,
    aliensTotal: 5,
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

  const hpPct = Math.max(0, (hud.playerHP / hud.playerMaxHP) * 100);
  const hpColor = hpPct > 60 ? '#22c55e' : hpPct > 30 ? '#f59e0b' : '#ef4444';
  const isOver = hud.phase === 'victory' || hud.phase === 'defeat';

  if (webglError) {
    return (
      <div style={{
        width: '100vw', height: '100vh', background: '#060d1a',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'Georgia, serif', color: '#fff',
      }}>
        <div style={{ fontSize: 72, marginBottom: 16 }}>⚓</div>
        <div style={{ fontSize: 28, fontWeight: 900, letterSpacing: '0.15em', color: '#ffd580', marginBottom: 12, textTransform: 'uppercase' }}>
          Pirate Boss Fight
        </div>
        <div style={{ fontSize: 14, color: '#888', maxWidth: 380, textAlign: 'center', lineHeight: 1.7 }}>
          This game requires WebGL, which is supported in all modern browsers.
          <br />
          Open the preview in a new tab to play in full desktop mode.
        </div>
        <div style={{ marginTop: 24, fontSize: 11, color: '#444', fontFamily: 'monospace' }}>
          {webglError}
        </div>
      </div>
    );
  }

  return (
    <div style={{ position: 'relative', width: '100vw', height: '100vh', background: '#000', overflow: 'hidden' }}>
      {/* Three.js Canvas */}
      <canvas
        ref={canvasRef}
        style={{ width: '100%', height: '100%', display: 'block', cursor: hud.phase === 'combat' ? 'crosshair' : 'default' }}
      />

      {/* Phase title */}
      {hud.phaseTitle && !isOver && (
        <div style={{
          position: 'absolute', inset: 0, display: 'flex',
          alignItems: 'center', justifyContent: 'center', pointerEvents: 'none',
        }}>
          <div style={{
            fontFamily: 'Georgia, serif',
            fontSize: 52,
            fontWeight: 900,
            color: '#ffd580',
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            textShadow: '0 0 40px rgba(255,160,50,0.9), 0 2px 12px rgba(0,0,0,0.95)',
          }}>
            {hud.phaseTitle}
          </div>
        </div>
      )}

      {/* Victory / Defeat */}
      {isOver && (
        <div style={{
          position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center', pointerEvents: 'none',
          background: hud.phase === 'victory' ? 'rgba(0,40,20,0.72)' : 'rgba(40,0,0,0.72)',
        }}>
          <div style={{
            fontFamily: 'Georgia, serif', fontSize: 72, fontWeight: 900,
            letterSpacing: '0.2em', textTransform: 'uppercase',
            color: hud.phase === 'victory' ? '#00ff88' : '#ff4444',
            textShadow: `0 0 70px ${hud.phase === 'victory' ? '#00ff88' : '#ff0000'}, 0 4px 20px rgba(0,0,0,1)`,
            marginBottom: 20,
          }}>
            {hud.phaseTitle}
          </div>
          <div style={{ fontFamily: 'Georgia, serif', fontSize: 20, color: '#aaa', letterSpacing: '0.1em' }}>
            {hud.phase === 'victory' ? 'The seas are yours, Captain.' : 'Your ship has been sunk.'}
          </div>
          <div style={{ fontFamily: 'Georgia, serif', fontSize: 13, color: '#555', letterSpacing: '0.12em', marginTop: 28, textTransform: 'uppercase' }}>
            Refresh to play again
          </div>
        </div>
      )}

      {/* Combat HUD */}
      {hud.phase === 'combat' && !isOver && (
        <>
          {/* Player HP — top left */}
          <div style={{ position: 'absolute', top: 20, left: 20, userSelect: 'none', fontFamily: 'Georgia, serif' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
              <span style={{ fontSize: 22 }}>☠</span>
              <span style={{ fontSize: 11, color: '#ccc', textTransform: 'uppercase', letterSpacing: '0.12em' }}>Ship Hull</span>
            </div>
            <div style={{
              width: 200, height: 13, background: 'rgba(0,0,0,0.6)',
              borderRadius: 7, overflow: 'hidden', border: '1px solid rgba(255,255,255,0.18)',
            }}>
              <div style={{
                height: '100%', width: `${hpPct}%`,
                background: `linear-gradient(90deg, ${hpColor}, ${hpColor}99)`,
                boxShadow: `0 0 8px ${hpColor}`,
                transition: 'width 0.3s, background 0.3s',
                borderRadius: 7,
              }} />
            </div>
            <div style={{ fontSize: 11, color: '#777', marginTop: 4 }}>{hud.playerHP} / {hud.playerMaxHP}</div>
          </div>

          {/* Enemy count — top right */}
          <div style={{ position: 'absolute', top: 20, right: 20, textAlign: 'right', userSelect: 'none', fontFamily: 'Georgia, serif' }}>
            <div style={{ fontSize: 11, color: '#aaa', textTransform: 'uppercase', letterSpacing: '0.12em', marginBottom: 6 }}>Enemies</div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
              {Array.from({ length: hud.aliensTotal }).map((_, i) => (
                <div key={i} style={{
                  width: 14, height: 14, borderRadius: '50%',
                  background: i < hud.aliensAlive ? '#00ff88' : 'rgba(255,255,255,0.08)',
                  boxShadow: i < hud.aliensAlive ? '0 0 8px #00ff88' : 'none',
                  border: '1px solid rgba(255,255,255,0.2)',
                  transition: 'all 0.4s',
                }} />
              ))}
            </div>
            <div style={{ fontSize: 13, color: '#00ff88', marginTop: 5 }}>{hud.aliensAlive} / {hud.aliensTotal} remaining</div>
          </div>
        </>
      )}

      {/* Controls hint */}
      {hud.showControls && hud.phase === 'combat' && (
        <div style={{
          position: 'absolute', bottom: 20, left: '50%', transform: 'translateX(-50%)',
          fontFamily: 'monospace', color: 'rgba(255,255,255,0.38)', fontSize: 12,
          letterSpacing: '0.08em', userSelect: 'none', textAlign: 'center',
        }}>
          WASD / ↑↓←→ &nbsp;·&nbsp; Move &nbsp;&nbsp;&nbsp; CLICK &nbsp;·&nbsp; Fire Cannons
        </div>
      )}

      {/* Cinematic intro label */}
      {hud.phase === 'intro' && (
        <div style={{
          position: 'absolute', bottom: 18, left: '50%', transform: 'translateX(-50%)',
          fontFamily: 'Georgia, serif', color: 'rgba(255,200,100,0.45)', fontSize: 12,
          letterSpacing: '0.18em', textTransform: 'uppercase', userSelect: 'none',
        }}>
          Pirate Boss Fight · Cinematic Opening
        </div>
      )}

      {/* Vignette */}
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        background: 'radial-gradient(ellipse at center, transparent 52%, rgba(0,0,0,0.58) 100%)',
      }} />
    </div>
  );
}
