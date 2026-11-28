import Phaser from 'phaser';
import { App } from '@/app';
import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { Settings } from '@/core/settings';
import { ROOMS, ROOM_ORDER } from '@/data/rooms';
import { VIEW_H, VIEW_W } from '@/config';
import { CreditsDialog } from '@/ui/CreditsDialog';
import { ConfirmDialog } from '@/ui/ConfirmDialog';
import { h, imgButton, reducedMotion } from '@/ui/dom';
import { SettingsDialog } from '@/ui/SettingsDialog';

/** Title screen: the house from the prolog behind the team's logo. */
export class MenuScene extends Phaser.Scene {
  private layer!: HTMLDivElement;

  constructor() {
    super('Menu');
  }

  create(): void {
    const bg = this.add.image(VIEW_W / 2, VIEW_H / 2, 'cs_lobby');
    const cover = Math.max(VIEW_W / bg.width, VIEW_H / bg.height);
    bg.setScale(cover * 1.06);
    // Slow drift keeps the title alive without pulling focus from the buttons.
    // It follows the motion setting, which doubles as its pause control.
    const drift = this.tweens.add({ targets: bg, x: VIEW_W / 2 - 24, y: VIEW_H / 2 - 8, duration: 14000, yoyo: true, repeat: -1, ease: 'Sine.easeInOut', paused: reducedMotion() });
    const offMotion = Settings.events.on('changed', () => (reducedMotion() ? drift.pause() : drift.resume()));
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, offMotion);
    this.add.rectangle(0, 0, VIEW_W, VIEW_H, 0x120b07, 0.18).setOrigin(0);
    // Soft shade at the bottom so the button row reads against the grass.
    const shade = this.add.graphics();
    shade.fillGradientStyle(0x120b07, 0x120b07, 0x120b07, 0x120b07, 0, 0, 0.55, 0.55);
    shade.fillRect(0, VIEW_H - 240, VIEW_W, 240);

    // Drop anything from a room that was left unfinished; the save is the source of truth.
    GameState.load();
    Audio.playMusic('menu');
    this.buildUi();
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.layer.remove());
  }

  private buildUi(): void {
    this.layer = App.layer('menu');
    // Any finished room means there is something to lose, so a new game always asks first.
    const canContinue = GameState.hasProgress();
    const nav = h('nav', { class: 'menu-buttons', 'aria-label': 'Menu utama' });
    // The team's lettered buttons, all the 64x32 family so the row reads as one set.
    const add = (file: string, label: string, fn: () => void): HTMLButtonElement => {
      const b = imgButton(file, label, 3, 64, 32);
      b.addEventListener('click', () => {
        Audio.uiClick();
        fn();
      });
      b.addEventListener('pointerenter', () => Audio.uiHover());
      nav.append(b);
      return b;
    };

    if (canContinue) {
      add('btn_load', GameState.allCompleted() ? 'Kunjungi lagi' : 'Lanjutkan', () => this.continueGame());
      add('btn_new_game', 'Mulai baru', () => this.confirmNewGame());
    } else {
      add('btn_play', 'Mulai', () => this.newGame());
    }
    add('btn_setting', 'Pengaturan', () => {
      const d = new SettingsDialog(this.layer);
      d.onClose = () => this.rebuild();
      d.open();
    });
    add('btn_credit', 'Kredit', () => new CreditsDialog(this.layer).open());

    // The logo hangs over the roof of the house in the painting.
    const logo = h('img', { class: 'menu-logo', src: 'assets/ui/title_logo_trim.png', alt: '', width: 307, height: 79, fetchpriority: 'high' });
    // Leaves from the apple tree and smoke from the chimney keep the painting alive.
    if (!reducedMotion()) {
      const amb = h('div', { class: 'menu-ambient', 'aria-hidden': 'true' });
      const colours = ['#c9852f', '#8fae4a', '#d9a441', '#6f8f3a', '#b5532e'];
      for (let i = 0; i < 14; i++) {
        amb.append(h('span', { class: 'leaf', style: `left:${180 + ((i * 97) % 520)}px;--c:${colours[i % colours.length]};--t:${8 + (i % 5) * 1.7}s;--d:${-(i * 1.3)}s` }));
      }
      for (let i = 0; i < 4; i++) amb.append(h('span', { class: 'smoke', style: `--d:${i * 1.25}s` }));
      this.layer.append(amb);
    }
    this.layer.append(h('h1', { class: 'menu-title' }, h('span', { class: 'sr-only' }, 'Memories'), logo), nav);
    if (canContinue) this.layer.append(this.saveNote());
    queueMicrotask(() => nav.querySelector('button')?.focus());
  }

  /** Where the player left off: one line per room, the next one marked. */
  private saveNote(): HTMLElement {
    const next = GameState.firstIncomplete();
    const list = h('ol', {});
    for (const id of ROOM_ORDER) {
      const done = GameState.isCompleted(id);
      list.append(h('li', { class: done ? 'done' : id === next ? 'next' : '' },
        h('span', {}, ROOMS[id].name),
        h('span', {}, done ? 'bersih' : id === next ? 'berikutnya' : 'belum')));
    }
    return h('section', { class: 'menu-save paper', 'aria-label': 'Progres tersimpan' }, h('h2', {}, 'Catatan terakhir'), list);
  }

  /** Rebuild after settings: deleting the save changes Lanjutkan/Mulai. */
  private rebuild(): void {
    this.layer.remove();
    this.buildUi();
  }

  private continueGame(): void {
    // After the ending, the whole (clean) house can still be revisited.
    void App.go('Room', { room: GameState.firstIncomplete() ?? 'living_room' });
  }

  private confirmNewGame(): void {
    new ConfirmDialog(this.layer, {
      title: 'Mulai baru?',
      body: 'Progres ruangan yang sudah selesai akan dihapus.',
      confirm: 'Hapus & mulai',
      onConfirm: () => this.newGame(),
    }).open();
  }

  private newGame(): void {
    GameState.newGame();
    void App.go('Story', { which: 'intro' }, 900);
  }
}
