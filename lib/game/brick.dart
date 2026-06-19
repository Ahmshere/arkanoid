import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../theme/theme_notifier.dart';

enum BrickType { normal1, normal2, hard, indestructible, dynamite }

class Brick extends RectangleComponent {
  static const double brickWidth = 60.0; // max width (bricks scale to fill screen)
  static const double brickHeight = 18.0;
  static const double brickGap = 0.0;    // no gaps = no corner-collision artifacts

  final BrickType type;
  final int colorIndex; // индивидуальный цвет кирпича
  int _hp;
  bool _isHitFlashing = false;
  double _flashTimer = 0.0;
  static const double _flashDuration = 0.10;

  // Расширенная палитра — 8 оттенков из темы, чтобы каждый кирпич выглядел ярко
  static List<Color> _palette(List<Color> base) {
    return [
      base[0],
      Color.lerp(base[0], base[1], 0.5)!,
      base[1],
      Color.lerp(base[1], base[2], 0.33)!,
      Color.lerp(base[1], base[2], 0.67)!,
      base[2],
      Color.lerp(base[0], base[2], 0.5)!,
      Color.lerp(base[1], base[0], 0.25)!,
    ];
  }

  int get pointValue => switch (type) {
    BrickType.normal1        => 10,
    BrickType.normal2        => 20,
    BrickType.hard           => 40,
    BrickType.indestructible => 0,
    BrickType.dynamite       => 30,
  };

  bool get isDynamite => type == BrickType.dynamite;

  Brick({required this.type, required Vector2 position, this.colorIndex = 0, double? width})
      : _hp = _initialHp(type),
        super(
          size: Vector2(width ?? brickWidth, brickHeight),
          position: position,
          anchor: Anchor.topLeft,
        );

  static int _initialHp(BrickType t) => switch (t) {
    BrickType.normal1        => 1,
    BrickType.normal2        => 2,
    BrickType.hard           => 3,
    BrickType.indestructible => 999,
    BrickType.dynamite       => 1,
  };

  bool hit() {
    if (type == BrickType.indestructible) { _triggerFlash(); return false; }
    if (type == BrickType.dynamite) { _triggerFlash(); return true; } // always destroyed in 1 hit
    _hp--;
    _triggerFlash();
    return _hp <= 0;
  }

  void _triggerFlash() {
    _isHitFlashing = true;
    _flashTimer = 0.0;
  }

  @override
  void update(double dt) {
    if (_isHitFlashing) {
      _flashTimer += dt;
      if (_flashTimer >= _flashDuration) _isHitFlashing = false;
    }
  }

