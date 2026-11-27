import Phaser from 'phaser';
import { App } from '@/app';
import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { VIEW_H, VIEW_W } from '@/config';
import { CreditsDialog } from '@/ui/CreditsDialog';
import { ConfirmDialog } from '@/ui/ConfirmDialog';
import { h, reducedMotion } from '@/ui/dom';
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
    if (!reducedMotion()) {
      // Slow drift keeps the title alive without pulling focus from the buttons.
      this.tweens.add({ targets: bg, x: VIEW_W / 2 - 24, y: VIEW_H / 2 - 8, duration: 14000, yoyo: true, repeat: -1, ease: 'Sine.easeInOut' });
    }
    this.add.rectangle(0, 0, VIEW_W, VIEW_H, 0x120b07, 0.18).setOrigin(0);
    // Left-side shade so the logo and buttons sit on a calm area of the painting.
    const shade = this.add.graphics();
    shade.fillGradientStyle(0x120b07, 0x120b07, 0x120b07, 0x120b07, 0.7, 0, 0.7, 0);
    shade.fillRect(0, 0, 640, VIEW_H);

    Audio.playMusic('menu');
    this.buildUi();
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.layer.remove());
  }

  private buildUi(): void {
    this.layer = App.layer('menu');
    const canContinue = GameState.hasProgress() && !GameState.allCompleted();
    const nav = h('nav', { class: 'menu-buttons', 'aria-label': 'Menu utama' });
    const add = (label: string, fn: () => void, primary = false): HTMLButtonElement => {
      const b = h('button', { class: `btn interactive${primary ? ' primary' : ''}`, type: 'button' }, label);
      b.addEventListener('click', () => {
        Audio.uiClick();
        fn();
      });
      b.addEventListener('pointerenter', () => Audio.uiHover());
      nav.append(b);
      return b;
    };

    if (canContinue) {
      add('Lanjutkan', () => this.continueGame(), true);
      add('Mulai Baru', () => this.confirmNewGame());
    } else {
      add('Mulai', () => this.newGame(), true);
    }
    add('Pengaturan', () => {
      const d = new SettingsDialog(this.layer);
      d.onClose = () => this.rebuild();
      d.open();
    });
    add('Kredit', () => new CreditsDialog(this.layer).open());

    const logo = h('img', { class: 'menu-logo', src: 'assets/ui/title_logo.png', alt: 'Memories', width: 640, height: 360 });
    const hint = h('p', { class: 'menu-hint muted' }, 'Pulang ke rumah Nenek, bersihkan ruangan demi ruangan.');
    this.layer.append(h('header', { class: 'menu-head' }, h('h1', { class: 'sr-only' }, 'Memories'), logo, hint), nav);
    queueMicrotask(() => nav.querySelector('button')?.focus());
  }

  /** Rebuild after settings: deleting the save changes Lanjutkan/Mulai. */
  private rebuild(): void {
    this.layer.remove();
    this.buildUi();
  }

  private continueGame(): void {
    const room = GameState.firstIncomplete();
    if (room) void App.go('Room', { room });
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
