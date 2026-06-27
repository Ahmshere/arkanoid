import 'dart:math';
import 'package:flutter/material.dart';
import '../data/score_repository.dart';
import '../theme/game_theme.dart';
import '../theme/theme_notifier.dart';
import '../game/arkanoid_game.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'worlds_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  int get _bestScore => ScoreRepository.instance.bestScore;
  int _debugLevel = 1;
  late AnimationController _ctrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.93, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _startGame() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => GameScreen(startLevel: _debugLevel),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    )).then((_) => setState(() {})); // обновить best score после возврата
  }

  void _openLeaderboard() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const LeaderboardScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    ));
  }

  void _openWorlds() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const WorldsScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    )).then((_) => setState(() {})); // refresh after theme change
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeNotifier,
      builder: (_, __, ___) {
        final t = themeNotifier.current;
        return Scaffold(
          body: Stack(
            children: [
              // Анимированный фон
              _AnimatedBackground(theme: t),

              // Контент
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BrickRow(theme: t),
                          const SizedBox(height: 28),
                          _AnimatedTitle(theme: t),
                          const SizedBox(height: 10),
                          Text('BREAK IT ALL',
                              style: TextStyle(
                                  color: t.accentColor,
                                  fontSize: 12,
                                  letterSpacing: 5,
                                  fontWeight: FontWeight.w500)),
                          if (_bestScore > 0) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: t.wallColor.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events_rounded,
                                      color: t.accentColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text('BEST  ',
                                      style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 11,
                                          letterSpacing: 2)),
                                  Text('$_bestScore',
                                      style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Play button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: GestureDetector(
                          onTap: _startGame,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: t.accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: t.accentColor, width: 1.5),
                            ),
                            child: Center(
                              child: Text('PLAY',
                                  style: TextStyle(
                                      color: t.accentColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 6)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // DEBUG: выбор стартового уровня
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('DEBUG LVL',
                              style: TextStyle(
                                  color: Colors.orange.withOpacity(0.7),
                                  fontSize: 9,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700)),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _debugLevel = (_debugLevel - 1).clamp(1, ArkanoidGame.maxLevels)),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.remove,
                                      color: Colors.orange, size: 16),
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                child: Center(
                                  child: Text('$_debugLevel',
                                      style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _debugLevel = (_debugLevel + 1).clamp(1, ArkanoidGame.maxLevels)),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.orange, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom row: HIGH SCORES + WORLDS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _openLeaderboard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: t.wallColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: t.wallColor.withOpacity(0.5),
                                      width: 1),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.emoji_events_rounded,
                                        color: t.textSecondary, size: 18),
                                    const SizedBox(height: 4),
                                    Text('SCORES',
                                        style: TextStyle(
                                            color: t.textSecondary,
                                            fontSize: 10,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _openWorlds,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: t.accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: t.accentColor.withOpacity(0.4),
                                      width: 1),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      themeNotifier.current.emoji,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('WORLDS',
                                        style: TextStyle(
                                            color: t.accentColor,
                                            fontSize: 10,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Animated background ───────────────────────────────────────────────────────

class _AnimatedBackground extends StatefulWidget {
  final GameThemeData theme;
  const _AnimatedBackground({required this.theme});
  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_FloatParticle> _particles;
  final Random _rng = Random();
  _DemoBall? _ball;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _ctrl.addListener(() => setState(() {}));
    _particles = List.generate(16, (_) => _FloatParticle(_rng));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final t = widget.theme;
    const dt = 1 / 60;

    // Инициализируем мяч при первом кадре, когда знаем размер экрана
    _ball ??= _DemoBall(size, _rng);
    _ball!.tick(dt, size);

    for (final p in _particles) p.tick(dt, size);

    return CustomPaint(
      size: size,
      painter: _BgPainter(_particles, t, _ball!),
    );
  }
}

// Демо-мяч прыгающий по фону меню
class _DemoBall {
  double x, y, vx, vy;
  final double r = 10.0;
  final List<Offset> _trail = [];
  static const int _trailLen = 18;

  _DemoBall(Size screen, Random rng)
      : x = screen.width * 0.5,
        y = screen.height * 0.55,
        vx = 95 + rng.nextDouble() * 50,
        vy = -(100 + rng.nextDouble() * 60);

  void tick(double dt, Size screen) {
    x += vx * dt;
    y += vy * dt;
    // Отскок от стен
    if (x < r) { x = r; vx = vx.abs(); }
    if (x > screen.width - r) { x = screen.width - r; vx = -vx.abs(); }
    if (y < r) { y = r; vy = vy.abs(); }
    if (y > screen.height - r) { y = screen.height - r; vy = -vy.abs(); }

    _trail.add(Offset(x, y));
    if (_trail.length > _trailLen) _trail.removeAt(0);
  }
}

class _FloatParticle {
  double x, y, size, vx, vy, rotation, rotSpeed, opacity;
  int shape;

  _FloatParticle(Random rng)
      : x = rng.nextDouble() * 400,
        y = rng.nextDouble() * 800,
        size = 8 + rng.nextDouble() * 30,
        vx = (rng.nextDouble() - 0.5) * 14,
        vy = (rng.nextDouble() - 0.5) * 14,
        rotation = 0,
        rotSpeed = (rng.nextDouble() - 0.5) * 0.5,
        opacity = 0.04 + rng.nextDouble() * 0.08,
        shape = rng.nextInt(3);

  void tick(double dt, Size screen) {
    x += vx * dt;
    y += vy * dt;
    rotation += rotSpeed * dt;
    if (x < -size) x = screen.width + size;
    if (x > screen.width + size) x = -size;
    if (y < -size) y = screen.height + size;
    if (y > screen.height + size) y = -size;
  }
}

class _BgPainter extends CustomPainter {
  final List<_FloatParticle> particles;
  final GameThemeData theme;
  final _DemoBall ball;
  _BgPainter(this.particles, this.theme, this.ball);

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bgTop, theme.bgBottom],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final baseColor = Color.lerp(theme.accentColor, theme.wallColor, 0.4)!;

    for (final p in particles) {
      final paint = Paint()
        ..color = baseColor.withOpacity(p.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.55),
            paint);
          break;
        case 1:
          final path = Path()
            ..moveTo(0, -p.size / 2)
            ..lineTo(p.size / 2, 0)
            ..lineTo(0, p.size / 2)
            ..lineTo(-p.size / 2, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
        default:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }

    // Трейл мяча
    final trail = ball._trail;
    for (int i = 0; i < trail.length; i++) {
      final t = i / trail.length;
      canvas.drawCircle(
        trail[i],
        ball.r * (0.3 + t * 0.5),
        Paint()
          ..color = theme.accentColor.withOpacity(t * 0.18),
      );
    }

    // Сам мяч
    final ballPos = Offset(ball.x, ball.y);
    // Свечение
    canvas.drawCircle(
      ballPos,
      ball.r * 2.2,
      Paint()..color = theme.accentColor.withOpacity(0.10),
    );
    // Основной круг
    canvas.drawCircle(
      ballPos,
      ball.r,
      Paint()..color = Colors.white.withOpacity(0.18),
    );
    // Блик
    canvas.drawCircle(
      Offset(ball.x - ball.r * 0.3, ball.y - ball.r * 0.3),
      ball.r * 0.35,
      Paint()..color = Colors.white.withOpacity(0.22),
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => true;
}

// ── Decorative brick row ──────────────────────────────────────────────────────

class _BrickRow extends StatelessWidget {
  final GameThemeData theme;
  const _BrickRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = theme.brickColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 32, height: 13,
        decoration: BoxDecoration(
          color: colors[i % colors.length],
          borderRadius: BorderRadius.circular(3),
        ),
      )),
    );
  }
}

