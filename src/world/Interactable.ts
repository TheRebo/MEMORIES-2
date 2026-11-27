import type Phaser from 'phaser';
import type { InteractDef } from '@/data/types';
import { Thing } from './Thing';

/** Double-click objects: tidy the pillow, throw out the wilted vase. */
export class Interactable extends Thing {
  readonly group: string;
  readonly trash: boolean;
  readonly label: string;
  private readonly def: InteractDef;
  private count = 0;
  done = false;
  private hovered = false;

  constructor(scene: Phaser.Scene, def: InteractDef) {
    super(scene, { ...def, originAtBase: true, layer: 'ysort', shadow: def.shadow, placeholderColor: 0x9a8aa0 });
    this.def = def;
    this.group = def.group;
    this.trash = def.trash;
    this.label = def.label;
  }

  setHover(on: boolean): void {
    if (this.done) on = false;
    if (this.hovered === on) return;
    this.hovered = on;
    this.sprite.setTint(on ? 0xfff3d6 : 0xffffff);
  }

  /** Returns true when this interaction finished the object. */
  interact(): boolean {
    if (this.done) return false;
    this.count += 1;
    this.scene.tweens.add({ targets: this.sprite, scaleX: 1.14, scaleY: 0.9, duration: 80, yoyo: true, ease: 'Quad.easeOut' });
    if (this.count < this.def.needed) return false;
    this.finish(false);
    return true;
  }

  restoreDone(): void {
    this.count = this.def.needed;
    this.finish(true);
  }

  private finish(instant: boolean): void {
    this.done = true;
    this.hovered = false;
    this.sprite.setTint(0xffffff);
    if (this.def.after) this.setTexture(this.def.after);
    if (this.def.hideAfter) {
      if (instant) this.setVisible(false);
      else {
        this.shadow?.setVisible(false);
        this.scene.tweens.add({ targets: this.sprite, alpha: 0, y: this.sprite.y - 6, duration: 260, onComplete: () => this.sprite.setVisible(false) });
      }
    }
  }
}
