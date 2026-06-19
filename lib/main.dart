import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/score_repository.dart';
import 'theme/theme_notifier.dart';
import 'screens/menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide status/nav bars for immersive game feel
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Load saved theme and scores
  await themeNotifier.load();
  await ScoreRepository.instance.load();

  // Init AdMob
  

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