// ── Animated brick title ──────────────────────────────────────────────────────

class _AnimatedTitle extends StatefulWidget {
  final GameThemeData theme;
  const _AnimatedTitle({required this.theme});
  @override
  State<_AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<_AnimatedTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const _letters = ['A', 'R', 'K', 'A', 'N', 'O', 'I', 'D'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final palette = [t.brickColors[0], t.brickColors[1], t.brickColors[2]];

    return LayoutBuilder(builder: (_, __) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_letters.length, (i) {
        final phase = _ctrl.value * 2 * pi - i * 0.52;
        final dy = sin(phase) * 9.0;
        final color = palette[i % palette.length];
        final light = Color.lerp(color, Colors.white, 0.30)!;
        final dark  = Color.lerp(color, Colors.black, 0.30)!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              width: 50,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [light, color, dark],
                  stops: const [0.0, 0.45, 1.0],
                ),
                boxShadow: [
                  // Цветное свечение
                  BoxShadow(
                    color: color.withOpacity(0.65),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                  // 3D нижний сдвиг
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 0,
                    offset: const Offset(4, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Верхний бевел (светлая грань)
                  Positioned(
                    left: 4, top: 4, right: 4,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Левый бевел
                  Positioned(
                    left: 4, top: 4, bottom: 7,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Нижняя тёмная грань
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(9),
                          bottomRight: Radius.circular(9),
                        ),
                      ),
                    ),
                  ),
                  // Буква
                  Center(
                    child: Text(
                      _letters[i],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: [
                          Shadow(color: Color(0x88000000), offset: Offset(1, 2), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
        ), // Row
      ); // FittedBox
    }); // LayoutBuilder
  }
}
