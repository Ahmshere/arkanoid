import 'package:flame/components.dart';
import 'brick.dart';
import 'level_builder.dart';

class BossData {
  final String name;
  final int hp;
  final double bulletInterval;
  const BossData(this.name, this.hp, this.bulletInterval);
}

class BossBuilder {
  static const List<BossData> _bossData = [
    BossData('SKULL',     8,  2.5),
    BossData('ROBOT',     10, 2.2),
    BossData('SPACESHIP', 12, 2.0),
    BossData('DRAGON',    15, 1.7),
  ];

  static const List<List<String>> _patterns = [
    // Boss 1 — Skull (череп)
    [
      '__XXXX__',
      '_XXXXXX_',
      'XX_XX_XX',
      'XX_XX_XX',
      'XXXXXXXX',
      '_X_XX_X_',
    ],
    // Boss 2 — Robot (робот)
    [
      '_XXXXXX_',
      'XXXXXXXX',
      'XX_XX_XX',
      'XXXXXXXX',
      'X_XXXX_X',
      'XXXXXXXX',
      '_X____X_',
    ],
    // Boss 3 — Spaceship (космический корабль)
    [
      '___XX___',
      '__XXXX__',
      '_XXXXXX_',
      'XX_XX_XX',
      'XXXXXXXX',
      '_X_XX_X_',
      '__X__X__',
    ],
    // Boss 4 — Dragon (дракон)
    [
      'X______X',
      'XX____XX',
      'XXX__XXX',
      'XXXXXXXX',
      '_XXXXXX_',
      '__XXXX__',
      '___XX___',
    ],
  ];

  static BossData dataFor(int bossIndex) =>
      _bossData[bossIndex.clamp(0, _bossData.length - 1)];

  static List<Brick> buildBoss(int bossIndex, Vector2 gameSize) {
    final idx = bossIndex.clamp(0, _patterns.length - 1);
    return LevelBuilder.buildFromLayout(_patterns[idx], gameSize);
  }
}
