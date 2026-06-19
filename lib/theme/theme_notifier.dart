import 'package:flutter/foundation.dart';
import 'game_theme.dart';

class ThemeNotifier extends ValueNotifier<AppTheme> {
  ThemeNotifier() : super(AppTheme.stone);

  // TODO: persist with shared_preferences before release
  Future<void> load() async {}

  Future<void> setTheme(AppTheme theme) async {
    value = theme;
  }

  GameThemeData get current => GameThemes.get(value);
}

final themeNotifier = ThemeNotifier();
