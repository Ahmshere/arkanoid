import 'dart:math';
import 'package:flutter/material.dart';

class _Particle {
  double x, y, vx, vy, size, life;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  }) : life = 1.0;

  bool get isDead => life <= 0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 280 * dt; // gravity
    vx *= 1 - dt * 1.2; // air drag
    life -= dt * 2.4;
    size -= dt * 6;
  }

  void render(Canvas canvas) {
    if (isDead || size <= 0.3) return;
    canvas.drawCircle(
      Offset(x, y),
      size.clamp(0.3, 20.0),
      Paint()..color = color.withOpacity(life.clamp(0.0, 1.0)),
    );
  }
}

class ExplosionEffect {
  static final Random _rng = Random();

  static const _sparkColors = [
    Color(0xFFFFD600), // vivid yellow
    Color(0xFFFF6D00), // orange
    Color(0xFFFF1744), // red
    Color(0xFFFFFFFF), // white flash
    Color(0xFFFF8F00), // amber
    Color(0xFFFFCC02), // gold
  ];

  static const _dynamiteColors = [
    Color(0xFFFF1744), // bright red
    Color(0xFFFF6D00), // deep orange
    Color(0xFFFFD600), // yellow
    Color(0xFFFFFFFF), // white core
    Color(0xFFFF3D00), // red-orange
    Color(0xFFFFAB00), // amber
    Color(0xFFE040FB), // purple flash
  ];

  static const _iceColors = [
    Color(0xFFCCF6FF), // ice white
    Color(0xFF00CFFF), // sky blue
    Color(0xFF80EEFF), // light cyan
    Color(0xFFFFFFFF), // pure white shard
    Color(0xFF48D1CC), // turquoise
    Color(0xFF87CEEB), // pale blue
  ];

  final double _cx, _cy;
  final bool isIce;
  final bool isDynamite;
  final List<_Particle> _particles = [];

  // Shockwave ring
  double _ringR = 0;
  double _ringOpacity = 0.9;

  bool get isDone => _particles.isEmpty && _ringOpacity <= 0;

  ExplosionEffect(this._cx, this._cy, {this.isIce = false, this.isDynamite = false}) {
    final colors = isIce ? _iceColors : (isDynamite ? _dynamiteColors : _sparkColors);

    // Количество искр: обычный=65, динамит=90, лёд=65
    final sparkCount = isDynamite ? 90 : 65;
    final chunkCount = isDynamite ? 24 : 18;

    // Мелкие быстрые искры
    for (int i = 0; i < sparkCount; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = (isIce ? 130.0 : isDynamite ? 160.0 : 90.0)
          + _rng.nextDouble() * (isDynamite ? 280.0 : 220.0);
      _particles.add(_Particle(
        x: _cx + (_rng.nextDouble() - 0.5) * 10,
        y: _cy + (_rng.nextDouble() - 0.5) * 6,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - (isIce ? 80 : isDynamite ? 120 : 50),
        size: 1.5 + _rng.nextDouble() * (isDynamite ? 5.5 : 4.5),
        color: colors[_rng.nextInt(colors.length)],
      ));
    }

    // Крупные обломки
    for (int i = 0; i < chunkCount; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 50.0 + _rng.nextDouble() * (isDynamite ? 200.0 : 130.0);
      _particles.add(_Particle(
        x: _cx + (_rng.nextDouble() - 0.5) * 14,
        y: _cy + (_rng.nextDouble() - 0.5) * 8,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - (isDynamite ? 60 : 20),
        size: 4.0 + _rng.nextDouble() * (isDynamite ? 9.0 : 7.0),
        color: colors[_rng.nextInt(isIce ? colors.length : (isDynamite ? colors.length : 3))],
      ));
    }
  }

  void update(double dt) {
    _ringR += (isDynamite ? 340 : 220) * dt;
    _ringOpacity -= dt * 3.5;

    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].isDead) _particles.removeAt(i);
    }
  }

  void render(Canvas canvas) {
    if (_ringOpacity > 0) {
      final Color glowColor;
      final Color sharpColor;
      if (isIce) {
        glowColor  = const Color(0xFF00CFFF);
        sharpColor = const Color(0xFFCCF6FF);
      } else if (isDynamite) {
        glowColor  = const Color(0xFFFF3D00);
        sharpColor = const Color(0xFFFFD600);
      } else {
        glowColor  = const Color(0xFFFFAA00);
        sharpColor = const Color(0xFFFFEE44);
      }

      // Outer glow (динамит — двойное кольцо)
      canvas.drawCircle(
        Offset(_cx, _cy),
        _ringR,
        Paint()
          ..color = glowColor.withOpacity(_ringOpacity.clamp(0.0, isDynamite ? 0.45 : 0.3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = isDynamite ? 14 : 8,
      );
      if (isDynamite) {
        // Второе кольцо поменьше для более мощного взрыва
        canvas.drawCircle(
          Offset(_cx, _cy),
          _ringR * 0.6,
          Paint()
            ..color = sharpColor.withOpacity(_ringOpacity.clamp(0.0, 0.5))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
      }
      // Sharp ring
      canvas.drawCircle(
        Offset(_cx, _cy),
        _ringR,
        Paint()
          ..color = sharpColor.withOpacity(_ringOpacity.clamp(0.0, 0.9))
          ..style = PaintingStyle.stroke
          ..strokeWidth = isDynamite ? 2.5 : 1.5,
      );
    }

    for (final p in _particles) p.render(canvas);
  }
}
