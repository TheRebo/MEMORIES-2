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
      if (slide.sfx) Audio.sfx(slide.sfx);
      this.box.show(slide.speaker, slide.text, slide.hold);
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

    switch (still ? 'none' : (slide.motion ?? 'none')) {
      case 'busArrive': {
        const bus = this.add.image(-360, 470, 'cs_bus').setScale(0.3).setOrigin(0.5, 1);
        c.add(bus);
        this.tweens.add({ targets: bus, x: 440, duration: 2600, ease: 'Cubic.easeOut' });
        this.tweens.add({ targets: bus, y: 468, duration: 180, yoyo: true, repeat: 12 });
        break;
      }
      case 'busLeave': {
        const bus = this.add.image(440, 470, 'cs_bus').setScale(0.3).setOrigin(0.5, 1);
        c.add(bus);
        this.tweens.add({ targets: bus, x: VIEW_W + 380, duration: 3200, ease: 'Cubic.easeIn', delay: 900 });
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

  private finish(): void {
    if (this.finished) return;
    this.finished = true;
    this.box.hide();
    if (this.which === 'intro') void App.go('Room', { room: 'living_room' }, 1000);
    else void App.go('TitleCard', undefined, 1600);
  }
}
