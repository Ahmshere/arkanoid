import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../data/score_repository.dart';
import '../data/progress_repository.dart';
import '../game/arkanoid_game.dart';
import '../game/powerup.dart';
import '../theme/theme_notifier.dart';
import '../services/ad_manager.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.startLevel = 1});
  final int startLevel;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

// Score pop-up data item
class _ScorePop {
  final int pts;
  final double x;
  final double y;
  final int combo;
  double opacity;
  double dy;          // accumulated upward drift
  double lifetime;    // seconds remaining
  _ScorePop({required this.pts, required this.x, required this.y, required this.combo})
      : opacity = 1.0, dy = 0, lifetime = 1.1;
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late ArkanoidGame _game;
  int _score = 0;
  int _lives = 3;
  int _bossHp = 0;
  PowerUpType? _activePowerUp;
  bool _showGameOver = false;
  bool _showLevelBanner = false;
  bool _isBossDefeat = false;
  int _combo = 0; // текущий комбо для HUD
  List<({String label, int pts})> _bonuses = [];
  bool _showPhase2Flash = false; // кратковременный флеш при Phase 2

  // Screen shake
  late AnimationController _shakeAnim;
  double _shakeIntensity = 0;
  final _shakeRng = Random();
  Offset _shakeOffset = Offset.zero;

