/** Logical resolution. Canvas and DOM UI both scale from this. */
export const VIEW_W = 1280;
export const VIEW_H = 720;

/** HUD bands that cover the world (logical px). The camera keeps hotspots out from under them. */
export const HUD_TOP = 56;
export const HUD_BOTTOM = 96;
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
