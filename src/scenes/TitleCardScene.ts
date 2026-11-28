import Phaser from 'phaser';
import { App } from '@/app';
import { Audio } from '@/core/audio';
import { CREDITS } from '@/data/story';
import { h } from '@/ui/dom';

/** Closing card after the epilog. Returns to the menu on click, key, or after a while. */
export class TitleCardScene extends Phaser.Scene {
  private done = false;

  constructor() {
    super('TitleCard');
  }

  create(): void {
    this.done = false;
    this.cameras.main.setBackgroundColor('#0d0907');
    const layer = App.layer('titlecard interactive');
    const back = h('button', { class: 'btn small interactive', type: 'button' }, 'Kembali ke menu');
    back.addEventListener('click', () => this.leave());
    layer.append(
      h('div', { class: 'titlecard-inner' },
        h('img', { src: 'assets/ui/title_logo_trim.png', alt: 'Memories', width: 640, height: 165 }),
        h('p', { class: 'titlecard-thanks display' }, CREDITS.thanks),
        back),
    );
    queueMicrotask(() => back.focus());
    const timer = window.setTimeout(() => this.leave(), 14000);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      window.clearTimeout(timer);
      layer.remove();
    });
  }

  private leave(): void {
    if (this.done) return;
    this.done = true;
    Audio.uiClick();
    void App.go('Menu', undefined, 1200);
  }
}
