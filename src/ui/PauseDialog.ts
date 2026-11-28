import { ConfirmDialog } from './ConfirmDialog';
import { h, imgButton } from './dom';
import { Audio } from '@/core/audio';
import { Modal } from './Modal';
import { SettingsDialog } from './SettingsDialog';

export interface PauseActions {
  roomName: string;
  percent: number;
  onTutorial: () => void;
  onMainMenu: () => void;
  /** Room already finished: leaving loses nothing. */
  roomSaved: boolean;
}

export class PauseDialog extends Modal {
  constructor(private readonly parent3: HTMLElement, private readonly actions: PauseActions) {
    super(parent3, 'Jeda');
  }

  protected build(): void {
    this.box.classList.add('pause');
    this.box.append(h('p', { class: 'pause-room' }, h('span', {}, this.actions.roomName), h('span', { class: 'display' }, `${this.actions.percent}% bersih`)));
    const list = h('div', { class: 'pause-menu' });
    const art = (file: string, label: string, w: number, fn: () => void): HTMLButtonElement => {
      const b = imgButton(file, label, 2, w, 32);
      b.addEventListener('click', () => {
        Audio.uiClick();
        fn();
      });
      b.addEventListener('pointerenter', () => Audio.uiHover());
      return b;
    };
    list.append(
      art('btn_continue_long', 'Lanjutkan', 165, () => this.close()),
      art('btn_setting_long', 'Pengaturan', 165, () => new SettingsDialog(this.parent3, { allowDelete: false }).open()),
      this.button('Tutorial', () => {
        this.close();
        this.actions.onTutorial();
      }, 'btn'),
      art('btn_quit_long', 'Menu utama', 192, () => this.leave()),
    );
    this.box.append(list);
    if (!this.actions.roomSaved) {
      this.box.append(h('p', { class: 'pause-note muted' }, 'Progres tersimpan otomatis setiap kali satu ruangan selesai.'));
    }
  }

  private leave(): void {
    if (this.actions.roomSaved) {
      this.close();
      this.actions.onMainMenu();
      return;
    }
    new ConfirmDialog(this.parent3, {
      title: 'Kembali ke menu?',
      body: 'Ruangan ini belum selesai, jadi progresnya di ruangan ini akan diulang.',
      confirm: 'Ke menu',
      onConfirm: () => {
        this.close();
        this.actions.onMainMenu();
      },
    }).open();
  }
}
