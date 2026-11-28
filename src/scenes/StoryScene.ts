import Phaser from 'phaser';
import { App } from '@/app';
import { Audio } from '@/core/audio';
import { VIEW_H, VIEW_W } from '@/config';
import { ENDING, INTRO, type Slide } from '@/data/story';
import { reducedMotion } from '@/ui/dom';
import { StoryBox } from '@/ui/StoryBox';

interface StoryData {
  which: 'intro' | 'ending';
}

/** Full-screen illustrated slides for the prolog and epilog. */
/** Where the bus wheels touch the road (screen px). */
const ROAD_Y = 676;

export class StoryScene extends Phaser.Scene {
  private slides: readonly Slide[] = [];
  private which: StoryData['which'] = 'intro';
  private index = -1;
  private box!: StoryBox;
  private art: Phaser.GameObjects.Container | null = null;
  private transitioning = false;
  private finished = false;

  constructor() {
    super('Story');
  }

  init(data: StoryData): void {
    this.which = data.which ?? 'intro';
    this.slides = this.which === 'intro' ? INTRO : ENDING;
    this.index = -1;
    this.transitioning = false;
    this.finished = false;
    this.art = null;
  }

  create(): void {
    this.cameras.main.setBackgroundColor('#0d0907');
    Audio.playMusic(this.which === 'intro' ? 'present' : 'ending', 1.6);
    this.box = new StoryBox(App.layer('story'), {
      onAdvance: () => this.next(),
      onSkip: () => this.finish(),
    });
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.box.destroy());
    this.next();
  }

  private next(): void {
    if (this.transitioning || this.finished) return;
    this.index += 1;
    const slide = this.slides[this.index];
    if (!slide) {
      this.finish();
      return;
    }
    this.transitioning = true;
    this.box.hide();
    const old = this.art;
    const fresh = this.buildArt(slide);
    fresh.setAlpha(0);
    this.tweens.add({ targets: fresh, alpha: 1, duration: old ? 500 : 900, ease: 'Sine.easeOut' });
    if (old) this.tweens.add({ targets: old, alpha: 0, duration: 400, onComplete: () => old.destroy() });
    this.art = fresh;
    this.time.delayedCall(old ? 450 : 700, () => {
      this.transitioning = false;
      if (this.finished) return;
      if (slide.sfx) Audio.sfx(slide.sfx);
      this.box.show(slide.speaker, slide.text, slide.hold, slide.box);
    });
  }

  private buildArt(slide: Slide): Phaser.GameObjects.Container {
    const c = this.add.container(0, 0);
    const still = reducedMotion();
    if (slide.art === 'hand_cut_fix') {
      c.add(this.add.rectangle(0, 0, VIEW_W, VIEW_H, 0x2e2118).setOrigin(0));
      const hand = this.add.image(VIEW_W / 2 + 80, still ? 470 : 820, 'cs_hand_cut_fix').setScale(1.25);
      c.add(hand);
      if (!still) this.tweens.add({ targets: hand, y: 470, duration: 1400, ease: 'Back.easeOut', delay: 300 });
      return c;
    }
    const key = slide.art === 'lobby' ? 'cs_lobby' : `cs_${slide.art}`;
    const img = this.add.image(VIEW_W / 2, VIEW_H / 2, key);
    const cover = Math.max(VIEW_W / img.width, VIEW_H / img.height);
    img.setScale(cover);
    c.add(img);
    if (slide.dim) c.add(this.add.rectangle(0, 0, VIEW_W, VIEW_H, 0x000000, slide.dim).setOrigin(0));

    // The prolog painting has no ground (the trunks run off the bottom edge), so the bus slides
    // get a strip of grass and a village dirt road for the wheels to sit on.
    const busSlide = slide.motion === 'busArrive' || slide.motion === 'busLeave';
    if (busSlide) c.add(this.ground());
    const busAt = (x: number): Phaser.GameObjects.Image => {
      const bus = this.add.image(x, ROAD_Y, 'cs_bus').setScale(0.36).setOrigin(0.5, 0.985);
      c.add([this.add.ellipse(x, ROAD_Y - 2, 470, 22, 0x000000, 0.28), bus]);
      return bus;
    };

    switch (still ? (busSlide ? 'busStill' : 'none') : (slide.motion ?? 'none')) {
      case 'busStill':
        busAt(520);
        break;
      case 'busArrive': {
        const bus = busAt(-360);
        const shadow = c.list[c.list.length - 2] as Phaser.GameObjects.Ellipse;
        this.tweens.add({ targets: [bus, shadow], x: 520, duration: 2600, ease: 'Cubic.easeOut' });
        // Engine idle: a small body bounce while it rolls, settling as it stops.
        this.tweens.add({ targets: bus, y: ROAD_Y - 3, duration: 160, yoyo: true, repeat: 12, ease: 'Sine.easeInOut' });
        this.dust(c, 520, 2600);
        break;
      }
      case 'busLeave': {
        const bus = busAt(520);
        const shadow = c.list[c.list.length - 2] as Phaser.GameObjects.Ellipse;
        this.tweens.add({ targets: [bus, shadow], x: VIEW_W + 420, duration: 3200, ease: 'Cubic.easeIn', delay: 900 });
        this.tweens.add({ targets: bus, y: ROAD_Y - 3, duration: 150, yoyo: true, repeat: 20, delay: 900 });
        break;
      }
      case 'panRight':
        img.setScale(cover * 1.12).setX(VIEW_W / 2 + 60);
        this.tweens.add({ targets: img, x: VIEW_W / 2 - 60, duration: 12000, ease: 'Sine.easeInOut' });
        break;
      case 'slowZoom':
        this.tweens.add({ targets: img, scale: cover * 1.06, duration: 10000, ease: 'Sine.easeOut' });
        break;
      default:
        break;
    }
    return c;
  }

  /** Grass bank and a rutted dirt road, drawn in the painting's 8px pixel grid and palette. */
  private ground(): Phaser.GameObjects.Graphics {
    const g = this.add.graphics();
    const P = 8;
    const grassTop = 600;
    g.fillStyle(0x1f5a3a).fillRect(0, grassTop, VIEW_W, VIEW_H - grassTop);
    // Ragged grass edge so it reads as a bank, not a ruler line.
    g.fillStyle(0x2f7d3b);
    for (let x = 0; x < VIEW_W; x += P) {
      const bump = ((x * 7919) % 23) % 3;
      g.fillRect(x, grassTop - bump * P, P, P * (2 + bump));
    }
    g.fillStyle(0x3d9446);
    for (let x = 0; x < VIEW_W; x += P * 3) g.fillRect(x + ((x / P) % 2) * P, grassTop + P, P, P);
    // Road: packed earth, two darker wheel ruts and a lighter crown.
    g.fillStyle(0x7a5a48).fillRect(0, ROAD_Y - 34, VIEW_W, VIEW_H - (ROAD_Y - 34));
    g.fillStyle(0x8c6a52).fillRect(0, ROAD_Y - 26, VIEW_W, 12);
    g.fillStyle(0x5f4436).fillRect(0, ROAD_Y - 6, VIEW_W, P).fillRect(0, ROAD_Y + 26, VIEW_W, P);
    g.fillStyle(0x2f7d3b);
    for (let x = 0; x < VIEW_W; x += P) if (((x * 31) % 17) % 4 === 0) g.fillRect(x, ROAD_Y - 34, P, P);
    // Pebbles.
    g.fillStyle(0xb89a7a);
    for (let x = 12; x < VIEW_W; x += 72) g.fillRect(x, ROAD_Y + 10 + ((x * 13) % 3) * P, P, P / 2);
    return g;
  }

  /** Puffs of road dust behind the wheels while the bus brakes. */
  private dust(c: Phaser.GameObjects.Container, stopX: number, ms: number): void {
    for (let i = 0; i < 10; i++) {
      this.time.delayedCall(ms * 0.35 + i * 120, () => {
        const puff = this.add.circle(stopX - 200 + Math.random() * 30, ROAD_Y - 6, 6 + Math.random() * 6, 0xc8b49a, 0.7);
        c.add(puff);
        this.tweens.add({ targets: puff, x: puff.x - 40 - Math.random() * 40, y: puff.y - 18, scale: 2.2, alpha: 0, duration: 900, onComplete: () => puff.destroy() });
      });
    }
  }

  private finish(): void {
    if (this.finished) return;
    this.finished = true;
    this.box.hide();
    if (this.which === 'intro') void App.go('Room', { room: 'living_room' }, 1000);
    else void App.go('TitleCard', undefined, 1600);
  }
}
