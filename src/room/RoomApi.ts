import type Phaser from 'phaser';
import type { RoomDef, TutorialPage } from '@/data/types';
import type { CameraRig } from '@/systems/CameraRig';
import type { Fx } from '@/systems/Fx';
import type { Lighting } from '@/systems/Lighting';
import type { Dirt, DirtSpec } from '@/world/Dirt';
import type { Item } from '@/world/Item';
import type { Thing } from '@/world/Thing';
import type { Zone } from '@/world/Zone';
import type { CandleSystem } from './CandleSystem';
import type { RoomContext } from './RoomContext';

/** What room events and systems may touch. Implemented by RoomScene. */
export interface RoomApi {
  /** The Phaser scene (named to avoid Scene.scene, the scene plugin). */
  readonly phaser: Phaser.Scene;
  readonly ctx: RoomContext;
  readonly def: RoomDef;
  readonly items: readonly Item[];
  readonly zones: readonly Zone[];
  readonly furniture: readonly Thing[];
  readonly dirt: readonly Dirt[];
  readonly lighting: Lighting;
  readonly camera: CameraRig;
  readonly fx: Fx;
  readonly candles: CandleSystem;
  readonly finished: boolean;
  percent(): number;
  spawnDirt(spec: DirtSpec): Dirt;
  findThing(id: string): Thing | undefined;
  /** Grime that has to be cleaned before `d` (dust over a stain). */
  blockerOf(d: Dirt): Dirt | null;
  /** Opens a tutorial (pauses the room while it is open). */
  showTutorial(pages: readonly TutorialPage[], title: string): void;
  /** Pointer position in world space. */
  pointerWorld(): { x: number; y: number };
  /** Register a click handler that runs before item dragging. Return true to consume the click. */
  addClickInterceptor(fn: (x: number, y: number) => boolean): () => void;
}
