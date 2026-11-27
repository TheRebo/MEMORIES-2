import { GameState } from '@/core/gameState';
import { Settings, type SettingsData } from '@/core/settings';
import { ConfirmDialog } from './ConfirmDialog';
import { h } from './dom';
import { Modal } from './Modal';

type VolumeKey = 'master' | 'music' | 'sfx';

export class SettingsDialog extends Modal {
  constructor(private readonly parent2: HTMLElement, private readonly opts: { allowDelete?: boolean } = { allowDelete: true }) {
    super(parent2, 'Pengaturan');
  }

  protected build(): void {
    const form = h('div', { class: 'settings' });
    const vol = (key: VolumeKey, label: string): void => {
      const id = `vol-${key}`;
      const out = h('output', { for: id }, `${Math.round(Settings.value[key] * 100)}`);
      const input = h('input', { type: 'range', id, min: 0, max: 100, step: 5, value: Math.round(Settings.value[key] * 100) });
      input.addEventListener('input', () => {
        const v = Number(input.value) / 100;
        out.textContent = input.value;
        Settings.set(key, v);
      });
      form.append(h('div', { class: 'row' }, h('label', { for: id }, label), input, out));
    };
    vol('master', 'Utama');
    vol('music', 'Musik');
    vol('sfx', 'Efek suara');

    const shake = h('input', { type: 'checkbox', id: 'opt-shake' });
    shake.checked = Settings.value.screenShake;
    shake.addEventListener('change', () => Settings.set('screenShake', shake.checked));
    form.append(h('label', { class: 'check', for: 'opt-shake' }, shake, 'Guncangan layar & kilatan'));

    const speeds: [SettingsData['textSpeed'], string][] = [['slow', 'Lambat'], ['normal', 'Normal'], ['fast', 'Cepat']];
    const seg = h('div', { class: 'seg', role: 'group', 'aria-labelledby': 'lbl-speed' });
    for (const [v, label] of speeds) {
      const b = this.button(label, () => {
        Settings.set('textSpeed', v);
        for (const x of seg.querySelectorAll('button')) x.setAttribute('aria-pressed', String(x === b));
      }, '');
      b.setAttribute('aria-pressed', String(Settings.value.textSpeed === v));
      seg.append(b);
    }
    form.append(h('div', { class: 'row row-wide' }, h('span', { id: 'lbl-speed' }, 'Kecepatan teks'), seg));

    const fs = h('input', { type: 'checkbox', id: 'opt-fs' });
    fs.checked = document.fullscreenElement !== null;
    fs.addEventListener('change', () => {
      const req = fs.checked ? document.documentElement.requestFullscreen?.() : document.exitFullscreen?.();
      void req?.catch(() => {
        fs.checked = document.fullscreenElement !== null;
      });
    });
    if (document.fullscreenEnabled) form.append(h('label', { class: 'check', for: 'opt-fs' }, fs, 'Layar penuh'));

    const status = h('p', { class: 'muted', role: 'status', 'aria-live': 'polite' });
    const actions = h('div', { class: 'dialog-actions' });
    if (this.opts.allowDelete) {
      const del = this.button('Hapus data simpanan', () => {
        new ConfirmDialog(this.parent2, {
          title: 'Hapus data?',
          body: 'Semua progres ruangan dan level alat akan hilang. Pengaturan tetap tersimpan.',
          confirm: 'Hapus',
          onConfirm: () => {
            GameState.deleteSave();
            status.textContent = 'Data simpanan dihapus.';
          },
        }).open();
      });
      actions.append(del);
    }
    actions.append(this.button('Selesai', () => this.close(), 'btn small primary'));
    this.box.append(form, status, actions);
  }
}
