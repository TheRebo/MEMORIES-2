import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { SPRITE } from '@/data/sprites';
import { CANDLE_KEY } from '@/data/tools';
import type { EventDef } from '@/data/types';
import type { RoomApi } from '@/room/RoomApi';
import { type Area, RoomEvent } from './RoomEvent';

const DEFAULTS = {
  blackoutDuration: 100,
  darkColor: [0.1, 0.1, 0.18, 1] as [number, number, number, number],
  emergencyCandles: 2,
  hintPosition: { x: 224, y: 200 },
  cobwebDelay: 12,
  cobwebInterval: 8,
  maxExtraCobwebs: 8,
  cobwebArea: { x: 10, y: 8, w: 428, h: 44 } as Area,
  cobwebSize: { x: 20, y: 16 },
  cobwebTaskGroup: 'Kemoceng jaring laba-laba baru',
  cobwebEffort: 200,
};

/** Power cut: only candle-lit spots can be cleaned; staying dark too long grows cobwebs. */
export class BlackoutEvent extends RoomEvent<typeof DEFAULTS> {
  private elapsed = 0;
  private darkTime = 0;
  private sinceWeb = 0;
  private extra = 0;
  private given = 0;
  private wasLit = true;
  private ticking = false;
  private readonly onUpdate = (_t: number, delta: number): void => this.tick(delta / 1000);

  constructor(room: RoomApi, def: EventDef) {
    super(room, def, DEFAULTS);
  }

  protected onStart(): void {
    const { ctx, lighting, candles, phaser: scene } = this.room;
    ctx.blackout = true;
    ctx.bus.emit('blackout', true);
    // The darkness layer carries the black; the tint only cools what the candles light.
    const [r, g, bl] = this.cfg.darkColor;
    lighting.addTint('blackout', [0.55 + r, 0.55 + g, 0.55 + bl, 1]);
    lighting.setBlackout(true);
    Audio.sfx('blackout_on', { volume: 0.9 });
    if (GameState.count('candle') <= 0) this.grantEmergency('Kamu menemukan sebatang lilin di laci dapur.');
    candles.onBurnOut = () => {
      if (this.running && GameState.count('candle') <= 0) this.grantEmergency('Kamu menemukan lilin cadangan!');
    };
    this.elapsed = 0;
    this.darkTime = 0;
    this.sinceWeb = 0;
    this.extra = 0;
    this.given = 0;
    this.wasLit = false;
    this.pointAt('candle', () => (this.wasLit ? null : this.cfg.hintPosition));
    ctx.bus.emit('attend', this.cfg.hintPosition);
    ctx.bus.emit('objective', `Gelap! Tahan tombol ${CANDLE_KEY.label} (atau tahan slot Lilin) lalu lepas di lantai untuk memasang lilin.`);
    if (!this.ticking) {
      scene.events.on('update', this.onUpdate);
      this.ticking = true;
    }
  }

  private grantEmergency(msg: string): void {
    if (this.given >= this.cfg.emergencyCandles) return;
    this.given += 1;
    GameState.addItem('candle', 1);
    Audio.sfx('reward', { volume: 0.7 });
    this.room.ctx.bus.emit('toast', msg);
  }

  private tick(dt: number): void {
    if (!this.running) return;
    const { ctx, candles } = this.room;
    this.elapsed += dt;
    const lit = candles.activeCount() > 0;
    if (lit !== this.wasLit) {
      this.wasLit = lit;
      if (lit) {
        ctx.bus.emit('objective', '');
      } else {
        this.pointAt('candle', () => (this.wasLit ? null : this.cfg.hintPosition));
        ctx.bus.emit('objective', `Lilin padam! Pasang lilin lagi (tombol ${CANDLE_KEY.label}) sebelum sarang laba-laba bertambah.`);
      }
    }
    if (lit) {
      this.darkTime = 0;
      this.sinceWeb = 0;
    } else {
      this.darkTime += dt;
      if (this.darkTime >= this.cfg.cobwebDelay) {
        this.sinceWeb += dt;
        if (this.sinceWeb >= this.cfg.cobwebInterval) {
          this.sinceWeb = 0;
          this.spawnCobweb();
        }
      }
    }
    if (this.elapsed >= this.cfg.blackoutDuration) this.end();
  }

  private spawnCobweb(): void {
    if (this.extra >= this.cfg.maxExtraCobwebs) return;
    this.extra += 1;
    const p = this.randomIn(this.cfg.cobwebArea);
    this.spawnDirt({
      x: p.x, y: p.y, w: this.cfg.cobwebSize.x, h: this.cfg.cobwebSize.y, tool: 'duster',
      effort: this.cfg.cobwebEffort, group: this.cfg.cobwebTaskGroup, tex: this.extra % 2 ? SPRITE.web_a : SPRITE.web_b,
    });
    this.room.ctx.bus.emit('toast', 'Sarang laba-laba bertambah!');
    this.room.ctx.bus.emit('tasksChanged');
  }

  private end(): void {
    const { ctx, lighting, candles, phaser: scene } = this.room;
    scene.events.off('update', this.onUpdate);
    this.ticking = false;
    candles.onBurnOut = null;
    this.clearPoint('candle');
    ctx.blackout = false;
    ctx.bus.emit('blackout', false);
    lighting.removeTint('blackout');
    lighting.setBlackout(false);
    Audio.sfx('blackout_off', { volume: 0.9 });
    ctx.bus.emit('objective', '');
    ctx.bus.emit('dialog', { speaker: 'MC', text: 'Listriknya menyala lagi. Syukurlah!', duration: 3.5 });
    this.finish();
  }

  protected override onDestroy(): void {
    this.room.phaser.events.off('update', this.onUpdate);
  }
}
