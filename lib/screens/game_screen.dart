import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../data/score_repository.dart';
import '../data/progress_repository.dart';
import '../game/arkanoid_game.dart';
import '../game/powerup.dart';
import '../theme/theme_notifier.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.startLevel = 1});
  final int startLevel;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ArkanoidGame _game;
  int _score = 0;
  int _lives = 3;
  int _bossHp = 0;
  PowerUpType? _activePowerUp;
  bool _showGameOver = false;
  bool _showLevelBanner = false;
  bool _isBossDefeat = false;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _game = ArkanoidGame(
      onGameOver: () {},
      onLevelComplete: () {},
      onScoreUpdate: (_) {},
      onPowerUpChanged: (_) {},
      startLevel: widget.startLevel,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeToGame());
  }

  void _subscribeToGame() {
    debugPrint('[ARKANOID UI] subscribing to game streams');
    _subs.add(_game.onLevelCompleteStream.listen((_) {
      debugPrint('[ARKANOID UI] received level complete event');
      _onLevelComplete();
    }));
    _subs.add(_game.onGameOverStream.listen((_) => _onGameOver()));
    _subs.add(_game.onScoreStream.listen((s) {
      if (mounted) setState(() => _score = s);
    }));
    _subs.add(_game.onLivesStream.listen((l) {
      if (mounted) setState(() => _lives = l);
    }));
    _subs.add(_game.onPowerUpStream.listen((t) {
      if (mounted) setState(() => _activePowerUp = t);
    }));
    _subs.add(_game.onBossHpStream.listen((hp) {
      if (mounted) setState(() => _bossHp = hp);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  void _onGameOver() {
    if (!mounted) return;
    ScoreRepository.instance.addScore(_score, _game.currentLevel).then((_) {
      ProgressRepository.instance.onScoreAdded(
          ScoreRepository.instance.bestScore);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showGameOver = true);
    });
  }

  void _onLevelComplete() {
    debugPrint('[ARKANOID UI] _onLevelComplete called, mounted=$mounted');
    if (!mounted) return;
    setState(() {
      _showLevelBanner = true;
      _isBossDefeat = _game.justDefeatedBoss;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _showLevelBanner = false);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _game.advanceLevel();
      });
    });
  }

  void _handleContinueAd() {
    setState(() => _showGameOver = false);
    _game.continueAfterAd();
  }

  void _handleRestart() {
    setState(() {
      _showGameOver = false;
      _score = 0;
      _lives = 3;
      _activePowerUp = null;
    });
    _game.restartGame();
  }

  void _handleMenu() {
    ScoreRepository.instance.addScore(_score, _game.currentLevel).then((_) {
      ProgressRepository.instance.onScoreAdded(ScoreRepository.instance.bestScore);
    });
    Navigator.of(context).pop();
  }

  Future<void> _onBackPressed() async {
    _game.pauseGame();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => _ExitConfirmDialog(theme: themeNotifier.current),
    );
    if (confirmed == true) {
      if (mounted) {
        ScoreRepository.instance.addScore(_score, _game.currentLevel).then((_) {
          ProgressRepository.instance.onScoreAdded(ScoreRepository.instance.bestScore);
        });
        Navigator.of(context).pop();
      }
    } else {
      _game.resumeGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeNotifier,
      builder: (_, __, ___) {
        final t = themeNotifier.current;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (_, __) => _onBackPressed(),
          child: Scaffold(
          backgroundColor: Color(t.bgBottom.value),
          body: Stack(
            children: [
              GameWidget(game: _game),

              SafeArea(
                child: _HUD(
                  score: _score,
                  lives: _lives,
                  level: _game.currentLevel,
                  activePowerUp: _activePowerUp,
                  theme: t,
                  onPause: () { _game.pauseGame(); _showPauseDialog(); },
                  isBossLevel: _game.isBossLevel,
                  bossHp: _bossHp,
                  bossMaxHp: _game.bossMaxHp,
                  bossName: _game.bossName,
                ),
              ),

              if (!_showGameOver && !_showLevelBanner)
                _LaunchHint(game: _game, theme: t),

              if (_showLevelBanner)
                _LevelBanner(
                  level: _game.currentLevel,
                  theme: t,
                  isBossDefeat: _isBossDefeat,
                  bossName: _game.bossName,
                ),

              if (_showGameOver)
                GameOverScreen(
                  score: _score,
                  level: _game.currentLevel,
                  theme: t,
                  onContinueAd: _handleContinueAd,
                  onRestart: _handleRestart,
                  onMenu: _handleMenu,
                ),
            ],
          ),
          ),
        );
      },
    );
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) => const _PauseDialog(),
    ).then((_) {
      if (_game.state == GameState.paused) _game.resumeGame();
    });
  }
}

// ── HUD ───────────────────────────────────────────────────────────────────────

class _HUD extends StatelessWidget {
  final int score, lives, level;
  final PowerUpType? activePowerUp;
  final dynamic theme;
  final VoidCallback onPause;
  final bool isBossLevel;
  final int bossHp, bossMaxHp;
  final String bossName;

