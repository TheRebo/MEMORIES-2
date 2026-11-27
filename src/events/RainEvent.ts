import Phaser from 'phaser';
import { Audio, type LoopHandle } from '@/core/audio';
import { DEPTH } from '@/config';
import { SPRITE } from '@/data/sprites';
import type { EventDef } from '@/data/types';
import type { RoomApi } from '@/room/RoomApi';
import { Fx } from '@/systems/Fx';
import { type Area, RoomEvent } from './RoomEvent';

const DEFAULTS = {
  puddleCount: 4,
  puddleTaskGroup: 'Pel genangan air (hujan)',
  puddleSize: { x: 30, y: 14 },
  puddleEffort: 220,
  spawnArea: { x: 50, y: 110, w: 340, h: 190 } as Area,
  rainDuration: 14,
  rainTint: [0.78, 0.84, 1, 1] as [number, number, number, number],
};

/** Sudden heavy rain: blue gloom, lightning, and new puddles to mop. */
export class RainEvent extends RoomEvent<typeof DEFAULTS> {
  private rain: Phaser.GameObjects.Particles.ParticleEmitter | null = null;
  private loop: LoopHandle | null = null;

  constructor(room: RoomApi, def: EventDef) {
    super(room, def, DEFAULTS);
  }

  protected onStart(): void {
    const { phaser: scene, lighting, def } = this.room;
    lighting.addTint('rain', this.cfg.rainTint);
    Fx.ensureTextures(scene);
    this.rain = scene.add.particles(0, 0, 'fx_px', {
      x: { min: -40, max: def.size.w + 40 }, y: -20, lifespan: 900, speedY: { min: 300, max: 380 }, speedX: { min: -70, max: -50 },
      scaleX: 0.5, scaleY: 3, alpha: { start: 0.5, end: 0.2 }, tint: 0xc4d8ff, frequency: 8, quantity: 2,
    }).setDepth(DEPTH.weather);
    this.loop = Audio.loop('rain_heavy', 0.7, 1.2);
    this.thunder();
    scene.time.delayedCall(1800, () => this.spawnPuddles());
    scene.time.delayedCall((1.8 + this.cfg.rainDuration) * 1000, () => this.end());
  }

  private thunder(): void {
    Audio.sfx('thunder', { volume: 0.9, detune: 150 });
    this.room.ctx.bus.emit('shake', { strength: 1.5, duration: 0.5 });
    this.room.lighting.pulseFlash(1, 0.35);
  }

  private spawnPuddles(): void {
    for (let i = 0; i < this.cfg.puddleCount; i += 1) {
      const p = this.randomIn(this.cfg.spawnArea);
      const d = this.spawnDirt({
        x: p.x, y: p.y, w: this.cfg.puddleSize.x, h: this.cfg.puddleSize.y, tool: 'mop',
        effort: this.cfg.puddleEffort, group: this.cfg.puddleTaskGroup, tex: SPRITE.puddle,
      });
      Audio.sfx('drip_floor', { volume: 0.6, detune: 200 });
      this.pointAt(`puddle${i}`, () => (d.done ? null : { x: d.x, y: d.y - 10 }));
    }
    this.room.ctx.bus.emit('tasksChanged');
    this.thunder();
  }

  private end(): void {
    this.rain?.stop();
    const r = this.rain;
    this.room.phaser.time.delayedCall(1200, () => r?.destroy());
    this.rain = null;
    this.loop?.stop(1.2);
    this.loop = null;
    this.room.lighting.removeTint('rain');
    this.room.ctx.bus.emit('dialog', { speaker: 'MC', text: 'Hujannya reda... tapi lantainya jadi becek. Harus dipel!', duration: 4 });
    this.finish();
  }

  protected override onDestroy(): void {
    this.loop?.stop(0.2);
  }
}

