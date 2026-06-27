/// Параметры движения блока босса (синусоида влево-вправо).
class BossMovement {
  /// Амплитуда качания в пикселях (в каждую сторону от центра).
  final double amplitude;

  /// Скорость качания в Гц (полных циклов в секунду).
  final double speed;

  const BossMovement({required this.amplitude, required this.speed});
}

/// Полное описание уровня-босса.
/// HP определяется автоматически как количество разрушаемых (H/M/L/D)
/// кирпичей в паттерне — чем больше «слабых мест», тем больше HP.
class BossLevelDef {
  final String name;
  final double bulletInterval;

  /// null = статичный босс, без движения.
  final BossMovement? movement;

  /// X = неразрушаемый каркас (кости/броня).
  /// H/M/L = разрушаемые слабые места (= HP босса).
  /// D = динамитный кирпич (редко).
  /// _ = пусто.
  final List<String> pattern;

  /// Фаза 2: активируется при HP ≤ 50%. null = без изменений.
  final double? phase2BulletInterval;
  final BossMovement? phase2Movement;

  const BossLevelDef({
    required this.name,
    required this.bulletInterval,
    this.movement,
    required this.pattern,
    this.phase2BulletInterval,
    this.phase2Movement,
  });
}
