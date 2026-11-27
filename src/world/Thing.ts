import Phaser from 'phaser';
import { DEPTH } from '@/config';
import { SPRITES, type SpriteKey } from '@/data/sprites';

export interface ThingSpec {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
  tex?: SpriteKey | undefined;
  /** true: (x, y) is the bottom-centre. false: centre. */
  originAtBase: boolean;
  layer: 'ground' | 'ysort';
  z?: number | undefined;
  scale?: readonly [number, number] | undefined;
  shadow?: boolean | undefined;
  rotation?: number | undefined;
  placeholderColor?: number;
}

/** Depth for an object: ground layer under everything, y-sorted objects by their base y. */
export function depthFor(layer: 'ground' | 'ysort', y: number, z = 0): number {
  if (layer === 'ground') return DEPTH.ground + z * 10 + y * 0.01;
  return (z > 0 ? DEPTH.raised : DEPTH.ysort) + y;
}

/**
 * A placed sprite in the room. Its hit area follows the sprite's visible pixels (alpha bbox),
 * so 128px canvases with small art inside are only clickable where the art is.
 */
export class Thing {
  readonly id: string;
  readonly sprite: Phaser.GameObjects.Image;
  readonly shadow: Phaser.GameObjects.Ellipse | null = null;
  readonly originAtBase: boolean;
  readonly layer: 'ground' | 'ysort';
  readonly z: number;
  w: number;
  h: number;
  protected sx: number;
  protected sy: number;
  protected texKey: SpriteKey | undefined;

  constructor(protected readonly scene: Phaser.Scene, spec: ThingSpec) {
    this.id = spec.id;
    this.w = spec.w;
    this.h = spec.h;
    this.originAtBase = spec.originAtBase;
    this.layer = spec.layer;
    this.z = spec.z ?? 0;
    this.sx = spec.scale?.[0] ?? 1;
    this.sy = spec.scale?.[1] ?? 1;
    this.texKey = spec.tex;
    const key = spec.tex ?? Thing.placeholder(scene, spec.w, spec.h, spec.placeholderColor ?? 0x8a6a52);
    this.sprite = scene.add.image(spec.x, spec.y, key).setOrigin(0.5, spec.originAtBase ? 1 : 0.5).setScale(this.sx, this.sy);
    if (spec.rotation) this.sprite.setRotation(spec.rotation);
    if (spec.shadow && spec.originAtBase) {
      const sw = Math.max(6, spec.w * 0.8 * this.sx);
      const sh = Math.min(10, Math.max(3, spec.w * 0.16));
      this.shadow = scene.add.ellipse(spec.x, spec.y - 1, sw, sh, 0x000000, 0.22);
    }
    this.applyDepth();
  }

  get x(): number {
    return this.sprite.x;
  }

  get y(): number {
    return this.sprite.y;
  }

  setPosition(x: number, y: number): void {
    this.sprite.setPosition(x, y);
    this.shadow?.setPosition(x, y - 1);
  }

  applyDepth(extra = 0): void {
    const d = depthFor(this.layer, this.sprite.y, this.z) + extra;
    this.sprite.setDepth(d);
    this.shadow?.setDepth(d - 0.5);
  }

  /** World-space rectangle of the visible pixels. */
  bounds(): Phaser.Geom.Rectangle {
    const scaleX = this.sprite.scaleX;
    const scaleY = this.sprite.scaleY;
    const fullW = this.w * scaleX;
    const fullH = this.h * scaleY;
    const left = this.sprite.x - fullW / 2;
    const top = this.originAtBase ? this.sprite.y - fullH : this.sprite.y - fullH / 2;
    const info = this.texKey ? SPRITES[this.texKey] : undefined;
    if (!info) return new Phaser.Geom.Rectangle(left, top, fullW, fullH);
    const [bx, by, bw, bh] = info.bbox;
    const kx = fullW / info.w;
    const ky = fullH / info.h;
    return new Phaser.Geom.Rectangle(left + bx * kx, top + by * ky, bw * kx, bh * ky);
  }

  contains(px: number, py: number, margin = 0): boolean {
    const r = this.bounds();
    return px >= r.x - margin && px <= r.right + margin && py >= r.y - margin && py <= r.bottom + margin;
  }

  center(): { x: number; y: number } {
    const r = this.bounds();
    return { x: r.centerX, y: r.centerY };
  }

  setTexture(key: SpriteKey): void {
    this.texKey = key;
    this.sprite.setTexture(key);
    const info = SPRITES[key];
    this.w = info.w;
    this.h = info.h;
  }

  setVisible(v: boolean): void {
    this.sprite.setVisible(v);
    this.shadow?.setVisible(v);
  }

  destroy(): void {
    this.sprite.destroy();
    this.shadow?.destroy();
  }

  /** Neutral rounded box for anything still lacking art (kept honest: it reads as a placeholder). */
  static placeholder(scene: Phaser.Scene, w: number, h: number, color: number): string {
    const key = `ph_${w}x${h}_${color.toString(16)}`;
    if (scene.textures.exists(key)) return key;
    const g = scene.make.graphics({}, false);
    g.fillStyle(color, 1).fillRect(1, 1, w - 2, h - 2);
    g.lineStyle(1, 0x000000, 0.5).strokeRect(0.5, 0.5, w - 1, h - 1);
    g.generateTexture(key, Math.max(2, Math.ceil(w)), Math.max(2, Math.ceil(h)));
    g.destroy();
    return key;
  }
}
