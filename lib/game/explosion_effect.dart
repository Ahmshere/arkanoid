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
    vy += 280 * dt; // gravity pulls sparks down
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

  final double _cx, _cy;
  final List<_Particle> _particles = [];

  // Shockwave ring
  double _ringR = 0;
  double _ringOpacity = 0.9;

  bool get isDone => _particles.isEmpty && _ringOpacity <= 0;

  ExplosionEffect(this._cx, this._cy) {
    // ~40 sparks
    for (int i = 0; i < 40; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 90.0 + _rng.nextDouble() * 220.0;
      _particles.add(_Particle(
        x: _cx + (_rng.nextDouble() - 0.5) * 10,
        y: _cy + (_rng.nextDouble() - 0.5) * 6,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 50, // slight upward bias
        size: 1.5 + _rng.nextDouble() * 4.5,
        color: _sparkColors[_rng.nextInt(_sparkColors.length)],
      ));
    }

    // 10 larger "chunk" debris
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 50.0 + _rng.nextDouble() * 130.0;
      _particles.add(_Particle(
        x: _cx + (_rng.nextDouble() - 0.5) * 14,
        y: _cy + (_rng.nextDouble() - 0.5) * 8,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 20,
        size: 4.0 + _rng.nextDouble() * 7.0,
        color: _sparkColors[_rng.nextInt(3)], // only warm colours for chunks
      ));
    }
  }

  void update(double dt) {
    // Expand & fade shockwave ring
    _ringR += 220 * dt;
    _ringOpacity -= dt * 3.5;

    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].isDead) _particles.removeAt(i);
    }
  }

  void render(Canvas canvas) {
    // Shockwave ring
    if (_ringOpacity > 0) {
      // outer glow
      canvas.drawCircle(
        Offset(_cx, _cy),
        _ringR,
        Paint()
          ..color = const Color(0xFFFFAA00).withOpacity(_ringOpacity.clamp(0.0, 0.3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      // sharp ring
      canvas.drawCircle(
        Offset(_cx, _cy),
        _ringR,
        Paint()
          ..color = const Color(0xFFFFEE44).withOpacity(_ringOpacity.clamp(0.0, 0.9))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Particles
    for (final p in _particles) p.render(canvas);
  }
}