  @override
  void render(Canvas canvas) {
    // Dynamite gets its own special rendering path
    if (type == BrickType.dynamite) {
      _renderDynamite(canvas);
      return;
    }

    final t = themeNotifier.current;

    Color baseColor;
    if (type == BrickType.indestructible) {
      baseColor = t.brickColors[3];
    } else {
      // Используем расширенную палитру для нормальных кирпичей
      final palette = _palette(t.brickColors.take(3).toList());
      baseColor = palette[colorIndex % palette.length];

      // Затемняем в зависимости от оставшегося HP у hard кирпичей
      if (type == BrickType.hard) {
        final factor = (_hp - 1) / 2.0; // 1.0 = full, 0.0 = almost dead
        baseColor = Color.lerp(
          Color.lerp(baseColor, Colors.black, 0.45)!,
          baseColor,
          factor,
        )!;
      }
    }

    if (_isHitFlashing) {
      baseColor = Color.lerp(baseColor, Colors.white, 0.6)!;
    }

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // Основной цвет
    canvas.drawRRect(rRect, Paint()..color = baseColor);

    if (type == BrickType.indestructible) {
      // Стальной паттерн — диагональные линии
      canvas.save();
      canvas.clipRRect(rRect);
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..strokeWidth = 1.5;
      for (double x = -size.y; x < size.x + size.y; x += 8) {
        canvas.drawLine(Offset(x, 0), Offset(x + size.y, size.y), linePaint);
      }
      // Крест из бликов
      canvas.drawLine(
        Offset(size.x * 0.2, size.y * 0.5),
        Offset(size.x * 0.8, size.y * 0.5),
        Paint()..color = Colors.white.withOpacity(0.15)..strokeWidth = 1,
      );
      canvas.restore();
      // X-метка
      final xPainter = TextPainter(
        text: TextSpan(
          text: '✕',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      xPainter.paint(
        canvas,
        Offset((size.x - xPainter.width) / 2, (size.y - xPainter.height) / 2),
      );
    } else {
      // Блик сверху — стеклянный эффект
      final highlightRect = Rect.fromLTWH(3, 2, size.x - 6, size.y * 0.38);
      canvas.drawRect(
        highlightRect,
        Paint()..color = Colors.white.withOpacity(0.22),
      );
      // Нижняя тень
      canvas.drawRect(
        Rect.fromLTWH(0, size.y - 3, size.x, 3),
        Paint()..color = Colors.black.withOpacity(0.2),
      );

      // Трещины для повреждённых кирпичей
      if (type != BrickType.normal1 && _hp < _initialHp(type)) {
        _renderCracks(canvas);
      }
    }

    // Обводка
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = t.brickStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = t.brickStrokeWidth,
    );
  }

  bool get isDestructible => type != BrickType.indestructible;
  void _renderCracks(Canvas canvas) {
    final totalHp = _initialHp(type);
    final missing = totalHp - _hp;
    final w = size.x;
    final h = size.y;

    // Уникальный Random для каждого кирпича — паттерн трещин всегда одинаковый
    // для данного кирпича, но разный между кирпичами
    final rng = Random(colorIndex * 31 + 17);

    double rnd() => rng.nextDouble();

    void crack(Canvas c, Offset a, Offset? mid, Offset b, double opacity, double width) {
      final p = Paint()
        ..color = Colors.black.withOpacity(opacity)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      final lp = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.25)
        ..strokeWidth = width * 0.6
        ..strokeCap = StrokeCap.round;
      if (mid != null) {
        c.drawLine(a, mid, p); c.drawLine(mid, b, p);
        c.drawLine(Offset(a.dx+0.7,a.dy+0.7), Offset(mid.dx+0.7,mid.dy+0.7), lp);
        c.drawLine(Offset(mid.dx+0.7,mid.dy+0.7), Offset(b.dx+0.7,b.dy+0.7), lp);
      } else {
        c.drawLine(a, b, p);
        c.drawLine(Offset(a.dx+0.7,a.dy+0.7), Offset(b.dx+0.7,b.dy+0.7), lp);
      }
    }

    if (missing >= 1) {
      // Главная трещина — из случайной точки верха вниз с изломом
      final sx = w * (0.25 + rnd() * 0.5);
      final mx = w * (0.15 + rnd() * 0.7);
      final my = h * (0.3 + rnd() * 0.35);
      final ex = w * (0.2 + rnd() * 0.6);
      crack(canvas, Offset(sx, 0), Offset(mx, my), Offset(ex, h), 0.65, 1.1);

      // Маленький отросток от излома
      final bx = mx + w * (rnd() * 0.3 - 0.05);
      final by = my + h * (0.1 + rnd() * 0.2);
      crack(canvas, Offset(mx, my), null, Offset(bx, by), 0.4, 0.8);
    }

    if (missing >= 2) {
      // Вторая трещина с другой стороны
      final sx = w * (0.15 + rnd() * 0.3);
      final mx = w * (0.4 + rnd() * 0.3);
      final my = h * (0.25 + rnd() * 0.4);
      final ex = w * (0.5 + rnd() * 0.4);
      crack(canvas, Offset(sx, h * rnd() * 0.2), Offset(mx, my),
            Offset(ex, h * (0.8 + rnd() * 0.2)), 0.5, 0.9);

      // Горизонтальный скол
      final sy = h * (0.4 + rnd() * 0.2);
      crack(canvas, Offset(w * rnd() * 0.2, sy), null,
            Offset(w * (0.5 + rnd() * 0.4), sy + h * (rnd() * 0.15 - 0.07)), 0.35, 0.8);

      // Точечные сколы
      final chipP = Paint()..color = Colors.black.withOpacity(0.45)..style = PaintingStyle.fill;
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(w * rnd(), h * rnd()), 0.9 + rnd() * 0.8, chipP);
      }
    }
  }

  void _renderDynamite(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // Black/yellow flash when hit
    final baseYellow = _isHitFlashing
        ? const Color(0xFFFFFFFF)
        : const Color(0xFFFFCC00);
    final baseDark = _isHitFlashing
        ? const Color(0xFFFFFFCC)
        : const Color(0xFF1A1200);

    // Main body — dark background
    canvas.drawRRect(rRect, Paint()..color = baseDark);

    // Hazard stripes (black/yellow diagonal)
    canvas.save();
    canvas.clipRRect(rRect);
    final stripePaint = Paint()..color = baseYellow;
    const stripeW = 8.0;
    for (double x = -h; x < w + h; x += stripeW * 2) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeW, 0)
        ..lineTo(x + stripeW + h, h)
        ..lineTo(x + h, h)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
    canvas.restore();

    // Top highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 1, w - 4, h * 0.28), const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.18),
    );

    // 💣 emoji / TNT text
    final tp = TextPainter(
      text: const TextSpan(
        text: '💣',
        style: TextStyle(fontSize: 11, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));

    // Border — bright yellow
    canvas.drawRRect(
      rRect,
      Paint()
        ..color = _isHitFlashing
            ? Colors.white
            : const Color(0xFFFFDD00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

}
