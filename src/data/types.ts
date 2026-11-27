import type { SpriteKey } from './sprites';

export type ToolId = 'broom' | 'mop' | 'cloth' | 'duster';
export type RoomId = 'living_room' | 'kitchen' | 'bedroom';
export type ActorId = 'nenek' | 'mc_kecil' | 'mc';
export type Rgba = readonly [number, number, number, number];

interface Placed {
  readonly id: string;
  readonly x: number;
  readonly y: number;
  readonly w: number;
  readonly h: number;
}

export interface DirtDef extends Placed {
  readonly tool: ToolId;
  /** Total scrub distance (world px) before the spot is clean. */
  readonly effort: number;
  readonly group: string;
  readonly tex?: SpriteKey;
  readonly layer?: 'ground' | 'ysort';
  /** Id of the furniture this grime sits on. */
  readonly parent?: string;
  readonly rotation?: number;
  readonly reward?: { readonly item: string; readonly amount: number; readonly message: string };
}

export interface PropDef extends Placed {
  readonly label: string;
  readonly tex?: SpriteKey;
  readonly layer: 'ground' | 'ysort';
  /** true: (x, y) is the bottom-centre "feet" point, used for y-sorting. false: (x, y) is the centre. */
  readonly originAtBase: boolean;
  readonly shadow: boolean;
  readonly z?: number;
  readonly scale?: readonly [number, number];
  readonly dirt?: readonly DirtDef[];
}

export interface ZoneDef extends Placed {
  readonly label: string;
  readonly tex?: SpriteKey;
  readonly accepts: string;
  readonly capacity: number;
  /** false: accepts any number (bin, sink). */
  readonly limit: boolean;
  /** Visual state per fill level: index 0 = empty. */
  readonly states: readonly SpriteKey[];
  /** Bin-style: states advance by fill ratio instead of one item per state. */
  readonly statesByFill?: boolean;
  readonly showCounter: boolean;
  readonly shadow: boolean;
  readonly z?: number;
  readonly dirt?: readonly DirtDef[];
}

export interface ItemDef extends Placed {
  readonly label: string;
  readonly tex?: SpriteKey;
  readonly type: string;
  readonly trash: boolean;
  readonly group: string;
  readonly z?: number;
}

export interface InteractDef extends Placed {
  readonly label: string;
  readonly tex?: SpriteKey;
  readonly after?: SpriteKey;
  readonly group: string;
  readonly hideAfter: boolean;
  readonly trash: boolean;
  readonly needed: number;
  readonly shadow: boolean;
  readonly z?: number;
}

export interface ActorDef extends Placed {
  readonly label: string;
  readonly tex?: SpriteKey;
  readonly actor: ActorId;
  readonly cutscene: string;
}

export interface CutsceneLine {
  readonly speaker: string;
  readonly text: string;
  readonly show?: readonly string[];
  readonly hide?: readonly string[];
  readonly moves?: readonly { readonly actor: string; readonly x: number; readonly y: number }[];
  readonly tint?: Rgba;
  readonly fadeToBlack?: boolean;
  readonly focus?: readonly [number, number];
  readonly zoom?: number;
  /** Seconds before auto-advance. Absent: wait for the player. */
  readonly hold?: number;
}

export interface TutorialPage {
  readonly title: string;
  readonly text: string;
  /** Optional illustration (sprite key) shown above the text. */
  readonly image?: SpriteKey;
}

/** Overrides read from the Godot scene; defaults live in each event class. */
export interface EventDef {
  readonly kind: 'cat' | 'rain' | 'blackout' | 'wind' | 'cockroach';
  readonly triggerProgress?: number;
  readonly introText?: string;
  readonly introDuration?: number;
  readonly tutorial?: readonly TutorialPage[];
  readonly [key: string]: unknown;
}

export interface RoomDef {
  readonly id: RoomId;
  readonly name: string;
  readonly short: string;
  readonly size: { readonly w: number; readonly h: number };
  readonly wallHeight: number;
  readonly background: SpriteKey;
  readonly flashbackTint: Rgba;
  readonly floorDirt: readonly DirtDef[];
  readonly props: readonly PropDef[];
  readonly zones: readonly ZoneDef[];
  readonly items: readonly ItemDef[];
  readonly interacts: readonly InteractDef[];
  readonly actors: readonly ActorDef[];
  readonly flashback: readonly CutsceneLine[];
  readonly events: readonly EventDef[];
}
