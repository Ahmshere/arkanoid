import 'package:flutter/material.dart';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int level;
  final dynamic theme;
  final VoidCallback onContinueAd;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.level,
    required this.theme,
    required this.onContinueAd,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: t.overlayColor,
        child: SlideTransition(
          position: _slideAnim,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    'GAME OVER',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 2,
                    color: t.accentColor,
                  ),
                  const SizedBox(height: 28),

                  // Score card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 32),
                    decoration: BoxDecoration(
                      color: t.wallColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: t.wallColor.withOpacity(0.8), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCol(
                            label: 'SCORE',
                            value: '${widget.score}',
                            theme: t),
                        Container(
                            width: 1, height: 40, color: t.wallColor),
                        _StatCol(
                            label: 'LEVEL',
                            value: '${widget.level}',
                            theme: t,
                            accent: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Continue (ad)
                  _ActionButton(
                    icon: Icons.play_circle_fill_rounded,
                    label: 'CONTINUE',
                    sublabel: 'Watch a short ad',
                    isPrimary: true,
                    theme: t,
                    onTap: widget.onContinueAd,
                  ),
                  const SizedBox(height: 12),

                  // Restart
                  _ActionButton(
                    icon: Icons.replay_rounded,
                    label: 'RESTART',
                    sublabel: 'Start from level 1',
                    isPrimary: false,
                    theme: t,
                    onTap: widget.onRestart,
                  ),
                  const SizedBox(height: 12),

                  // Menu
                  GestureDetector(
                    onTap: widget.onMenu,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home_rounded,
                              color: t.textSecondary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'MAIN MENU',
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final dynamic theme;
  final bool accent;

  const _StatCol({
    required this.label,
    required this.value,
    required this.theme,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: theme.textSecondary,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: accent ? theme.accentColor : theme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isPrimary;
  final dynamic theme;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isPrimary,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final primaryColor = t.accentColor as Color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? primaryColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isPrimary
                  ? primaryColor.withOpacity(0.8)
                  : (t.wallColor as Color).withOpacity(0.6),
              width: widget.isPrimary ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  color: widget.isPrimary ? primaryColor : t.textSecondary,
                  size: 26),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(
                          color: widget.isPrimary
                              ? primaryColor
                              : t.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                  Text(widget.sublabel,
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.5)),
                ],
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: widget.isPrimary
                      ? primaryColor.withOpacity(0.6)
                      : (t.textSecondary as Color).withOpacity(0.4),
                  size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
