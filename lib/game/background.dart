import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/theme_notifier.dart';

/// Медленно плывущие геометрические частицы на фоне
class BackgroundLayer extends Component {
  final List<_Particle> _particles = [];
  late Vector2 _screenSize;
  final Random _rng = Random();

  BackgroundLayer(Vector2 screenSize) {
    _screenSize = screenSize;
    _spawnParticles();
  }

  void _spawnParticles() {
    _particles.clear();
    final count = 18;
    for (int i = 0; i < count; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble() * _screenSize.x,
        y: _rng.nextDouble() * _screenSize.y,
        size: 6 + _rng.nextDouble() * 28,
        speedX: (_rng.nextDouble() - 0.5) * 12,
        speedY: (_rng.nextDouble() - 0.5) * 12,
        rotSpeed: (_rng.nextDouble() - 0.5) * 0.4,
        shape: _rng.nextInt(3), // 0=rect, 1=diamond, 2=circle
        opacity: 0.04 + _rng.nextDouble() * 0.08,
      ));
    }
  }

  void onResize(Vector2 size) {
    _screenSize = size;
    _spawnParticles();
  }

  @override
  void update(double dt) {
    for (final p in _particles) {
      p.x += p.speedX * dt;
      p.y += p.speedY * dt;
      p.rotation += p.rotSpeed * dt;

      // Wrap around edges
      if (p.x < -p.size) p.x = _screenSize.x + p.size;
      if (p.x > _screenSize.x + p.size) p.x = -p.size;
      if (p.y < -p.size) p.y = _screenSize.y + p.size;
      if (p.y > _screenSize.y + p.size) p.y = -p.size;
    }
  }

  @override
  void render(Canvas canvas) {
    final t = themeNotifier.current;
    // Основной цвет частиц — смесь accentColor и wallColor
    final baseColor = Color.lerp(t.accentColor, t.wallColor, 0.5)!;

    for (final p in _particles) {
      final color = baseColor.withOpacity(p.opacity);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case 0: // прямоугольник
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
          break;
        case 1: // ромб
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, 0)
            ..lineTo(0, p.size / 2)
            ..lineTo(-p.size / 2, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case 2: // окружность
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
      }
      canvas.restore();
    }
  }
}

class _Particle {
  double x, y, size, speedX, speedY, rotSpeed, opacity, rotation;
  int shape;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.rotSpeed,
    required this.opacity,
    required this.shape,
  }) : rotation = 0;
}
