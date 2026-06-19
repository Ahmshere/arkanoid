import 'package:flutter/material.dart';
import '../data/score_repository.dart';
import '../theme/theme_notifier.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeNotifier,
      builder: (_, __, ___) {
        final t = themeNotifier.current;
        final entries = ScoreRepository.instance.entries;

        return Scaffold(
          backgroundColor: t.bgBottom,
          body: Stack(
            children: [
              // Gradient background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.bgTop, t.bgBottom],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: t.wallColor.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  color: t.textSecondary, size: 18),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'HIGH SCORES',
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 38), // balance
                        ],
                      ),
                    ),

                    // Trophy icon
                    Icon(Icons.emoji_events_rounded,
                        color: t.accentColor, size: 40),
                    const SizedBox(height: 16),

                    // Table header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _headerCell('#', 40, t.textSecondary),
                          _headerCell('SCORE', null, t.textSecondary,
                              flex: true),
                          _headerCell('LVL', 52, t.textSecondary),
                          _headerCell('WHEN', 80, t.textSecondary,
                              align: TextAlign.right),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                          color: t.wallColor.withOpacity(0.5), height: 16),
                    ),

                    // Entries
                    Expanded(
                      child: entries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sports_esports_rounded,
                                      color:
                                          t.textSecondary.withOpacity(0.3),
                                      size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No scores yet',
                                    style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 14,
                                        letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Play a game to set your first record!',
                                    style: TextStyle(
                                        color: t.textSecondary
                                            .withOpacity(0.5),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              itemCount: entries.length,
                              itemBuilder: (_, i) {
                                final e = entries[i];
                                final isTop3 = i < 3;
                                final medalColor = i == 0
                                    ? const Color(0xFFFFD700)
                                    : i == 1
                                        ? const Color(0xFFC0C0C0)
                                        : const Color(0xFFCD7F32);

                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isTop3
                                        ? medalColor.withOpacity(0.08)
                                        : t.wallColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isTop3
                                          ? medalColor.withOpacity(0.35)
                                          : t.wallColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Rank
                                      SizedBox(
                                        width: 28,
                                        child: isTop3
                                            ? Icon(Icons.emoji_events_rounded,
                                                color: medalColor, size: 18)
                                            : Text(
                                                '${i + 1}',
                                                style: TextStyle(
                                                    color: t.textSecondary,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Score
                                      Expanded(
                                        child: Text(
                                          '${e.score}',
                                          style: TextStyle(
                                            color: isTop3
                                                ? t.textPrimary
                                                : t.textPrimary
                                                    .withOpacity(0.85),
                                            fontSize: isTop3 ? 18 : 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      // Level
                                      Container(
                                        width: 40,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              t.accentColor.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'L${e.level}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: t.accentColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Date
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          _formatDate(e.date),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: t.textSecondary
                                                .withOpacity(0.7),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerCell(String text, double? width, Color color,
      {bool flex = false, TextAlign align = TextAlign.left}) {
    final child = Text(
      text,
      textAlign: align,
      style: TextStyle(
          color: color,
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600),
    );
    if (flex) return Expanded(child: child);
    return SizedBox(width: width, child: child);
  }
}
