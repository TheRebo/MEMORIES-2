import Phaser from 'phaser';
import { CAMERA, HUD_BOTTOM, HUD_TOP, VIEW_H, VIEW_W } from '@/config';
import { Settings } from '@/core/settings';

/**
 * Top-down camera. Pans while the pointer sits near the edge of the free area between HUD panels,
 * zooms with the wheel, shakes, and takes over for in-map cutscenes.
 */
export class CameraRig {
  private readonly cam: Phaser.Cameras.Scene2D.Camera;
  private zoom: number = CAMERA.defaultZoom;
  private targetZoom: number = CAMERA.defaultZoom;
  private pos: { x: number; y: number };
  private pan = { x: 0, y: 0 };
  private insetLeft = 0;
  private cinematic = false;
  private cinTarget: { x: number; y: number };
  private shakeT = 0;
  private shakeTotal = 0.1;
  private shakeStrength = 0;
  private pulse = 0;
  private attendUntil = 0;
  private attendTarget = { x: 0, y: 0 };
  enabled = true;

  constructor(private readonly scene: Phaser.Scene, private readonly world: { w: number; h: number }) {
    this.cam = scene.cameras.main;
    this.cam.setRoundPixels(false);
    this.pos = { x: world.w / 2, y: world.h / 2 };
    this.cinTarget = { ...this.pos };
    this.cam.setZoom(this.zoom);
    scene.input.on(Phaser.Input.Events.POINTER_WHEEL, (_p: Phaser.Input.Pointer, _o: unknown, _dx: number, dy: number) => {
      if (!this.enabled || this.cinematic) return;
      this.targetZoom = Phaser.Math.Clamp(this.targetZoom - Math.sign(dy) * CAMERA.zoomStep, CAMERA.minZoom, CAMERA.maxZoom);
    });
    this.apply();
  }

  setInsetLeft(px: number): void {
    this.insetLeft = px;
  }

  /** Screen rectangle not covered by HUD panels. */
  usable(): Phaser.Geom.Rectangle {
    if (this.cinematic) return new Phaser.Geom.Rectangle(0, 0, VIEW_W, VIEW_H);
    return new Phaser.Geom.Rectangle(this.insetLeft, HUD_TOP, VIEW_W - this.insetLeft, VIEW_H - HUD_TOP - HUD_BOTTOM);
  }

  shake(strength: number, duration: number): void {
    if (!Settings.value.screenShake) return;
    this.shakeStrength = Math.max(this.shakeT > 0 ? this.shakeStrength : 0, strength);
    this.shakeTotal = Math.max(0.05, duration);
    this.shakeT = this.shakeTotal;
  }

  /** Brief zoom-in used for the room-complete celebration. */
  zoomPulse(amount: number, seconds: number): void {
    this.scene.tweens.addCounter({
      from: 0, to: 1, duration: seconds * 1000, ease: 'Sine.easeInOut',
      onUpdate: (tw) => {
        this.pulse = Math.sin((tw.getValue() ?? 0) * Math.PI) * amount;
      },
    });
  }

  /** Briefly frame a spot that needs the player (window, cockroach), then hand control back. */
  attend(x: number, y: number, seconds = 2.2): void {
    this.attendTarget = { x, y };
    this.attendUntil = this.scene.time.now + seconds * 1000;
  }

  beginCinematic(): void {
    this.cinematic = true;
    this.cinTarget = { x: this.world.w / 2, y: this.world.h / 2 };
  }

  focus(x: number, y: number, zoom?: number): void {
    this.cinTarget = { x, y };
    if (zoom && zoom > 0) this.targetZoom = Phaser.Math.Clamp(zoom, CAMERA.minZoom, CAMERA.maxZoom);
  }

  endCinematic(): void {
    this.cinematic = false;
    this.targetZoom = CAMERA.defaultZoom;
  }

