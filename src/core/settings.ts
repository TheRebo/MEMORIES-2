import { STORAGE_KEYS } from '@/config';
import { Emitter } from './emitter';
import { isRecord, num, storage } from './storage';

export interface SettingsData {
  master: number;
  music: number;
  sfx: number;
  /**
   * Screen motion: camera shake, flashes, drifting menu background, ambient dust, bobbing arrows.
   * Off by default when the OS asks for reduced motion; this is also the pause control for looping motion.
   */
  screenShake: boolean;
  /** Seconds a new dialog line stays locked, preventing accidental skips. */
  textSpeed: 'slow' | 'normal' | 'fast';
}

const prefersReducedMotion = (): boolean =>
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true;

function defaults(): SettingsData {
  return { master: 0.9, music: 0.7, sfx: 0.9, screenShake: !prefersReducedMotion(), textSpeed: 'normal' };
}

class SettingsStore {
  readonly events = new Emitter<{ changed: SettingsData }>();
  private data: SettingsData = defaults();

  load(): void {
    const raw = storage.read(STORAGE_KEYS.settings);
    const d = defaults();
    if (isRecord(raw)) {
      d.master = clamp01(num(raw['master'], d.master));
      d.music = clamp01(num(raw['music'], d.music));
      d.sfx = clamp01(num(raw['sfx'], d.sfx));
      if (typeof raw['screenShake'] === 'boolean') d.screenShake = raw['screenShake'];
      if (raw['textSpeed'] === 'slow' || raw['textSpeed'] === 'normal' || raw['textSpeed'] === 'fast') d.textSpeed = raw['textSpeed'];
    }
    this.data = d;
  }

  get value(): Readonly<SettingsData> {
    return this.data;
  }

  set<K extends keyof SettingsData>(key: K, value: SettingsData[K]): void {
    this.data[key] = value;
    storage.write(STORAGE_KEYS.settings, this.data);
    this.events.emit('changed', this.data);
  }

  /** Characters per second for typewriter text. */
  get charsPerSecond(): number {
    return { slow: 28, normal: 48, fast: 90 }[this.data.textSpeed];
  }
}

function clamp01(v: number): number {
  return Math.min(1, Math.max(0, v));
}

export const Settings = new SettingsStore();
