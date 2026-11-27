import type Phaser from 'phaser';
import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { CANDLE_KEY } from '@/data/tools';
import { modalOpen } from '@/ui/Modal';
import { Candle } from '@/world/Candle';
import type { RoomContext } from './RoomContext';

export interface CandleConfig {
  maxActive: number;
  burnTime: number;
  radius: number;
  minY: number;
}

/** Placing candles during a blackout: hold 5 (or press the candle slot), release over the floor. */
export class CandleSystem {
  readonly list: Candle[] = [];
  private source: 'key' | 'slot' | null = null;
  readonly config: CandleConfig;
  /** Fired when a candle burns out. */
  onBurnOut: (() => void) | null = null;

  private readonly onKeyDown = (e: KeyboardEvent): void => {
    if (e.repeat || e.code !== CANDLE_KEY.code || modalOpen() || this.ctx.cinematic) return;
    this.hold('key');
  };
  private readonly onKeyUp = (e: KeyboardEvent): void => {
    if (e.code === CANDLE_KEY.code && this.source === 'key') this.release();
  };
  private readonly onPointerUp = (): void => {
    if (this.source === 'slot') this.release();
  };

  constructor(
    private readonly scene: Phaser.Scene,
    private readonly ctx: RoomContext,
    private readonly pointerWorld: () => { x: number; y: number },
    private readonly pointerOverUi: () => boolean,
    config: Partial<CandleConfig> = {},
  ) {
    this.config = { maxActive: 3, burnTime: 45, radius: 200, minY: 70, ...config };
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
    window.addEventListener('pointerup', this.onPointerUp);
    window.addEventListener('pointercancel', this.onPointerUp);
  }

  slotDown(e: PointerEvent): void {
    if (e.button !== 0) return;
    this.hold('slot');
  }

  private hold(source: 'key' | 'slot'): void {
    if (GameState.count('candle') <= 0 || this.ctx.heldTool !== null || this.ctx.dragging) return;
    this.source = source;
    this.ctx.holdingCandle = true;
    Audio.sfx('pickup', { volume: 0.6 });
    this.ctx.bus.emit('candleHeld', true);
  }

  private release(): void {
    if (!this.source) return;
    this.source = null;
    this.ctx.holdingCandle = false;
    this.ctx.bus.emit('candleHeld', false);
    if (this.pointerOverUi()) return; // released over the HUD: cancel
    if (!this.ctx.blackout) {
      this.ctx.bus.emit('toast', 'Belum waktunya memasang lilin.');
      return;
    }
    if (this.activeCount() >= this.config.maxActive) {
      this.ctx.bus.emit('toast', 'Lilinnya sudah cukup banyak!');
      return;
    }
    if (!GameState.takeItem('candle')) return;
    const p = this.pointerWorld();
    const x = Math.min(Math.max(p.x, 12), this.ctx.def.size.w - 12);
    const y = Math.min(Math.max(p.y, this.config.minY), this.ctx.def.size.h - 8);
    const c = new Candle(this.scene, x, y, this.config.burnTime, this.config.radius);
    this.list.push(c);
  }

  activeCount(): number {
    return this.list.filter((c) => c.alive).length;
  }

  isLit(x: number, y: number): boolean {
    return this.list.some((c) => c.isLit(x, y));
  }

  update(dt: number): void {
    for (let i = this.list.length - 1; i >= 0; i -= 1) {
      const c = this.list[i]!;
      if (!c.update(dt)) {
        this.list.splice(i, 1);
        this.onBurnOut?.();
      }
    }
  }

  /** Lights out at the end of a blackout. */
  extinguishAll(): void {
    for (const c of this.list) {
      c.alive = false;
      this.scene.tweens.add({ targets: [c.sprite, c.glow], alpha: 0, duration: 600, onComplete: () => c.destroy() });
    }
    this.list.length = 0;
  }

  destroy(): void {
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    window.removeEventListener('pointerup', this.onPointerUp);
    window.removeEventListener('pointercancel', this.onPointerUp);
  }
}

