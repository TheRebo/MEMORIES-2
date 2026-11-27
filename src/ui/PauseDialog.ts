import { ConfirmDialog } from './ConfirmDialog';
import { h } from './dom';
import { Modal } from './Modal';
import { SettingsDialog } from './SettingsDialog';

export interface PauseActions {
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
    const list = h('div', { class: 'pause-menu' });
    list.append(
      this.button('Lanjutkan', () => this.close(), 'btn primary'),
      this.button('Tutorial', () => {
        this.close();
        this.actions.onTutorial();
      }, 'btn'),
      this.button('Pengaturan', () => new SettingsDialog(this.parent3, { allowDelete: false }).open(), 'btn'),
      this.button('Menu utama', () => this.leave(), 'btn'),
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