  final List<_ScorePop> _popups = [];
  DateTime _lastPopTick = DateTime.now();
  Ticker? _popTicker; // тикер для анимации поп-апов

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _shakeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
      if (!mounted) return;
      final t = 1.0 - _shakeAnim.value; // decay
      if (t > 0) {
        _shakeOffset = Offset(
          (_shakeRng.nextDouble() - 0.5) * _shakeIntensity * t,
          (_shakeRng.nextDouble() - 0.5) * _shakeIntensity * t,
        );
      } else {
        _shakeOffset = Offset.zero;
      }
      setState(() {});
    });

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
    _subs.add(_game.onScorePopStream.listen((e) {
      if (!mounted) return;
      setState(() {
        _combo = e.combo;
        _popups.add(_ScorePop(pts: e.pts, x: e.x, y: e.y, combo: e.combo));
      });
      _startPopTicker(); // запускаем анимационный тикер
    }));
    _subs.add(_game.onShakeStream.listen((intensity) {
      if (!mounted) return;
      _shakeIntensity = intensity;
      _shakeAnim.forward(from: 0);
    }));
    _subs.add(_game.onBonusStream.listen((b) {
      if (mounted) setState(() => _bonuses = b);
    }));
    _subs.add(_game.onBossPhaseStream.listen((phase) {
      if (!mounted) return;
      setState(() => _showPhase2Flash = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showPhase2Flash = false);
      });
    }));
  }

  void _startPopTicker() {
    if (_popTicker != null) return; // уже запущен
    _lastPopTick = DateTime.now();
    _popTicker = createTicker((_) {
      if (!mounted) return;
      final now = DateTime.now();
      final dt = now.difference(_lastPopTick).inMicroseconds / 1e6;
      _lastPopTick = now;
      setState(() {
        _popups.removeWhere((p) {
          p.dy += 60 * dt;
          p.lifetime -= dt;
          p.opacity = (p.lifetime / 0.6).clamp(0.0, 1.0);
          return p.lifetime <= 0;
        });
      });
      if (_popups.isEmpty) {
        _popTicker?.stop();
        _popTicker?.dispose();
        _popTicker = null;
      }
    })..start();
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _shakeAnim.dispose();
    _popTicker?.stop();
    _popTicker?.dispose();
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
      setState(() { _showLevelBanner = false; _bonuses = []; });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _game.advanceLevel();
      });
    });
  }

  void _handleContinueAd() {
    AdManager.instance.showRewarded(
      onRewarded: () {
        if (!mounted) return;
        setState(() => _showGameOver = false);
        _game.continueAfterAd();
      },
      onNoAd: () {
        // Реклама не загрузилась — разрешаем Continue бесплатно
        if (!mounted) return;
        setState(() => _showGameOver = false);
        _game.continueAfterAd();
      },
    );
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
              Transform.translate(
                offset: _shakeOffset,
                child: GameWidget(game: _game),
              ),

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
                  combo: _combo,
                ),
              ),

              // Score pop-up overlay
              if (_popups.isNotEmpty) ...[
                ..._popups.map((p) => Positioned(
                  left: p.x - 28,
                  top: p.y - p.dy - 16,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: p.opacity.clamp(0.0, 1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p.combo >= 2)
                            Text(
                              '×${p.combo}',
                              style: TextStyle(
                                color: p.combo >= 3
                                    ? const Color(0xFFFF6D00)
                                    : const Color(0xFFFFCC00),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                shadows: const [Shadow(color: Colors.black54, offset: Offset(1,1))],
                              ),
                            ),
                          Text(
                            '+${p.pts}',
                            style: TextStyle(
                              color: p.combo >= 3
                                  ? const Color(0xFFFF6D00)
                                  : p.combo >= 2
                                      ? const Color(0xFFFFCC00)
                                      : Colors.white,
                              fontSize: p.combo >= 2 ? 15 : 13,
                              fontWeight: FontWeight.w800,
                              shadows: const [Shadow(color: Colors.black54, offset: Offset(1,1))],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
              ],

              if (!_showGameOver && !_showLevelBanner)
                _LaunchHint(game: _game, theme: t),

              if (_showLevelBanner)
                _LevelBanner(
                  level: _game.currentLevel,
                  theme: t,
                  isBossDefeat: _isBossDefeat,
                  bossName: _game.bossName,
                  bonuses: _bonuses,
                ),

              // Phase 2 flash overlay
              if (_showPhase2Flash)
                IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 0.0),
                    duration: const Duration(milliseconds: 1800),
                    builder: (_, v, __) => Container(
                      color: const Color(0xFFFF1744).withOpacity(v * 0.3),
                      child: Center(
                        child: Opacity(
                          opacity: (v * 2).clamp(0.0, 1.0),
                          child: const Text(
                            '⚠ PHASE 2 ⚠',
                            style: TextStyle(
                              color: Color(0xFFFF1744),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
  final int score, lives, level, combo;
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
    this.combo = 0,
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
                  Row(
                    children: [
                      Text('SCORE',
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600)),
                      if (combo >= 2) ...[
                        const SizedBox(width: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            key: ValueKey(combo),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: combo >= 3
                                  ? const Color(0xFFFF6D00)
                                  : const Color(0xFFFFCC00),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '×$combo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
              _HeartsRow(lives: lives),
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

// ── Animated hearts row ───────────────────────────────────────────────────────

class _HeartsRow extends StatefulWidget {
  final int lives;
  const _HeartsRow({required this.lives});

  @override
  State<_HeartsRow> createState() => _HeartsRowState();
}

class _HeartsRowState extends State<_HeartsRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.5)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.5, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_HeartsRow old) {
    super.didUpdateWidget(old);
    if (widget.lives != old.lives) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          if (i >= widget.lives) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Transform.scale(
              scale: _scale.value,
              child: const Icon(
                Icons.favorite_rounded,
                size: 16,
                color: Color(0xFFE53935),
              ),
            ),
          );
        }),
      ),
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

class _LevelBanner extends StatefulWidget {
  final int level;
  final dynamic theme;
  final bool isBossDefeat;
  final String bossName;
  final List<({String label, int pts})> bonuses;

  const _LevelBanner({
    required this.level,
    required this.theme,
    this.isBossDefeat = false,
    this.bossName = '',
    this.bonuses = const [],
  });

  @override
  State<_LevelBanner> createState() => _LevelBannerState();
}

class _LevelBannerState extends State<_LevelBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween(begin: 0.80, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _glow  = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0)));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final glowColor = widget.isBossDefeat
        ? const Color(0xFFFF4444)
        : t.accentColor as Color;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (t.bgTop as Color).withOpacity(0.92),
              (t.bgBottom as Color).withOpacity(0.96),
            ],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, child) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(_glow.value * 0.55),
                      blurRadius: _glow.value * 48,
                      spreadRadius: _glow.value * 8,
                    ),
                  ],
                ),
                child: child,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...(widget.isBossDefeat
                    ? [
                        Text('☠  BOSS DEFEATED  ☠',
                            style: TextStyle(
                                color: glowColor,
                                fontSize: 14,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(widget.bossName,
                            style: TextStyle(
                                color: glowColor,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(color: glowColor.withOpacity(0.7),
                                      blurRadius: 20),
                                ])),
                      ]
                    : [
                        Text('LEVEL CLEAR!',
                            style: TextStyle(
                                color: glowColor,
                                fontSize: 14,
                                letterSpacing: 5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('LEVEL ${widget.level}',
                            style: TextStyle(
                                color: t.textPrimary as Color,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(color: glowColor.withOpacity(0.6),
                                      blurRadius: 20),
                                ])),
                      ]),
                  // Бонусы
                  if (widget.bonuses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...widget.bonuses.map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.label,
                              style: TextStyle(
                                  color: glowColor,
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('+${b.pts}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
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
