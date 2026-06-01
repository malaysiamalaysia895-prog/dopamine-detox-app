// ============================================================
// phase_themes.dart — Visual Themes for All 5 Game Phases
// Tech Tycoon Merge
// ============================================================

import 'package:flutter/material.dart';
import '../models/models.dart';

class PhaseTheme {
  final String name;
  final String subtitle;
  final Color bgCenter;
  final Color bgMid;
  final Color bgEdge;
  final Color primary;
  final Color accent;
  final Color gridTile;
  final Color gridBorder;
  final Color gridGlow;
  final Color spawnerColor;
  final Color textPrimary;
  final Color textSecondary;
  final String bgmAsset;

  const PhaseTheme({
    required this.name,
    required this.subtitle,
    required this.bgCenter,
    required this.bgMid,
    required this.bgEdge,
    required this.primary,
    required this.accent,
    required this.gridTile,
    required this.gridBorder,
    required this.gridGlow,
    required this.spawnerColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.bgmAsset,
  });

  BoxDecoration get backgroundDecoration => BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 1.4,
      colors: [bgCenter, bgMid, bgEdge],
      stops: const [0.0, 0.5, 1.0],
    ),
  );

  BoxDecoration gridCellDecoration({bool isEmpty = false, bool isHighlighted = false}) => BoxDecoration(
    color: isHighlighted
        ? primary.withOpacity(0.35)
        : isEmpty
            ? gridTile.withOpacity(0.4)
            : gridTile.withOpacity(0.7),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: isHighlighted ? primary : gridBorder,
      width: isHighlighted ? 2.5 : 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: gridGlow.withOpacity(isHighlighted ? 0.6 : 0.25),
        blurRadius: isHighlighted ? 14 : 6,
        spreadRadius: isHighlighted ? 2 : 0,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.5),
        blurRadius: 4,
        offset: const Offset(2, 3),
      ),
    ],
  );

  BoxDecoration get spawnerDecoration => BoxDecoration(
    gradient: RadialGradient(
      colors: [spawnerColor, spawnerColor.withOpacity(0.4)],
      radius: 0.9,
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: spawnerColor, width: 2.5),
    boxShadow: [
      BoxShadow(color: spawnerColor.withOpacity(0.7), blurRadius: 20, spreadRadius: 3),
      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 4)),
    ],
  );
}

const Map<GamePhase, PhaseTheme> kPhaseThemes = {
  GamePhase.garage: PhaseTheme(
    name: 'The Dusty Garage',
    subtitle: 'Levels 1 – 10',
    bgCenter: Color(0xFFFBC02D),   // warm dim yellow
    bgMid:    Color(0xFF3E2723),   // rusty brown
    bgEdge:   Color(0xFF000000),   // black
    primary:        Color(0xFFFF6B35),
    accent:         Color(0xFF00E5FF),
    gridTile:       Color(0xFF3E2723),
    gridBorder:     Color(0xFF795548),
    gridGlow:       Color(0xFFFF6B35),
    spawnerColor:   Color(0xFFFF6B35),
    textPrimary:    Colors.white,
    textSecondary:  Color(0xFFBCAAA4),
    bgmAsset: 'assets/audio/bgm_garage.mp3',
  ),

  GamePhase.office: PhaseTheme(
    name: 'The Office Upgrade',
    subtitle: 'Levels 11 – 20',
    bgCenter: Color(0xFFE3F2FD),   // icy cyan/white
    bgMid:    Color(0xFF1565C0),   // mid blue
    bgEdge:   Color(0xFF0D47A1),   // deep blue
    primary:        Color(0xFF1E90FF),
    accent:         Color(0xFFFFFFFF),
    gridTile:       Color(0x33FFFFFF),  // frosted glass
    gridBorder:     Color(0xFF90CAF9),
    gridGlow:       Color(0xFF64B5F6),
    spawnerColor:   Color(0xFF1E90FF),
    textPrimary:    Color(0xFF0D47A1),
    textSecondary:  Color(0xFF1565C0),
    bgmAsset: 'assets/audio/bgm_office.mp3',
  ),

  GamePhase.silicon: PhaseTheme(
    name: 'Silicon Valley Tycoon',
    subtitle: 'Levels 21 – 30',
    bgCenter: Color(0xFFFF007F),   // neon pink
    bgMid:    Color(0xFF120024),   // deep dark purple
    bgEdge:   Color(0xFF000000),   // black
    primary:        Color(0xFFFF007F),
    accent:         Color(0xFFCC00FF),
    gridTile:       Color(0xFF0D0018),
    gridBorder:     Color(0xFFCC00FF),
    gridGlow:       Color(0xFFFF007F),
    spawnerColor:   Color(0xFFCC00FF),
    textPrimary:    Colors.white,
    textSecondary:  Color(0xFFCC00FF),
    bgmAsset: 'assets/audio/bgm_silicon.mp3',
  ),

  GamePhase.megacorp: PhaseTheme(
    name: 'Global Mega-Corp',
    subtitle: 'Levels 31 – 40',
    bgCenter: Color(0xFF00FF00),   // acid green
    bgMid:    Color(0xFF001400),   // dark green
    bgEdge:   Color(0xFF000000),   // black
    primary:        Color(0xFF00FF41),
    accent:         Color(0xFF39FF14),
    gridTile:       Color(0xFF001800),
    gridBorder:     Color(0xFF00FF41),
    gridGlow:       Color(0xFF00FF00),
    spawnerColor:   Color(0xFF00FF41),
    textPrimary:    Color(0xFF00FF41),
    textSecondary:  Color(0xFF4CAF50),
    bgmAsset: 'assets/audio/bgm_megacorp.mp3',
  ),

  GamePhase.universe: PhaseTheme(
    name: 'Masters of the Universe',
    subtitle: 'Levels 41 – 50',
    bgCenter: Color(0xFFFFD700),   // gold
    bgMid:    Color(0xFF4B0082),   // deep purple
    bgEdge:   Color(0xFF000000),   // black
    primary:        Color(0xFFFFD700),
    accent:         Color(0xFFE5E4E2), // platinum
    gridTile:       Color(0xFF0A0010),
    gridBorder:     Color(0xFFFFD700),
    gridGlow:       Color(0xFFFFD700),
    spawnerColor:   Color(0xFFFFD700),
    textPrimary:    Color(0xFFFFD700),
    textSecondary:  Color(0xFFE5E4E2),
    bgmAsset: 'assets/audio/bgm_universe.mp3',
  ),
};

PhaseTheme themeOf(GamePhase phase) => kPhaseThemes[phase]!;
