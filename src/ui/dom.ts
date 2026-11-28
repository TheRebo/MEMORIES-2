import { Settings } from '@/core/settings';

type Attrs = Record<string, string | number | boolean | undefined | null | EventListener>;
type Child = Node | string | number | false | null | undefined;

/** Tiny element builder: h('button', { class: 'btn', onclick: fn }, 'Label'). */
export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs: Attrs = {},
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith('on') && typeof v === 'function') {
      el.addEventListener(k.slice(2), v);
    } else if (k === 'class') {
      el.className = String(v);
    } else if (k === 'text') {
      el.textContent = String(v);
    } else if (v === true) {
      el.setAttribute(k, '');
    } else {
      el.setAttribute(k, String(v));
    }
  }
  for (const c of children) {
    if (c === false || c === null || c === undefined) continue;
    el.append(typeof c === 'string' || typeof c === 'number' ? String(c) : c);
  }
  return el;
}

export const asset = (path: string): string => `assets/${path}`;

/** Focus trap for modal dialogs. Returns a release function that restores previous focus. */
export function trapFocus(root: HTMLElement): () => void {
  const prev = document.activeElement as HTMLElement | null;
  const focusables = (): HTMLElement[] =>
    [...root.querySelectorAll<HTMLElement>('button, [href], input, select, [tabindex]:not([tabindex="-1"])')].filter(
      (e) => !e.hasAttribute('disabled') && e.offsetParent !== null,
    );
  const onKey = (e: KeyboardEvent): void => {
    if (e.key !== 'Tab') return;
    const list = focusables();
    if (list.length === 0) return;
    const first = list[0]!;
    const last = list[list.length - 1]!;
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  };
  root.addEventListener('keydown', onKey);
  queueMicrotask(() => focusables()[0]?.focus());
  return () => {
    root.removeEventListener('keydown', onKey);
    prev?.focus?.();
  };
}

export function reducedMotion(): boolean {
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true) return true;
  return !Settings.value.screenShake;
}

/**
 * Button drawn by the team's lettered art (PLAY, SETTING, ...). The picture carries the visible
 * word, so the accessible name comes from `label` in the player's language.
 * `scale` keeps whole-pixel scaling so the pixel letters stay crisp.
 */
export function imgButton(file: string, label: string, scale: number, w: number, hgt: number, extraClass = ''): HTMLButtonElement {
  return h('button', { class: `img-btn interactive ${extraClass}`.trim(), type: 'button', 'aria-label': label, title: label,
    style: `--w:${w * scale}px;--h:${hgt * scale}px` },
  h('img', { src: `assets/ui/${file}.png`, alt: '', width: w * scale, height: hgt * scale, draggable: 'false' }));
}
