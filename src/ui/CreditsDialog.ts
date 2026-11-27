import { CREDITS } from '@/data/story';
import { h } from './dom';
import { Modal } from './Modal';

export class CreditsDialog extends Modal {
  constructor(parent: HTMLElement) {
    super(parent, 'Kredit');
  }

  protected build(): void {
    const roles = h('dl', { class: 'credits' });
    for (const r of CREDITS.roles) roles.append(h('dt', { class: 'muted' }, r.role), h('dd', {}, r.name));
    const third = h('ul', { class: 'credits-third muted' }, ...CREDITS.thirdParty.map((t) => h('li', {}, t)));
    this.box.append(roles, third, h('p', {}, CREDITS.thanks), h('div', { class: 'dialog-actions' }, this.button('Kembali', () => this.close())));
  }
}
