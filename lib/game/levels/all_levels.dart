// ══════════════════════════════════════════════════════════
//  РЕЕСТР УРОВНЕЙ
//  Чтобы добавить новый уровень:
//    1. Создайте файл lib/game/levels/level_NN.dart
//       с константой: const List<String> levelNN = [ ... ];
//    2. Добавьте import ниже.
//    3. Добавьте levelNN в список allLevels.
//  Пустой список ([]) -> уровень генерируется случайно.
//  Боссы появляются каждые 5 уровней: 5, 10, 15, 20, 25, 30
// ══════════════════════════════════════════════════════════

import 'level_01.dart';
import 'level_02.dart';
import 'level_03.dart';
import 'level_04.dart';
import 'level_05.dart';
import 'level_06.dart';
import 'level_07.dart';
import 'level_08.dart';
import 'level_09.dart';
import 'level_10.dart';
import 'level_11.dart';
import 'level_12.dart';
import 'level_13.dart';
import 'level_14.dart';
import 'level_15.dart';
import 'level_16.dart';
import 'level_17.dart';
import 'level_18.dart';
import 'level_19.dart';
import 'level_20.dart';
import 'level_21.dart';
import 'level_22.dart';
import 'level_23.dart';
import 'level_24.dart';
import 'level_25.dart';
import 'level_26.dart';
import 'level_27.dart';
import 'level_28.dart';
import 'level_29.dart';
import 'level_30.dart';

const List<List<String>> allLevels = [
  level01, level02, level03, level04, level05,  // <- BOSS 1 после 5
  level06, level07, level08, level09, level10,  // <- BOSS 2 после 10
  level11, level12, level13, level14, level15,  // <- BOSS 3 после 15
  level16, level17, level18, level19, level20,  // <- BOSS 4 после 20
  level21, level22, level23, level24, level25,  // <- BOSS 1 после 25
  level26, level27, level28, level29, level30,  // <- BOSS 2 после 30
];

/*
Symbol  Bonus on destroy
f       Fireball
i       Iceball
s       Speed (60 sec)
t       Triple ball
b       Big ball
g       Magnet
e       +1 life
w       Slow ball
*/
