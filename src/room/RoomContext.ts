import { Emitter } from '@/core/emitter';
import type { RoomDef, ToolId } from '@/data/types';

export type HeldSource = 'slot' | 'key' | 'toggle';

export type RoomEvents = {
  /** Task list or done-state changed: tracker recounts. */
  tasksChanged: void;
  progress: number;
  groupDone: string;
  toast: string;
  dialog: { speaker: string; text: string; duration: number };
  dialogHide: void;
  dialogHint: boolean;
  objective: string;
  eventBar: { label: string; value: number } | null;
  hint: { x: number; y: number; text: string };
  shake: { strength: number; duration: number };
  pointer: { id: string; target: { x: number; y: number } | (() => { x: number; y: number } | null) };
  pointerClear: string;
  tutorial: { id: string; pages: readonly import('@/data/types').TutorialPage[] };
  toolChanged: { tool: ToolId | null; source: HeldSource | null };
  candleHeld: boolean;
  blackout: boolean;
  fade: { toBlack: boolean; ms: number };
  cinematic: boolean;
  roomFinished: void;
};

/**
 * Per-room runtime state shared by systems and events. Created fresh for every room visit,
 * so nothing leaks between rooms (the Godot build relied on clearing a global autoload).
 */
export class RoomContext {
  readonly bus = new Emitter<RoomEvents>();
  heldTool: ToolId | null = null;
  heldSource: HeldSource | null = null;
  holdingCandle = false;
  dragging = false;
  blackout = false;
  cinematic = false;
  private readonly blocks = new Map<string, string>();
  private readonly active = new Set<string>();
  private lastBlockedNotice = -Infinity;

  constructor(readonly def: RoomDef) {}

  // ---------- Room events in progress ----------
  beginEvent(id: string): void {
    this.active.add(id);
    this.bus.emit('tasksChanged');
  }

  endEvent(id: string): void {
    this.active.delete(id);
    this.bus.emit('tasksChanged');
  }

  get eventsActive(): boolean {
    return this.active.size > 0;
  }

  // ---------- Cleaning blocked (cockroach) ----------
  setBlocked(reason: string, on: boolean, message = ''): void {
    if (on) this.blocks.set(reason, message);
    else this.blocks.delete(reason);
  }

  get blocked(): boolean {
    return this.blocks.size > 0;
  }

  /** Rate-limited toast explaining why cleaning is blocked. */
  notifyBlocked(): void {
    const now = performance.now();
    if (now - this.lastBlockedNotice < 2500) return;
    this.lastBlockedNotice = now;
    const msg = this.blocks.values().next().value;
    if (msg) this.bus.emit('toast', msg);
  }

  /** True while the player is holding something that should suppress hover/drag. */
  get handsBusy(): boolean {
    return this.heldTool !== null || this.holdingCandle;
  }
}
