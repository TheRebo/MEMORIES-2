/** Logical resolution. Canvas and DOM UI both scale from this. */
export const VIEW_W = 1280;
export const VIEW_H = 720;

/** HUD bands that cover the world (logical px). The camera keeps hotspots out from under them. */
/** Seconds for three stars per room; two stars up to 1.5x, one star after that. */
export const STAR_PAR = { living_room: 420, kitchen: 480, bedroom: 480 } as const;

export function starsFor(par: number, seconds: number): 1 | 2 | 3 {
  return seconds <= par ? 3 : seconds <= par * 1.5 ? 2 : 1;
}

export const HUD_TOP = 92;
export const HUD_BOTTOM = 108;
/** Width the open task note takes from the left of the room (panel + gutter). */
export const HUD_TODO_W = 296;

export const CAMERA = {
  defaultZoom: 3,
  minZoom: 1.6,
  maxZoom: 5,
  zoomStep: 0.25,
  smoothing: 6,
  deadZone: 0.2,
  cinematicZoom: 3.5,
} as const;

/** Rendering depth bands. Y-sorted objects use their base y inside the 0..9999 band. */
export const DEPTH = {
  background: -3000,
  ground: -2000,
  floorDirt: -1000,
  ysort: 0,
  raised: 10000,
  dragged: 50000,
  weather: 60000,
  lighting: 70000,
  darkness: 71000,
  flash: 72000,
} as const;

export const STORAGE_KEYS = {
  save: 'memories.save.v3',
  settings: 'memories.settings.v1',
} as const;
