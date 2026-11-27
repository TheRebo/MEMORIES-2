import Phaser from 'phaser';
import { Audio } from '@/core/audio';
import { DEPTH } from '@/config';
import type { EventDef } from '@/data/types';
import type { RoomApi } from '@/room/RoomApi';
import { type Area, RoomEvent } from './RoomEvent';

const DEFAULTS = {
  shakeStrength: 2.5,
  shakeDuration: 0.6,
  scatterCount: 4,
  minItemsNeeded: 2,
  runSpeed: 90,
  catEntry: { x: 540, y: 200 },
  catExit: { x: -30, y: 260 },
  floorArea: { x: 60, y: 110, w: 392, h: 210 } as Area,
};

const SCATTER_TYPES = ['book', 'pajangan', 'trash'] as const;

/** A cat runs in and knocks tidied things back onto the floor. */
export class CatEvent extends RoomEvent<typeof DEFAULTS> {
  constructor(room: RoomApi, def: EventDef) {
    super(room, def, DEFAULTS);
  }

  protected override canStart(pct: number): boolean {
    return pct >= 85 || this.eligibleItems(SCATTER_TYPES).length >= this.cfg.minItemsNeeded;
  }

  protected onStart(): void {
    void this.run();
  }

  private async run(): Promise<void> {
    const { phaser: scene, ctx } = this.room;
    Audio.sfx('meow', { detune: 120 });
    ctx.bus.emit('shake', { strength: this.cfg.shakeStrength, duration: this.cfg.shakeDuration });
    await this.delay(900);
    const cat = scene.add.sprite(this.cfg.catEntry.x, this.cfg.catEntry.y, 'cat_run').setOrigin(0.5, 1).play('cat_run');
    this.pointAt('cat', () => (cat.active ? { x: cat.x, y: cat.y - 24 } : null));
    let left = this.cfg.scatterCount;
    let total = 0;
    for (let i = 0; i < 3; i += 1) {
      const p = this.randomIn(this.cfg.floorArea);
      await this.runTo(cat, p.x, p.y);
      const n = Math.ceil(left / (3 - i));
      const moved = this.scatter(n, SCATTER_TYPES, this.cfg.floorArea);
      left -= moved;
      total += moved;
      if (moved > 0) Audio.sfx('rattle', { volume: 0.7, detune: 100 });
      Audio.sfx('meow', { detune: 200, volume: 0.8 });
      ctx.bus.emit('shake', { strength: this.cfg.shakeStrength * 0.6, duration: 0.35 });
    }
    await this.runTo(cat, this.cfg.catExit.x, this.cfg.catExit.y);
    this.clearPoint('cat');
    cat.destroy();
    if (total > 0) ctx.bus.emit('dialog', { speaker: 'MC', text: 'Aduh... barang-barangnya berantakan lagi!', duration: 3.5 });
    this.finish();
  }

  private runTo(cat: Phaser.GameObjects.Sprite, x: number, y: number): Promise<void> {
    const dist = Phaser.Math.Distance.Between(cat.x, cat.y, x, y);
    // Sprite art faces left.
    cat.setFlipX(x > cat.x);
    return new Promise((resolve) => {
      this.room.phaser.tweens.add({
        targets: cat, x, y, duration: (Math.max(dist, 1) / this.cfg.runSpeed) * 1000,
        onUpdate: () => cat.setDepth(DEPTH.raised + cat.y),
        onComplete: () => resolve(),
      });
    });
  }

  private delay(ms: number): Promise<void> {
    return new Promise((r) => this.room.phaser.time.delayedCall(ms, r));
  }
}
