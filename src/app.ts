import type Phaser from 'phaser';
import { h } from '@/ui/dom';
import type { UiStage } from '@/ui/stage';

export type SceneKey = 'Preload' | 'Menu' | 'Story' | 'Room' | 'TitleCard';

/** Shared handles: the Phaser game, the DOM UI stage and black-fade scene transitions. */
class AppContext {
  game!: Phaser.Game;
  stage!: UiStage;
  private fadeEl!: HTMLDivElement;
  private busy = false;

  init(game: Phaser.Game, stage: UiStage): void {
    this.game = game;
    this.stage = stage;
    this.fadeEl = h('div', { class: 'screen-fade', 'aria-hidden': 'true' });
    stage.root.append(this.fadeEl);
  }

  /** A fresh layer for a scene's DOM UI. Removed by the caller on shutdown. */
  layer(className: string): HTMLDivElement {
    const el = h('div', { class: `layer ${className}` });
    this.stage.root.insertBefore(el, this.fadeEl);
    return el;
  }

  fade(toBlack: boolean, ms: number): Promise<void> {
    this.fadeEl.style.transitionDuration = `${ms}ms`;
    this.fadeEl.classList.toggle('on', toBlack);
    return new Promise((r) => window.setTimeout(r, ms));
  }

  /** Fade to black, switch scene, fade back in. Ignores re-entry while a switch is running. */
  async go(key: SceneKey, data?: object, ms = 600): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.fadeEl.classList.add('block');
    await this.fade(true, ms / 2);
    // Stop every other live scene, including paused ones (a paused room would keep its HUD on screen).
    for (const s of this.game.scene.getScenes(false)) {
      if (s.scene.key !== key && (s.sys.isActive() || s.sys.isPaused() || s.sys.isSleeping())) this.game.scene.stop(s.scene.key);
    }
    this.game.scene.start(key, data);
    await new Promise((r) => window.setTimeout(r, 60));
    await this.fade(false, ms / 2);
    this.fadeEl.classList.remove('block');
    this.busy = false;
  }
}

export const App = new AppContext();
