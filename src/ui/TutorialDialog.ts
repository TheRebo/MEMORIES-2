import { SPRITES } from '@/data/sprites';
import type { TutorialPage } from '@/data/types';
import { h } from './dom';
import { Modal } from './Modal';

/** Paged tutorial. Left/Right arrow keys flip pages; Escape closes. */
export class TutorialDialog extends Modal {
  private index = 0;
  private readonly title = h('p', { class: 'display', style: 'margin:0 0 10px;font-size:22px;color:var(--cream)' });
  private readonly shot = h('div', { class: 'tutorial-shot', 'aria-hidden': 'true' });
  private readonly text = h('p', { class: 'tutorial-text' });
  private readonly page = h('span', { class: 'tutorial-page' });
  private prev!: HTMLButtonElement;
  private next!: HTMLButtonElement;
  private readonly onArrow = (e: KeyboardEvent): void => {
    if (e.key === 'ArrowRight') this.go(1);
    else if (e.key === 'ArrowLeft') this.go(-1);
  };

  constructor(parent: HTMLElement, private readonly pages: readonly TutorialPage[], heading = 'Cara bermain') {
    super(parent, heading);
    this.box.classList.add('tutorial');
  }

  protected build(): void {
    this.prev = this.button('Kembali', () => this.go(-1));
    this.next = this.button('Lanjut', () => this.go(1), 'btn small primary');
    const skip = this.button('Tutup', () => this.close());
    this.box.append(this.title, this.shot, this.text, h('div', { class: 'tutorial-foot' }, this.page, skip, this.prev, this.next));
    this.box.addEventListener('keydown', this.onArrow);
    this.render();
  }

  private go(d: number): void {
    const n = this.index + d;
    if (n >= this.pages.length) {
      this.close();
      return;
    }
    this.index = Math.max(0, n);
    this.render();
  }

  private render(): void {
    const p = this.pages[this.index];
    if (!p) return;
    this.title.textContent = p.title;
    this.text.textContent = p.text;
    this.page.textContent = `${this.index + 1} / ${this.pages.length}`;
    this.prev.disabled = this.index === 0;
    this.next.textContent = this.index === this.pages.length - 1 ? 'Mulai' : 'Lanjut';
    this.shot.replaceChildren();
    if (p.image) {
      this.shot.append(h('img', { src: `assets/${SPRITES[p.image].file}`, alt: '', width: 96, height: 96 }));
      this.shot.hidden = false;
    } else {
      this.shot.hidden = true;
    }
  }
}
