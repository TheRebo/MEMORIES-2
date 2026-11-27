import type { EventDef } from '@/data/types';
import type { RoomApi } from '@/room/RoomApi';
import { BlackoutEvent } from './BlackoutEvent';
import { CatEvent } from './CatEvent';
import { CockroachEvent } from './CockroachEvent';
import { RainEvent } from './RainEvent';
import type { RoomEvent } from './RoomEvent';
import { WindEvent } from './WindEvent';

export function createEvent(room: RoomApi, def: EventDef): RoomEvent {
  switch (def.kind) {
    case 'cat':
      return new CatEvent(room, def);
    case 'rain':
      return new RainEvent(room, def);
    case 'blackout':
      return new BlackoutEvent(room, def);
    case 'wind':
      return new WindEvent(room, def);
    case 'cockroach':
      return new CockroachEvent(room, def);
  }
}
