import type Phaser from 'phaser';
import type { ActorDef } from '@/data/types';
import { Thing } from './Thing';

/** Cutscene character (Nenek, young MC, adult MC). Hidden until a cutscene line shows it. */
export class Actor extends Thing {
  readonly actorId: string;
  private bob: Phaser.Tweens.Tween | null = null;

  constructor(scene: Phaser.Scene, def: ActorDef) {
    super(scene, { ...def, originAtBase: true, layer: 'ysort', shadow: true, placeholderColor: 0x6d8fc4 });
    this.actorId = def.actor;
    // The adult MC shares the young MC sprite; drawn a little taller so the two read as different ages.
    if (def.actor === 'mc') this.sprite.setScale(1.15);
    this.setVisible(false);
  }

  appear(): void {
    this.sprite.setAlpha(0);
    this.setVisible(true);
    this.scene.tweens.add({ targets: this.sprite, alpha: 1, duration: 450 });
  }

  vanish(): void {
    this.scene.tweens.add({ targets: this.sprite, alpha: 0, duration: 450, onComplete: () => this.setVisible(false) });
  }

  walkTo(x: number, y: number, speed = 40): Promise<void> {
    const dist = Math.hypot(x - this.x, y - this.y);
    if (dist < 1) return Promise.resolve();
    this.sprite.setFlipX(x < this.x);
    this.bob?.stop();
    this.bob = this.scene.tweens.add({ targets: this.sprite, scaleY: this.sprite.scaleY * 0.94, duration: 110, yoyo: true, repeat: -1 });
    return new Promise((resolve) => {
      this.scene.tweens.add({
        targets: this.sprite, x, y, duration: (dist / speed) * 1000,
        onUpdate: () => {
          this.shadow?.setPosition(this.sprite.x, this.sprite.y - 1);
          this.applyDepth();
        },
        onComplete: () => {
          this.bob?.stop();
          this.bob = null;
          this.sprite.setScale(this.actorId === 'mc' ? 1.15 : 1);
          resolve();
        },
      });
    });
  }
}
