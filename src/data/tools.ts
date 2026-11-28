import type { SfxKey } from './audio';
import { SPRITE, type SpriteKey } from './sprites';
import type { ToolId } from './types';

export interface ToolInfo {
  readonly id: ToolId;
  readonly name: string;
  /** Keyboard key that holds this tool (KeyboardEvent.code). */
  readonly code: string;
  readonly keyLabel: string;
  readonly icon: SpriteKey;
  readonly sfx: SfxKey;
  /** Particle colour while scrubbing. */
  readonly tint: number;
}

export const TOOLS: readonly ToolInfo[] = [
  { id: 'broom', name: 'Sapu', code: 'Digit1', keyLabel: '1', icon: SPRITE.tool_broom, sfx: 'tool_broom', tint: 0xd9c08a },
  { id: 'mop', name: 'Pel', code: 'Digit2', keyLabel: '2', icon: SPRITE.tool_mop, sfx: 'tool_mop', tint: 0x9cc7e8 },
  { id: 'cloth', name: 'Kain Lap', code: 'Digit3', keyLabel: '3', icon: SPRITE.tool_cloth, sfx: 'tool_cloth', tint: 0xe8b0b4 },
  { id: 'duster', name: 'Kemoceng', code: 'Digit4', keyLabel: '4', icon: SPRITE.tool_duster, sfx: 'tool_duster', tint: 0xcfc3e8 },
];

export const CANDLE_KEY = { code: 'Digit5', label: '5' } as const;

export function toolInfo(id: ToolId): ToolInfo {
  const t = TOOLS.find((x) => x.id === id);
  if (!t) throw new Error(`Unknown tool ${id}`);
  return t;
}

/** Tool upgrades (Godot ToolController defaults). */
export const TOOL_LEVELS = {
  // 9 spots per step (was 6): upgrades are earned across the house, not in the first room.
  cleansPerLevel: 9,
  maxLevel: 5,
  speedBonusPerLevel: 0.25,
} as const;

/** Level 1 -> 2 needs `base` spots, 2 -> 3 needs `base * 2` more, and so on. */
export function levelForCount(count: number): number {
  let level = 1;
  let remaining = count;
  while (level < TOOL_LEVELS.maxLevel && remaining >= TOOL_LEVELS.cleansPerLevel * level) {
    remaining -= TOOL_LEVELS.cleansPerLevel * level;
    level += 1;
  }
  return level;
}
