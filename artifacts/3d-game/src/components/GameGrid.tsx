import { useState, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useGameStore, GridCell } from "../store/useGameStore";
import { getItemById, PHASE_THEMES } from "../data/gameData";
import { LEVELS } from "../data/gameData";

function ObstacleIcon({ type }: { type: GridCell["obstacle"] }) {
  if (type === "dusty_web") return <span className="text-2xl select-none">🕸️</span>;
  if (type === "locked_crate") return <span className="text-2xl select-none">📦</span>;
  if (type === "black_hole") return <span className="text-2xl select-none animate-pulse">🕳️</span>;
  return null;
}

interface CellProps {
  cell: GridCell;
  theme: keyof typeof PHASE_THEMES;
  onDragStart: (col: number, row: number) => void;
  onDrop: (col: number, row: number) => void;
  onTap: (col: number, row: number) => void;
  isDragging: boolean;
  isSource: boolean;
}

function GameCell({ cell, theme, onDragStart, onDrop, onTap, isDragging, isSource }: CellProps) {
  const themeColors = PHASE_THEMES[theme];
  const item = cell.itemId ? getItemById(cell.itemId) : null;

  const isBlackHole = cell.obstacle === "black_hole";

  const bgStyle = isBlackHole
    ? "bg-black border-purple-900"
    : cell.locked
    ? "bg-black/40 border-gray-700"
    : isDragging
    ? "bg-white/15 border-white/40"
    : isSource
    ? "bg-white/20 border-yellow-400 scale-95"
    : item
    ? "bg-white/10 border-white/20 cursor-grab active:cursor-grabbing"
    : "bg-white/5 border-white/10 cursor-pointer hover:bg-white/10";

  return (
    <motion.div
      layout
      className={`relative flex items-center justify-center rounded-xl border-2 transition-colors select-none ${bgStyle}`}
      style={{
        boxShadow: isSource ? `0 0 12px ${themeColors.primary}88` : undefined,
      }}
      onPointerDown={e => {
        e.preventDefault();
        if (cell.locked || isBlackHole) return;
        if (item) onDragStart(cell.col, cell.row);
        else onTap(cell.col, cell.row);
      }}
      onPointerEnter={() => {
        if (isDragging && !isSource) onDrop(cell.col, cell.row);
      }}
      whileTap={item && !cell.locked ? { scale: 0.9 } : undefined}
    >
      {/* Black hole swirl */}
      {isBlackHole && (
        <motion.div
          className="absolute inset-0 rounded-xl"
          style={{ background: "radial-gradient(circle, #6600cc44, #000)" }}
          animate={{ rotate: [0, 360] }}
          transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
        />
      )}

      {/* Obstacle */}
      {cell.obstacle && !item && (
        <div className="relative z-10">
          <ObstacleIcon type={cell.obstacle} />
        </div>
      )}

      {/* Item */}
      <AnimatePresence>
        {item && (
          <motion.div
            key={item.id + cell.id}
            initial={{ scale: 0, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0, opacity: 0 }}
            transition={{ type: "spring", stiffness: 400, damping: 20 }}
            className="flex flex-col items-center justify-center gap-0.5 z-10"
          >
            <span className="text-2xl leading-none select-none">{item.emoji}</span>
            <span className="text-[9px] text-white/70 font-medium text-center leading-tight px-0.5 max-w-[56px] truncate">
              {item.name}
            </span>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Merge indicator */}
      {isDragging && !isSource && item && (
        <div
          className="absolute inset-0 rounded-xl border-2 animate-pulse"
          style={{ borderColor: themeColors.primary, boxShadow: `0 0 8px ${themeColors.primary}` }}
        />
      )}
    </motion.div>
  );
}

export function GameGrid() {
  const { grid, currentLevel, moveItem, spawnItem, phase } = useGameStore();
  const cfg = LEVELS[currentLevel];
  const theme = cfg?.theme ?? "garage";
  const themeColors = PHASE_THEMES[theme];

  const [dragSource, setDragSource] = useState<[number, number] | null>(null);

  function handleDragStart(col: number, row: number) {
    setDragSource([col, row]);
  }

  function handleDrop(col: number, row: number) {
    if (!dragSource) return;
    const [fc, fr] = dragSource;
    if (fc === col && fr === row) {
      setDragSource(null);
      return;
    }
    moveItem(fc, fr, col, row);
    setDragSource(null);
  }

  function handleTap(col: number, row: number) {
    if (dragSource) {
      handleDrop(col, row);
    } else {
      spawnItem(col, row);
    }
  }

  function handlePointerUp() {
    setDragSource(null);
  }

  if (!cfg || phase === "menu") return null;

  const cellSize = Math.min(
    Math.floor((Math.min(window.innerWidth - 32, 420)) / cfg.gridCols),
    72
  );

  return (
    <div
      className="flex-1 flex items-center justify-center p-2"
      onPointerUp={handlePointerUp}
    >
      <div
        className="grid gap-1.5"
        style={{
          gridTemplateColumns: `repeat(${cfg.gridCols}, ${cellSize}px)`,
          gridTemplateRows: `repeat(${cfg.gridRows}, ${cellSize}px)`,
        }}
      >
        {Array.from({ length: cfg.gridCols }, (_, c) =>
          Array.from({ length: cfg.gridRows }, (_, r) => {
            const cell = grid[c]?.[r];
            if (!cell) return null;
            return (
              <GameCell
                key={cell.id}
                cell={cell}
                theme={theme}
                onDragStart={handleDragStart}
                onDrop={handleDrop}
                onTap={handleTap}
                isDragging={dragSource !== null}
                isSource={dragSource?.[0] === c && dragSource?.[1] === r}
              />
            );
          })
        )}
      </div>
    </div>
  );
}
