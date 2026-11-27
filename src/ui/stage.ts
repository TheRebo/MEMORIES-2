import { VIEW_H, VIEW_W } from '@/config';

/**
 * Keeps the 1280x720 DOM UI layer exactly on top of the scaled canvas,
 * so UI coordinates and the game's logical coordinates are the same numbers.
 */
export class UiStage {
  readonly root: HTMLElement;
  private scale = 1;

  constructor(root: HTMLElement, private readonly canvasHost: HTMLElement) {
    this.root = root;
    const update = (): void => this.sync();
    window.addEventListener('resize', update);
    new ResizeObserver(update).observe(canvasHost);
    this.sync();
  }

  sync(): void {
    const canvas = this.canvasHost.querySelector('canvas');
    const rect = (canvas ?? this.canvasHost).getBoundingClientRect();
    const appRect = this.root.parentElement?.getBoundingClientRect() ?? new DOMRect();
    this.scale = rect.width > 0 ? rect.width / VIEW_W : Math.min(window.innerWidth / VIEW_W, window.innerHeight / VIEW_H);
    this.root.style.left = `${rect.left - appRect.left}px`;
    this.root.style.top = `${rect.top - appRect.top}px`;
    this.root.style.transform = `scale(${this.scale})`;
  }

  /** Converts a client (viewport) point into logical UI coordinates. */
  toLogical(clientX: number, clientY: number): { x: number; y: number } {
    const r = this.root.getBoundingClientRect();
    return { x: (clientX - r.left) / this.scale, y: (clientY - r.top) / this.scale };
  }

  /** Swap the cursor style on the app root. */
  setCursor(kind: 'default' | 'hand' | 'grab' | 'drag' | 'none'): void {
    const app = this.root.parentElement;
    if (!app) return;
    app.classList.remove('cur-hand', 'cur-grab', 'cur-drag', 'cur-none');
    if (kind !== 'default') app.classList.add(`cur-${kind}`);
  }
}
