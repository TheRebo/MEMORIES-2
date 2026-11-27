import { Audio } from '@/core/audio';
import { Settings } from '@/core/settings';
import { CAMERA } from '@/config';
import type { CutsceneLine } from '@/data/types';
import { modalOpen } from '@/ui/Modal';
import type { Actor } from '@/world/Actor';
import type { RoomApi } from './RoomApi';

/**
 * Flashback played inside the room once it is clean: actors appear and walk, the camera frames
 * them, the room turns warm. Click/Enter advances (after a short lock), Esc skips.
 */
export class RoomCutscene {
  private advance: (() => void) | null = null;
  private skip = false;
  private lockedUntil = 0;
  private faded = false;

  private readonly onKey = (e: KeyboardEvent): void => {
    if (modalOpen()) return;
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopImmediatePropagation();
      this.skip = true;
      this.advance?.();
    } else if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      this.press();
    }
  };
  private readonly onPointer = (e: PointerEvent): void => {
    if (modalOpen() || e.button !== 0) return;
    if ((e.target as HTMLElement | null)?.closest('button')) return;
    this.press();
  };

  constructor(
    private readonly room: RoomApi,
    private readonly actors: readonly Actor[],
    private readonly ui: { dialog: (s: string, t: string) => void; hideDialog: () => void; hint: (on: boolean) => void; typing: () => boolean; finishTyping: () => void; fade: (black: boolean, ms: number) => void },
  ) {}

  async play(lines: readonly CutsceneLine[]): Promise<void> {
    const { ctx, camera, lighting } = this.room;
    ctx.cinematic = true;
    ctx.bus.emit('cinematic', true);
    camera.beginCinematic();
    window.addEventListener('keydown', this.onKey, true);
    window.addEventListener('pointerdown', this.onPointer);
    Audio.playMusic('flashback', 1.6);
    await this.wait(1000);

    for (const line of lines) {
      if (this.skip) break;
      await this.runLine(line);
    }

    this.ui.hideDialog();
    this.ui.hint(false);
    for (const a of this.actors) if (a.sprite.visible) a.vanish();
    if (this.faded) {
      this.ui.fade(false, 800);
      await this.wait(900);
    }
    await this.wait(600);
    lighting.removeTint('cutscene');
    camera.endCinematic();
    window.removeEventListener('keydown', this.onKey, true);
    window.removeEventListener('pointerdown', this.onPointer);
    ctx.cinematic = false;
    ctx.bus.emit('cinematic', false);
  }

  private async runLine(line: CutsceneLine): Promise<void> {
    const { camera, lighting } = this.room;
    if (line.fadeToBlack && !this.faded) {
      this.faded = true;
      this.ui.fade(true, 900);
      await this.wait(1000);
    }
    if (line.tint) lighting.addTint('cutscene', line.tint);
    for (const id of line.hide ?? []) this.actor(id)?.vanish();
    for (const id of line.show ?? []) this.actor(id)?.appear();
    for (const m of line.moves ?? []) void this.actor(m.actor)?.walkTo(m.x, m.y);
    if (line.focus) camera.focus(line.focus[0], line.focus[1], line.zoom ?? CAMERA.cinematicZoom);

    if (line.text) this.ui.dialog(line.speaker, line.text);
    else this.ui.hideDialog();
    this.ui.hint(false);
    // Lock scales with text speed so slow readers are not skipped past by an eager click.
    this.lockedUntil = performance.now() + (Settings.value.textSpeed === 'slow' ? 1400 : 1000);
    const hintTimer = window.setTimeout(() => this.ui.hint(true), this.lockedUntil - performance.now());
    await new Promise<void>((resolve) => {
      let auto = 0;
      this.advance = () => {
        window.clearTimeout(auto);
        this.advance = null;
        resolve();
      };
      if (line.hold) auto = window.setTimeout(() => this.advance?.(), line.hold * 1000);
    });
    window.clearTimeout(hintTimer);
  }

  private press(): void {
    if (!this.advance) return;
    if (this.ui.typing()) {
      this.ui.finishTyping();
      return;
    }
    if (performance.now() < this.lockedUntil) return;
    Audio.uiClick();
    this.advance();
  }

  private actor(id: string): Actor | undefined {
    return this.actors.find((a) => a.actorId === id);
  }

  private wait(ms: number): Promise<void> {
    return new Promise((r) => window.setTimeout(r, ms));
  }
}
