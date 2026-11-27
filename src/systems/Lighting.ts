import Phaser from 'phaser';
import { DEPTH } from '@/config';
import type { Rgba } from '@/data/types';
import { Candle } from '@/world/Candle';

type Rgb = { r: number; g: number; b: number };

const DIM: Rgb = { r: 0.8, g: 0.76, b: 0.73 };
const CLEAN: Rgb = { r: 1.0, g: 0.97, b: 0.92 };
const WARM: Rgb = { r: 1.0, g: 0.9, b: 0.74 };

/**
 * Room ambience: a multiply layer that warms up as the room gets cleaner, an additive flash layer
 * (lightning, celebration), and a darkness layer with candle-shaped holes for blackouts.
 */
export class Lighting {
  private readonly tintLayer: Phaser.GameObjects.Rectangle;
  private readonly flashLayer: Phaser.GameObjects.Rectangle;
  private readonly dark: Phaser.GameObjects.RenderTexture;
  private readonly hole: Phaser.GameObjects.Image;
  private base: Rgb = { ...DIM };
  private baseTarget: Rgb = { ...DIM };
  private readonly tints = new Map<string, Rgb>();
  private current: Rgb = { ...DIM };
  private flash = 0;
  private darkness = 0;
  private darknessTarget = 0;
  private breathe = 0;
  private time = 0;

  constructor(private readonly scene: Phaser.Scene, w: number, h: number) {
    const pad = 400;
    this.tintLayer = scene.add.rectangle(-pad, -pad, w + pad * 2, h + pad * 2, 0xffffff).setOrigin(0).setDepth(DEPTH.lighting).setBlendMode(Phaser.BlendModes.MULTIPLY);
    this.flashLayer = scene.add.rectangle(-pad, -pad, w + pad * 2, h + pad * 2, 0xfff4dc).setOrigin(0).setDepth(DEPTH.flash).setBlendMode(Phaser.BlendModes.ADD).setAlpha(0);
    this.dark = scene.add.renderTexture(0, 0, w, h).setOrigin(0).setDepth(DEPTH.darkness).setVisible(false);
    this.hole = scene.make.image({ key: Candle.glowTexture(scene) }, false);
  }

  /** 0 = filthy, 1 = clean. */
  setCleanliness(t: number): void {
    this.baseTarget = lerp(DIM, CLEAN, Phaser.Math.Clamp(t, 0, 1));
  }

  setWarm(instant: boolean): void {
    this.baseTarget = { ...WARM };
    this.breathe = 0.025;
    if (instant) this.base = { ...WARM };
  }

  addTint(id: string, c: Rgba): void {
    this.tints.set(id, { r: c[0], g: c[1], b: c[2] });
  }

  removeTint(id: string): void {
    this.tints.delete(id);
  }

  pulseFlash(peak: number, seconds: number): void {
    this.scene.tweens.addCounter({
      from: 0, to: 1, duration: seconds * 1000,
      onUpdate: (tw) => {
        const v = tw.getValue() ?? 0;
        this.flash = (v < 0.25 ? v / 0.25 : 1 - (v - 0.25) / 0.75) * peak;
      },
      onComplete: () => {
        this.flash = 0;
      },
    });
  }

  setBlackout(on: boolean): void {
    this.darknessTarget = on ? 0.9 : 0;
    if (on) this.dark.setVisible(true);
  }

  update(dt: number, candles: readonly Candle[]): void {
    this.time += dt;
    const k = 1 - Math.exp(-3 * dt);
    this.base = lerp(this.base, this.baseTarget, k);
    let target = { ...this.base };
    for (const t of this.tints.values()) target = { r: target.r * t.r, g: target.g * t.g, b: target.b * t.b };
    this.current = lerp(this.current, target, 1 - Math.exp(-4 * dt));
    const b = 1 + this.breathe * Math.sin(this.time * 1.6);
    this.tintLayer.setFillStyle(Phaser.Display.Color.GetColor(ch(this.current.r * b), ch(this.current.g * b), ch(this.current.b * b)));
    this.flashLayer.setAlpha(Math.max(0, this.flash) * 0.6);

    this.darkness += (this.darknessTarget - this.darkness) * (1 - Math.exp(-2.5 * dt));
    if (this.darkness < 0.01 && this.darknessTarget === 0) {
      this.dark.setVisible(false);
      return;
    }
    this.dark.clear();
    this.dark.fill(0x05060d, this.darkness);
    for (const c of candles) {
      if (!c.alive) continue;
      const s = (c.radius * 2.4) / 128;
      this.hole.setScale(s);
      this.dark.erase(this.hole, c.lightX, c.lightY);
    }
  }
}

function lerp(a: Rgb, b: Rgb, t: number): Rgb {
  return { r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t };
}

function ch(v: number): number {
  return Math.round(Phaser.Math.Clamp(v, 0, 1) * 255);
}
