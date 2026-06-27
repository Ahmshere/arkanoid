import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ball.dart';
import 'background.dart';
import 'boss_builder.dart';
import 'brick.dart';
import 'enemy_bullet.dart';
import 'enemy_creature.dart';
import 'explosion_effect.dart';
import 'paddle.dart';
import 'powerup.dart';
import 'level_builder.dart';
import '../theme/theme_notifier.dart';

enum GameState { waitingToLaunch, playing, levelComplete, gameOver, paused }

class _ActiveEffect {
  final PowerUpType type;
  double remaining;
  _ActiveEffect(this.type, this.remaining);
}

class ArkanoidGame extends FlameGame with PanDetector, TapCallbacks {
  final VoidCallback onGameOver;
  final VoidCallback onLevelComplete;
  final Function(int score) onScoreUpdate;
  final Function(PowerUpType? type) onPowerUpChanged;

  // StreamControllers для безопасного общения с Flutter UI
  final _levelCompleteCtrl = StreamController<void>.broadcast();
  final _gameOverCtrl = StreamController<void>.broadcast();
  final _scoreCtrl = StreamController<int>.broadcast();
  final _livesCtrl = StreamController<int>.broadcast();
  final _powerUpCtrl = StreamController<PowerUpType?>.broadcast();
  final _bossHpCtrl = StreamController<int>.broadcast();
  final _scorePopCtrl = StreamController<({int pts, double x, double y, int combo})>.broadcast();
  final _shakeCtrl = StreamController<double>.broadcast(); // intensity
  final _bonusCtrl = StreamController<List<({String label, int pts})>>.broadcast();
  final _bossPhaseCtrl = StreamController<int>.broadcast(); // эмитит 2 при активации Phase 2

  Stream<void> get onLevelCompleteStream => _levelCompleteCtrl.stream;
  Stream<void> get onGameOverStream => _gameOverCtrl.stream;
  Stream<int> get onScoreStream => _scoreCtrl.stream;
  Stream<int> get onLivesStream => _livesCtrl.stream;
  Stream<PowerUpType?> get onPowerUpStream => _powerUpCtrl.stream;
  Stream<int> get onBossHpStream => _bossHpCtrl.stream;
  Stream<({int pts, double x, double y, int combo})> get onScorePopStream => _scorePopCtrl.stream;
  Stream<double> get onShakeStream => _shakeCtrl.stream;
  Stream<List<({String label, int pts})>> get onBonusStream => _bonusCtrl.stream;
  Stream<int> get onBossPhaseStream => _bossPhaseCtrl.stream;

  ArkanoidGame({
    required this.onGameOver,
    required this.onLevelComplete,
    required this.onScoreUpdate,
    required this.onPowerUpChanged,
    this.startLevel = 1,
  });

  final int startLevel;

  late Ball ball;
  late Paddle paddle;
  late BackgroundLayer _bg;
  bool _bgInitialized = false;

  final List<Brick> bricks = [];
  final List<FallingPowerUp> _powerUps = [];
  final List<_ActiveEffect> _effects = [];
  final Random _rng = Random();

  // Дополнительные шары (тройной бонус)
  final List<Ball> _extraBalls = [];
  bool _tripleBallUnlocked = false;

  // Система боссов
  int _bossCount = 0; // сколько боссов уже было побеждено
  bool _isBossLevel = false;
  bool justDefeatedBoss = false;
  int _bossHp = 0;
  int _bossMaxHp = 0;
  int _bossIndex = 0;
  String _bossName = '';
  double _bulletTimer = 0;
  double _bulletInterval = 2.5;
  final List<EnemyBullet> _bullets = [];

  // Движение блока босса (синусоида влево-вправо)
  BossMovement? _bossMovement;
  double _bossOffsetPhase = 0.0; // текущая фаза синусоиды (радианы)
  double _bossOffsetX = 0.0;     // текущий сдвиг от исходных позиций (px)

  // Flying creatures (level 4+)
  final List<EnemyCreature> _creatures = [];
  final List<CreatureBullet> _creatureBullets = [];

  // Visual explosion effects
  final List<ExplosionEffect> _explosions = [];

  // ── Новые бонусы ─────────────────────────────────────────────────────────
  final List<_LaserBeam> _laserBeams = [];
  int _mineBallHits = 0; // оставшиеся мины
  double _shieldGlow = 0.0; // пульсация щита

  bool get _laserActive  => _effects.any((e) => e.type == PowerUpType.laser);
  bool get _shieldActive => _effects.any((e) => e.type == PowerUpType.shield);
  bool get _ghostActive  => _effects.any((e) => e.type == PowerUpType.ghostBall);
  bool get _stickyActive => _effects.any((e) => e.type == PowerUpType.stickyBall);

  /// Все активные шары (основной + дополнительные).
  List<Ball> get _allBalls => [ball, ..._extraBalls];

  bool get isBossLevel => _isBossLevel;
  String get bossName => _bossName;
  int get bossMaxHp => _bossMaxHp;
  int get bossHp => _bossHp;

  int score = 0;
  int lives = 3;
  late int currentLevel = startLevel.clamp(1, maxLevels);
  int _destructibleTotal = 0;
  int _destroyedCount = 0;
  int _comboCount = 0; // сброс при потере шара
  bool _processingBallLost = false;
  double _autoLaunchTimer = 0.0; // автостарт через 60 сек
  DateTime _levelStartTime = DateTime.now();
  int _livesAtLevelStart = 3;
  bool _bossInPhase2 = false;
  bool _fireballDropped = false;
  bool _iceballDropped = false;

  // Stuck-ball rescue: counts consecutive frames where ball overlaps a brick.
  // A ball that truly can't escape a brick will stay overlapping for many frames.
  // A ball bouncing normally exits the brick within 1 frame (collision correction).
  int _stuckInBrickFrames = 0;
  static const int _stuckFrameThreshold = 45; // ~1.5s at 30fps

  // Per-frame jump detector — catches unexpected teleports
  Vector2 _prevFrameBallPos = Vector2.zero();

  GameState state = GameState.waitingToLaunch;
  Vector2 get gameSize => size;
  static int get maxLevels => LevelBuilder.levelCount;

