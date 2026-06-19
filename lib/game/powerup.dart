import 'dart:math';
import 'package:flutter/material.dart';

enum PowerUpType {
  paddleWide,
  paddleNarrow,
  ballBig,
  ballFast,
  magnetPaddle,
  extraLife,
  slowBall,
  fireball,
  tripleBall,
}

extension PowerUpInfo on PowerUpType {
  bool get isPositive => switch (this) {
    PowerUpType.paddleNarrow => false,
    PowerUpType.ballFast     => false,
    _ => true,
  };

  bool get isDuration => switch (this) {
    PowerUpType.extraLife  => false,
    PowerUpType.tripleBall => false,
    _ => true,
  };

  String get label => switch (this) {
    PowerUpType.paddleWide   => 'WIDE',
    PowerUpType.paddleNarrow => 'NARROW',
    PowerUpType.ballBig      => 'BIG',
    PowerUpType.ballFast     => 'FAST',
    PowerUpType.magnetPaddle => 'MAGNET',
    PowerUpType.extraLife    => '+LIFE',
    PowerUpType.slowBall     => 'SLOW',
    PowerUpType.fireball     => 'FIREBALL',
    PowerUpType.tripleBall   => 'MULTI',
  };

  Color get color => switch (this) {
    PowerUpType.paddleWide   => const Color(0xFF4CAF50),
    PowerUpType.paddleNarrow => const Color(0xFFE53935),
    PowerUpType.ballBig      => const Color(0xFF2196F3),
    PowerUpType.ballFast     => const Color(0xFFFF5722),
    PowerUpType.magnetPaddle => const Color(0xFF9C27B0),
    PowerUpType.extraLife    => const Color(0xFFE91E63),
    PowerUpType.slowBall     => const Color(0xFF00BCD4),
    PowerUpType.fireball     => const Color(0xFFFF6D00),
    PowerUpType.tripleBall   => const Color(0xFF00E676),
  };
}

// Простой data-класс — никакого Flame, только позиция и тип
class FallingPowerUp {
  static const double w = 50.0;
  static const double h = 22.0;
  static const double speed = 130.0;

  final PowerUpType type;
  double x; // левый край
  double y; // верхний край
  double wobble = 0.0;

  FallingPowerUp({required this.type, required double cx, required double cy})
      : x = cx - w / 2,
        y = cy - h / 2;

  void update(double dt) {
    y += speed * dt;
    wobble += dt * 2.5;
  }

  // Хитбокс — просто прямоугольник в игровых координатах
  Rect get rect => Rect.fromLTWH(x, y, w, h);

  void render(Canvas canvas) {
    final color = type.color;
    final wx = sin(wobble) * 2.0;
    final rect = Rect.fromLTWH(x + wx, y, w, h);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Тело
    canvas.drawRRect(
      rRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.25)!,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
        ).createShader(rect),
    );

    // Обводка
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = type == PowerUpType.fireball
            ? Colors.orange.withOpacity(0.8)
            : type.isPositive
                ? Colors.white.withOpacity(0.5)
                : Colors.red.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = type == PowerUpType.fireball ? 2.0 : 1.5,
    );

    // Блик
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + wx + 3, y + 2, w - 6, h * 0.35),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withOpacity(0.2),
    );

    // Текст — одна строка без переноса
    final tp = TextPainter(
      text: TextSpan(
        text: type.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    // Эффект "бочка катится": текст непрерывно прокручивается сверху вниз.
    // wobble растёт со временем (+=dt*2.5) — используем как движок прокрутки.
    final period = tp.height + 5.0; // шаг между повторами
    final scroll = (wobble * 7.92) % period; // +10% ещё быстрее

    final textX = x + wx + (w - tp.width) / 2;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(x + wx + 1, y + 1, w - 2, h - 2));
    // Несколько копий текста с шагом period — никогда не бывает пустот
    for (double dy = -period; dy < h + period; dy += period) {
      tp.paint(canvas, Offset(textX, y + scroll + dy - tp.height));
    }
    canvas.restore();
  }
}

const double kPowerUpChance = 0.32;

/// Случайный бонус (исключая fireball — он выпадает отдельной логикой;
/// tripleBall — только если разблокирован после первого босса)
PowerUpType randomPowerUp(Random rng, {bool tripleBallEnabled = false}) {
  final types = PowerUpType.values.where((t) {
    if (t == PowerUpType.fireball) return false;
    if (t == PowerUpType.tripleBall && !tripleBallEnabled) return false;
    return true;
  }).toList();
  return types[rng.nextInt(types.length)];
}
