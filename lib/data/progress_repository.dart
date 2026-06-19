import 'package:shared_preferences/shared_preferences.dart';
import '../theme/game_theme.dart';

/// Stores unlocked world themes and selected theme.
/// Best score for unlock checks is delegated to ScoreRepository.
class ProgressRepository {
  ProgressRepository._();
  static final ProgressRepository instance = ProgressRepository._();

  static const _keySelected = 'progress_selected_theme';
  static const _keyUnlocked = 'progress_unlocked_themes';

  /// Score required to unlock each theme. 0 = always free.
  static const Map<AppTheme, int> unlockScore = {
    AppTheme.stone:   0,
    AppTheme.neon:    0,
    AppTheme.forest:  0,
    AppTheme.candy:   0,
    AppTheme.earth:   0,
    AppTheme.moon:    1000,
    AppTheme.volcano: 3000,
    AppTheme.ice:     6000,
    AppTheme.space:   10000,
  };

  AppTheme _selected = AppTheme.stone;
  final Set<AppTheme> _unlocked = {};

  AppTheme get selected => _selected;

  bool isUnlocked(AppTheme theme) => _unlocked.contains(theme);

  /// Call once at app start (after ScoreRepository is loaded).
  Future<void> load(int bestScore) async {
    final prefs = await SharedPreferences.getInstance();

    // Restore saved unlocks
    final saved = prefs.getStringList(_keyUnlocked) ?? [];
    _unlocked.clear();
    for (final s in saved) {
      final match = AppTheme.values.where((e) => e.name == s);
      if (match.isNotEmpty) _unlocked.add(match.first);
    }

    // Always unlock score-zero themes
    for (final e in AppTheme.values) {
      if ((unlockScore[e] ?? 999999) == 0) _unlocked.add(e);
    }

    // Apply current best score
    _checkUnlocks(bestScore);

    // Restore selected theme
    final themeStr = prefs.getString(_keySelected);
    if (themeStr != null) {
      final match = AppTheme.values.where((e) => e.name == themeStr);
      if (match.isNotEmpty && _unlocked.contains(match.first)) {
        _selected = match.first;
      }
    }
  }

  /// Call whenever a new game score is recorded.
  Future<void> onScoreAdded(int bestScore) async {
    final before = Set<AppTheme>.from(_unlocked);
    _checkUnlocks(bestScore);
    if (_unlocked.length != before.length) {
      await _saveUnlocked();
    }
  }

  void _checkUnlocks(int bestScore) {
    for (final entry in unlockScore.entries) {
      if (bestScore >= entry.value) {
        _unlocked.add(entry.key);
      }
    }
  }

  Future<void> selectTheme(AppTheme theme) async {
    if (!_unlocked.contains(theme)) return;
    _selected = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelected, theme.name);
  }

  Future<void> _saveUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _keyUnlocked, _unlocked.map((e) => e.name).toList());
  }
}
