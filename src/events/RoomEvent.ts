import Phaser from 'phaser';
import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import type { SfxKey } from '@/data/audio';
import type { EventDef, TutorialPage } from '@/data/types';
import type { RoomApi } from '@/room/RoomApi';
import type { Dirt, DirtSpec } from '@/world/Dirt';
import type { Item } from '@/world/Item';
import type { Thing } from '@/world/Thing';

export interface Area {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface BaseConfig {
  enabled: boolean;
  triggerProgress: number;
  repeatEnabled: boolean;
  repeatInterval: number;
  repeatJitter: number;
  maxRepeats: number;
  introSpeaker: string;
  introText: string;
  introDuration: number;
  startSfx: SfxKey | null;
  tutorial: readonly TutorialPage[];
  tutorialEveryTime: boolean;
}

const BASE: BaseConfig = {
  enabled: true,
  triggerProgress: 50,
  repeatEnabled: true,
  repeatInterval: 90,
  repeatJitter: 20,
  maxRepeats: 2,
  introSpeaker: 'Kejadian!',
  introText: '',
  introDuration: 4.5,
  startSfx: 'warning',
  tutorial: [],
  tutorialEveryTime: false,
};

/** Read a value from the Godot overrides with a typed default. */
function pick<T>(def: EventDef, key: string, fallback: T): T {
  const v = def[key];
  if (v === undefined || v === null) return fallback;
  if (typeof fallback === 'object' && fallback !== null && 'w' in (fallback as object) && typeof v === 'object' && v && 'w' in v) return v as T;
  return typeof v === typeof fallback ? (v as T) : fallback;
}

/**
 * Base room event. Starts when room progress reaches `triggerProgress`, can come back after a
 * delay, and keeps the room from completing while running. Timers use the scene clock, so they
 * stop while the game is paused (the Godot build kept counting).
 */
export abstract class RoomEvent<C extends object = object> {
  readonly id: string;
  protected readonly cfg: BaseConfig & C;
  protected running = false;
  private started = false;
  private repeats = 0;
  private readonly unsub: () => void;

  constructor(protected readonly room: RoomApi, def: EventDef, defaults: C) {
    this.id = `${def.kind}`;
    const merged: Record<string, unknown> = { ...BASE, ...defaults };
    for (const key of Object.keys(merged)) merged[key] = pick(def, key, merged[key]);
    if (def.tutorial) merged['tutorial'] = def.tutorial;
    this.cfg = merged as BaseConfig & C;
    if (GameState.isCompleted(room.def.id)) this.cfg.enabled = false;
    this.unsub = room.ctx.bus.on('progress', (pct) => this.onProgress(pct));
  }

  get isRunning(): boolean {
    return this.running;
  }

  private onProgress(pct: number): void {
    if (!this.cfg.enabled || this.started || pct < this.cfg.triggerProgress || !this.canStart(pct)) return;
    this.started = true;
    this.launch();
  }

  private launch(): void {
    if (this.running || this.room.finished) return;
    this.running = true;
    this.room.ctx.beginEvent(this.id);
    if (this.cfg.startSfx) Audio.sfx(this.cfg.startSfx, { volume: 0.7 });
    if (this.cfg.introText) this.room.ctx.bus.emit('dialog', { speaker: this.cfg.introSpeaker, text: this.cfg.introText, duration: this.cfg.introDuration });
    this.showTutorial();
    this.onStart();
  }

  private showTutorial(): void {
    if (this.cfg.tutorial.length === 0) return;
    const key = `event:${this.id}`;
    if (!this.cfg.tutorialEveryTime && GameState.hasSeen(key)) return;
    GameState.markSeen(key);
    // Let the event's first beat land before pausing for the explanation.
    this.room.phaser.time.delayedCall(900, () => this.room.showTutorial(this.cfg.tutorial, 'Kejadian'));
  }

  /** Extra start condition. */
  protected canStart(_pct: number): boolean {
    return true;
  }

  protected abstract onStart(): void;

  protected finish(): void {
    if (!this.running) return;
    this.running = false;
    this.room.ctx.endEvent(this.id);
    this.scheduleRepeat();
  }

  private scheduleRepeat(): void {
    const c = this.cfg;
    if (!c.repeatEnabled || !c.enabled) return;
    if (c.maxRepeats > 0 && this.repeats >= c.maxRepeats) return;
    const delay = Math.max(5, c.repeatInterval + Phaser.Math.FloatBetween(-c.repeatJitter, c.repeatJitter));
    this.room.phaser.time.delayedCall(delay * 1000, () => this.tryRepeat());
  }

  private tryRepeat(): void {
    if (this.room.finished) return;
    if (this.room.ctx.eventsActive || this.room.ctx.cinematic || !this.canStart(this.room.percent())) {
      this.room.phaser.time.delayedCall(8000, () => this.tryRepeat());
      return;
    }
    this.repeats += 1;
    this.launch();
  }

  // ---------- Helpers ----------
  protected pointAt(id: string, get: () => { x: number; y: number } | null): void {
    this.room.ctx.bus.emit('pointer', { id: `${this.id}:${id}`, target: get });
  }

  protected clearPoint(id: string): void {
    this.room.ctx.bus.emit('pointerClear', `${this.id}:${id}`);
  }

  protected randomIn(a: Area): { x: number; y: number } {
    return { x: Phaser.Math.FloatBetween(a.x, a.x + a.w), y: Phaser.Math.FloatBetween(a.y, a.y + a.h) };
  }

  protected spawnDirt(spec: Omit<DirtSpec, 'id'>): Dirt {
    const d = this.room.spawnDirt({ ...spec, id: `${this.id}-${Phaser.Math.RND.uuid().slice(0, 8)}` });
    d.sprite.setAlpha(0);
    this.room.phaser.tweens.add({ targets: d.sprite, alpha: 1, duration: 600 });
    return d;
  }

  /** Items already put away whose type is in `types`. */
  protected eligibleItems(types: readonly string[]): Item[] {
    return this.room.items.filter((it) => it.done && it.zone !== null && types.includes(it.type));
  }

  /** Throw `n` tidied items back onto the floor. Returns how many moved. */
  protected scatter(n: number, types: readonly string[], area: Area): number {
    const cands = Phaser.Utils.Array.Shuffle(this.eligibleItems(types));
    let count = 0;
    for (const it of cands) {
      if (count >= n) break;
      const p = this.randomIn(area);
      it.scatterTo(p.x, p.y);
      count += 1;
    }
    if (count > 0) this.room.ctx.bus.emit('tasksChanged');
    return count;
  }

  protected randomFurniture(): Thing | null {
    const list = this.room.furniture.filter((f) => f.layer === 'ysort' && f.originAtBase);
    return list.length ? Phaser.Utils.Array.GetRandom(list) : null;
  }

  destroy(): void {
    this.unsub();
    this.onDestroy();
  }

  protected onDestroy(): void {}
}
