import type { RoomDef, RoomId } from '../types';
import { bedroom } from './bedroom';
import { kitchen } from './kitchen';
import { livingRoom } from './livingRoom';

export const ROOM_ORDER: readonly RoomId[] = ['living_room', 'kitchen', 'bedroom'];

export const ROOMS: Readonly<Record<RoomId, RoomDef>> = {
  living_room: livingRoom,
  kitchen,
  bedroom,
};

export function nextRoom(id: RoomId): RoomId | null {
  const i = ROOM_ORDER.indexOf(id);
  return i >= 0 && i + 1 < ROOM_ORDER.length ? (ROOM_ORDER[i + 1] ?? null) : null;
}
