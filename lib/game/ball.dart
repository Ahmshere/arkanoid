import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/theme_notifier.dart';
import 'arkanoid_game.dart';

class Ball extends CircleComponent with HasGameRef<ArkanoidGame> {
  static const double ballRadius = 9.0;
  static const double initialSpeed = 380.0;
  static const double maxSpeed = 680.0;
  static const double speedIncrement = 8.0;

  Vector2 velocity = Vector2.zero();
  bool isLaunched = false;
  bool isMagnetized = false;
  bool isFireball = false;
  bool isIceball = false;
  bool isExtra = false; // доп. шар (тройной шар) — не отнимает жизнь при падении

  // Шлейф огненного / ледяного шара
  final List<Vector2> _trail = [];
  static const int _trailLength = 12;

  Ball() : super(radius: ballRadius);

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
    _updatePaint();
  }

  void _updatePaint() {
    if (isFireball) {
      paint = Paint()
        ..color = const Color(0xFFFF6600)
        ..style = PaintingStyle.fill;
    } else if (isIceball) {
      paint = Paint()
        ..color = const Color(0xFF00CFFF)
        ..style = PaintingStyle.fill;
    } else {
      final t = themeNotifier.current;
      paint = Paint()
        ..color = t.ballColor
        ..style = PaintingStyle.fill;
    }
  }

  void launch({double? angleRad}) {
    _updatePaint();
    isMagnetized = false;
    final angle = angleRad ?? ((-pi / 2) + (Random().nextDouble() - 0.5) * pi / 3);
    velocity = Vector2(cos(angle), sin(angle)) * initialSpeed;
    isLaunched = true;
  }

  void resetTo(Vector2 pos) {
    position = pos.clone();
    velocity = Vector2.zero();
    isLaunched = false;
    isMagnetized = false;
    isFireball = false;
    isIceball = false;
    _trail.clear();
    radius = ballRadius;
    _updatePaint();
  }

  void setRadius(double r) {
    radius = r;
  }

  void resetRadius() => setRadius(ballRadius);

  void applyMagnet() => isMagnetized = true;
  void clearMagnet() => isMagnetized = false;

  void setFireball(bool active) {
    isFireball = active;
    if (active) isIceball = false; // mutual exclusion
    _updatePaint();
  }

  void setIceball(bool active) {
    isIceball = active;
    if (active) isFireball = false; // mutual exclusion
    _updatePaint();
  }

  @override
  void render(Canvas canvas) {
    final cx = radius;
    final cy = radius;

    // Шлейф (рисуем под шаром)
    if (_trail.isNotEmpty) {
      for (int i = _trail.length - 1; i >= 0; i--) {
        final ageFrac = i.toDouble() / _trail.length; // 0=свежий, 1=старый
        final trailR = radius * (1.0 - ageFrac * 0.70).clamp(0.05, 1.0);
        final alpha = ((1.0 - ageFrac) * 0.55).clamp(0.0, 1.0);
        final tp = _trail[i];
        final lx = tp.x - position.x + radius;
        final ly = tp.y - position.y + radius;
        final Color color;
        if (isIceball) {
          color = ageFrac < 0.5
              ? const Color(0xFFCCF6FF) // белесо-голубой — свежие
              : const Color(0xFF009FCC); // тёмно-синий — старые
        } else {
          color = ageFrac < 0.5
              ? const Color(0xFFFFD700) // золотой — свежие
              : const Color(0xFFFF3300); // красно-оранжевый — старые
        }
        canvas.drawCircle(
          Offset(lx, ly),
          trailR,
          Paint()
            ..color = color.withOpacity(alpha)
            ..style = PaintingStyle.fill,
        );
      }
    }

    if (isFireball) {
      // Огненный ореол
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 1.7,
        Paint()
          ..color = const Color(0xFFFF4500).withOpacity(0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 1.35,
        Paint()
          ..color = const Color(0xFFFF6600).withOpacity(0.30)
          ..style = PaintingStyle.fill,
      );
    } else if (isIceball) {
      // Ледяной ореол
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 1.8,
        Paint()
          ..color = const Color(0xFF87EEFF).withOpacity(0.14)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 1.4,
        Paint()
          ..color = const Color(0xFF00CFFF).withOpacity(0.28)
          ..style = PaintingStyle.fill,
      );
      // Кольцо льда
      canvas.drawCircle(
        Offset(cx, cy),
        radius * 1.15,
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    super.render(canvas);
    final t = themeNotifier.current;

    // Блик (верхний левый)
    canvas.drawCircle(
      Offset(cx - radius * 0.28, cy - radius * 0.28),
      radius * 0.26,
      Paint()
        ..color = (isFireball ? Colors.yellow : isIceball ? Colors.white : t.ballHighlight).withOpacity(0.55)
        ..style = PaintingStyle.fill,
    );

    // Большой шарик — дополнительное кольцо
    if (radius > ballRadius * 1.4) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius - 1.5,
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  void update(double dt) {
    if (!isLaunched) return;

    // Обновляем шлейф
    if ((isFireball || isIceball) && !isMagnetized) {
      _trail.insert(0, position.clone());
      if (_trail.length > _trailLength) _trail.removeLast();
    } else {
      _trail.clear();
    }

    if (isMagnetized) {
      position.x = gameRef.paddle.centerX;
      velocity = Vector2.zero();
      return;
    }

    position += velocity * dt;

    final gs = gameRef.gameSize;

    if (position.x - radius <= 0) {
      position.x = radius;
      velocity.x = velocity.x.abs();
      gameRef.onWallHit();
    } else if (position.x + radius >= gs.x) {
      position.x = gs.x - radius;
      velocity.x = -velocity.x.abs();
      gameRef.onWallHit();
    }

    if (position.y - radius <= 0) {
      position.y = radius;
      velocity.y = velocity.y.abs();
      gameRef.onWallHit();
    }

    if (position.y - radius > gs.y) {
      if (isExtra) {
        isLaunched = false; // ArkanoidGame удалит без потери жизни
      } else {
        gameRef.onBallLost();
      }
    }
  }

  void reflectX() { velocity.x = -velocity.x; _clampSpeed(); }
  void reflectY() { velocity.y = -velocity.y; _clampSpeed(); }

  void reflectOffPaddle(double hitFraction) {
    if (isMagnetized) return;
    const maxAngle = 65 * pi / 180;
    final angle = hitFraction * maxAngle - pi / 2;
    final speed = min(velocity.length + speedIncrement, maxSpeed);
    velocity = Vector2(cos(angle), sin(angle)) * speed;
  }

  void multiplySpeed(double factor) {
    velocity = velocity * factor;
    _clampSpeed();
  }

  void _clampSpeed() {
    if (velocity.length > maxSpeed) {
      velocity = velocity.normalized() * maxSpeed;
    }
    if (velocity.length < 120) {
      velocity = velocity.normalized() * 120;
    }
  }
}
