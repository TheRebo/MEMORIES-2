import Phaser from 'phaser';
import { Audio } from '@/core/audio';
import { SPRITE } from '@/data/sprites';
import { depthFor } from './Thing';

/** Placed during a blackout. Lights a circle, burns down, flickers, then goes out. */
export class Candle {
  readonly sprite: Phaser.GameObjects.Image;
  readonly glow: Phaser.GameObjects.Image;
  private readonly label: Phaser.GameObjects.Text;
  remaining: number;
  radius: number;
  alive = true;

  constructor(
    private readonly scene: Phaser.Scene,
    x: number,
    y: number,
    private readonly burnTime = 45,
    private readonly baseRadius = 90,
  ) {
    this.remaining = burnTime;
    this.radius = baseRadius;
    this.sprite = scene.add.image(x, y, SPRITE.candle).setOrigin(0.5, 1).setDepth(depthFor('ysort', y, 1));
    this.glow = scene.add.image(x, y - 12, Candle.glowTexture(scene)).setBlendMode(Phaser.BlendModes.ADD).setAlpha(0.55);
    this.label = scene.add
      .text(x, y - 22, '', { fontFamily: 'Cairopixel', fontSize: '8px', color: '#f4e6c8', stroke: '#120b07', strokeThickness: 2, resolution: 4 })
      .setOrigin(0.5, 1)
      .setDepth(this.sprite.depth + 1);
    this.sprite.setScale(0.2);
    scene.tweens.add({ targets: this.sprite, scale: 1, duration: 260, ease: 'Back.easeOut' });
    Audio.sfx('candle_light', { volume: 0.8 });
  }

  /** Light centre in world space. */
  get lightX(): number {
    return this.sprite.x;
  }

  get lightY(): number {
    return this.sprite.y - 10;
  }

  isLit(px: number, py: number): boolean {
    return this.alive && Phaser.Math.Distance.Between(px, py, this.lightX, this.lightY) <= this.radius;
  }

  /** Returns false once burnt out. */
  update(dt: number): boolean {
    if (!this.alive) return false;
    this.remaining -= dt;
    const fade = Phaser.Math.Clamp(this.remaining / (this.burnTime * 0.2), 0, 1);
    const flicker = 1 + (Math.random() - 0.5) * 0.08;
    this.radius = this.baseRadius * (0.55 + 0.45 * fade) * flicker;
    this.glow.setScale((this.radius * 2) / 128).setAlpha(0.4 * (0.4 + 0.6 * fade));
    this.label.setText(`${Math.max(0, Math.ceil(this.remaining))}s`);
    this.label.setColor(this.remaining < 8 ? '#f08a72' : '#f4e6c8');
    if (this.remaining <= 0) {
      this.alive = false;
      Audio.sfx('candle_out', { volume: 0.8 });
      this.scene.tweens.add({ targets: [this.sprite, this.glow, this.label], alpha: 0, duration: 400, onComplete: () => this.destroy() });
      return false;
    }
    return true;
  }

  destroy(): void {
    this.sprite.destroy();
    this.glow.destroy();
    this.label.destroy();
  }

  /** Soft radial gradient used both for the warm glow and to cut holes in the darkness. */
  static glowTexture(scene: Phaser.Scene): string {
    const key = 'light_radial';
    if (scene.textures.exists(key)) return key;
    const tex = scene.textures.createCanvas(key, 128, 128);
    if (!tex) return '__WHITE';
    const ctx = tex.getContext();
    const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
    g.addColorStop(0, 'rgba(255,214,150,1)');
    g.addColorStop(0.45, 'rgba(255,190,120,0.55)');
    g.addColorStop(1, 'rgba(255,170,90,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 128, 128);
    tex.refresh();
    return key;
  }
}
