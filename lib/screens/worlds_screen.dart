import 'package:flutter/material.dart';
import '../data/progress_repository.dart';
import '../theme/game_theme.dart';
import '../theme/theme_notifier.dart';

class WorldsScreen extends StatefulWidget {
  const WorldsScreen({super.key});

  @override
  State<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends State<WorldsScreen> {
  // World themes shown in the "Worlds" section (in unlock order)
  static const _worldOrder = [
    AppTheme.earth,
    AppTheme.moon,
    AppTheme.volcano,
    AppTheme.ice,
    AppTheme.space,
  ];

  // Classic themes shown in a separate row at the top
  static const _classicOrder = [
    AppTheme.stone,
    AppTheme.neon,
    AppTheme.forest,
    AppTheme.candy,
  ];

  void _selectTheme(AppTheme theme) async {
    if (!ProgressRepository.instance.isUnlocked(theme)) return;
    await themeNotifier.setTheme(theme);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = themeNotifier.current;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.bgTop, t.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: t.wallColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: t.wallColor.withOpacity(0.8), width: 1),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: t.textPrimary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'WORLDS',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Classic themes
                      _SectionLabel(label: 'CLASSIC', theme: t),
                      const SizedBox(height: 10),
                      Row(
                        children: _classicOrder
                            .map((th) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: _ClassicCard(
                                      appTheme: th,
                                      isSelected:
                                          themeNotifier.value == th,
                                      onTap: () => _selectTheme(th),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),

                      const SizedBox(height: 24),

                      // World themes
                      _SectionLabel(label: 'WORLDS', theme: t),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock by reaching score milestones',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _worldOrder.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, i) {
                          final th = _worldOrder[i];
                          return _WorldCard(
                            appTheme: th,
                            isSelected: themeNotifier.value == th,
                            onTap: () => _selectTheme(th),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final GameThemeData theme;
  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 3,
      ),
    );
  }
}

// ── Classic theme card (compact, horizontal row) ──────────────────────────────

class _ClassicCard extends StatelessWidget {
  final AppTheme appTheme;
  final bool isSelected;
  final VoidCallback onTap;
  const _ClassicCard(
      {required this.appTheme, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = GameThemes.get(appTheme);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              data.bgTop,
              data.bgBottom,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? data.accentColor : data.wallColor.withOpacity(0.6),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: data.accentColor.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              data.name.split(' ').first,
              style: TextStyle(
                color: isSelected ? data.accentColor : data.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 16,
                height: 3,
                decoration: BoxDecoration(
                  color: data.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── World theme card (larger, with lock/unlock state) ─────────────────────────

class _WorldCard extends StatelessWidget {
  final AppTheme appTheme;
  final bool isSelected;
  final VoidCallback onTap;
  const _WorldCard(
      {required this.appTheme, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = GameThemes.get(appTheme);
    final unlocked = ProgressRepository.instance.isUnlocked(appTheme);
    final threshold = ProgressRepository.unlockScore[appTheme] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              unlocked ? data.bgTop : const Color(0xFF0A0A0A),
              unlocked ? data.bgBottom : const Color(0xFF050505),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? data.accentColor
                : unlocked
                    ? data.wallColor.withOpacity(0.6)
                    : const Color(0xFF2A2A2A),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: data.accentColor.withOpacity(0.45),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Brick color bar at top
            if (unlocked)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                  child: Row(
                    children: data.brickColors
                        .map((c) => Expanded(
                              child: Container(height: 5, color: c),
                            ))
                        .toList(),
                  ),
                ),
              ),

            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.emoji,
                    style: TextStyle(
                      fontSize: unlocked ? 36 : 30,
                      color: unlocked ? null : const Color(0xFF444444),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.name,
                    style: TextStyle(
                      color: unlocked ? data.textPrimary : const Color(0xFF505050),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (unlocked)
                    Text(
                      isSelected ? '✓ ACTIVE' : 'TAP TO SELECT',
                      style: TextStyle(
                        color: isSelected
                            ? data.accentColor
                            : data.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.lock_rounded,
                            color: const Color(0xFF606060), size: 11),
                        const SizedBox(width: 4),
                        Text(
                          '$threshold pts',
                          style: const TextStyle(
                            color: Color(0xFF606060),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Lock overlay
            if (!unlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

            // Selected check mark
            if (isSelected)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: data.accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
