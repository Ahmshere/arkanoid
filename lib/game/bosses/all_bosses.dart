// ══════════════════════════════════════════════════════════
//  РЕЕСТР БОССОВ
//  Чтобы добавить нового босса:
//    1. Создайте файл lib/game/bosses/boss_NN.dart
//       с константой: const BossLevelDef bossNN = BossLevelDef(...);
//    2. Добавьте import ниже.
//    3. Добавьте bossNN в список allBosses.
//  Боссы чередуются циклически: после последнего — снова первый.
// ══════════════════════════════════════════════════════════

import 'boss_level_def.dart';
import 'boss_01.dart';
import 'boss_02.dart';
import 'boss_03.dart';
import 'boss_04.dart';

export 'boss_level_def.dart';

const List<BossLevelDef> allBosses = [
  boss01,
  boss02,
  boss03,
  boss04,
];


/*
* Каждый следующий босс быстрее и с большим размахом.
* Чтобы добавить нового босса — создаёшь boss_05.dart + две строки в all_bosses.dart,
*  и он автоматически войдёт в ротацию.
* */