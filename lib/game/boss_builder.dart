import 'package:flame/components.dart';
import 'brick.dart';
import 'level_builder.dart';
import 'bosses/all_bosses.dart';

export 'bosses/all_bosses.dart';

class BossBuilder {
  static BossLevelDef dataFor(int bossIndex) =>
      allBosses[bossIndex % allBosses.length];

  static List<Brick> buildBoss(int bossIndex, Vector2 gameSize) {
    final def = dataFor(bossIndex);
    return LevelBuilder.buildFromLayout(def.pattern, gameSize);
  }
}
