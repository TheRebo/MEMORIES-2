import Phaser from 'phaser';
import { Audio } from '@/core/audio';
import { SPRITE } from '@/data/sprites';
import { DEPTH } from '@/config';

/** Wanders the floor; cleaning is blocked until it is clicked. */
export class Cockroach {
  readonly sprite: Phaser.GameObjects.Image;
  private target = { x: 0, y: 0 };
  private pause = 0;
  dead = false;

  constructor(
    private readonly scene: Phaser.Scene,
    x: number,
    y: number,
    private readonly area: Phaser.Geom.Rectangle,
    private readonly speed = 40,
  ) {
    this.sprite = scene.add.image(x, y, SPRITE.roach).setScale(0.5).setDepth(DEPTH.raised + 900);
    this.pickTarget();
  }

  private pickTarget(): void {
    this.target = { x: Phaser.Math.FloatBetween(this.area.x, this.area.right), y: Phaser.Math.FloatBetween(this.area.y, this.area.bottom) };
  }

  update(dt: number): void {
    if (this.dead) return;
    if (this.pause > 0) {
      this.pause -= dt;
      return;
    }
    const dx = this.target.x - this.sprite.x;
    const dy = this.target.y - this.sprite.y;
    const d = Math.hypot(dx, dy);
    if (d < 2) {
      if (Math.random() < 0.3) this.pause = Phaser.Math.FloatBetween(0.3, 0.9);
      this.pickTarget();
      return;
    }
    const step = Math.min(d, this.speed * dt);
    this.sprite.x += (dx / d) * step;
    this.sprite.y += (dy / d) * step;
    // Sprite faces up; rotate toward travel direction.
    this.sprite.setRotation(Math.atan2(dy, dx) + Math.PI / 2);
  }

  /** Generous hit radius: it is small and moving. */
  hit(px: number, py: number): boolean {
    return !this.dead && Phaser.Math.Distance.Between(px, py, this.sprite.x, this.sprite.y) <= 11;
  }

  squish(): void {
    if (this.dead) return;
    this.dead = true;
    Audio.sfx('shard', { volume: 0.7, detune: 120 });
    this.scene.tweens.add({ targets: this.sprite, scaleX: 0.8, scaleY: 0.2, duration: 120 });
    this.scene.tweens.add({ targets: this.sprite, alpha: 0, duration: 500, delay: 200, onComplete: () => this.sprite.destroy() });
  }
}
