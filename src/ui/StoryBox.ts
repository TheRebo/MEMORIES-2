import { Audio } from '@/core/audio';
import { Settings } from '@/core/settings';
import { modalOpen } from './Modal';
import { h } from './dom';
import { Typewriter } from './Typewriter';

interface StoryBoxHandlers {
  onAdvance: () => void;
  onSkip: () => void;
}

/**
 * Dialogue box for full-screen slides. First press finishes the line, the next press advances.
 * A short lock after each line appears stops a fast double-click from skipping text unread.
 */
export class StoryBox {
  private readonly box: HTMLDivElement;
  private readonly speaker: HTMLParagraphElement;
  private readonly text: HTMLParagraphElement;
  private readonly hint: HTMLParagraphElement;
  private readonly skip: HTMLButtonElement;
  private readonly tw: Typewriter;
  private visible = false;
  private lockedUntil = 0;
  private autoTimer = 0;

  private readonly onKey = (e: KeyboardEvent): void => {
    if (modalOpen()) return;
    if (e.key === 'Escape') {
      e.preventDefault();
      this.handlers.onSkip();
    } else if (e.key === 'Enter' || e.key === ' ') {
      if (document.activeElement === this.skip) return;
      e.preventDefault();
      this.press();
    }
  };
  private readonly onPointer = (e: PointerEvent): void => {
    if (modalOpen() || e.button !== 0 || (e.target as HTMLElement).closest('button')) return;
    this.press();
  };

  constructor(private readonly layer: HTMLDivElement, private readonly handlers: StoryBoxHandlers) {
    this.speaker = h('p', { class: 'story-speaker display' });
    this.text = h('p', { class: 'story-text' });
    this.hint = h('p', { class: 'story-hint muted', 'aria-hidden': 'true' }, 'Klik atau tekan Enter untuk lanjut');
    this.box = h('div', { class: 'story-box panel', role: 'region', 'aria-live': 'polite', 'aria-label': 'Dialog' }, this.speaker, this.text, this.hint);
    this.skip = h('button', { class: 'btn small story-skip interactive', type: 'button' }, 'Lewati');
    this.skip.addEventListener('click', () => {
      Audio.uiClick();
      handlers.onSkip();
    });
    layer.classList.add('interactive');
    layer.append(this.box, this.skip);
    this.tw = new Typewriter(this.text);
    window.addEventListener('keydown', this.onKey);
    layer.addEventListener('pointerdown', this.onPointer);
  }

  show(speaker: string, text: string, hold?: number): void {
    this.visible = true;
    this.speaker.textContent = speaker;
    this.speaker.hidden = speaker === '';
    this.box.classList.add('on');
    this.hint.classList.remove('on');
    this.lockedUntil = performance.now() + 450;
    this.tw.start(text, Settings.charsPerSecond, () => this.hint.classList.add('on'));
    window.clearTimeout(this.autoTimer);
    if (hold) this.autoTimer = window.setTimeout(() => this.advance(), hold * 1000);
  }

  hide(): void {
    this.visible = false;
    this.box.classList.remove('on');
    window.clearTimeout(this.autoTimer);
  }

  private press(): void {
    if (!this.visible || performance.now() < this.lockedUntil) return;
    if (this.tw.running) {
      this.tw.finish();
      return;
    }
    Audio.uiClick();
    this.advance();
  }

  private advance(): void {
    if (!this.visible) return;
    this.hide();
    this.handlers.onAdvance();
  }

  destroy(): void {
    window.removeEventListener('keydown', this.onKey);
    this.layer.removeEventListener('pointerdown', this.onPointer);
    this.tw.stop();
    window.clearTimeout(this.autoTimer);
    this.layer.remove();
  }
}
