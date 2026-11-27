import { Audio, type LoopHandle } from '@/core/audio';
import type { SpriteKey } from '@/data/sprites';
import type { EventDef } from '@/data/types';
import type { RoomApi } from '@/room/RoomApi';
import type { Thing } from '@/world/Thing';
import { type Area, RoomEvent } from './RoomEvent';

const DEFAULTS = {
  windowId: 'Jendela',
  windowOpenTexture: '' as string,
  windowHalfTexture: '' as string,
  windowClosedTexture: '' as string,
  clickGain: 0.07,
  decayPerSecond: 0.1,
  clickMargin: 6,
  shakeWhileOpen: 0.8,
  penaltyEnabled: true,
  penaltyGrace: 8,
  penaltyInterval: 10,
  scatterTypes: ['desk_item', 'clothes', 'trash'] as string[],
  scatterBase: 1,
  scatterPerTier: 0.5,
  maxScatter: 4,
  dustBase: 1,
  dustPerTier: 0.5,
  maxDust: 4,
  maxExtraDust: 20,
  floorArea: { x: 40, y: 100, w: 368, h: 200 } as Area,
  dustSize: { x: 28, y: 14 },
  dustEffort: 200,
  dustFloorGroup: 'Sapu debu tertiup angin',
  dustClothGroup: 'Lap debu tertiup angin',
};

/**
 * Wind blows the window open. Click it repeatedly to close it (progress decays if you stop).
 * While open: the camera trembles and waves of chaos scatter tidied things and add dust.
 */
export class WindEvent extends RoomEvent<typeof DEFAULTS> {
  private win: Thing | undefined;
  private original: SpriteKey | null = null;
  private progress = 0;
  private floor = 0;
  private state = 0;
  private elapsed = 0;
  private waveT = 0;
  private shakeT = 0;
  private dustTotal = 0;
  private loop: LoopHandle | null = null;
  private releaseClick: (() => void) | null = null;
  private readonly onUpdate = (_t: number, delta: number): void => this.tick(delta / 1000);

  constructor(room: RoomApi, def: EventDef) {
    super(room, def, DEFAULTS);
  }

  protected onStart(): void {
    this.win = this.room.findThing(this.cfg.windowId);
    if (!this.win) {
      this.finish();
      return;
    }
    this.original ??= (this.win.sprite.texture.key as SpriteKey);
    this.progress = 0;
    this.floor = 0;
    this.elapsed = 0;
    this.waveT = 0;
    this.dustTotal = 0;
    this.setState(0);
    Audio.sfx('door_close', { volume: 0.7 });
    this.loop = Audio.loop('wind_strong', 0.6, 1);
    const w = this.win;
    this.pointAt('window', () => ({ x: w.x, y: w.bounds().y - 4 }));
    this.room.ctx.bus.emit('objective', 'Klik jendela berkali-kali untuk menutupnya!');
    this.emitBar();
    this.releaseClick = this.room.addClickInterceptor((x, y) => this.onClick(x, y));
    this.room.phaser.events.on('update', this.onUpdate);
  }

  private setState(s: number): void {
    this.state = s;
    if (!this.win) return;
    const key = s === 0 ? this.cfg.windowOpenTexture : s === 1 ? this.cfg.windowHalfTexture : (this.cfg.windowClosedTexture || this.original);
    if (key) this.win.setTexture(key as SpriteKey);
  }

  private emitBar(): void {
    this.room.ctx.bus.emit('eventBar', { label: 'Tutup jendela!', value: this.progress });
  }

  private tick(dt: number): void {
    if (!this.running) return;
    this.progress = Math.max(this.floor, this.progress - this.cfg.decayPerSecond * dt);
    this.elapsed += dt;
    this.shakeT -= dt;
    if (this.shakeT <= 0) {
      this.room.ctx.bus.emit('shake', { strength: this.cfg.shakeWhileOpen, duration: 0.3 });
      this.shakeT = 0.4;
    }
    if (this.cfg.penaltyEnabled && this.elapsed >= this.cfg.penaltyGrace) {
      this.waveT += dt;
      if (this.waveT >= this.cfg.penaltyInterval) {
        this.waveT = 0;
        this.penaltyWave();
      }
    }
    this.emitBar();
  }

  private penaltyWave(): void {
    const c = this.cfg;
    const tier = Math.floor((this.elapsed - c.penaltyGrace) / c.penaltyInterval);
    const nScatter = Math.min(c.maxScatter, c.scatterBase + Math.floor(tier * c.scatterPerTier));
    const nDust = Math.min(c.maxDust, c.dustBase + Math.floor(tier * c.dustPerTier));
    this.scatter(nScatter, c.scatterTypes, c.floorArea);
    for (let i = 0; i < nDust; i += 1) {
      if (this.dustTotal < c.maxExtraDust) {
        const p = this.randomIn(c.floorArea);
        this.spawnDirt({ x: p.x, y: p.y, w: c.dustSize.x, h: c.dustSize.y, tool: 'broom', effort: c.dustEffort, group: c.dustFloorGroup, tex: 'debu_ulahan_daus' });
        this.dustTotal += 1;
      }
      const f = this.randomFurniture();
      if (f && this.dustTotal < c.maxExtraDust) {
        const b = f.bounds();
        this.spawnDirt({
          x: b.centerX + (Math.random() - 0.5) * b.width * 0.7,
          y: b.y + b.height * (0.15 + Math.random() * 0.6),
          w: 16, h: 10, tool: 'cloth', effort: c.dustEffort * 0.8, group: c.dustClothGroup, parent: f,
        });
        this.dustTotal += 1;
      }
    }
    Audio.sfx('rattle', { volume: 0.8 });
    this.room.ctx.bus.emit('shake', { strength: c.shakeWhileOpen * 2, duration: 0.4 });
    this.room.ctx.bus.emit('toast', 'Angin makin kencang! Barang berhamburan dan debu bertambah!');
    this.room.ctx.bus.emit('tasksChanged');
  }

  private onClick(x: number, y: number): boolean {
    const w = this.win;
    if (!w || !this.running || !w.contains(x, y, this.cfg.clickMargin)) return false;
    this.progress = Math.min(1, this.progress + this.cfg.clickGain);
    Audio.sfx('window_close', { volume: 0.45, detune: 200, minGap: 30 });
    const x0 = w.sprite.x;
    this.room.phaser.tweens.add({ targets: w.sprite, x: x0 + 1, duration: 40, yoyo: true, onComplete: () => w.sprite.setX(x0) });
    if (this.progress >= 0.5 && this.state === 0) {
      this.floor = 0.5;
      this.setState(1);
      this.room.ctx.bus.emit('toast', 'Jendela setengah tertutup! Terus klik!');
    }
    if (this.progress >= 1) this.close();
    this.emitBar();
    return true;
  }

  private close(): void {
    this.room.phaser.events.off('update', this.onUpdate);
    this.releaseClick?.();
    this.releaseClick = null;
    this.setState(2);
    Audio.sfx('window_close', { volume: 0.9 });
    this.loop?.stop(0.6);
    this.loop = null;
    this.clearPoint('window');
    this.room.ctx.bus.emit('objective', '');
    this.room.ctx.bus.emit('eventBar', null);
    this.room.ctx.bus.emit('dialog', { speaker: 'MC', text: 'Fiuh... jendelanya akhirnya tertutup.', duration: 3 });
    this.finish();
  }

  protected override onDestroy(): void {
    this.room.phaser.events.off('update', this.onUpdate);
    this.releaseClick?.();
    this.loop?.stop(0.2);
  }
}