  @override
  Color backgroundColor() => themeNotifier.current.bgBottom;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_bgInitialized) _bg.onResize(size);
  }

  @override
  Future<void> onLoad() async {
    _bg = BackgroundLayer(size);
    _bgInitialized = true;
    await _setupLevel();
  }

  // ── Level setup ───────────────────────────────────────────────────────────

  Future<void> _setupLevel() async {
    _processingBallLost = false;
    _clearEffectsImmediate();

    for (final b in bricks) { if (b.isMounted) remove(b); }
    bricks.clear();
    _powerUps.clear();
    _bullets.clear();
    _creatures.clear();
    _creatureBullets.clear();
    for (final eb in _extraBalls) { if (eb.isMounted) remove(eb); }
    _extraBalls.clear();

    for (final c in children.whereType<Ball>().toList()) remove(c);
    for (final c in children.whereType<Paddle>().toList()) remove(c);

    _isBossLevel = false;
    _bossMovement = null;
    _bossOffsetPhase = 0.0;
    _bossOffsetX = 0.0;
    _bossInPhase2 = false;
    _comboCount = 0;
    _levelStartTime = DateTime.now();
    _livesAtLevelStart = lives;

    await Future.delayed(Duration.zero);

    if (_bgInitialized) _bg.onResize(size);

    final newBricks = LevelBuilder.buildLevel(currentLevel, size);
    _destructibleTotal = LevelBuilder.destructibleCount(newBricks);
    _destroyedCount = 0;
    _fireballDropped = false;
    _iceballDropped = false;
    _stuckInBrickFrames = 0;
    debugPrint('[ARKANOID] Level $currentLevel built. Total bricks: ${newBricks.length}, destructible: $_destructibleTotal');

    for (final brick in newBricks) { bricks.add(brick); add(brick); }

    paddle = Paddle();
    final centerX = size.x / 2;
    paddle.position = Vector2(centerX, size.y - Paddle.bottomMargin);
    paddle.snapTo(centerX);
    add(paddle);

    ball = Ball();
    add(ball);
    _resetBallToPaddle();

    // Spawn creatures on level 4+
    _spawnCreatures();

    state = GameState.waitingToLaunch;
  }

  Future<void> _setupBossLevel() async {
    _processingBallLost = false;
    _clearEffectsImmediate();

    for (final b in bricks) { if (b.isMounted) remove(b); }
    bricks.clear();
    _powerUps.clear();
    _bullets.clear();
    _creatures.clear();
    _creatureBullets.clear();
    for (final eb in _extraBalls) { if (eb.isMounted) remove(eb); }
    _extraBalls.clear();

    for (final c in children.whereType<Ball>().toList()) remove(c);
    for (final c in children.whereType<Paddle>().toList()) remove(c);

    await Future.delayed(Duration.zero);

    if (_bgInitialized) _bg.onResize(size);

    final data = BossBuilder.dataFor(_bossIndex);
    _bossName = data.name;
    _bulletInterval = data.bulletInterval;
    _bulletTimer = data.bulletInterval;
    _isBossLevel = true;
    _bossInPhase2 = false;
    _comboCount = 0;
    _destroyedCount = 0;
    _fireballDropped = false;
    _iceballDropped = false;
    _bossMovement = data.movement;
    _bossOffsetPhase = 0.0;
    _bossOffsetX = 0.0;
    _levelStartTime = DateTime.now();
    _livesAtLevelStart = lives;

    final newBricks = BossBuilder.buildBoss(_bossIndex, size);
    // HP = кол-во разрушаемых кирпичей в паттерне (H/M/L/D)
    _bossMaxHp = LevelBuilder.destructibleCount(newBricks);
    _bossHp = _bossMaxHp;
    _bossHpCtrl.add(_bossHp);

    debugPrint('[ARKANOID] Boss level: $_bossName, HP: $_bossMaxHp (from ${newBricks.length} bricks), bulletInterval: $_bulletInterval');

    for (final brick in newBricks) { bricks.add(brick); add(brick); }

    paddle = Paddle();
    final centerX = size.x / 2;
    paddle.position = Vector2(centerX, size.y - Paddle.bottomMargin);
    paddle.snapTo(centerX);
    add(paddle);

    ball = Ball();
    add(ball);
    _resetBallToPaddle();

    state = GameState.waitingToLaunch;
  }

  void _resetBallToPaddle() {
    _autoLaunchTimer = 0.0;
    ball.resetTo(Vector2(paddle.centerX, paddle.top - Ball.ballRadius - 2));
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent info) {
    if (state == GameState.waitingToLaunch) {
      ball.clearMagnet();
      ball.launch();
      state = GameState.playing;
    } else if (state == GameState.playing && _laserActive) {
      _shootLaser();
    }
  }

  void _shootLaser() {
    final px = paddle.position.x;
    final py = paddle.position.y;
    final pw = paddle.size.x;
    // Два луча: левее и правее центра
    _laserBeams.add(_LaserBeam(px + pw * 0.28, py - 4));
    _laserBeams.add(_LaserBeam(px + pw * 0.72, py - 4));
    HapticFeedback.selectionClick();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    paddle.moveTo(info.eventPosition.global.x);
    if (state == GameState.waitingToLaunch) _resetBallToPaddle();
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    // Cap dt to 33ms: prevents ball tunneling when Android drops frame rate
    // (e.g. after touch-boost timeout: "high hint" → "no preference")
    dt = dt.clamp(0.0, 1 / 30.0);

    if (_bgInitialized) _bg.update(dt);

    super.update(dt);

    // Взрывы всегда обновляются — даже после levelComplete/bossDefeated,
    // чтобы анимация доигрывала до конца.
    for (int i = _explosions.length - 1; i >= 0; i--) {
      _explosions[i].update(dt);
      if (_explosions[i].isDone) _explosions.removeAt(i);
    }

    if (state == GameState.paused ||
        state == GameState.gameOver ||
        state == GameState.levelComplete) {
      return;
    }

    // Автостарт: если шар лежит на ракетке 60 секунд — запускаем автоматически
    if (state == GameState.waitingToLaunch) {
      _autoLaunchTimer += dt;
      if (_autoLaunchTimer >= 60.0) {
        _autoLaunchTimer = 0.0;
        ball.clearMagnet();
        ball.launch();
        state = GameState.playing;
      }
    } else {
      _autoLaunchTimer = 0.0;
    }

    _tickEffects(dt);

    // Обновляем падающие бонусы
    for (final pu in _powerUps) pu.update(dt);

    // Боссовые снаряды — спавним и обновляем
    if (_isBossLevel && state == GameState.playing) {
      // Проверяем переход в Phase 2 (при HP ≤ 50%)
      if (!_bossInPhase2 && _bossMaxHp > 0 && _bossHp <= _bossMaxHp ~/ 2) {
        _bossInPhase2 = true;
        final def = BossBuilder.dataFor(_bossIndex);
        if (def.phase2BulletInterval != null) _bulletInterval = def.phase2BulletInterval!;
        if (def.phase2Movement != null) _bossMovement = def.phase2Movement!;
        _shakeCtrl.add(5.0); // небольшой shake при переходе
        scheduleMicrotask(() => _bossPhaseCtrl.add(2));
        debugPrint('[ARKANOID] Boss Phase 2! interval=$_bulletInterval');
      }

      _bulletTimer -= dt;
      if (_bulletTimer <= 0) {
        _bulletTimer = _bulletInterval;
        _spawnBossBullet();
      }
    }
    for (int i = _bullets.length - 1; i >= 0; i--) {
      _bullets[i].update(dt);
      if (_bullets[i].y > size.y) {
        // Пролетел мимо — просто исчезает
        _bullets.removeAt(i);
      } else if (_bullets[i].rect.overlaps(paddle.toAbsoluteRect())) {
        // Прямое попадание в ракетку — потеря жизни
        _bullets.removeAt(i);
        _bossBulletReachedBottom();
      }
    }

    // Движение блока босса (синусоида влево-вправо)
    if (_isBossLevel && state == GameState.playing) {
      final mv = _bossMovement;
      if (mv != null && bricks.isNotEmpty) {
        _bossOffsetPhase += dt * mv.speed * 2 * pi;
        final newOffsetX = sin(_bossOffsetPhase) * mv.amplitude;
        final delta = newOffsetX - _bossOffsetX;
        _bossOffsetX = newOffsetX;
        for (final brick in bricks) {
          brick.position.x += delta;
        }
      }
    }

    // Летающие существа + их снаряды
    // Двигаются и при waitingToLaunch (магнит поймал мяч) — не должны замирать
    if (!_isBossLevel &&
        (state == GameState.playing || state == GameState.waitingToLaunch)) {
      for (final c in _creatures) c.update(dt, size.x, _creatureBullets);
    }
    for (int i = _creatureBullets.length - 1; i >= 0; i--) {
      _creatureBullets[i].update(dt);
      if (_creatureBullets[i].y > size.y) {
        // Пролетел мимо ракетки — просто исчезает, жизнь не снимается
        _creatureBullets.removeAt(i);
      } else if (_creatureBullets[i].rect.overlaps(paddle.toAbsoluteRect())) {
        // Прямое попадание в ракетку — жизнь снимается
        _creatureBullets.removeAt(i);
        _bossBulletReachedBottom();
      }
    }

    // Дополнительные шары (тройной бонус)
    for (int i = _extraBalls.length - 1; i >= 0; i--) {
      final eb = _extraBalls[i];
      if (!eb.isLaunched) {
        if (eb.isMounted) remove(eb);
        _extraBalls.removeAt(i);
        continue;
      }
      _checkBallPaddleCollision(eb);
      _checkBallBrickCollisions(eb);
      if (_isBossLevel) _checkBulletCollisions(eb);
      _checkCreatureCollisions(eb);
      _checkCreatureBulletCollisions(eb);
    }

    // Основной шар
    _checkBallPaddleCollision(ball);
    _checkBallBrickCollisions(ball);
    if (_isBossLevel) _checkBulletCollisions(ball);
    _checkCreatureCollisions(ball);
    _checkCreatureBulletCollisions(ball);

    _checkPowerUpCollisions();
    _updateLaserBeams(dt);
    _updateShield(dt);
    _checkStuckBall(dt);
    _detectBallJump();
  }

  // ── Лазер ────────────────────────────────────────────────────────────────

  void _updateLaserBeams(double dt) {
    for (int i = _laserBeams.length - 1; i >= 0; i--) {
      _laserBeams[i].update(dt);
      if (_laserBeams[i].y < -40) { _laserBeams.removeAt(i); continue; }
      bool hit = false;
      final lRect = _laserBeams[i].rect;
      for (int j = bricks.length - 1; j >= 0; j--) {
        if (j >= bricks.length) break;
        final brick = bricks[j];
        if (!brick.isMounted) continue;
        if (!lRect.overlaps(brick.toAbsoluteRect())) continue;
        if (!brick.isDestructible) { hit = true; break; } // отражается от X
        final px = brick.position.x + brick.size.x / 2;
        final py = brick.position.y + brick.size.y / 2;
        final wasDynamite = brick.isDynamite;
        final destroyed = brick.hit();
        if (destroyed) {
          _maybeDrop(brick);
          remove(brick); bricks.removeAt(j); _destroyedCount++;
          _addScore(brick.pointValue, popX: px, popY: py);
          if (_onBrickKilled()) return;
          if (wasDynamite) _handleDynamiteExplosion(brick);
        } else {
          _explosions.add(ExplosionEffect(px, py));
        }
        hit = true;
        break;
      }
      if (hit) _laserBeams.removeAt(i);
    }
  }

  // ── Щит ──────────────────────────────────────────────────────────────────

  void _updateShield(double dt) {
    _shieldGlow += dt * 4.0;
    if (!_shieldActive) return;
    final shieldY = size.y - 18.0;
    for (final b in _allBalls) {
      if (!b.isLaunched || b.isMagnetized) continue;
      if (b.position.y + b.radius >= shieldY && b.velocity.y > 0) {
        b.velocity.y = -b.velocity.y.abs();
        b.position.y = shieldY - b.radius - 1;
        HapticFeedback.lightImpact();
      }
    }
  }

  /// Frame-count based stuck-ball rescue.
  /// Counts consecutive frames where the ball still overlaps a brick AFTER
  /// collision correction. A normally bouncing ball is pushed to the brick
  /// surface within one frame, so this counter stays at 0. A ball truly
  /// trapped inside a brick (collision can't push it out) will accumulate
  /// frames and trigger a rescue after [_stuckFrameThreshold] frames (~1.5s).
  void _checkStuckBall(double dt) {
    if (!ball.isLaunched || ball.isMagnetized) {
      _stuckInBrickFrames = 0;
      return;
    }

    // Deflate by 1px so floating-point "touching" rects don't count as overlap.
    final bRect = ball.toAbsoluteRect().deflate(1.0);
    final overlapsBrick = bricks.any(
      (br) => br.isMounted && bRect.overlaps(br.toAbsoluteRect()),
    );

    if (!overlapsBrick) {
      if (_stuckInBrickFrames > 0) {
        debugPrint('[STUCK] exited brick after $_stuckInBrickFrames frames');
      }
      _stuckInBrickFrames = 0;
      return;
    }

    _stuckInBrickFrames++;
    // Log only at milestones to avoid spam
    if (_stuckInBrickFrames == 1 || _stuckInBrickFrames % 15 == 0) {
      debugPrint('[STUCK] inside brick: $_stuckInBrickFrames frames '
          'ball=(${ball.position.x.toInt()},${ball.position.y.toInt()}) '
          'r=${ball.radius.toStringAsFixed(1)}');
    }

    if (_stuckInBrickFrames < _stuckFrameThreshold) return;

    // Ball is genuinely trapped — teleport below lowest brick row
    _stuckInBrickFrames = 0;
    final lowestBrick = bricks.fold<double>(
      0,
      (prev, br) => br.absolutePosition.y + br.size.y > prev
          ? br.absolutePosition.y + br.size.y
          : prev,
    );
    final safeY = (lowestBrick > 0 ? lowestBrick : size.y * 0.4) + 24;
    final before = ball.position.clone();
    ball.position = Vector2(size.x / 2, safeY.clamp(size.y * 0.3, size.y * 0.72));
    final vspeed = ball.velocity.length.clamp(200.0, 500.0);
    final sign = (_rng.nextBool() ? 1 : -1).toDouble();
    ball.velocity = Vector2(vspeed * 0.45 * sign, vspeed * 0.89);
    debugPrint('[STUCK] Teleported after $_stuckFrameThreshold frames: '
        '(${before.x.toInt()},${before.y.toInt()}) '
        '→ (${ball.position.x.toInt()},${ball.position.y.toInt()})');
  }

  /// Detects if the ball jumped more than 50px in a single frame.
  /// This catches unexpected teleportation from any source.
  void _detectBallJump() {
    if (!ball.isLaunched) {
      _prevFrameBallPos = ball.position.clone();
      return;
    }
    final jump = (ball.position - _prevFrameBallPos).length;
    if (jump > 50) {
      debugPrint('[JUMP] Ball jumped ${jump.toStringAsFixed(1)}px: '
          '(${_prevFrameBallPos.x.toInt()},${_prevFrameBallPos.y.toInt()}) '
          '→ (${ball.position.x.toInt()},${ball.position.y.toInt()}) '
          'v=(${ball.velocity.x.toInt()},${ball.velocity.y.toInt()}) '
          'fireball=${ball.isFireball} iceball=${ball.isIceball} '
          'magnetized=${ball.isMagnetized}');
    }
    _prevFrameBallPos = ball.position.clone();
  }

  // ── Effects ───────────────────────────────────────────────────────────────

  void _tickEffects(double dt) {
    for (int i = _effects.length - 1; i >= 0; i--) {
      _effects[i].remaining -= dt;
      if (_effects[i].remaining <= 0) {
        // Fireball must not expire while the ball is still in the brick zone
        // (upper half of screen) — keep extending until it drops to safety.
        if (((_effects[i].type == PowerUpType.fireball && ball.isFireball) ||
                (_effects[i].type == PowerUpType.iceball && ball.isIceball)) &&
            ball.isLaunched &&
            ball.absolutePosition.y < size.y * 0.55) {
          _effects[i].remaining = 0.5; // check again in half a second
          continue;
        }
        _revertEffect(_effects[i].type);
        _effects.removeAt(i);
        _notifyPowerUp();
      }
    }
  }

  void _revertEffect(PowerUpType type) {
    switch (type) {
      case PowerUpType.paddleWide:
      case PowerUpType.paddleNarrow:
        paddle.resetWidth();
        break;
      case PowerUpType.ballBig:
        ball.resetRadius();
        break;
      case PowerUpType.ballFast:
        ball.multiplySpeed(0.65);
        break;
      case PowerUpType.slowBall:
        ball.multiplySpeed(1.5);
        break;
      case PowerUpType.magnetPaddle:
        paddle.isMagnetic = false;
        if (ball.isMagnetized) {
          ball.clearMagnet();
          ball.launch();
          state = GameState.playing;
        }
        break;
      case PowerUpType.extraLife:
        break;
      case PowerUpType.fireball:
        ball.setFireball(false);
        _escapeBallFromBricks(ball);
        break;
      case PowerUpType.iceball:
        ball.setIceball(false);
        _escapeBallFromBricks(ball);
        break;
      case PowerUpType.tripleBall:
        break; // мгновенный эффект, отменять нечего
      case PowerUpType.laser:
        _laserBeams.clear();
        break;
      case PowerUpType.shield:
        break;
      case PowerUpType.ghostBall:
        break;
      case PowerUpType.mineBall:
        _mineBallHits = 0;
        break;
      case PowerUpType.stickyBall:
        // Если шар прилип — отпускаем
        if (ball.isMagnetized && !paddle.isMagnetic) {
          ball.clearMagnet();
          ball.launch();
          state = GameState.playing;
        }
        break;
    }
  }

  void _clearEffectsImmediate() {
    for (final e in _effects) _revertEffect(e.type);
    _effects.clear();
    _notifyPowerUp();
  }

  /// When fireball expires, the ball may be trapped inside a tight gap between
  /// indestructible bricks and a wall. Push it to a safe open position.
  void _escapeBallFromBricks(Ball b) {
    if (!b.isLaunched) return;
    final bRect = b.toAbsoluteRect();
    final stuck = bricks.any(
      (br) => br.isMounted && bRect.overlaps(br.toAbsoluteRect()),
    );
    if (!stuck) return;

    debugPrint('[ESCAPE] Ball stuck in brick at (${b.position.x.toInt()},${b.position.y.toInt()}), '
        'fireball=${b.isFireball} iceball=${b.isIceball} — teleporting below bricks');

    // Find the bottom edge of the lowest brick row so we can exit below them.
    double lowestBottom = 0;
    for (final br in bricks) {
      if (!br.isMounted) continue;
      final bottom = br.absolutePosition.y + br.size.y;
      if (bottom > lowestBottom) lowestBottom = bottom;
    }

    // Place ball just below all bricks, centered horizontally.
    final beforePos = b.position.clone();
    b.position.x = size.x / 2;
    b.position.y = lowestBottom + b.radius + 8;
    // Ensure ball is heading downward toward paddle so player can still save it.
    if (b.velocity.y < 0) b.reflectY();

    debugPrint('[ESCAPE] Teleported: (${beforePos.x.toInt()},${beforePos.y.toInt()}) '
        '→ (${b.position.x.toInt()},${b.position.y.toInt()}), lowestBrickBottom=${lowestBottom.toInt()}');
  }

  // ── Dynamite chain explosion ──────────────────────────────────────────────

  void _handleDynamiteExplosion(Brick origin) {
    final cx = origin.absolutePosition.x + origin.size.x / 2;
    final cy = origin.absolutePosition.y + origin.size.y / 2;

    // Spawn visual explosion (динамит — мощный взрыв)
    _explosions.add(ExplosionEffect(cx, cy, isDynamite: true));
    _shakeCtrl.add(7.0); // screen shake
    // covers all 8 neighbours regardless of brick size (actual size varies by screen)
    final range = origin.size.x * 1.85 + origin.size.y * 1.85;

    final toDestroy = bricks.where((br) {
      if (!br.isMounted || !br.isDestructible) return false;
      final bx = br.absolutePosition.x + br.size.x / 2;
      final by = br.absolutePosition.y + br.size.y / 2;
      final dx = bx - cx;
      final dy = by - cy;
      return sqrt(dx * dx + dy * dy) < range;
    }).toList();

    int chainScore = 0;
    for (final br in toDestroy) {
      chainScore += br.pointValue > 0 ? br.pointValue : 10;
      remove(br);
      bricks.remove(br);
      _destroyedCount++;
      if (_isBossLevel && _onBrickKilled()) break; // босс побеждён в середине цепи
    }
    // Bonus: 50 pts + 15 per chained brick (не увеличивает комбо — это одна акция)
    _addScore(chainScore + 50 + toDestroy.length * 15, countCombo: false);
    if (!_isBossLevel) {
      // Обычный уровень: проверяем завершение после всей цепи
      final remaining = bricks.where((br) => br.isDestructible).length;
      if (remaining == 0) _triggerLevelComplete();
    } else if (_bossHp > 0) {
      // Боссовый уровень: шок-волна динамита бьёт дополнительно на 3 HP
      _bossHp = (_bossHp - 3).clamp(0, _bossMaxHp);
      _bossHpCtrl.add(_bossHp);
      debugPrint('[ARKANOID] Dynamite blast! Boss bonus -3 HP → $_bossHp / $_bossMaxHp');
      if (_bossHp <= 0) _onBossDefeated();
    }
  }

  // ── Creature spawning & collisions ────────────────────────────────────────

  void _spawnCreatures() {
    _creatures.clear();
    _creatureBullets.clear();
    if (currentLevel < 4 || _isBossLevel) return;

    final count = currentLevel >= 6 ? 2 : 1;
    final midY = size.y * 0.52; // float in lower half of playfield
    final spacing = size.x / (count + 1);

    for (int i = 0; i < count; i++) {
      final type = (currentLevel >= 6) ? CreatureType.ufo : CreatureType.bat;
      _creatures.add(EnemyCreature(
        type: type,
        startX: spacing * (i + 1),
        startY: midY + (i.isEven ? 0 : 30),
      ));
    }
  }

  /// Ball hits a creature: creature dies, ball deflects randomly, +150 pts.
  void _checkCreatureCollisions(Ball b) {
    if (!b.isLaunched) return;
    final bRect = b.toAbsoluteRect();
    for (int i = _creatures.length - 1; i >= 0; i--) {
      final c = _creatures[i];
      if (!c.alive) continue;
      if (!bRect.overlaps(c.rect)) continue;
      c.alive = false;
      _creatures.removeAt(i);
      _addScore(150);
      // Randomise ball direction slightly so it doesn't just bounce straight back
      final angle = (pi / 4) + Random().nextDouble() * (pi / 2);
      final speed = b.velocity.length;
      final sign = b.velocity.x >= 0 ? 1 : -1;
      b.velocity = Vector2(
        sign * speed * cos(angle),
        -speed.abs() * sin(angle).abs(), // always send upward
      );
      break;
    }
  }

  /// Ball hits a creature bullet: bullet destroyed, ball continues, +20 pts.
  void _checkCreatureBulletCollisions(Ball b) {
    if (!b.isLaunched) return;
    final bRect = b.toAbsoluteRect();
    for (int i = _creatureBullets.length - 1; i >= 0; i--) {
      if (bRect.overlaps(_creatureBullets[i].rect)) {
        _creatureBullets.removeAt(i);
        _addScore(20);
      }
    }
  }

  // ── Collisions ────────────────────────────────────────────────────────────

  void _checkBallPaddleCollision(Ball b) {
    if (!b.isLaunched || b.isMagnetized) return;
    final ballB = b.toAbsoluteRect();
    if (!ballB.overlaps(paddle.toAbsoluteRect()) || b.velocity.y <= 0) return;

    final hitFraction =
        ((b.position.x - paddle.position.x) / (paddle.size.x / 2))
            .clamp(-1.0, 1.0);

    final beforePaddlePos = b.position.clone();
    if ((paddle.isMagnetic || _stickyActive) && !b.isExtra) {
      // Магнит / липучка: шар прилипает к ракетке, тап — отпустить
      b.applyMagnet();
      b.position.y = paddle.top - b.radius;
      state = GameState.waitingToLaunch;
    } else {
      b.reflectOffPaddle(hitFraction);
      b.position.y = paddle.top - b.radius;
    }
    final paddleSnapDist = (b.position - beforePaddlePos).length;
    if (paddleSnapDist > 30) {
      debugPrint('[PADDLE-SNAP] ${paddleSnapDist.toStringAsFixed(1)}px: '
          '(${beforePaddlePos.x.toInt()},${beforePaddlePos.y.toInt()}) '
          '→ (${b.position.x.toInt()},${b.position.y.toInt()})');
    }

    // Лёгкая вибрация при касании ракетки
    HapticFeedback.lightImpact();
  }

  void _checkBallBrickCollisions(Ball b) {
    if (!b.isLaunched || b.isMagnetized) return;
    final ballB = b.toAbsoluteRect();

    for (int i = bricks.length - 1; i >= 0; i--) {
      // Safety guard: list may have shrunk if explosion removed bricks during iteration
      if (i >= bricks.length) break;
      final brick = bricks[i];
      if (!brick.isMounted) continue;
      if (!ballB.overlaps(brick.toAbsoluteRect())) continue;

      if (b.isFireball) {
        // Огненный шар — сквозь любые кирпичи без отражения (кроме X)
        if (!brick.isDestructible) continue;
        _maybeDrop(brick);
        final wasDynamite = brick.isDynamite;
        final px = brick.position.x + brick.size.x / 2;
        final py = brick.position.y;
        remove(brick);
        bricks.removeAt(i);
        _destroyedCount++;
        _addScore(brick.pointValue, popX: px, popY: py);
        if (_onBrickKilled()) return;
        if (wasDynamite) { _handleDynamiteExplosion(brick); return; }
      } else if (b.isIceball) {
        // Ледяной шар — уничтожает ЛЮБЫЕ кирпичи, включая неразрушаемые X
        final isIndestructible = !brick.isDestructible;
        if (!isIndestructible) _maybeDrop(brick); // дроп только с разрушаемых
        final wasDynamite = brick.isDynamite;
        final bx = brick.position.x + brick.size.x / 2;
        final by = brick.position.y + brick.size.y / 2;
        remove(brick);
        bricks.removeAt(i);
        _destroyedCount++;
        if (isIndestructible) {
          _addScore(25, popX: bx, popY: by, countCombo: false); // бонус за разрушение «нерушимого»
          _explosions.add(ExplosionEffect(bx, by, isIce: true));
        } else {
          _addScore(brick.pointValue, popX: bx, popY: by);
          if (_onBrickKilled()) return;
        }
        if (wasDynamite) { _handleDynamiteExplosion(brick); return; }
      } else if (_ghostActive) {
        // Призрачный шар — проходит насквозь без отскока (как fireball)
        if (!brick.isDestructible) continue;
        _maybeDrop(brick);
        final wasDynamite = brick.isDynamite;
        final px = brick.position.x + brick.size.x / 2;
        final py = brick.position.y;
        remove(brick); bricks.removeAt(i); _destroyedCount++;
        _addScore(brick.pointValue, popX: px, popY: py);
        if (_onBrickKilled()) return;
        if (wasDynamite) { _handleDynamiteExplosion(brick); return; }
      } else {
        // Обычный режим — одно столкновение за кадр
        final bb = brick.toAbsoluteRect();
        final overlapX = min(ballB.right - bb.left, bb.right - ballB.left);
        final overlapY = min(ballB.bottom - bb.top, bb.bottom - ballB.top);
        // При угловом ударе (overlapX ≈ overlapY) используем вектор скорости,
        // чтобы выбрать правильную ось отражения и избежать "прыжка".
        final useX = overlapX < overlapY ||
            ((overlapY - overlapX).abs() <= 1.5 && b.velocity.x.abs() > b.velocity.y.abs());
        // Reject phantom collisions caused by floating-point precision:
        // if overlap in either axis is < 1px the rects are merely touching, not intersecting.
        if (overlapX < 1.0 || overlapY < 1.0) continue;

        final beforeCollPos = b.position.clone();
        final beforeCollVel = b.velocity.clone();
        if (useX) {
          b.reflectX();
          if (b.velocity.x < 0) {
            b.position.x = bb.left - b.radius;
          } else {
            b.position.x = bb.right + b.radius;
          }
        } else {
          b.reflectY();
          if (b.velocity.y < 0) {
            b.position.y = bb.top - b.radius;
          } else {
            b.position.y = bb.bottom + b.radius;
          }
        }
        // Log suspicious large position corrections (>30px)
        final corrDist = (b.position - beforeCollPos).length;
        if (corrDist > 30) {
          debugPrint('[BRICK-CORR] Large correction ${corrDist.toStringAsFixed(1)}px: '
              '(${beforeCollPos.x.toInt()},${beforeCollPos.y.toInt()}) → (${b.position.x.toInt()},${b.position.y.toInt()}) '
              'overlapX=${overlapX.toStringAsFixed(1)} overlapY=${overlapY.toStringAsFixed(1)} '
              'useX=$useX vel=(${beforeCollVel.x.toInt()},${beforeCollVel.y.toInt()})');
        }

        final destroyed = brick.hit();
        if (destroyed) {
          _maybeDrop(brick);
          final px = brick.position.x + brick.size.x / 2;
          final py = brick.position.y;
          // Mine Ball: уничтоженный кирпич взрывается как динамит
          final triggerMine = _mineBallHits > 0 && !brick.isDynamite && brick.isDestructible;
          if (triggerMine) {
            _mineBallHits--;
            if (_mineBallHits <= 0) {
              _effects.removeWhere((e) => e.type == PowerUpType.mineBall);
              _notifyPowerUp();
            }
          }
          if (brick.isDynamite || triggerMine) {
            remove(brick);
            bricks.removeAt(i);
            _destroyedCount++;
            _addScore(brick.pointValue, popX: px, popY: py);
            final bossEnded = _onBrickKilled();
            _handleDynamiteExplosion(brick);
            if (bossEnded) return;
          } else {
            remove(brick);
            bricks.removeAt(i);
            _destroyedCount++;
            _addScore(brick.pointValue, popX: px, popY: py);
            if (_onBrickKilled()) return;
          }
        } else {
          _addScore(2, countCombo: false); // chip hit — не увеличивает комбо
        }
        break;
      }
    }
  }

  void _checkBulletCollisions(Ball b) {
    if (!b.isLaunched) return;
    final ballRect = b.toAbsoluteRect();
    for (int i = _bullets.length - 1; i >= 0; i--) {
      if (ballRect.overlaps(_bullets[i].rect)) {
        _bullets.removeAt(i);
        _bossHp--;
        _bossHpCtrl.add(_bossHp);
        debugPrint('[ARKANOID] Boss hit! HP: $_bossHp / $_bossMaxHp');
        if (_bossHp <= 0) {
          _onBossDefeated();
          return;
        }
      }
    }
  }

  void _addScore(int pts, {double? popX, double? popY, bool countCombo = true}) {
    if (countCombo && pts > 0) _comboCount++;
    final multiplier = (countCombo && _comboCount >= 3) ? 3
        : (countCombo && _comboCount >= 2) ? 2 : 1;
    final total = pts * multiplier;
    score += total;
    _scoreCtrl.add(score);
    if (popX != null && popY != null && pts > 0) {
      _scorePopCtrl.add((pts: total, x: popX, y: popY, combo: _comboCount));
    }
  }

  void _maybeDrop(Brick brick) {
    final center = brick.position + brick.size / 2;

    // Кирпич с гарантированным бонусом — всегда роняет, игнорирует случайность
    if (brick.guaranteedDrop != null) {
      _powerUps.add(FallingPowerUp(type: brick.guaranteedDrop!, cx: center.x, cy: center.y));
      // Обновляем флаги чтоб не выпало ещё раз случайно
      if (brick.guaranteedDrop == PowerUpType.fireball) _fireballDropped = true;
      if (brick.guaranteedDrop == PowerUpType.iceball)  _iceballDropped  = true;
      return;
    }

    // Fireball: 7% chance, max 1 per level
    if (!_fireballDropped && _rng.nextDouble() < 0.07) {
      _fireballDropped = true;
      _powerUps.add(FallingPowerUp(type: PowerUpType.fireball, cx: center.x, cy: center.y));
      return;
    }
    // Iceball: 5% chance, max 1 per level, only from level 3+
    if (!_iceballDropped && currentLevel >= 3 && _rng.nextDouble() < 0.05) {
      _iceballDropped = true;
      _powerUps.add(FallingPowerUp(type: PowerUpType.iceball, cx: center.x, cy: center.y));
      return;
    }
    if (_rng.nextDouble() > kPowerUpChance) return;
    _powerUps.add(FallingPowerUp(
      type: randomPowerUp(_rng, tripleBallEnabled: _tripleBallUnlocked),
      cx: center.x,
      cy: center.y,
    ));
  }

  void _checkPowerUpCollisions() {
    final px = paddle.position.x;
    final py = paddle.position.y;
    final pw = paddle.size.x;
    final ph = paddle.size.y;
    final paddleB = Rect.fromLTWH(px - pw / 2, py - ph / 2, pw, ph);

    for (int i = _powerUps.length - 1; i >= 0; i--) {
      final pu = _powerUps[i];
      if (pu.y > size.y + 30) { _powerUps.removeAt(i); continue; }
      if (pu.rect.overlaps(paddleB)) {
        applyPowerUp(pu.type, duration: _durationFor(pu.type));
        _addScore(100);
        _powerUps.removeAt(i);
      }
    }
  }

  // ── Boss system ───────────────────────────────────────────────────────────

  void _spawnBossBullet() {
    final mounted = bricks.where((b) => b.isMounted).toList();
    if (mounted.isEmpty) return;
    final brick = mounted[_rng.nextInt(mounted.length)];
    final cx = brick.position.x + (brick.size.x / 2);
    final cy = brick.position.y + brick.size.y;
    _bullets.add(EnemyBullet(x: cx, y: cy));
  }

  /// Вызывается после уничтожения каждого разрушаемого кирпича.
  /// На уровне босса: снижает HP и проверяет победу.
  /// На обычном уровне: проверяет, не остались ли ещё разрушаемые кирпичи.
  /// Возвращает true если игровое состояние изменилось (босс побеждён / уровень завершён).
  bool _onBrickKilled() {
    if (_isBossLevel) {
      _bossHp--;
      if (_bossHp < 0) _bossHp = 0;
      _bossHpCtrl.add(_bossHp);
      debugPrint('[ARKANOID] Boss brick hit! HP: $_bossHp / $_bossMaxHp');
      if (_bossHp <= 0) { _onBossDefeated(); return true; }
      return false;
    } else {
      final remaining = bricks.where((br) => br.isDestructible).length;
      debugPrint('[ARKANOID] destroyed=$_destroyedCount / remaining=$remaining');
      if (remaining == 0) { _triggerLevelComplete(); return true; }
      return false;
    }
  }

  void _onBossDefeated() {
    debugPrint('[ARKANOID] Boss defeated! Total bosses: ${_bossCount + 1}');

    // Взрываем все оставшиеся кирпичи (X-каркас) с эффектом
    double sumX = 0, sumY = 0, count = 0;
    for (final brick in List<Brick>.from(bricks)) {
      if (!brick.isMounted) continue;
      final cx = brick.absolutePosition.x + brick.size.x / 2;
      final cy = brick.absolutePosition.y + brick.size.y / 2;
      sumX += cx; sumY += cy; count++;
      _explosions.add(ExplosionEffect(cx, cy, isDynamite: true));
      remove(brick);
    }
    bricks.clear();

    // Центральный мега-взрыв в центре масс босса
    final centerX = count > 0 ? sumX / count : size.x / 2;
    final centerY = count > 0 ? sumY / count : size.y * 0.35;
    _explosions.add(ExplosionEffect(centerX, centerY, isDynamite: true));
    _explosions.add(ExplosionEffect(centerX, centerY, isDynamite: true)); // двойной
    _shakeCtrl.add(14.0); // сильный шейк при победе над боссом

    _isBossLevel = false;
    _bullets.clear();
    justDefeatedBoss = true;
    _bossCount++;
    _tripleBallUnlocked = true; // разблокируется после первого босса навсегда
    _triggerLevelComplete();
  }

  // ── Ball events ───────────────────────────────────────────────────────────

  void onWallHit() {
    // Зарезервировано: можно добавить звук/вибрацию при ударе о стену
  }

  void onBallLost() {
    if (_processingBallLost) return;
    if (state == GameState.gameOver || state == GameState.levelComplete) return;

    // Если есть доп. шары — продвигаем один в основной, жизнь не теряем
    if (_extraBalls.isNotEmpty) {
      ball.isLaunched = false;
      if (ball.isMounted) remove(ball);
      ball = _extraBalls.removeLast();
      ball.isExtra = false;
      return;
    }

    _comboCount = 0;
    _mineBallHits = 0;
    debugDumpRemainingBricks();
    _processingBallLost = true;
    _clearEffectsImmediate();
    lives--;
    _livesCtrl.add(lives);

    if (lives <= 0) {
      state = GameState.gameOver;
      scheduleMicrotask(() => _gameOverCtrl.add(null));
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (state == GameState.gameOver || state == GameState.levelComplete) return;
        _resetBallToPaddle();
        state = GameState.waitingToLaunch;
        _processingBallLost = false;
      });
    }
  }

  /// Снаряд босса достиг дна — штрафная потеря жизни без сброса шара.
  void _bossBulletReachedBottom() {
    if (_processingBallLost) return;
    if (state == GameState.gameOver || state == GameState.levelComplete) return;
    _processingBallLost = true;
    _comboCount = 0;
    lives--;
    _livesCtrl.add(lives);
    if (lives <= 0) {
      state = GameState.gameOver;
      scheduleMicrotask(() => _gameOverCtrl.add(null));
    } else {
      // Мяч продолжает лететь, просто снимаем блокировку через небольшую паузу
      Future.delayed(const Duration(milliseconds: 400), () {
        _processingBallLost = false;
      });
    }
  }

  // ── Multi-ball ────────────────────────────────────────────────────────────

  void _spawnExtraBalls(int count) {
    if (!ball.isLaunched) return;
    final baseSpeed = ball.velocity.length > 0 ? ball.velocity.length : Ball.initialSpeed;
    final baseAngle = atan2(ball.velocity.y, ball.velocity.x);

    for (int i = 0; i < count; i++) {
      final angleOffset = (i == 0 ? -0.35 : 0.35);
      final angle = baseAngle + angleOffset;

      final eb = Ball();
      eb.isExtra = true;
      eb.velocity = Vector2(cos(angle), sin(angle)) * baseSpeed;
      eb.isLaunched = true;
      eb.position = ball.position.clone();
      _extraBalls.add(eb);
      add(eb);
    }
  }

  // ── Apply power-up ────────────────────────────────────────────────────────

  double _durationFor(PowerUpType t) => switch (t) {
    PowerUpType.paddleWide   => 8.0,
    PowerUpType.paddleNarrow => 6.0,
    PowerUpType.ballBig      => 7.0,
    PowerUpType.ballFast     => 60.0,
    PowerUpType.magnetPaddle => 6.0,
    PowerUpType.slowBall     => 6.0,
    PowerUpType.extraLife    => 0.0,
    PowerUpType.fireball     => 5.0,
    PowerUpType.iceball      => 5.0,
    PowerUpType.tripleBall   => 0.0,
    PowerUpType.laser        => 15.0,
    PowerUpType.shield       => 12.0,
    PowerUpType.ghostBall    => 5.0,
    PowerUpType.mineBall     => 0.0,  // счётчик, не таймер
    PowerUpType.stickyBall   => 8.0,
  };

  /// ballFast и slowBall можно стакировать до 2 раз — каждый стак независим.
  static const _stackableTypes = {PowerUpType.ballFast, PowerUpType.slowBall};

  void applyPowerUp(PowerUpType type, {required double duration}) {
    final opp = _oppositeOf(type);
    if (opp != null) {
      _effects.removeWhere((e) { if (e.type == opp) { _revertEffect(opp); return true; } return false; });
    }
    if (_stackableTypes.contains(type)) {
      // Стакируемые эффекты: каждый пик добавляет отдельный таймер, максимум 2
      final current = _effects.where((e) => e.type == type).length;
      if (duration > 0 && current < 2) {
        _effects.add(_ActiveEffect(type, duration));
      }
    } else {
      final ex = _effects.where((e) => e.type == type).toList();
      if (ex.isNotEmpty) {
        ex.first.remaining = max(ex.first.remaining, duration);
      } else if (duration > 0) {
        _effects.add(_ActiveEffect(type, duration));
      }
    }

    switch (type) {
      case PowerUpType.paddleWide:
        paddle.setWidth(Paddle.paddleWidth * 1.7);
      case PowerUpType.paddleNarrow:
        paddle.setWidth(Paddle.paddleWidth * 0.55);
      case PowerUpType.ballBig:
        // Cap at 1.55x so ball diameter (≈28px) stays below brick height (18px × 2 rows)
        ball.setRadius(Ball.ballRadius * 1.55);
      case PowerUpType.ballFast:
        ball.multiplySpeed(1.55);
      case PowerUpType.slowBall:
        ball.multiplySpeed(0.6);
      case PowerUpType.magnetPaddle:
        paddle.isMagnetic = true;
      case PowerUpType.extraLife:
        lives = min(lives + 1, 3);
        _livesCtrl.add(lives);
      case PowerUpType.fireball:
        ball.setFireball(true);
      case PowerUpType.iceball:
        ball.setIceball(true);
      case PowerUpType.tripleBall:
        _spawnExtraBalls(2);
      case PowerUpType.laser:
        break; // активируется, стреляет по тапу
      case PowerUpType.shield:
        break; // барьер появляется в render
      case PowerUpType.ghostBall:
        break; // меняет поведение коллизий
      case PowerUpType.mineBall:
        _mineBallHits = 3;
      case PowerUpType.stickyBall:
        break; // меняет поведение ракетки
    }
    _notifyPowerUp();
  }

  PowerUpType? _oppositeOf(PowerUpType t) => switch (t) {
    PowerUpType.paddleWide   => PowerUpType.paddleNarrow,
    PowerUpType.paddleNarrow => PowerUpType.paddleWide,
    PowerUpType.ballFast     => PowerUpType.slowBall,
    PowerUpType.slowBall     => PowerUpType.ballFast,
    _ => null,
  };

  void _notifyPowerUp() {
    _powerUpCtrl.add(_effects.isNotEmpty ? _effects.last.type : null);
  }

  // ── Game state ────────────────────────────────────────────────────────────

  void debugDumpRemainingBricks() {
    debugPrint('[ARKANOID] === REMAINING BRICKS DUMP ===');
    for (final b in bricks) {
      debugPrint('[ARKANOID] brick at (${b.position.x.toStringAsFixed(0)}, ${b.position.y.toStringAsFixed(0)}) type=${b.type} mounted=${b.isMounted}');
    }
    debugPrint('[ARKANOID] === END DUMP (count: ${bricks.length}) ===');
  }

  void _triggerLevelComplete() {
    debugPrint('[ARKANOID] _triggerLevelComplete called, current state=$state');
    if (state == GameState.levelComplete) {
      debugPrint('[ARKANOID] already in levelComplete state, skipping');
      return;
    }
    state = GameState.levelComplete;

    // Bonuses: speed + no-damage
    final elapsed = DateTime.now().difference(_levelStartTime).inSeconds;
    final bonuses = <({String label, int pts})>[];
    if (!_isBossLevel) {
      if (elapsed < 30) {
        bonuses.add((label: 'SPEED', pts: 500));
        _addScore(500, countCombo: false);
      } else if (elapsed < 60) {
        bonuses.add((label: 'SPEED', pts: 300));
        _addScore(300, countCombo: false);
      } else if (elapsed < 90) {
        bonuses.add((label: 'SPEED', pts: 100));
        _addScore(100, countCombo: false);
      }
      if (lives >= _livesAtLevelStart) {
        bonuses.add((label: 'NO DAMAGE', pts: 500));
        _addScore(500, countCombo: false);
      }
    }
    if (bonuses.isNotEmpty) {
      scheduleMicrotask(() => _bonusCtrl.add(bonuses));
    }
    scheduleMicrotask(() => _levelCompleteCtrl.add(null));
  }

  void advanceLevel() {
    if (justDefeatedBoss) {
      justDefeatedBoss = false;
      currentLevel = currentLevel >= maxLevels ? 1 : currentLevel + 1;
      _setupLevel();
      return;
    }
    if (currentLevel % 5 == 0) {
      _bossIndex = _bossCount % 4;
      _setupBossLevel();
      return;
    }
    currentLevel = currentLevel >= maxLevels ? 1 : currentLevel + 1;
    _setupLevel();
  }

  void restartGame() {
    score = 0;
    lives = 3;
    currentLevel = 1;
    _bossCount = 0;
    _isBossLevel = false;
    justDefeatedBoss = false;
    _bossInPhase2 = false;
    _bullets.clear();
    _laserBeams.clear();
    _mineBallHits = 0;
    for (final eb in _extraBalls) { if (eb.isMounted) remove(eb); }
    _extraBalls.clear();
    _tripleBallUnlocked = false;
    _scoreCtrl.add(0);
    _livesCtrl.add(3);
    _setupLevel();
  }

  @override
  void onRemove() {
    _levelCompleteCtrl.close();
    _gameOverCtrl.close();
    _scoreCtrl.close();
    _livesCtrl.close();
    _powerUpCtrl.close();
    _bossHpCtrl.close();
    _scorePopCtrl.close();
    _shakeCtrl.close();
    _bonusCtrl.close();
    _bossPhaseCtrl.close();
    super.onRemove();
  }

  void continueAfterAd() {
    lives = 1;
    _processingBallLost = false;
    _clearEffectsImmediate();
    state = GameState.waitingToLaunch;
    _resetBallToPaddle();
  }

  void pauseGame() {
    if (state == GameState.playing || state == GameState.waitingToLaunch) {
      state = GameState.paused;
      pauseEngine();
    }
  }

  void resumeGame() {
    if (state == GameState.paused) {
      state = GameState.playing;
      resumeEngine();
    }
  }

  // Rendering ----------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final t = themeNotifier.current;
    final bgRect = Rect.fromLTWH(0, 0, size.x, size.y);

    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.bgTop, t.bgBottom],
        ).createShader(bgRect),
    );

    if (_bgInitialized) _bg.render(canvas);

    final gridPaint = Paint()
      ..color = (t.wallColor as Color).withOpacity(0.09)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.x; x += 40)
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    for (double y = 0; y < size.y; y += 40)
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);

    super.render(canvas);

    // Power-ups, bullets, creatures, explosions
    for (final pu in _powerUps) pu.render(canvas);
    for (final bullet in _bullets) bullet.render(canvas);
    for (final c in _creatures) c.render(canvas);
    for (final cb in _creatureBullets) cb.render(canvas);
    for (final ex in _explosions) ex.render(canvas);

    // Shield barrier
    if (_shieldActive) {
      final shieldY = size.y - 18.0;
      final pulse = (sin(_shieldGlow) * 0.5 + 0.5);
      canvas.drawRect(
        Rect.fromLTWH(0, shieldY - 10, size.x, 20),
        Paint()..color = Color.fromRGBO(0, 229, 255, 0.10 + pulse * 0.08),
      );
      canvas.drawLine(
        Offset(0, shieldY),
        Offset(size.x, shieldY),
        Paint()
          ..color = Color.fromRGBO(0, 229, 255, 0.85 + pulse * 0.15)
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawLine(
        Offset(0, shieldY),
        Offset(size.x, shieldY),
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, 0.6 + pulse * 0.4)
          ..strokeWidth = 1.5,
      );
    }

    // Laser beams
    for (final beam in _laserBeams) {
      final cx = beam.x;
      final cy = beam.y;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy), width: 12, height: 30),
        Paint()..color = const Color(0x40FF1744),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy), width: 4, height: 22),
        Paint()
          ..color = const Color(0xFFFF1744)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy), width: 2, height: 20),
        Paint()..color = Colors.white,
      );
    }
  }
}

// Laser beam helper

class _LaserBeam {
  double x;
  double y;
  static const double speed = 950.0;

  _LaserBeam(this.x, this.y);

  void update(double dt) => y -= speed * dt;

  Rect get rect => Rect.fromCenter(
    center: Offset(x, y),
    width: 6,
    height: 24,
  );
}
