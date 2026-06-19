import 'package:flutter/foundation.dart';
import '../data/progress_repository.dart';
import 'game_theme.dart';

class ThemeNotifier extends ValueNotifier<AppTheme> {
  ThemeNotifier() : super(AppTheme.stone);

  Future<void> load() async {
    // ProgressRepository.load() must be called before this.
    value = ProgressRepository.instance.selected;
  }

  Future<void> setTheme(AppTheme theme) async {
    await ProgressRepository.instance.selectTheme(theme);
    value = ProgressRepository.instance.selected;
  }

  GameThemeData get current => GameThemes.get(value);
}

final themeNotifier = ThemeNotifier();
