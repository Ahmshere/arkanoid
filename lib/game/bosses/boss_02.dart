// Boss 2 — ROBOT (Робот) — ~11 HP (H/M-кирпичи)
// X = броня   H = слабые места   M = полубронированные   _ = пусто
import 'boss_level_def.dart';

const boss02 = BossLevelDef(
  name: 'ROBOT',
  bulletInterval: 2.2,
  movement: BossMovement(amplitude: 36, speed: 0.65),
  pattern: [
    '_XHHHX_X', // вентиляция шлема (3H)
    'HXXXXXXH', // боковые пластины (2H)
    'XX_HH_XX', // глаза (2H)
    'XXXXXXXX', // грудная броня
    'X_HXXHXX', // плечевые стыки (2H)
    'XXXXXXXX', // пояс
    '_H____H_', // ноги (2H)
  ],
  // HP = 11 (авто)
  // Phase 2: при ≤5 HP — агрессивный режим
  phase2BulletInterval: 1.3,
  phase2Movement: BossMovement(amplitude: 52, speed: 1.0),
);
