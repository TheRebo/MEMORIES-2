import { Audio } from '@/core/audio';

/**
 * Reveals text character by character with a soft tick. The unrevealed part stays in the layout
 * (transparent) so the box never reflows, and screen readers get the full line once.
 */
export class Typewriter {
  private raf = 0;
  private full = '';
  private shown = 0;
  private onDone: (() => void) | null = null;
  private readonly visible = document.createElement('span');
  private readonly rest = document.createElement('span');
  running = false;

  constructor(private readonly el: HTMLElement) {
    this.visible.setAttribute('aria-hidden', 'true');
    this.rest.setAttribute('aria-hidden', 'true');
    this.rest.className = 'tw-rest';
  }

  start(text: string, cps: number, onDone?: () => void): void {
    this.stop();
    this.full = text;
    this.shown = 0;
    this.onDone = onDone ?? null;
    this.running = true;
    const sr = document.createElement('span');
    sr.className = 'sr-only';
    sr.textContent = text;
    this.el.replaceChildren(sr, this.visible, this.rest);
    this.render();
    const t0 = performance.now();
    const step = (): void => {
      const n = Math.min(this.full.length, Math.floor(((performance.now() - t0) / 1000) * cps));
      if (n !== this.shown) {
        if (/\S/.test(this.full.charAt(n - 1)) && n % 2 === 0) Audio.sfx('type_tick', { volume: 0.35, minGap: 45, detune: 80 });
        this.shown = n;
        this.render();
      }
      if (n >= this.full.length) this.complete();
      else this.raf = requestAnimationFrame(step);
    };
    this.raf = requestAnimationFrame(step);
  }

  finish(): void {
    if (!this.running) return;
    this.shown = this.full.length;
    this.render();
    this.complete();
  }

  stop(): void {
    cancelAnimationFrame(this.raf);
    this.running = false;
  }

  private complete(): void {
    cancelAnimationFrame(this.raf);
    this.running = false;
    const cb = this.onDone;
    this.onDone = null;
    cb?.();
  }

  private render(): void {
    this.visible.textContent = this.full.slice(0, this.shown);
    this.rest.textContent = this.full.slice(this.shown);
  }
}
