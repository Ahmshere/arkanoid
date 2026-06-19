import 'dart:math';
import 'package:flame/components.dart';
import 'brick.dart';

typedef LevelLayout = List<String>;

class LevelBuilder {
  static const double topOffset = 110.0;
  static final Random _rng = Random();

  // L=normal1, M=normal2, H=hard, X=indestructible, D=dynamite, _=пусто
  // Все ряды — не более 8 символов
  static const List<LevelLayout> _layouts = [
    // Level 1 — чистые ряды, 1 динамит
    [
      'LLLLLLLL',
      'LMLDMLLL',
      'MMMMMMMM',
      'MLMMMLMM',
    ],
    // Level 2 — барьеры с проходами, 1 динамит между барьерами
    [
      'LLLLLLLL',
      '_XXXXXX_',
      'LLDLLLLL',
      'MMMMMMMM',
      'LLLLLLLL',
      '__XXXX__',
      'HHHHHHHH',
    ],
    // Level 3 — крепость, динамит внутри
    [
      'XXX__XXX',
      'XLLLLLLX',
      'XLMDHMLX',
      'XLMHHMLX',
      'XLLLLLLX',
      'XXX__XXX',
    ],
    // Level 4 — ромб, 1 динамит в центре
    [
      '___XX___',
      '__XHHX__',
      '_XHMMHX_',
      'XHDMMMHX',
      '_XHMMHX_',
      '__XHHX__',
      '___XX___',
      'LLLLLLLL',
    ],
    // Level 5 — два барьера с широкими проходами, без центральной X-колонны
    [
      'MMM__MMM',
      'MMD__MMM',
      '__XXXX__', // барьер 1 — 2 прохода по 2 кирпича
      'HHH__HHH',
      'MMM__MMM',
      '__XXXX__', // барьер 2 — 2 прохода по 2 кирпича
      'MMMMMMMM',
      'MMMMMMMM',
    ],
    // Level 6 — хаос (генерируется, 1 динамит добавляется отдельно)
    [],
    // Level 7 — три колонны, 1 динамит в средней секции
    [
      'XXXXXXXX',
      'MMXMMXMM',
      'HHXHHXHH',
      'MDXMMXMM',
      'HHXHHXHH',
      'MMXMMXMM',
    ],
  ];

  static List<Brick> buildLevel(int level, Vector2 gameSize) {
    final idx = (level - 1).clamp(0, _layouts.length - 1);
    final layout = _layouts[idx];
    return layout.isEmpty
        ? _buildRandom(level, gameSize)
        : buildFromLayout(layout, gameSize);
  }

  /// Вычисляет ширину кирпича так, чтобы [cols] колонок помещались на экране.
  static double _brickWidth(double screenW, int cols) {
    const margin = 6.0; // отступ с каждой стороны
    const gap = Brick.brickGap;
    final w = ((screenW - 2 * margin - (cols - 1) * gap) / cols).floorToDouble();
    return w.clamp(20.0, Brick.brickWidth.toDouble());
  }

  static List<Brick> buildFromLayout(LevelLayout layout, Vector2 gameSize) {
    final bricks = <Brick>[];
    final stepH = Brick.brickHeight + Brick.brickGap;
    int globalIndex = 0;

    // Единая ширина кирпича для всего уровня — берём максимальное кол-во колонок
    final maxCols = layout.map((r) => r.length).reduce(max);
    final brickW = _brickWidth(gameSize.x, maxCols);

    for (int row = 0; row < layout.length; row++) {
      final rowStr = layout[row];
      final cols = rowStr.length;
      final stepW = brickW + Brick.brickGap;
      final rowWidth = cols * stepW - Brick.brickGap;
      final startX = (gameSize.x - rowWidth) / 2;

      for (int col = 0; col < cols; col++) {
        BrickType? type = switch (rowStr[col]) {
          'L' => BrickType.normal1,
          'M' => BrickType.normal2,
          'H' => BrickType.hard,
          'X' => BrickType.indestructible,
          'D' => BrickType.dynamite,
          _ => null,
        };
        if (type == null) continue;

        bricks.add(Brick(
          type: type,
          position: Vector2(startX + col * stepW, topOffset + row * stepH),
          colorIndex: globalIndex++,
          width: brickW,
        ));
      }
    }
    return bricks;
  }

  static List<Brick> _buildRandom(int level, Vector2 gameSize) {
    final bricks = <Brick>[];
    const cols = 8;
    const rows = 7;
    final brickW = _brickWidth(gameSize.x, cols);
    final stepW = brickW + Brick.brickGap;
    final stepH = Brick.brickHeight + Brick.brickGap;
    final startX = (gameSize.x - (cols * stepW - Brick.brickGap)) / 2;
    int idx = 0;

    // Pick one random position for dynamite (skip row 0 so it's reachable)
    final dynRow = 1 + _rng.nextInt(rows - 1);
    final dynCol = _rng.nextInt(cols);

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        BrickType type;
        if (row == dynRow && col == dynCol) {
          type = BrickType.dynamite;
        } else {
          final r = _rng.nextInt(10);
          type = r < 1
              ? BrickType.indestructible
              : r < 3
                  ? BrickType.hard
                  : r < 6
                      ? BrickType.normal2
                      : BrickType.normal1;
        }

        bricks.add(Brick(
          type: type,
          position: Vector2(startX + col * stepW, topOffset + row * stepH),
          colorIndex: idx++,
          width: brickW,
        ));
      }
    }
    return bricks;
  }

  static int destructibleCount(List<Brick> bricks) =>
      bricks.where((b) => b.isDestructible).length;
}
