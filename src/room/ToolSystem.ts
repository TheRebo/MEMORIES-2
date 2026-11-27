import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { TOOLS, TOOL_LEVELS, toolInfo } from '@/data/tools';
import type { ToolId } from '@/data/types';
import { modalOpen } from '@/ui/Modal';
import type { Dirt } from '@/world/Dirt';
import type { RoomApi } from './RoomApi';
import type { HeldSource } from './RoomContext';

const TAP_MS = 220;

/**
 * Holding and using cleaning tools.
 * - Hold 1-4, or hold a slot: the tool stays in hand until released (as in the Godot build).
 * - Tap a slot (or Enter on it): the tool stays in hand until tapped again, Esc or right-click.
 *   This makes the game playable on touch screens and trackpads.
 */
export class ToolSystem {
  private last = { x: 0, y: 0 };
  private slotDownAt = 0;
  private slotDownPos = { x: 0, y: 0 };
  private working = false;
  private lastDarkNotice = -Infinity;
  private lastWrongAt = -Infinity;
  private freshStroke = false;

  private readonly onKeyDown = (e: KeyboardEvent): void => {
    if (e.repeat || modalOpen() || this.room.ctx.cinematic) return;
    const t = TOOLS.find((x) => x.code === e.code);
    if (t) this.pick(t.id, 'key');
  };
  private readonly onKeyUp = (e: KeyboardEvent): void => {
    const t = TOOLS.find((x) => x.code === e.code);
    if (t && this.room.ctx.heldTool === t.id && this.room.ctx.heldSource === 'key') this.release();
  };
  private readonly onPointerUp = (e: PointerEvent): void => {
    const ctx = this.room.ctx;
    if (ctx.heldSource !== 'slot') return;
    const quick = performance.now() - this.slotDownAt < TAP_MS && Math.hypot(e.clientX - this.slotDownPos.x, e.clientY - this.slotDownPos.y) < 12;
    if (quick) {
      ctx.heldSource = 'toggle';
      this.emit();
    } else {
      this.release();
    }
  };
  /** A new press starts a fresh stroke: jumping to another spot must not count as scrubbing. */
  private readonly onPointerDown = (): void => {
    this.freshStroke = true;
  };
  private readonly onContext = (e: MouseEvent): void => {
    if (this.room.ctx.heldSource === 'toggle') {
      e.preventDefault();
      this.release();
    }
  };

  constructor(private readonly room: RoomApi, private readonly pointerScreen: () => { x: number; y: number }) {
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
    window.addEventListener('pointerup', this.onPointerUp);
    window.addEventListener('pointercancel', this.onPointerUp);
    window.addEventListener('contextmenu', this.onContext);
    window.addEventListener('pointerdown', this.onPointerDown);
  }

  /** Slot pressed with the pointer. */
  slotDown(tool: ToolId, e: PointerEvent): void {
    if (e.button !== 0 || this.room.ctx.cinematic) return;
    const ctx = this.room.ctx;
    if (ctx.heldSource === 'toggle' && ctx.heldTool === tool) {
      this.release();
      return;
    }
    this.slotDownAt = performance.now();
    this.slotDownPos = { x: e.clientX, y: e.clientY };
    this.pick(tool, 'slot');
  }

  /** Keyboard activation of a slot: sticky toggle. */
  slotActivate(tool: ToolId): void {
    const ctx = this.room.ctx;
    if (ctx.heldTool === tool) this.release();
    else this.pick(tool, 'toggle');
  }

  /** Esc while a sticky tool is held puts it down instead of pausing. */
  releaseSticky(): boolean {
    if (this.room.ctx.heldSource !== 'toggle') return false;
    this.release();
    return true;
  }

  pick(tool: ToolId, source: HeldSource): void {
    const ctx = this.room.ctx;
    // One thing in hand at a time: not while carrying an item or a candle.
    if (ctx.holdingCandle || ctx.dragging) return;
    ctx.heldTool = tool;
    ctx.heldSource = source;
    this.last = this.pointerScreen();
    Audio.sfx('pickup', { volume: 0.6, detune: 80 });
    this.emit();
  }

  release(): void {
    const ctx = this.room.ctx;
    if (ctx.heldTool === null) return;
    ctx.heldTool = null;
    ctx.heldSource = null;
    this.working = false;
    Audio.sfx('tool_drop', { volume: 0.5 });
    this.emit();
  }

  private emit(): void {
    this.room.ctx.bus.emit('toolChanged', { tool: this.room.ctx.heldTool, source: this.room.ctx.heldSource });
  }

  get isWorking(): boolean {
    return this.working;
  }

  speedOf(tool: ToolId): number {
    return 1 + (GameState.toolLevel(tool) - 1) * TOOL_LEVELS.speedBonusPerLevel;
  }

  update(): void {
    const ctx = this.room.ctx;
    const tool = ctx.heldTool;
    const p = this.pointerScreen();
    const moved = this.freshStroke ? 0 : Math.hypot(p.x - this.last.x, p.y - this.last.y);
    this.freshStroke = false;
    this.last = p;
    this.working = false;
    if (tool === null || ctx.cinematic || modalOpen() || moved < 1) return;
    if (ctx.blocked) {
      ctx.notifyBlocked();
      return;
    }
    const w = this.room.pointerWorld();
    const level = GameState.toolLevel(tool);
    const radius = 3 + (level - 1) * 0.6;
    const amount = Math.min(moved, 60) * this.speedOf(tool);
    let wrong: Dirt | null = null;
    for (const d of this.room.dirt) {
      if (d.done || !d.sprite.visible || !d.contains(w.x, w.y, radius)) continue;
      if (ctx.blackout && !this.room.candles.isLit(w.x, w.y)) {
        if (performance.now() - this.lastDarkNotice > 2500) {
          this.lastDarkNotice = performance.now();
          ctx.bus.emit('toast', 'Terlalu gelap! Pasang lilin dulu.');
        }
        continue;
      }
      const r = d.scrub(tool, amount);
      if (r === 'wrong-tool') {
        wrong = d;
        continue;
      }
      if (r === 'none') continue;
      this.working = true;
      if (r === 'cleaned') this.onCleaned(d);
    }
    if (this.working) {
      this.room.fx.scrubAt(w.x, w.y, toolInfo(tool).tint);
      Audio.sfx(toolInfo(tool).sfx, { volume: 0.55, minGap: 170, detune: 120 });
    } else if (wrong && performance.now() - this.lastWrongAt > 1400) {
      this.lastWrongAt = performance.now();
      wrong.nudge();
      Audio.sfx('wrong_tool', { volume: 0.6 });
      ctx.bus.emit('hint', { x: p.x, y: p.y, text: `Butuh: ${toolInfo(wrong.tool).name}` });
    }
  }

  private onCleaned(d: Dirt): void {
    const c = d.center();
    this.room.fx.cleanBurst(c.x, c.y);
    Audio.sfx('clean_done', { volume: 0.7, detune: 100 });
    GameState.addToolClean(d.tool);
    if (d.reward) {
      GameState.addItem(d.reward.item, d.reward.amount);
      Audio.sfx('reward', { volume: 0.8 });
      this.room.ctx.bus.emit('toast', d.reward.message || `Kamu menemukan ${d.reward.item}!`);
    }
    this.room.ctx.bus.emit('tasksChanged');
  }

  destroy(): void {
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    window.removeEventListener('pointerup', this.onPointerUp);
    window.removeEventListener('pointercancel', this.onPointerUp);
    window.removeEventListener('contextmenu', this.onContext);
    window.removeEventListener('pointerdown', this.onPointerDown);
  }
}
