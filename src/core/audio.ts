import Phaser from 'phaser';
import type { SfxKey } from '@/data/audio';
import { Settings } from './settings';

export type MusicKey = 'menu' | 'present' | 'flashback' | 'ending';

type Snd = Phaser.Sound.WebAudioSound | Phaser.Sound.HTML5AudioSound | Phaser.Sound.NoAudioSound;

export interface LoopHandle {
  stop(fadeSeconds?: number): void;
  setVolume(v: number): void;
}

/** Music crossfades and SFX playback on top of Phaser's global sound manager. */
class AudioManager {
  private sound!: Phaser.Sound.BaseSoundManager;
  private music: Snd | null = null;
  private musicKey: MusicKey | null = null;
  private pending: MusicKey | null = null;
  private lastPlayed = new Map<string, number>();
  private loops = new Set<{ snd: Snd; base: number }>();

  init(game: Phaser.Game): void {
    this.sound = game.sound;
    this.sound.pauseOnBlur = true;
    this.sound.on(Phaser.Sound.Events.UNLOCKED, () => {
      if (this.pending) {
        const k = this.pending;
        this.pending = null;
        this.playMusic(k, 0.6);
      }
    });
    Settings.events.on('changed', () => this.applyVolumes());
  }

  private get musicVolume(): number {
    return Settings.value.music * Settings.value.master;
  }

  private get sfxVolume(): number {
    return Settings.value.sfx * Settings.value.master;
  }

  private applyVolumes(): void {
    if (this.music) this.music.setVolume(this.musicVolume);
    for (const l of this.loops) l.snd.setVolume(l.base * this.sfxVolume);
  }

  playMusic(key: MusicKey, fade = 1.2): void {
    if (this.musicKey === key && this.music?.isPlaying) return;
    if (this.sound.locked) {
      this.pending = key;
      this.musicKey = key;
      return;
    }
    const old = this.music;
    const next = this.sound.add(`music_${key}`, { loop: true, volume: 0 }) as Snd;
    this.music = next;
    this.musicKey = key;
    next.play();
    fadeTo(next, this.musicVolume, fade);
    if (old) fadeTo(old, 0, fade * 0.8, () => old.destroy());
  }

  stopMusic(fade = 1): void {
    const old = this.music;
    this.music = null;
    this.musicKey = null;
    this.pending = null;
    if (old) fadeTo(old, 0, fade, () => old.destroy());
  }

  /**
   * One-shot SFX. `minGap` (ms) drops repeats of the same key fired too quickly,
   * `detune` adds a random pitch variation so repeated sounds do not feel mechanical.
   */
  sfx(key: SfxKey, opts: { volume?: number; detune?: number; minGap?: number; rate?: number } = {}): void {
    if (!this.sound || !this.sound.game.cache.audio.exists(key)) return;
    const now = performance.now();
    const gap = opts.minGap ?? 40;
    if (now - (this.lastPlayed.get(key) ?? -Infinity) < gap) return;
    this.lastPlayed.set(key, now);
    const vol = (opts.volume ?? 1) * this.sfxVolume;
    if (vol <= 0.001) return;
    this.sound.play(key, {
      volume: vol,
      rate: opts.rate ?? 1,
      detune: opts.detune ? Phaser.Math.Between(-opts.detune, opts.detune) : 0,
    });
  }

  /** Looping ambience (rain, wind). */
  loop(key: SfxKey, volume = 1, fadeIn = 0.8): LoopHandle {
    if (!this.sound.game.cache.audio.exists(key)) return { stop: () => undefined, setVolume: () => undefined };
    const snd = this.sound.add(key, { loop: true, volume: 0 }) as Snd;
    const entry = { snd, base: volume };
    this.loops.add(entry);
    snd.play();
    fadeTo(snd, volume * this.sfxVolume, fadeIn);
    return {
      stop: (f = 0.8) => {
        this.loops.delete(entry);
        fadeTo(snd, 0, f, () => snd.destroy());
      },
      setVolume: (v: number) => {
        entry.base = v;
        snd.setVolume(v * this.sfxVolume);
      },
    };
  }

  stopAllLoops(): void {
    for (const l of [...this.loops]) {
      this.loops.delete(l);
      l.snd.destroy();
    }
  }

  uiClick(): void {
    this.sfx('ui_click', { volume: 0.8, detune: 60 });
  }

  uiHover(): void {
    this.sfx('ui_hover', { volume: 0.5, minGap: 70 });
  }
}

/** Volume fade driven by requestAnimationFrame so it keeps running while scenes are paused. */
function fadeTo(snd: Snd, target: number, seconds: number, done?: () => void): void {
  const start = (snd as { volume: number }).volume;
  const t0 = performance.now();
  const dur = Math.max(1, seconds * 1000);
  const step = (): void => {
    if (!snd.manager) return;
    const k = Math.min(1, (performance.now() - t0) / dur);
    snd.setVolume(start + (target - start) * k);
    if (k < 1) requestAnimationFrame(step);
    else done?.();
  };
  requestAnimationFrame(step);
}

export const Audio = new AudioManager();