  const _HUD({
    required this.score,
    required this.lives,
    required this.level,
    required this.activePowerUp,
    required this.theme,
    required this.onPause,
    this.isBossLevel = false,
    this.bossHp = 0,
    this.bossMaxHp = 0,
    this.bossName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SCORE',
                      style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600)),
                  Text('$score',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const Spacer(),
              Column(
                children: [
                  Text('LVL',
                      style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600)),
                  Text('$level',
                      style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const Spacer(),
              Row(
                children: List.generate(3, (i) => i < lives
                    ? Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(Icons.favorite_rounded,
                            size: 16, color: theme.accentColor))
                    : const SizedBox.shrink()),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onPause,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.wallColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pause_rounded,
                      color: theme.textSecondary, size: 20),
                ),
              ),
            ],
          ),
        ),
        if (isBossLevel && bossMaxHp > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Text(
                  bossName,
                  style: const TextStyle(
                    color: Color(0xFFFF4444),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: bossMaxHp > 0 ? bossHp / bossMaxHp : 0,
                      backgroundColor: const Color(0xFFFF4444).withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4444)),
                      minHeight: 7,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$bossHp',
                  style: const TextStyle(
                    color: Color(0xFFFF4444),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        if (activePowerUp != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(activePowerUp),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: activePowerUp!.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: activePowerUp!.color.withOpacity(0.6), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activePowerUp!.isPositive
                        ? Icons.bolt_rounded
                        : Icons.warning_amber_rounded,
                    color: activePowerUp!.color,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(activePowerUp!.label,
                      style: TextStyle(
                          color: activePowerUp!.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Launch hint ───────────────────────────────────────────────────────────────

class _LaunchHint extends StatelessWidget {
  final ArkanoidGame game;
  final dynamic theme;
  const _LaunchHint({required this.game, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (game.state != GameState.waitingToLaunch) return const SizedBox.shrink();
    return Positioned(
      bottom: 110,
      left: 0, right: 0,
      child: Center(
        child: Text('TAP TO LAUNCH',
            style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Level banner ──────────────────────────────────────────────────────────────

class _LevelBanner extends StatelessWidget {
  final int level;
  final dynamic theme;
  final bool isBossDefeat;
  final String bossName;

  const _LevelBanner({
    required this.level,
    required this.theme,
    this.isBossDefeat = false,
    this.bossName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.overlayColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: isBossDefeat
              ? [
                  const Text('☠  BOSS DEFEATED  ☠',
                      style: TextStyle(
                          color: Color(0xFFFF4444),
                          fontSize: 14,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(bossName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4)),
                ]
              : [
                  Text('LEVEL CLEAR!',
                      style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 14,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('LEVEL $level',
                      style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                ],
        ),
      ),
    );
  }
}

// ── Pause Dialog ──────────────────────────────────────────────────────────────

class _PauseDialog extends StatelessWidget {
  const _PauseDialog();

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.current;
    return Material(
      color: Colors.transparent,
      child: Container(
        color: t.overlayColor,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            decoration: BoxDecoration(
              color: t.bgTop,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.accentColor.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: t.wallColor.withOpacity(0.4),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.pause_circle_filled_rounded,
                          color: t.accentColor, size: 36),
                      const SizedBox(height: 8),
                      Text('PAUSED',
                          style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _DialogBtn(
                        label: 'RESUME',
                        icon: Icons.play_arrow_rounded,
                        isPrimary: true,
                        theme: t,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 12),
                      _DialogBtn(
                        label: 'MAIN MENU',
                        icon: Icons.home_rounded,
                        isPrimary: false,
                        theme: t,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final dynamic theme;
  final VoidCallback onTap;
  const _DialogBtn({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.theme,
    required this.onTap,
  });
  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.isPrimary
        ? widget.theme.accentColor as Color
        : widget.theme.textSecondary as Color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.isPrimary ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(widget.isPrimary ? 0.8 : 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(widget.label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Exit confirmation dialog ──────────────────────────────────────────────────

class _ExitConfirmDialog extends StatelessWidget {
  final dynamic theme;
  const _ExitConfirmDialog({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Material(
      color: Colors.transparent,
      child: Container(
        color: (t.overlayColor as Color).withOpacity(0.85),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: t.bgTop,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: (t.accentColor as Color).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4), blurRadius: 32),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.exit_to_app_rounded,
                      color: t.accentColor, size: 32),
                  const SizedBox(height: 12),
                  Text('QUIT GAME?',
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3)),
                  const SizedBox(height: 6),
                  Text('Your score will be saved',
                      style: TextStyle(
                          color: t.textSecondary, fontSize: 12)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _ConfirmBtn(
                          label: 'STAY',
                          isPrimary: true,
                          theme: t,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ConfirmBtn(
                          label: 'QUIT',
                          isPrimary: false,
                          theme: t,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmBtn extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final dynamic theme;
  final VoidCallback onTap;
  const _ConfirmBtn(
      {required this.label,
      required this.isPrimary,
      required this.theme,
      required this.onTap});
  @override
  State<_ConfirmBtn> createState() => _ConfirmBtnState();
}

class _ConfirmBtnState extends State<_ConfirmBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.isPrimary
        ? widget.theme.accentColor as Color
        : (widget.theme.textSecondary as Color).withOpacity(0.7);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? color.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(widget.isPrimary ? 0.8 : 0.4),
                width: 1.5),
          ),
          child: Center(
            child: Text(widget.label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ),
        ),
      ),
    );
  }
}
