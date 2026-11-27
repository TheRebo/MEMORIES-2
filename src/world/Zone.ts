import type Phaser from 'phaser';
import type { SpriteKey } from '@/data/sprites';
import type { ZoneDef } from '@/data/types';
import type { Item } from './Item';
import { Thing } from './Thing';

/** Drop target (shelf, cupboard, sink, bin). Its sprite changes as it fills. */
export class Zone extends Thing {
  readonly accepts: string;
  readonly capacity: number;
  readonly limit: boolean;
  readonly label: string;
  private readonly states: readonly SpriteKey[];
  private readonly byFill: boolean;
  received = 0;
  private glow = false;
  private pulse: Phaser.Tweens.Tween | null = null;

  constructor(scene: Phaser.Scene, def: ZoneDef) {
    super(scene, {
      ...def,
      tex: def.states[0] ?? def.tex,
      originAtBase: true,
      layer: 'ysort',
      shadow: def.shadow,
      placeholderColor: 0x6b4a33,
    });
    this.accepts = def.accepts;
    this.capacity = Math.max(1, def.capacity);
    this.limit = def.limit;
    this.label = def.label;
    this.states = def.states;
    this.byFill = def.statesByFill === true;
  }

  canAccept(item: Item): boolean {
    if (item.type !== this.accepts || item.done) return false;
    return !(this.limit && this.received >= this.capacity);
  }

  /** Visual cue while a matching item is being dragged: pulse, brighter when hovered. */
  setTargetState(state: 'off' | 'candidate' | 'hover'): void {
    const on = state !== 'off';
    this.sprite.setTint(state === 'hover' ? 0xfff0c0 : 0xffffff);
    if (on === this.glow && state !== 'hover') return;
    this.glow = on;
    this.pulse?.stop();
    this.sprite.setScale(this.sx, this.sy);
    if (on) {
      this.pulse = this.scene.tweens.add({ targets: this.sprite, scaleY: this.sy * 1.04, duration: 420, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    }
  }

  receive(item: Item): void {
    this.received += 1;
    this.applyState();
    item.consumeInto(this);
    this.setTargetState('off');
    this.scene.tweens.add({ targets: this.sprite, scaleX: this.sx * 1.08, scaleY: this.sy * 0.94, duration: 90, yoyo: true, delay: 180 });
  }

  release(_item: Item): void {
    this.received = Math.max(0, this.received - 1);
    this.applyState();
  }

  setFill(n: number): void {
    this.received = n;
    this.applyState();
  }

  private applyState(): void {
    if (this.states.length === 0) return;
    let idx: number;
    if (this.byFill) {
      // Bins: empty, some, full, by share of capacity.
      const ratio = this.received / this.capacity;
      idx = this.received === 0 ? 0 : Math.min(this.states.length - 1, 1 + Math.floor(ratio * (this.states.length - 1)));
    } else {
      idx = Math.min(this.received, this.states.length - 1);
    }
    const key = this.states[idx];
    if (key) this.setTexture(key);
  }
}
