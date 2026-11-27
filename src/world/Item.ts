import type Phaser from 'phaser';
import { DEPTH } from '@/config';
import { GameState } from '@/core/gameState';
import type { ItemDef } from '@/data/types';
import { Thing } from './Thing';
import type { Zone } from './Zone';

/** A loose item that is dragged into a matching zone (shelf, cupboard, sink, bin). */
export class Item extends Thing {
  readonly type: string;
  readonly trash: boolean;
  readonly group: string;
  readonly label: string;
  done = false;
  zone: Zone | null = null;
  private home: { x: number; y: number };
  private grab = { x: 0, y: 0 };
  private hovered = false;

  constructor(scene: Phaser.Scene, def: ItemDef) {
    super(scene, { ...def, originAtBase: true, layer: 'ysort', shadow: true, placeholderColor: 0xb09060 });
    this.type = def.type;
    this.trash = def.trash;
    this.group = def.group;
    this.label = def.label;
    this.home = { x: def.x, y: def.y };
  }

  setHover(on: boolean): void {
    if (this.hovered === on || this.done) return;
    this.hovered = on;
    this.sprite.setTint(on ? 0xfff3d6 : 0xffffff);
    this.scene.tweens.add({ targets: this.sprite, scale: on ? 1.12 : 1, duration: 90, ease: 'Quad.easeOut' });
  }

  beginDrag(px: number, py: number): void {
    // Stop the hover scale tween so it cannot fight the pick-up squash.
    this.scene.tweens.killTweensOf(this.sprite);
    this.hovered = false;
    this.sprite.setTint(0xffffff);
    this.grab = { x: this.x - px, y: this.y - py };
    this.sprite.setDepth(DEPTH.dragged);
    this.shadow?.setDepth(DEPTH.dragged - 1).setScale(1.3).setAlpha(0.6);
    this.scene.tweens.add({ targets: this.sprite, scaleX: 1.2, scaleY: 1.1, duration: 80, yoyo: false, ease: 'Back.easeOut' });
  }

  dragTo(px: number, py: number): void {
    const x = px + this.grab.x;
    const y = py + this.grab.y;
    this.sprite.setPosition(x, y - 3); // lifted off the floor
    this.shadow?.setPosition(x, y + 1);
  }

  /** Dropped somewhere invalid: glide back with a little bounce. */
  returnHome(): void {
    this.endDrag();
    this.scene.tweens.add({
      targets: this.sprite, x: this.home.x, y: this.home.y, duration: 260, ease: 'Back.easeOut',
      onUpdate: () => this.shadow?.setPosition(this.sprite.x, this.sprite.y - 1),
      onComplete: () => this.applyDepth(),
    });
  }

  /** Slide into the zone and disappear. */
  consumeInto(zone: Zone): void {
    this.zone = zone;
    this.done = true;
    this.endDrag();
    const c = zone.center();
    this.shadow?.setVisible(false);
    this.sprite.setDepth(DEPTH.dragged);
    this.scene.tweens.add({
      targets: this.sprite, x: c.x, y: c.y, scale: 0.25, alpha: 0, duration: 230, ease: 'Quad.easeIn',
      onComplete: () => this.sprite.setVisible(false),
    });
  }

  /** Knocked out of its zone (cat, wind) and lands at (x, y). */
  scatterTo(x: number, y: number): void {
    const from = this.zone ? this.zone.center() : { x: this.x, y: this.y };
    // Trash knocked out of the bin no longer counts as collected (it is counted again when re-binned).
    if (this.trash && this.zone) GameState.addTrash(-1);
    this.zone?.release(this);
    this.zone = null;
    this.done = false;
    this.home = { x, y };
    this.scene.tweens.killTweensOf(this.sprite);
    this.sprite.setVisible(true).setAlpha(1).setScale(0.5).setPosition(from.x, from.y).setTint(0xffffff);
    this.shadow?.setVisible(true).setScale(1).setAlpha(1).setPosition(x, y - 1);
    this.sprite.setDepth(DEPTH.dragged);
    const peak = Math.min(from.y, y) - 18;
    this.scene.tweens.add({ targets: this.sprite, x, duration: 520, ease: 'Linear' });
    this.scene.tweens.chain({
      targets: this.sprite,
      tweens: [
        { y: peak, duration: 220, ease: 'Quad.easeOut' },
        { y, duration: 300, ease: 'Bounce.easeOut' },
      ],
      onComplete: () => this.applyDepth(),
    });
    this.scene.tweens.add({ targets: this.sprite, scale: 1, duration: 520 });
  }

  restoreDone(zone: Zone | null): void {
    this.done = true;
    this.zone = zone;
    this.setVisible(false);
  }

  private endDrag(): void {
    this.shadow?.setScale(1).setAlpha(1);
    this.scene.tweens.add({ targets: this.sprite, scaleX: 1, scaleY: 1, duration: 90 });
    this.applyDepth();
  }
}
