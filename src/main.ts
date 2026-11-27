import Phaser from 'phaser';
import { App } from './app';
import { VIEW_H, VIEW_W } from './config';
import { GameState } from './core/gameState';
import { Settings } from './core/settings';
import { MenuScene } from './scenes/MenuScene';
import { PreloadScene } from './scenes/PreloadScene';
import { RoomScene } from './scenes/RoomScene';
import { StoryScene } from './scenes/StoryScene';
import { TitleCardScene } from './scenes/TitleCardScene';
import { UiStage } from './ui/stage';
import './ui/styles.css';
import './ui/layout.css';

Settings.load();
GameState.load();

const gameHost = document.getElementById('game')!;
const uiRoot = document.getElementById('ui')!;

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: gameHost,
  width: VIEW_W,
  height: VIEW_H,
  pixelArt: true,
  roundPixels: true,
  backgroundColor: '#0d0907',
  disableContextMenu: true,
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  input: { activePointers: 2 },
  audio: { disableWebAudio: false },
  scene: [PreloadScene, MenuScene, StoryScene, RoomScene, TitleCardScene],
});

const stage = new UiStage(uiRoot, gameHost);
App.init(game, stage);
game.scale.on(Phaser.Scale.Events.RESIZE, () => stage.sync());
game.events.once(Phaser.Core.Events.READY, () => stage.sync());

// Fonts are part of the look; make sure they are ready before text is measured.
void document.fonts?.ready.then(() => stage.sync());
