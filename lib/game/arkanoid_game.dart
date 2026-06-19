import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'ball.dart';
import 'background.dart';
import 'boss_builder.dart';
import 'brick.dart';
import 'enemy_bullet.dart';
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

  Stream<void> get onLevelCompleteStream => _levelCompleteCtrl.stream;
  Stream<void> get onGameOverStream => _gameOverCtrl.stream;
  Stream<int> get onScoreStream => _scoreCtrl.stream;
  Stream<int> get onLivesStream => _livesCtrl.stream;
  Stream<PowerUpType?> get onPowerUpStream => _powerUpCtrl.stream;
  Stream<int> get onBossHpStream => _bossHpCtrl.stream;

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

  bool get isBossLevel => _isBossLevel;
  String get bossName => _bossName;
  int get bossMaxHp => _bossMaxHp;
  int get bossHp => _bossHp;

  int score = 0;
  int lives = 3;
  late int currentLevel = startLevel.clamp(1, maxLevels);
  int _destructibleTotal = 0;
  int _destroyedCount = 0;
  bool _processingBallLost = false;
  bool _fireballDropped = false;

  GameState state = GameState.waitingToLaunch;
  Vector2 get gameSize => size;
  static const int maxLevels = 7;

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
    for (final eb in _extraBalls) { if (eb.isMounted) remove(eb); }
    _extraBalls.clear();

    for (final c in children.whereType<Ball>().toList()) remove(c);
    for (final c in children.whereType<Paddle>().toList()) remove(c);

    _isBossLevel = false;

    await Future.delayed(Duration.zero);

    if (_bgInitialized) _bg.onResize(size);

    final newBricks = LevelBuilder.buildLevel(currentLevel, size);
    _destructibleTotal = LevelBuilder.destructibleCount(newBricks);
    _destroyedCount = 0;
    _fireballDropped = false;
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

    state = GameState.waitingToLaunch;
  }

  Future<void> _setupBossLevel() async {
    _processingBallLost = false;
    _clearEffectsImmediate();

    for (final b in bricks) { if (b.isMounted) remove(b); }
    bricks.clear();
    _powerUps.clear();
    _bullets.clear();
    for (final eb in _extraBalls) { if (eb.isMounted) remove(eb); }
    _extraBalls.clear();

    for (final c in children.whereType<Ball>().toList()) remove(c);
    for (final c in children.whereType<Paddle>().toList()) remove(c);

    await Future.delayed(Duration.zero);

    if (_bgInitialized) _bg.onResize(size);

    final data = BossBuilder.dataFor(_bossIndex);
    _bossName = data.name;
    _bossMaxHp = data.hp;
    _bossHp = data.hp;
    _bulletInterval = data.bulletInterval;
    _bulletTimer = data.bulletInterval;
    _isBossLevel = true;
    _destroyedCount = 0;
    _fireballDropped = false;
    _bossHpCtrl.add(_bossHp);

    debugPrint('[ARKANOID] Boss level: $_bossName, HP: $_bossMaxHp, bulletInterval: $_bulletInterval');

    final newBricks = BossBuilder.buildBoss(_bossIndex, size);
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
    ball.resetTo(Vector2(paddle.centerX, paddle.top - Ball.ballRadius - 2));
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent info) {
    if (state == GameState.waitingToLaunch) {
      ball.clearMagnet();
      ball.launch();
      state = GameState.playing;
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    paddle.moveTo(info.eventPosition.global.x);
    if (state == GameState.waitingToLaunch) _resetBallToPaddle();
  }

  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    if (_bgInitialized) _bg.update(dt);

    super.update(dt);

    if (state == GameState.paused ||
        state == GameState.gameOver ||
        state == GameState.levelComplete) {
      return;
    }
    _tickEffects(dt);

    // Обновляем падающие бонусы
    for (final pu in _powerUps) pu.update(dt);

    // Боссовые снаряды — спавним и обновляем
    if (_isBossLevel && state == GameState.playing) {
      _bulletTimer -= dt;
      if (_bulletTimer <= 0) {
        _bulletTimer = _bulletInterval;
        _spawnBossBullet();
      }
    }
    for (int i = _bullets.length - 1; i >= 0; i--) {
      _bullets[i].update(dt);
      if (_bullets[i].y > size.y + 20) {
        _bullets.removeAt(i);
        _bossBulletReachedBottom(); // снаряд достиг дна — потеря жизни
      }
    }

    // Дополнительные шары (тройной бонус)
    for (int i = _extraBalls.length - 1; i >= 0; i--) {
      final eb = _extraBalls[i];
      if (!eb.isLaunched) {
        // Шар упал за экран — просто убираем без потери жизни
        if (eb.isMounted) remove(eb);
        _extraBalls.removeAt(i);
        continue;
      }
      _checkBallPaddleCollision(eb);
      _checkBallBrickCollisions(eb);
      if (_isBossLevel) _checkBulletCollisions(eb);
    }

    // Основной шар
    _checkBallPaddleCollision(ball);
    _checkBallBrickCollisions(ball);
    if (_isBossLevel) _checkBulletCollisions(ball);

    _checkPowerUpCollisions();
  }

  // ── Effects ───────────────────────────────────────────────────────────────

  void _tickEffects(double dt) {
    for (int i = _effects.length - 1; i >= 0; i--) {
      _effects[i].remaining -= dt;
      if (_effects[i].remaining <= 0) {
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
      case PowerUpType.tripleBall:
        break; // мгновенный эффект, отменять нечего
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

    // Find the bottom edge of the lowest brick row so we can exit below them.
    double lowestBottom = 0;
    for (final br in bricks) {
      if (!br.isMounted) continue;
      final bottom = br.absolutePosition.y + br.size.y;
      if (bottom > lowestBottom) lowestBottom = bottom;
    }

    // Place ball just below all bricks, centered horizontally.
    b.position.x = size.x / 2;
    b.position.y = lowestBottom + b.radius + 8;
    // Ensure ball is heading downward toward paddle so player can still save it.
    if (b.velocity.y < 0) b.reflectY();
  }

  // ── Collisions ────────────────────────────────────────────────────────────

  void _checkBallPaddleCollision(Ball b) {
    if (!b.isLaunched || b.isMagnetized) return;
    final ballB = b.toAbsoluteRect();
    if (!ballB.overlaps(paddle.toAbsoluteRect()) || b.velocity.y <= 0) return;

    final hitFraction =
        ((b.position.x - paddle.position.x) / (paddle.size.x / 2))
            .clamp(-1.0, 1.0);

    if (paddle.isMagnetic && !b.isExtra) {
      // Доп. шары не прилипают к ракетке
      b.applyMagnet();
      b.position.y = paddle.top - b.radius;
      state = GameState.waitingToLaunch;
    } else {
      b.reflectOffPaddle(hitFraction);
      b.position.y = paddle.top - b.radius;
    }
  }

  void _checkBallBrickCollisions(Ball b) {
    if (!b.isLaunched || b.isMagnetized) return;
    final ballB = b.toAbsoluteRect();

    for (int i = bricks.length - 1; i >= 0; i--) {
      final brick = bricks[i];
      if (!brick.isMounted) continue;
      if (!ballB.overlaps(brick.toAbsoluteRect())) continue;

      if (b.isFireball) {
        // Огненный шар — сквозь любые кирпичи без отражения
        if (!brick.isDestructible) continue; // X пропускаем насквозь
        _maybeDrop(brick);
        remove(brick);
        bricks.removeAt(i);
        _destroyedCount++;
        _addScore(brick.pointValue);
        final remaining = bricks.where((br) => br.isDestructible).length;
        if (remaining == 0) { _triggerLevelComplete(); return; }
      } else {
        // Обычный режим — одно столкновение за кадр
        final bb = brick.toAbsoluteRect();
        final overlapX = min(ballB.right - bb.left, bb.right - ballB.left);
        final overlapY = min(ballB.bottom - bb.top, bb.bottom - ballB.top);
        // При угловом ударе (overlapX ≈ overlapY) используем вектор скорости,
        // чтобы выбрать правильную ось отражения и избежать "прыжка".
        final useX = overlapX < overlapY ||
            ((overlapY - overlapX).abs() <= 1.5 && b.velocity.x.abs() > b.velocity.y.abs());
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

        final destroyed = brick.hit();
        if (destroyed) {
          _maybeDrop(brick);
          remove(brick);
          bricks.removeAt(i);
          _destroyedCount++;
          _addScore(brick.pointValue);
          final remaining = bricks.where((br) => br.isDestructible).length;
          debugPrint('[ARKANOID] destroyed=$_destroyedCount / remaining=$remaining');
          if (remaining == 0) { _triggerLevelComplete(); return; }
        } else {
          _addScore(2);
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

  void _maybeDrop(Brick brick) {
    final center = brick.position + brick.size / 2;
    if (!_fireballDropped && _rng.nextDouble() < 0.07) {
      _fireballDropped = true;
      _powerUps.add(FallingPowerUp(
        type: PowerUpType.fireball,
        cx: center.x,
        cy: center.y,
      ));
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

  void _onBossDefeated() {
    debugPrint('[ARKANOID] Boss defeated! Total bosses: ${_bossCount + 1}');
    _isBossLevel = false;
    _bullets.clear();
    justDefeatedBoss = true;
    _bossCount++;
    _tripleBallUnlocked = true; // разблокируется после первого босса навсегда
    _triggerLevelComplete();
  }

  /// Снаряд босса достиг дна — штрафная потеря жизни без сброса шара.
  void _bossBulletReachedBottom() {
    if (_processingBallLost) return;
    if (state == GameState.gameOver || state == GameState.levelComplete) return;
    _processingBallLost = true;
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
    PowerUpType.ballFast     => 8.0,
    PowerUpType.magnetPaddle => 6.0,
    PowerUpType.slowBall     => 6.0,
    PowerUpType.extraLife    => 0.0,
    PowerUpType.fireball     => 5.0,
    PowerUpType.tripleBall   => 0.0,
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
        ball.setRadius(Ball.ballRadius * 2.1);
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
      case PowerUpType.tripleBall:
        _spawnExtraBalls(2);
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
    scheduleMicrotask(() {
      debugPrint('[ARKANOID] firing _levelCompleteCtrl.add(null)');
      _levelCompleteCtrl.add(null);
    });
  }

  void onBallLost() {
    if (_processingBallLost) return;
    if (state == GameState.gameOver || state == GameState.levelComplete) return;

    // Если есть доп. шары — продвигаем один в основной, жизнь не теряем
    if (_extraBalls.isNotEmpty) {
      ball.isLaunched = false; // останавливаем старый шар
      if (ball.isMounted) remove(ball);
      ball = _extraBalls.removeLast();
      ball.isExtra = false;
      return;
    }

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

  void onWallHit() {}
  void _addScore(int pts) {
    score += pts;
    _scoreCtrl.add(score);
  }

  void advanceLevel() {
    if (justDefeatedBoss) {
      // После победы над боссом — следующий обычный уровень
      justDefeatedBoss = false;
      currentLevel = currentLevel >= maxLevels ? 1 : currentLevel + 1;
      _setupLevel();
      return;
    }
    if (currentLevel == 5) {
      // После уровня 5 — всегда босс
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
    _bullets.clear();
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
      state = GameState.paused; pauseEngine();
    }
  }

  void resumeGame() {
    if (state == GameState.paused) { state = GameState.playing; resumeEngine(); }
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

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

    // Рисуем бонусы и снаряды поверх всего
    for (final pu in _powerUps) pu.render(canvas);
    for (final bullet in _bullets) bullet.render(canvas);
  }
}
