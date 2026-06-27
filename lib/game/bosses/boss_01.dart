// Boss 1 — SKULL (Череп) — 6 HP (H-кирпичи)
// X = неразрушаемый каркас   H = слабые места (глаза, зубы)   _ = пусто
import 'boss_level_def.dart';

const boss01 = BossLevelDef(
  name: 'SKULL',
  bulletInterval: 2.5,
  movement: BossMovement(amplitude: 28, speed: 0.55),
  pattern: [
    '__XXXX__', // темя
    '_XXXXXX_', // верхний каркас
    'XXHXXHXX', // глаза (2H)
    'XX_XX_XX', // скулы
    '_XHXXHX_', // щёки (2H)
    '_X_HH_X_', // зубы (2H)
  ],
  // HP = 6 (авто: 6 разрушаемых H-кирпичей)
  // Phase 2: при ≤3 HP — быстрее стреляет и качается быстрее
  phase2BulletInterval: 1.5,
  phase2Movement: BossMovement(amplitude: 40, speed: 0.90),
);
