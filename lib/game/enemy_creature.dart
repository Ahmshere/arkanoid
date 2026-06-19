import 'dart:math';
import 'package:flutter/material.dart';

enum CreatureType { bat, ufo }

/// A flying enemy that moves horizontally in a sine wave pattern,
/// occasionally fires bullets at the paddle, and deflects the ball on contact.
class EnemyCreature {
  static const double w = 32.0;
  static const double h = 20.0;
  static const double bulletSpeed = 220.0;

  final CreatureType type;
  double x; // center X
  double y; // center Y
  double _vx;
  double _phase; // sine wave phase
  double _shootTimer;
  final double _shootInterval;
  bool alive = true;
  double _animPhase = 0;

  static final Random _rng = Random();

  EnemyCreature({
    required this.type,
    required double startX,
    required double startY,
  })  : x = startX,
        y = startY,
        _vx = ((_rng.nextBool() ? 1 : -1) * (55.0 + _rng.nextDouble() * 25.0)),
        _phase = _rng.nextDouble() * 6.28,
        _shootTimer = 1.0 + _rng.nextDouble() * 2.0,
        _shootInterval = type == CreatureType.ufo ? 3.5 : 5.0;

  Rect get rect => Rect.fromCenter(
      center: Offset(x, y), width: w, height: h);

  void update(double dt, double screenW, List<CreatureBullet> bullets) {
    if (!alive) return;
    _animPhase += dt * 6.0;

    // Horizontal movement with sine wave vertical wobble
    x += _vx * dt;
    y += sin(_phase + _animPhase * 0.4) * 0.8;

    // Bounce off walls
    if (x - w / 2 < 4) { x = w / 2 + 4; _vx = _vx.abs(); }
    if (x + w / 2 > screenW - 4) { x = screenW - w / 2 - 4; _vx = -_vx.abs(); }

    // Shoot timer
    _shootTimer -= dt;
    if (_shootTimer <= 0) {
      _shootTimer = _shootInterval + _rng.nextDouble() * 2.0;
      bullets.add(CreatureBullet(x: x, y: y + h / 2));
    }
  }

  void render(Canvas canvas) {
    if (!alive) return;
    final wingFlap = sin(_animPhase) * 0.5 + 0.5; // 0..1

    if (type == CreatureType.bat) {
      _renderBat(canvas, wingFlap);
    } else {
      _renderUfo(canvas, wingFlap);
    }
  }

  void _renderBat(Canvas canvas, double wingFlap) {
    canvas.save();
    canvas.translate(x, y);

    // Wings — two bezier-style paths
    final wingH = 8.0 + wingFlap * 4.0;
    final bodyColor = const Color(0xFF9933CC);
    final wingColor = const Color(0xFF6600AA);

    // Left wing
    final leftWing = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(-14, -wingH, -16, 2)
      ..quadraticBezierTo(-10, 6, 0, 4)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = wingColor);

    // Right wing
    final rightWing = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(14, -wingH, 16, 2)
      ..quadraticBezierTo(10, 6, 0, 4)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = wingColor);

    // Wing membrane lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(-4, 3), const Offset(-14, -1), linePaint);
    canvas.drawLine(const Offset(-4, 3), const Offset(-10, 4), linePaint);
    canvas.drawLine(const Offset(4, 3), const Offset(14, -1), linePaint);
    canvas.drawLine(const Offset(4, 3), const Offset(10, 4), linePaint);

    // Body (oval)
    canvas.drawOval(
      const Rect.fromLTWH(-5, -5, 10, 10),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFCC55EE), Color(0xFF7700AA)],
        ).createShader(const Rect.fromLTWH(-5, -5, 10, 10))
        ..color = bodyColor,
    );

    // Eyes
    canvas.drawCircle(const Offset(-2, -2), 1.5, Paint()..color = const Color(0xFFFF3300));
    canvas.drawCircle(const Offset(2, -2), 1.5, Paint()..color = const Color(0xFFFF3300));
    canvas.drawCircle(const Offset(-2, -2), 0.6, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(2, -2), 0.6, Paint()..color = Colors.white);

    // Fangs
    canvas.drawLine(const Offset(-1.5, 3), const Offset(-2, 6),
        Paint()..color = Colors.white..strokeWidth = 1.2);
    canvas.drawLine(const Offset(1.5, 3), const Offset(2, 6),
        Paint()..color = Colors.white..strokeWidth = 1.2);

    canvas.restore();
  }

  void _renderUfo(Canvas canvas, double wingFlap) {
    canvas.save();
    canvas.translate(x, y);

    // Glow
    canvas.drawCircle(
      Offset.zero,
      16,
      Paint()
        ..color = const Color(0xFF00FF88).withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Dome
    final domePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.5),
        colors: [Color(0xFF88FFCC), Color(0xFF00AA55)],
      ).createShader(const Rect.fromLTWH(-8, -10, 16, 12));
    canvas.drawOval(
      const Rect.fromLTWH(-8, -10, 16, 12),
      domePaint,
    );

    // Saucer body
    final saucerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFCCCCCC), Color(0xFF666688)],
      ).createShader(const Rect.fromLTWH(-14, -2, 28, 8));
    canvas.drawOval(const Rect.fromLTWH(-14, -2, 28, 8), saucerPaint);

    // Rim highlight
    canvas.drawOval(
      const Rect.fromLTWH(-14, -2, 28, 8),
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Pulsing lights under saucer
    final lightColors = [
      const Color(0xFFFF3333),
      const Color(0xFF33FF33),
      const Color(0xFF3333FF),
    ];
    for (int i = 0; i < 3; i++) {
      final lx = -8.0 + i * 8.0;
      final pulse = sin(_animPhase + i * 2.1) * 0.5 + 0.5;
      canvas.drawCircle(
        Offset(lx, 5),
        2.0,
        Paint()..color = lightColors[i].withOpacity(0.5 + pulse * 0.5),
      );
    }

    canvas.restore();
  }
}

// ── Creature bullet ──────────────────────────────────────────────────────────

class CreatureBullet {
  static const double bW = 4.0, bH = 10.0;
  double x, y;
  double _phase;

  CreatureBullet({required this.x, required this.y})
      : _phase = Random().nextDouble() * 6.28;

  void update(double dt) {
    y += EnemyCreature.bulletSpeed * dt;
    _phase += dt * 10.0;
  }

  Rect get rect =>
      Rect.fromCenter(center: Offset(x, y), width: bW, height: bH);

  void render(Canvas canvas) {
    final glow = sin(_phase) * 0.4 + 0.6;
    // Glow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: bW + 4, height: bH + 6),
      Paint()
        ..color = const Color(0xFF00FF88).withOpacity(0.25 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Core
    canvas.drawOval(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF88FFCC), Colors.white, 0.4)!,
            const Color(0xFF00CC66),
          ],
        ).createShader(rect),
    );
  }
}