  update(dt: number, pointer: { x: number; y: number }): void {
    const k = 1 - Math.exp(-CAMERA.smoothing * dt);
    this.zoom += (this.targetZoom - this.zoom) * k;
    const usable = this.usable();
    const effZoom = this.zoom + this.pulse;
    const view = { w: usable.width / effZoom, h: usable.height / effZoom };
    let target: { x: number; y: number };
    if (this.cinematic) {
      const hw = view.w / 2;
      const hh = view.h / 2;
      target = {
        x: Phaser.Math.Clamp(this.cinTarget.x, Math.min(hw, this.world.w / 2), Math.max(hw, this.world.w - hw)),
        y: Phaser.Math.Clamp(this.cinTarget.y, Math.min(hh, this.world.h / 2), Math.max(hh, this.world.h - hh)),
      };
    } else {
      const maxPanNow = { x: Math.max(1, (this.world.w - view.w) / 2), y: Math.max(1, (this.world.h - view.h) / 2) };
      if (this.scene.time.now < this.attendUntil) {
        this.pan = {
          x: Phaser.Math.Clamp((this.attendTarget.x - this.world.w / 2) / maxPanNow.x, -1, 1),
          y: Phaser.Math.Clamp((this.attendTarget.y - this.world.h / 2) / maxPanNow.y, -1, 1),
        };
      } else if (this.enabled && usable.contains(pointer.x, pointer.y)) {
        const nx = Phaser.Math.Clamp((pointer.x - usable.centerX) / (usable.width / 2), -1, 1);
        const ny = Phaser.Math.Clamp((pointer.y - usable.centerY) / (usable.height / 2), -1, 1);
        this.pan = { x: dead(nx), y: dead(ny) };
      }
      const maxPan = { x: Math.max(0, (this.world.w - view.w) / 2), y: Math.max(0, (this.world.h - view.h) / 2) };
      target = { x: this.world.w / 2 + this.pan.x * maxPan.x, y: this.world.h / 2 + this.pan.y * maxPan.y };
    }
    this.pos.x += (target.x - this.pos.x) * k;
    this.pos.y += (target.y - this.pos.y) * k;

    let sx = 0;
    let sy = 0;
    if (this.shakeT > 0) {
      this.shakeT -= dt;
      const s = (Math.max(0, this.shakeT) / this.shakeTotal) * this.shakeStrength;
      sx = (Math.random() * 2 - 1) * s;
      sy = (Math.random() * 2 - 1) * s;
    }
    this.apply(sx, sy, effZoom);
  }

  /** Place world point `pos` at the centre of the usable screen rect. */
  private apply(sx = 0, sy = 0, zoom = this.zoom): void {
    const u = this.usable();
    this.cam.setZoom(zoom);
    const viewLeft = this.pos.x - u.centerX / zoom;
    const viewTop = this.pos.y - u.centerY / zoom;
    // Phaser zooms around the camera centre: worldView.x = scrollX + (W - W/zoom) / 2.
    this.cam.setScroll(viewLeft - (VIEW_W - VIEW_W / zoom) / 2 + sx, viewTop - (VIEW_H - VIEW_H / zoom) / 2 + sy);
  }

  worldToScreen(x: number, y: number): { x: number; y: number } {
    const z = this.cam.zoom;
    const left = this.cam.scrollX + (VIEW_W - VIEW_W / z) / 2;
    const top = this.cam.scrollY + (VIEW_H - VIEW_H / z) / 2;
    return { x: (x - left) * z, y: (y - top) * z };
  }

  screenToWorld(x: number, y: number): { x: number; y: number } {
    const z = this.cam.zoom;
    const left = this.cam.scrollX + (VIEW_W - VIEW_W / z) / 2;
    const top = this.cam.scrollY + (VIEW_H - VIEW_H / z) / 2;
    return { x: left + x / z, y: top + y / z };
  }
}

function dead(v: number): number {
  const a = Math.abs(v);
  if (a <= CAMERA.deadZone) return 0;
  return (Math.sign(v) * (a - CAMERA.deadZone)) / (1 - CAMERA.deadZone);
}
