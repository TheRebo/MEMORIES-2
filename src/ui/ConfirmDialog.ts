import { h } from './dom';
import { Modal } from './Modal';

export interface ConfirmOptions {
  title: string;
  body: string;
  confirm: string;
  cancel?: string;
  onConfirm: () => void;
}

export class ConfirmDialog extends Modal {
  constructor(parent: HTMLElement, private readonly opts: ConfirmOptions) {
    super(parent, opts.title);
  }

  protected build(): void {
    const cancel = this.button(this.opts.cancel ?? 'Batal', () => this.close());
    const ok = this.button(this.opts.confirm, () => {
      this.close();
      this.opts.onConfirm();
    }, 'btn small primary');
    this.box.append(h('p', {}, this.opts.body), h('div', { class: 'dialog-actions' }, cancel, ok));
  }
}
