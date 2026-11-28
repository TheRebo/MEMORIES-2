// Dump the game's data modules to JSON for the Godot port (godot/data/*.json).
import { writeFileSync } from 'node:fs';
import { ROOMS, ROOM_ORDER } from '../src/data/rooms/index';
import { SPRITES, SPRITE } from '../src/data/sprites';
import { INTRO, ENDING, START_TUTORIAL, CREDITS } from '../src/data/story';
import { TOOLS, TOOL_LEVELS, CANDLE_KEY } from '../src/data/tools';
import { SFX_KEYS, MUSIC_KEYS } from '../src/data/audio';
import { STAR_PAR, CAMERA } from '../src/config';
const out = (name: string, v: unknown): void => writeFileSync(`godot/data/${name}.json`, JSON.stringify(v, null, 1));
out('rooms', { order: ROOM_ORDER, rooms: ROOMS });
out('sprites', { sprites: SPRITES, named: SPRITE });
out('story', { intro: INTRO, ending: ENDING, start_tutorial: START_TUTORIAL, credits: CREDITS });
out('game', { tools: TOOLS, tool_levels: TOOL_LEVELS, candle_key: CANDLE_KEY, sfx: SFX_KEYS, music: MUSIC_KEYS, star_par: STAR_PAR, camera: CAMERA });
