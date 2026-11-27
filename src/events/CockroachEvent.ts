import Phaser from 'phaser';
import type { EventDef } from '@/data/types';
import type { RoomApi } from '@/room/RoomApi';
import { Cockroach } from '@/world/Cockroach';
import { type Area, RoomEvent } from './RoomEvent';

const DEFAULTS = {
  roachCount: 1,
  roachSpeed: 40,
  walkArea: { x: 40, y: 100, w: 368, h: 200 } as Area,
  spawnPoint: { x: 224, y: 290 },
};

/** A cockroach blocks cleaning until the player clicks it. */
export class CockroachEvent extends RoomEvent<typeof DEFAULTS> {
  private roaches: Cockroach[] = [];
  private releaseClick: (() => void) | null = null;
  private readonly onUpdate = (_t: number, delta: number): void => {
    for (const r of this.roaches) r.update(delta / 1000);
  };

  constructor(room: RoomApi, def: EventDef) {
    super(room, def, DEFAULTS);
  }

  protected onStart(): void {
    const { phaser: scene, ctx } = this.room;
    const a = this.cfg.walkArea;
    const area = new Phaser.Geom.Rectangle(a.x, a.y, a.w, a.h);
    for (let i = 0; i < this.cfg.roachCount; i += 1) {
      const r = new Cockroach(scene, this.cfg.spawnPoint.x + i * 14, this.cfg.spawnPoint.y, area, this.cfg.roachSpeed);
      this.roaches.push(r);
      this.pointAt(`roach${i}`, () => (r.dead ? null : { x: r.sprite.x, y: r.sprite.y - 6 }));
    }
    ctx.setBlocked('roach', true, 'Ada kecoa! Klik kecoa itu dulu.');
    ctx.bus.emit('objective', 'Ada kecoa! Klik kecoanya agar bisa lanjut membersihkan.');
    scene.events.on('update', this.onUpdate);
    this.releaseClick = this.room.addClickInterceptor((x, y) => this.onClick(x, y));
  }

  private onClick(x: number, y: number): boolean {
    const hit = this.roaches.find((r) => r.hit(x, y));
    if (!hit) return false;
    hit.squish();
    this.room.fx.puffAt(hit.sprite.x, hit.sprite.y, 6);
    this.roaches = this.roaches.filter((r) => r !== hit);
    if (this.roaches.length === 0) this.cleared();
    return true;
  }

  private cleared(): void {
    const { phaser: scene, ctx } = this.room;
    scene.events.off('update', this.onUpdate);
    this.releaseClick?.();
    this.releaseClick = null;
    ctx.setBlocked('roach', false);
    ctx.bus.emit('objective', '');
    ctx.bus.emit('dialog', { speaker: 'MC', text: 'Hih... kecoanya sudah pergi. Lanjut bersih-bersih!', duration: 3 });
    this.finish();
  }

  protected override onDestroy(): void {
    this.room.phaser.events.off('update', this.onUpdate);
    this.releaseClick?.();
    this.room.ctx.setBlocked('roach', false);
  }
}
