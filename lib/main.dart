import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/score_repository.dart';
import 'data/progress_repository.dart';
import 'theme/theme_notifier.dart';
import 'screens/menu_screen.dart';
import 'services/ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide status/nav bars for immersive game feel
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load scores first (needed for unlock checks)
  await ScoreRepository.instance.load();

  // Load progress (unlocked worlds, selected theme) based on best score
  await ProgressRepository.instance.load(ScoreRepository.instance.bestScore);

  // Load saved theme selection
  await themeNotifier.load();

  // Инициализация AdMob
  await AdManager.instance.initialize();

  runApp(const ArkanoidApp());
}

class ArkanoidApp extends StatelessWidget {
  const ArkanoidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeNotifier,
      builder: (_, __, ___) {
        final t = themeNotifier.current;
        return MaterialApp(
          title: 'Arkanoid',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: t.bgBottom,
            colorScheme: ColorScheme.dark(
              primary: t.accentColor,
              surface: t.bgTop,
            ),
            fontFamily: 'monospace',
          ),
          home: const MenuScreen(),
        );
      },
    );
  }
}
