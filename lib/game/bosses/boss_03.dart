// Boss 3 — SPACESHIP (Корабль) — ~12 HP (H/M-кирпичи)
// X = корпус   H = энергощиты   M = двигатели   _ = пусто
import 'boss_level_def.dart';

const boss03 = BossLevelDef(
  name: 'SPACESHIP',
  bulletInterval: 2.0,
  movement: BossMovement(amplitude: 44, speed: 0.75),
  pattern: [
    '___HH___', // нос (2H)
    '__XXXX__', // кабина
    '_XHXXHX_', // крылья (2H)
    'HXXXXXHX', // крыло-двигатели (2H)
    'XXHXXHXX', // центр корпуса (2H)
    'MXXXXMXX', // сопла (2M)
    '__H__H__', // хвост (2H)
  ],
  // HP = 12 (авто: 12 разрушаемых H/M-кирпичей)
  // Phase 2: при ≤6 HP — форсаж
  phase2BulletInterval: 1.1,
  phase2Movement: BossMovement(amplitude: 60, speed: 1.15),
);
