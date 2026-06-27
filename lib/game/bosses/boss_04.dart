// Boss 4 — DRAGON (Дракон) — ~14 HP (H/M-кирпичи)
// X = чешуя   H = уязвимые точки   M = мягкое брюхо   _ = пусто
import 'boss_level_def.dart';

const boss04 = BossLevelDef(
  name: 'DRAGON',
  bulletInterval: 1.7,
  movement: BossMovement(amplitude: 52, speed: 0.85),
  pattern: [
    'H______H', // рога (2H)
    'XHXXXXHX', // шея (2H)
    'XXXHHXXX', // пасть (2H)
    'XHXXXXHX', // грудь (2H)
    'MXXXXXMX', // живот (2M)
    'XHXXXXHX', // лапы (2H)
    'HXXXXH_X', // хвост (2H)
  ],
  // HP = 14 (авто)
  // Phase 2: при ≤7 HP — RAGE MODE
  phase2BulletInterval: 0.9,
  phase2Movement: BossMovement(amplitude: 68, speed: 1.30),
);
