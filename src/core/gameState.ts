import { STORAGE_KEYS } from '@/config';
import { ROOM_ORDER } from '@/data/rooms';
import { levelForCount } from '@/data/tools';
import type { RoomId, ToolId } from '@/data/types';
import { Emitter } from './emitter';
import { isRecord, num, storage } from './storage';

interface SaveData {
  version: 3;
  progress: Partial<Record<RoomId, number>>;
  inventory: Record<string, number>;
  toolCounts: Partial<Record<ToolId, number>>;
  /** Fastest clean per room, in seconds. */
  bestTimes?: Partial<Record<RoomId, number>>;
  trashTotal: number;
  tutorialSeen: boolean;
  seenTutorials: string[];
}

type StateEvents = {
  inventory: void;
  trash: number;
  toolLevel: { tool: ToolId; level: number; leveledUp: boolean };
  roomCompleted: RoomId;
};

function blank(): SaveData {
  return { version: 3, progress: {}, inventory: {}, toolCounts: {}, trashTotal: 0, tutorialSeen: false, seenTutorials: [] };
}

function isRoomId(v: string): v is RoomId {
  return (ROOM_ORDER as readonly string[]).includes(v);
}

function parse(raw: unknown): SaveData | null {
  if (!isRecord(raw) || raw['version'] !== 3) return null;
  const out = blank();
  if (isRecord(raw['progress'])) {
    for (const [k, v] of Object.entries(raw['progress'])) if (isRoomId(k)) out.progress[k] = Math.min(100, Math.max(0, num(v, 0)));
  }
  if (isRecord(raw['inventory'])) {
    for (const [k, v] of Object.entries(raw['inventory'])) out.inventory[k] = Math.max(0, Math.floor(num(v, 0)));
  }
  if (isRecord(raw['bestTimes'])) {
    out.bestTimes = {};
    for (const [k, v] of Object.entries(raw['bestTimes'])) if (isRoomId(k) && num(v, 0) > 0) out.bestTimes[k] = num(v, 0);
  }
  if (isRecord(raw['toolCounts'])) {
    for (const [k, v] of Object.entries(raw['toolCounts'])) {
      if (k === 'broom' || k === 'mop' || k === 'cloth' || k === 'duster') out.toolCounts[k] = Math.max(0, Math.floor(num(v, 0)));
    }
  }
  out.trashTotal = Math.max(0, Math.floor(num(raw['trashTotal'], 0)));
  out.tutorialSeen = raw['tutorialSeen'] === true;
  if (Array.isArray(raw['seenTutorials'])) out.seenTutorials = raw['seenTutorials'].filter((x): x is string => typeof x === 'string');
  return out;
}

/** Persistent progress. Autosaves when a room is completed (as in the Godot build) and on settings-level changes. */
class GameStateStore {
  readonly events = new Emitter<StateEvents>();
  private data: SaveData = blank();

  load(): void {
    this.data = parse(storage.read(STORAGE_KEYS.save)) ?? blank();
  }

  save(): boolean {
    return storage.write(STORAGE_KEYS.save, this.data);
  }

  newGame(): void {
    this.data = blank();
    this.save();
  }

  deleteSave(): void {
    storage.remove(STORAGE_KEYS.save);
    this.data = blank();
  }

  // ---------- Rooms ----------
  progress(room: RoomId): number {
    return this.data.progress[room] ?? 0;
  }

  /** Live progress while playing. Capped below 100 until the room is formally completed. */
  setProgress(room: RoomId, pct: number): void {
    if (this.isCompleted(room)) return;
    this.data.progress[room] = Math.min(99, Math.max(0, pct));
  }

  isCompleted(room: RoomId): boolean {
    return this.progress(room) >= 100;
  }

  completeRoom(room: RoomId): void {
    this.data.progress[room] = 100;
    this.save();
    this.events.emit('roomCompleted', room);
  }

  bestTime(room: RoomId): number | null {
    return this.data.bestTimes?.[room] ?? null;
  }

  /** Records a finish time; true if it beats the previous best. */
  recordTime(room: RoomId, seconds: number): boolean {
    const prev = this.bestTime(room);
    if (prev !== null && prev <= seconds) return false;
    this.data.bestTimes = { ...this.data.bestTimes, [room]: Math.round(seconds) };
    this.save();
    return true;
  }

  /** True once any room has been finished: the menu then offers "Lanjutkan". */
  hasProgress(): boolean {
    return ROOM_ORDER.some((r) => this.isCompleted(r));
  }

  allCompleted(): boolean {
    return ROOM_ORDER.every((r) => this.isCompleted(r));
  }

  firstIncomplete(): RoomId | null {
    return ROOM_ORDER.find((r) => !this.isCompleted(r)) ?? null;
  }

  // ---------- Inventory ----------
  count(item: string): number {
    return this.data.inventory[item] ?? 0;
  }

  addItem(item: string, amount = 1): void {
    this.data.inventory[item] = this.count(item) + amount;
    this.events.emit('inventory');
  }

  takeItem(item: string, amount = 1): boolean {
    if (this.count(item) < amount) return false;
    this.data.inventory[item] = this.count(item) - amount;
    this.events.emit('inventory');
    return true;
  }

  // ---------- Trash ----------
  get trashTotal(): number {
    return this.data.trashTotal;
  }

  addTrash(delta: number): void {
    this.data.trashTotal = Math.max(0, this.data.trashTotal + delta);
    this.events.emit('trash', this.data.trashTotal);
  }

  // ---------- Tools ----------
  toolLevel(tool: ToolId): number {
    return levelForCount(this.data.toolCounts[tool] ?? 0);
  }

  addToolClean(tool: ToolId): void {
    const before = this.toolLevel(tool);
    this.data.toolCounts[tool] = (this.data.toolCounts[tool] ?? 0) + 1;
    const after = this.toolLevel(tool);
    this.events.emit('toolLevel', { tool, level: after, leveledUp: after > before });
  }

  // ---------- Tutorials ----------
  get tutorialSeen(): boolean {
    return this.data.tutorialSeen;
  }

  markTutorialSeen(): void {
    this.data.tutorialSeen = true;
  }

  hasSeen(id: string): boolean {
    return this.data.seenTutorials.includes(id);
  }

  markSeen(id: string): void {
    if (!this.hasSeen(id)) this.data.seenTutorials.push(id);
  }
}

export const GameState = new GameStateStore();
