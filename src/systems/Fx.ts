import Phaser from 'phaser';
import { DEPTH } from '@/config';
import { reducedMotion } from '@/ui/dom';

/** Particle effects. Every emitter here is one-shot or ambient; none blocks input. */
export class Fx {
  private readonly scrub: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly sparkle: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly puff: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly motes: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly calm = reducedMotion();

  constructor(private readonly scene: Phaser.Scene, w: number, h: number) {
    Fx.ensureTextures(scene);
    this.scrub = scene.add.particles(0, 0, 'fx_px', {
      emitting: false, lifespan: { min: 250, max: 520 }, speed: { min: 12, max: 40 }, angle: { min: 200, max: 340 },
      gravityY: 60, scale: { start: 1, end: 0 }, alpha: { start: 0.9, end: 0 },
    }).setDepth(DEPTH.weather - 10);
    this.sparkle = scene.add.particles(0, 0, 'fx_star', {
      emitting: false, lifespan: { min: 380, max: 700 }, speed: { min: 18, max: 55 }, scale: { start: 1, end: 0 },
      alpha: { start: 1, end: 0 }, tint: [0xfff2b0, 0xf2b84b, 0xffffff], rotate: { min: 0, max: 90 },
    }).setDepth(DEPTH.weather - 9);
    this.puff = scene.add.particles(0, 0, 'fx_px', {
      emitting: false, lifespan: 380, speed: { min: 8, max: 26 }, angle: { min: 180, max: 360 },
      scale: { start: 2, end: 0 }, alpha: { start: 0.5, end: 0 }, tint: 0xd8cbb4,
    }).setDepth(DEPTH.weather - 11);
    this.motes = scene.add.particles(0, 0, 'fx_px', {
      x: { min: 0, max: w }, y: { min: 0, max: h }, lifespan: 6000, frequency: this.calm ? -1 : 180,
      speedX: { min: -3, max: 3 }, speedY: { min: -2, max: 2 }, scale: { min: 0.5, max: 1 },
      alpha: { start: 0, end: 0, ease: (t: number) => Math.sin(t * Math.PI) }, tint: 0xd9d0c0, quantity: 1,
    }).setDepth(DEPTH.weather - 20);
    this.setMotes(0.5, 0xd9d0c0);
  }

  static ensureTextures(scene: Phaser.Scene): void {
    if (!scene.textures.exists('fx_px')) {
      const g = scene.make.graphics({}, false);
      g.fillStyle(0xffffff).fillRect(0, 0, 2, 2).generateTexture('fx_px', 2, 2);
      g.clear().fillStyle(0xffffff).fillRect(2, 0, 1, 5).fillRect(0, 2, 5, 1).generateTexture('fx_star', 5, 5);
      g.destroy();
    }
  }

  scrubAt(x: number, y: number, tint: number): void {
    this.scrub.setParticleTint(tint);
    this.scrub.explode(this.calm ? 1 : 2, x, y);
  }

  cleanBurst(x: number, y: number): void {
    this.sparkle.explode(this.calm ? 4 : 12, x, y);
    this.puff.explode(this.calm ? 2 : 6, x, y);
  }

  puffAt(x: number, y: number, n = 6): void {
    this.puff.explode(this.calm ? 2 : n, x, y);
  }

  /** Ambient dust: dense and grey while dirty, sparse warm gold once the room is clean. */
  setMotes(alpha: number, tint: number): void {
    this.motes.setParticleTint(tint);
    this.motes.setParticleAlpha({ start: 0, end: 0, ease: (t: number) => Math.sin(t * Math.PI) * alpha });
  }

  celebrate(w: number, h: number): void {
    if (this.calm) return;
    for (let i = 0; i < 40; i += 1) {
      this.scene.time.delayedCall(i * 35, () => this.sparkle.explode(2, Phaser.Math.Between(16, w - 16), Phaser.Math.Between(40, h - 16)));
    }
  }
}
