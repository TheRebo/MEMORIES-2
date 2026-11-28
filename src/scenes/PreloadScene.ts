import Phaser from 'phaser';
import { App } from '@/app';
import { Audio } from '@/core/audio';
import { MUSIC_KEYS, SFX_KEYS } from '@/data/audio';
import { SPRITES } from '@/data/sprites';
import type { CutsceneArt } from '@/data/story';
import { h } from '@/ui/dom';

const CUTSCENE_ART: readonly CutsceneArt[] = [
  'bus_stop', 'trees', 'door_wall', 'door_wall_window', 'hand_empty', 'hand_key', 'hand_cut_fix',
  'grave_day', 'grave_dark', 'grave_flowers',
];

/** Loads every asset with a visible progress bar and an error state with retry. */
export class PreloadScene extends Phaser.Scene {
  private layer!: HTMLDivElement;
  private failed: string[] = [];

  constructor() {
    super('Preload');
  }

  preload(): void {
    this.layer = App.layer('loading');
    const bar = h('div', { class: 'loading-fill' });
    const label = h('p', { class: 'loading-label display', role: 'status', 'aria-live': 'polite' }, 'Memuat... 0%');
    this.layer.append(
      h('div', { class: 'loading-box' },
        h('h1', { class: 'loading-title' }, h('img', { src: 'assets/ui/title_logo_trim.png', alt: 'Memories', width: 460, height: 118 })),
        h('div', { class: 'loading-track', role: 'progressbar', 'aria-label': 'Memuat aset', 'aria-valuemin': 0, 'aria-valuemax': 100 }, bar),
        label),
    );
    const track = bar.parentElement!;
    this.load.on(Phaser.Loader.Events.PROGRESS, (v: number) => {
      const pct = Math.round(v * 100);
      bar.style.width = `${pct}%`;
      track.setAttribute('aria-valuenow', String(pct));
      label.textContent = `Memuat... ${pct}%`;
    });
    this.load.on(Phaser.Loader.Events.FILE_LOAD_ERROR, (file: Phaser.Loader.File) => this.failed.push(file.key));

    for (const [key, info] of Object.entries(SPRITES)) this.load.image(key, `assets/${info.file}`);
    this.load.spritesheet('cat_run', 'assets/sprites/cat_run.png', { frameWidth: 35, frameHeight: 32 });
    for (const art of CUTSCENE_ART) this.load.image(`cs_${art}`, `assets/cutscene/${art}.png`);
    this.load.image('cs_bus', 'assets/cutscene/bus.png');
    this.load.image('cs_lobby', 'assets/ui/lobby.png');
    this.load.image('title_logo', 'assets/ui/title_logo.png');
    for (const k of MUSIC_KEYS) this.load.audio(`music_${k}`, [`assets/audio/music/${k}.ogg`, `assets/audio/music/${k}.mp3`]);
    for (const k of SFX_KEYS) this.load.audio(k, `assets/audio/sfx/${k}.wav`);
  }

  create(): void {
    if (this.failed.length > 0) {
      this.showError();
      return;
    }
    this.layer.remove();
    Audio.init(this.game);
    this.anims.create({ key: 'cat_run', frames: this.anims.generateFrameNumbers('cat_run'), frameRate: 12, repeat: -1 });
    void App.go('Menu', undefined, 500);
  }

  private showError(): void {
    this.layer.replaceChildren(
      h('div', { class: 'loading-box panel', role: 'alert' },
        h('p', { class: 'panel-title' }, 'Gagal memuat'),
        h('p', {}, `${this.failed.length} file tidak bisa dimuat. Periksa koneksi lalu coba lagi.`),
        h('p', { class: 'muted' }, this.failed.slice(0, 4).join(', ')),
        h('button', { class: 'btn primary interactive', onclick: () => window.location.reload() }, 'Coba lagi')),
    );
  }
}
