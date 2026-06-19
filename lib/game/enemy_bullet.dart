import 'dart:math';
import 'package:flutter/material.dart';

class EnemyBullet {
  static const double bulletW = 5.0;
  static const double bulletH = 15.0;
  static const double bulletSpeed = 195.0;

  double x;
  double y;
  double _phase;

  EnemyBullet({required this.x, required this.y})
      : _phase = Random().nextDouble() * 6.28;

  void update(double dt) {
    y += bulletSpeed * dt;
    _phase += dt * 8.0;
  }

  Rect get rect => Rect.fromCenter(
        center: Offset(x, y),
        width: bulletW,
        height: bulletH,
      );

  void render(Canvas canvas) {
    final r = rect;
    final glowAlpha = 0.20 + sin(_phase).abs() * 0.15;

    // Внешнее свечение
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.inflate(5), const Radius.circular(7)),
      Paint()
        ..color = const Color(0xFFFF1100).withOpacity(glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // Центральный луч
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFFFF99), Color(0xFFFF2200)],
        ).createShader(r),
    );
  }
}
