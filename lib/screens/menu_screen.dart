import 'dart:math';
import 'package:flutter/material.dart';
import '../data/score_repository.dart';
import '../theme/game_theme.dart';
import '../theme/theme_notifier.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

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
                                    _debugLevel = (_debugLevel - 1).clamp(1, 7)),
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
                                    _debugLevel = (_debugLevel + 1).clamp(1, 7)),
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

                    // Leaderboard button
                    GestureDetector(
                      onTap: _openLeaderboard,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events_rounded,
                                color: t.textSecondary, size: 16),
                            const SizedBox(width: 8),
                            Text('HIGH SCORES',
                                style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 12,
                                    letterSpacing: 3,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Theme selector
                    Column(
                      children: [
                        Text('THEME',
                            style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 10,
                                letterSpacing: 3)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: AppTheme.values
                              .map((th) => _ThemeChip(
                                    appTheme: th,
                                    isSelected: themeNotifier.value == th,
                                    onTap: () => themeNotifier.setTheme(th),
                                  ))
                              .toList(),
                        ),
                      ],
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

    for (final p in _particles) p.tick(dt, size);

    return CustomPaint(
      size: size,
      painter: _BgPainter(_particles, t),
    );
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
  _BgPainter(this.particles, this.theme);

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

// ── Theme chip ────────────────────────────────────────────────────────────────

class _ThemeChip extends StatelessWidget {
  final AppTheme appTheme;
  final bool isSelected;
  final VoidCallback onTap;
  const _ThemeChip(
      {required this.appTheme,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = GameThemes.get(appTheme);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? data.accentColor.withOpacity(0.2)
              : data.wallColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? data.accentColor : data.wallColor.withOpacity(0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              data.name.split(' ').first,
              style: TextStyle(
                color: isSelected ? data.accentColor : data.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
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
    // Assign a color per letter cycling through the first 3 brick colors
    final palette = [t.brickColors[0], t.brickColors[1], t.brickColors[2]];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_letters.length, (i) {
        final phase = _ctrl.value * 2 * pi - i * 0.55;
        final dy = sin(phase) * 7.0;
        final color = palette[i % palette.length];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Container(
              width: 34,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.55),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _letters[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
