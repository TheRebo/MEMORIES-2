import type Phaser from 'phaser';
import type { SpriteKey } from '@/data/sprites';
import type { DirtDef, ToolId } from '@/data/types';
import { grimeTexture } from './grime';
import { Thing } from './Thing';

export type ScrubResult = 'cleaned' | 'progress' | 'wrong-tool' | 'none';

export interface DirtSpec {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
  tool: ToolId;
  effort: number;
  group: string;
  tex?: SpriteKey | undefined;
  rotation?: number | undefined;
  reward?: DirtDef['reward'];
  /** Furniture this grime sits on; drawn just above it. */
  parent?: Thing | undefined;
}

/** A dirty spot cleaned by scrubbing with the matching tool. */
export class Dirt extends Thing {
  readonly tool: ToolId;
  readonly effort: number;
  readonly group: string;
  readonly reward: DirtDef['reward'];
  readonly parent: Thing | undefined;
  remaining: number;
  done = false;
  private wobble: Phaser.Tweens.Tween | null = null;

  constructor(scene: Phaser.Scene, spec: DirtSpec) {
    const tex = spec.tex;
    super(scene, {
      id: spec.id,
      x: spec.x,
      y: spec.y,
      w: spec.w,
      h: spec.h,
      tex,
      originAtBase: false,
      layer: spec.parent ? spec.parent.layer : 'ground',
      z: spec.parent ? spec.parent.z : 1,
      rotation: spec.rotation,
    });
    if (!tex) {
      // No drawn sprite for this spot: generate pixel grime that fits its area.
      this.sprite.setTexture(grimeTexture(scene, spec.id, spec.tool, spec.w, spec.h));
    }
    this.tool = spec.tool;
    this.effort = spec.effort;
    this.group = spec.group;
    this.reward = spec.reward;
    this.parent = spec.parent;
    this.remaining = spec.effort;
    this.applyDepth();
  }

  override applyDepth(): void {
    if (this.parent) {
      this.sprite.setDepth(this.parent.sprite.depth + 0.2);
      return;
    }
    super.applyDepth();
  }

  /** Scrub with `tool` for `amount` effort. */
  scrub(tool: ToolId, amount: number): ScrubResult {
    if (this.done) return 'none';
    if (tool !== this.tool) return 'wrong-tool';
    this.remaining = Math.max(0, this.remaining - amount);
    const ratio = this.remaining / this.effort;
    // Fade with a floor so the last bit of grime stays visible until it is truly gone.
    this.sprite.setAlpha(0.18 + 0.82 * ratio);
    if (!this.wobble?.isPlaying()) {
      this.wobble = this.scene.tweens.add({ targets: this.sprite, scaleX: this.sprite.scaleX * 1.06, duration: 60, yoyo: true });
    }
    if (this.remaining <= 0) {
      this.done = true;
      this.scene.tweens.add({ targets: this.sprite, alpha: 0, scale: 1.25, duration: 220, ease: 'Quad.easeOut', onComplete: () => this.sprite.setVisible(false) });
      return 'cleaned';
    }
    return 'progress';
  }

  /** Mark as already clean (revisiting a finished room). */
  restoreDone(): void {
    this.done = true;
    this.remaining = 0;
    this.sprite.setVisible(false);
  }

  /** Shake when scrubbed with the wrong tool. */
  nudge(): void {
    const x0 = this.sprite.x;
    this.scene.tweens.add({ targets: this.sprite, x: x0 + 1.5, duration: 40, yoyo: true, repeat: 2, onComplete: () => this.sprite.setX(x0) });
  }
}
