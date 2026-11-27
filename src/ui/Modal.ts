import { Audio } from '@/core/audio';
import { h, trapFocus } from './dom';

const stack: Modal[] = [];
/** True while any modal dialog is open (gameplay input ignores the world then). */
export const modalOpen = (): boolean => stack.length > 0;

/** Base dialog: backdrop, focus trap, Escape closes, focus returns to the opener. */
export abstract class Modal {
  protected readonly backdrop: HTMLDivElement;
  protected readonly box: HTMLDivElement;
  private release: (() => void) | null = null;
  private readonly onKey = (e: KeyboardEvent): void => {
    // Nested dialogs (confirm over settings): only the top-most one handles Escape.
    if (e.key === 'Escape' && this.closable && stack[stack.length - 1] === this) {
      e.preventDefault();
      e.stopPropagation();
      this.close();
    }
  };
  onClose: (() => void) | null = null;

  constructor(
    private readonly parent: HTMLElement,
    title: string,
    protected closable = true,
  ) {
    const id = `dlg-${Math.random().toString(36).slice(2, 8)}`;
    this.box = h('div', { class: 'panel modal', role: 'dialog', 'aria-modal': 'true', 'aria-labelledby': id });
    this.box.append(h('h2', { class: 'panel-title', id }, title));
    this.backdrop = h('div', { class: 'modal-backdrop' }, this.box);
  }

  protected abstract build(): void;

  open(): this {
    this.build();
    this.parent.append(this.backdrop);
    stack.push(this);
    this.release = trapFocus(this.box);
    window.addEventListener('keydown', this.onKey, true);
    return this;
  }

  close(): void {
    if (!this.backdrop.isConnected) return;
    Audio.uiClick();
    window.removeEventListener('keydown', this.onKey, true);
    this.backdrop.remove();
    const i = stack.indexOf(this);
    if (i >= 0) stack.splice(i, 1);
    this.release?.();
    this.onClose?.();
  }

  protected button(label: string, fn: () => void, cls = 'btn small'): HTMLButtonElement {
    const b = h('button', { class: `${cls} interactive`, type: 'button' }, label);
    b.addEventListener('click', () => {
      Audio.uiClick();
      fn();
    });
    b.addEventListener('pointerenter', () => Audio.uiHover());
    return b;
  }
}
