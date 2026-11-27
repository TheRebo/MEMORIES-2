import type Phaser from 'phaser';
import type { ToolId } from '@/data/types';

function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i += 1) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function rng(seed: number): () => number {
  let s = seed || 1;
  return () => {
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    return ((s >>> 0) % 10000) / 10000;
  };
}

const PALETTE: Record<ToolId, readonly number[]> = {
  broom: [0x8d8170, 0xa59a88, 0x6f6455],
  mop: [0x5b4a36, 0x6d5940, 0x4a3b2b],
  cloth: [0x7a6f60, 0x948a79, 0x5f5649, 0xb0a691],
  duster: [0xbfb8ad, 0xd8d2c8, 0x9d968b],
};

/**
 * Pixel grime for dirt spots that have no drawn sprite (furniture dust, film on glass).
 * Deterministic per spot id, so a spot looks the same on every visit.
 */
export function grimeTexture(scene: Phaser.Scene, id: string, tool: ToolId, w: number, h: number): string {
  const W = Math.max(4, Math.round(w));
  const H = Math.max(3, Math.round(h));
  const key = `grime_${tool}_${W}x${H}_${hash(id) % 997}`;
  if (scene.textures.exists(key)) return key;
  const tex = scene.textures.createCanvas(key, W, H);
  if (!tex) return '__WHITE';
  const ctx = tex.getContext();
  const rand = rng(hash(id));
  const pal = PALETTE[tool];
  const pick = (): string => `#${(pal[Math.floor(rand() * pal.length)] ?? pal[0]!).toString(16).padStart(6, '0')}`;

  if (tool === 'duster') {
    // Dust film along the top edge with a few hanging threads.
    for (let x = 0; x < W; x += 1) {
      const depth = 1 + Math.floor(rand() * Math.min(3, H));
      for (let y = 0; y < depth; y += 1) {
        ctx.globalAlpha = 0.55 + rand() * 0.35;
        ctx.fillStyle = pick();
        ctx.fillRect(x, y, 1, 1);
      }
      if (rand() < 0.12) {
        ctx.globalAlpha = 0.5;
        ctx.fillRect(x, depth, 1, Math.min(H - depth, 1 + Math.floor(rand() * 3)));
      }
    }
  } else {
    // Speckled film, denser toward the middle, with a couple of streaks.
    const cx = W / 2;
    const cy = H / 2;
    const count = Math.floor(W * H * (tool === 'mop' ? 0.45 : 0.32));
    for (let i = 0; i < count; i += 1) {
      const x = Math.floor(rand() * W);
      const y = Math.floor(rand() * H);
      const d = Math.hypot((x - cx) / (W / 2), (y - cy) / (H / 2));
      if (d > 1 || rand() < d * 0.6) continue;
      ctx.globalAlpha = 0.35 + rand() * 0.45;
      ctx.fillStyle = pick();
      ctx.fillRect(x, y, rand() < 0.18 ? 2 : 1, 1);
    }
    const streaks = Math.max(1, Math.floor(W / 14));
    for (let s = 0; s < streaks; s += 1) {
      let x = Math.floor(rand() * W);
      let y = Math.floor(rand() * H);
      ctx.globalAlpha = 0.4;
      ctx.fillStyle = pick();
      for (let k = 0; k < 4 + rand() * 6; k += 1) {
        ctx.fillRect(x, y, 1, 1);
        x += rand() < 0.7 ? 1 : 0;
        y += rand() < 0.4 ? 1 : 0;
        if (x >= W || y >= H) break;
      }
    }
  }
  ctx.globalAlpha = 1;
  tex.refresh();
  return key;
}
