import 'package:flutter/material.dart';

enum AppTheme { stone, neon, forest, candy }

class GameThemeData {
  final String name;
  final String emoji;

  // Background
  final Color bgTop;
  final Color bgBottom;

  // Ball
  final Color ballColor;
  final Color ballHighlight;

  // Paddle
  final Color paddleGradientStart;
  final Color paddleGradientEnd;
  final Color paddleStroke;

  // Bricks - 4 tiers by HP
  final List<Color> brickColors;
  final Color brickStroke;
  final double brickStrokeWidth;

  // UI
  final Color textPrimary;
  final Color textSecondary;
  final Color accentColor;
  final Color overlayColor;

  // Walls / border
  final Color wallColor;

  const GameThemeData({
    required this.name,
    required this.emoji,
    required this.bgTop,
    required this.bgBottom,
    required this.ballColor,
    required this.ballHighlight,
    required this.paddleGradientStart,
    required this.paddleGradientEnd,
    required this.paddleStroke,
    required this.brickColors,
    required this.brickStroke,
    required this.brickStrokeWidth,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentColor,
    required this.overlayColor,
    required this.wallColor,
  });
}

class GameThemes {
  static const Map<AppTheme, GameThemeData> themes = {
    AppTheme.stone: GameThemeData(
      name: 'Cosmic',
      emoji: '🌌',
      bgTop: Color(0xFF0D1B3E),
      bgBottom: Color(0xFF06090F),
      ballColor: Color(0xFFFFE566),
      ballHighlight: Color(0xFFFFFFFF),
      paddleGradientStart: Color(0xFF4A9EFF),
      paddleGradientEnd: Color(0xFF1A5FCC),
      paddleStroke: Color(0xFF88CCFF),
      brickColors: [
        Color(0xFF00B0FF), // vivid blue
        Color(0xFFFF1744), // vivid red
        Color(0xFFFFD600), // vivid yellow
        Color(0xFF78909C), // dark steel (indestructible)
      ],
      brickStroke: Color(0xFF0A1628),
      brickStrokeWidth: 1.5,
      textPrimary: Color(0xFFE8F0FF),
      textSecondary: Color(0xFF6A8AB0),
      accentColor: Color(0xFF4FC3F7),
      overlayColor: Color(0xCC060912),
      wallColor: Color(0xFF1A2E50),
    ),

    AppTheme.neon: GameThemeData(
      name: 'Neon Grid',
      emoji: '⚡',
      bgTop: Color(0xFF050510),
      bgBottom: Color(0xFF020208),
      ballColor: Color(0xFF00F5FF),
      ballHighlight: Color(0xFFFFFFFF),
      paddleGradientStart: Color(0xFF8B00FF),
      paddleGradientEnd: Color(0xFF4400CC),
      paddleStroke: Color(0xFFCC44FF),
      brickColors: [
        Color(0xFF00E5FF), // vivid cyan
        Color(0xFFD500F9), // vivid magenta
        Color(0xFF76FF03), // vivid green
        Color(0xFF757575), // vivid orange (indestructible)
      ],
      brickStroke: Color(0xFF000000),
      brickStrokeWidth: 1.0,
      textPrimary: Color(0xFF00F5FF),
      textSecondary: Color(0xFF7B6AAA),
      accentColor: Color(0xFFCC44FF),
      overlayColor: Color(0xDD020208),
      wallColor: Color(0xFF1A0033),
    ),

    AppTheme.forest: GameThemeData(
      name: 'Deep Forest',
      emoji: '🌿',
      bgTop: Color(0xFF1A2510),
      bgBottom: Color(0xFF0D1508),
      ballColor: Color(0xFFE8D5A0),
      ballHighlight: Color(0xFFFFF8E0),
      paddleGradientStart: Color(0xFF5C7A3A),
      paddleGradientEnd: Color(0xFF3A5020),
      paddleStroke: Color(0xFF8BAE5A),
      brickColors: [
        Color(0xFF66BB6A), // vivid green
        Color(0xFFFF8F00), // vivid amber
        Color(0xFF8D6E63), // warm brown
        Color(0xFF8D6E63), // dark wood (indestructible)
      ],
      brickStroke: Color(0xFF1A2510),
      brickStrokeWidth: 2.0,
      textPrimary: Color(0xFFD4E8A8),
      textSecondary: Color(0xFF7A9A5A),
      accentColor: Color(0xFFA8CC6A),
      overlayColor: Color(0xCC0D1508),
      wallColor: Color(0xFF243318),
    ),

    AppTheme.candy: GameThemeData(
      name: 'Candy Pop',
      emoji: '🍬',
      bgTop: Color(0xFFFFF0F5),
      bgBottom: Color(0xFFFAE0EC),
      ballColor: Color(0xFFFF6B9D),
      ballHighlight: Color(0xFFFFFFFF),
      paddleGradientStart: Color(0xFFFF85B3),
      paddleGradientEnd: Color(0xFFFF4D8A),
      paddleStroke: Color(0xFFFFB3CC),
      brickColors: [
        Color(0xFFFF4081), // vivid pink
        Color(0xFF40C4FF), // vivid blue
        Color(0xFFFFD740), // vivid yellow
        Color(0xFFB0BEC5), // lavender (indestructible)
      ],
      brickStroke: Color(0xFFFFFFFF),
      brickStrokeWidth: 2.0,
      textPrimary: Color(0xFF5A2A42),
      textSecondary: Color(0xFFAA6080),
      accentColor: Color(0xFFFF4D8A),
      overlayColor: Color(0xCCFAE0EC),
      wallColor: Color(0xFFFFD6E8),
    ),
  };

  static GameThemeData get(AppTheme theme) => themes[theme]!;
}
