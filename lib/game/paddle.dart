import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/theme_notifier.dart';
import 'arkanoid_game.dart';

class Paddle extends RectangleComponent with HasGameRef<ArkanoidGame> {
  static const double paddleHeight = 18.0;
  static const double paddleWidth = 80.0;
  static const double bottomMargin = 90.0;

  static const double _minWidth = 44.0;
  static const double _maxWidth = 140.0;

  double _targetX = 0.0;
  static const double lerpSpeed = 18.0;

  bool isMagnetic = false;

  Paddle()
      : super(
          size: Vector2(paddleWidth, paddleHeight),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    paint = Paint()..color = Colors.transparent;
  }

  void moveTo(double x) {
    final hw = size.x / 2;
    _targetX = x.clamp(hw, gameRef.gameSize.x - hw);
  }

  /// Мгновенно ставит ракетку в позицию x (без анимации lerp).
  void snapTo(double x) {
    position.x = x;
    _targetX = x;
  }

  void setWidth(double w) {
    final clamped = w.clamp(_minWidth, _maxWidth);
    size = Vector2(clamped, paddleHeight);
    // Корректируем позицию чтобы не вылезти за края
    final hw = size.x / 2;
    position.x = position.x.clamp(hw, gameRef.gameSize.x - hw);
    _targetX = position.x;
  }

  void resetWidth() => setWidth(paddleWidth);

  @override
  void update(double dt) {
    position.x += (_targetX - position.x) * lerpSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final t = themeNotifier.current;
    const r = Radius.circular(8);
    const tipW = 11.0; // ширина красного наконечника

    final fullRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rRect = RRect.fromRectAndRadius(fullRect, r);

    // 1. Магнитное свечение
    if (isMagnetic) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(fullRect.inflate(3), const Radius.circular(11)),
        Paint()
          ..color = const Color(0xFF9C27B0).withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 2. Основное тело
    canvas.drawRRect(
      rRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isMagnetic
              ? [const Color(0xFFCE93D8), const Color(0xFF7B1FA2)]
              : [t.paddleGradientStart, t.paddleGradientEnd],
        ).createShader(fullRect),
    );

    // 3. Красные наконечники (как в оригинальном Arkanoid)
    if (!isMagnetic) {
      final tipPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF3030), Color(0xFF990000)],
        ).createShader(Rect.fromLTWH(0, 0, tipW, 18));

      // Левый наконечник
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, tipW, size.y),
          topLeft: r, bottomLeft: r,
        ),
        tipPaint,
      );

      // Правый наконечник
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(size.x - tipW, 0, tipW, size.y),
          topRight: r, bottomRight: r,
        ),
        tipPaint,
      );
    }

    // 4. Обводка
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = isMagnetic ? const Color(0xFFE1BEE7) : t.paddleStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 5. Блик сверху (только над основным телом, не над наконечниками)
    canvas.drawLine(
      Offset(tipW + 3, 3),
      Offset(size.x - tipW - 3, 3),
      Paint()
        ..color = (isMagnetic ? Colors.white : Colors.white).withOpacity(0.35)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  double get centerX => position.x;
  double get top => position.y - size.y / 2;
}
