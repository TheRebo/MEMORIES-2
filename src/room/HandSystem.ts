import { App } from '@/app';
import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { modalOpen } from '@/ui/Modal';
import type { Interactable } from '@/world/Interactable';
import type { Item } from '@/world/Item';
import type { Zone } from '@/world/Zone';
import type { RoomApi } from './RoomApi';

const DOUBLE_MS = 380;
const PICK_MARGIN = 3;

/**
 * Empty-hand interaction: hover feedback, dragging items into zones, and double-clicking objects.
 * Valid zones pulse while a matching item is carried, so the destination is never a guess.
 */
export class HandSystem {
  private dragging: Item | null = null;
  private hoverItem: Item | null = null;
  private hoverInteract: Interactable | null = null;
  private hoverZone: Zone | null = null;
  private lastDown = { t: -Infinity, x: 0, y: 0, target: null as Interactable | null };

  private readonly onUp = (): void => this.drop();

  constructor(
    private readonly room: RoomApi,
    private readonly interacts: readonly Interactable[],
    private readonly onHoverLabel: (text: string | null) => void,
  ) {
    window.addEventListener('pointerup', this.onUp);
    window.addEventListener('pointercancel', this.onUp);
  }

  /** Canvas pointerdown (already filtered: not over the HUD, no modal). */
  pointerDown(x: number, y: number, button: number): void {
    const ctx = this.room.ctx;
    if (button !== 0 || ctx.handsBusy || ctx.cinematic || this.dragging) return;

    const target = this.pickInteractable(x, y);
    const now = performance.now();
    if (target && this.lastDown.target === target && now - this.lastDown.t < DOUBLE_MS && Math.hypot(x - this.lastDown.x, y - this.lastDown.y) < 10) {
      this.lastDown.t = -Infinity;
      if (ctx.blocked) {
        ctx.notifyBlocked();
        return;
      }
      this.interact(target);
      return;
    }
    this.lastDown = { t: now, x, y, target };

    const item = this.pickItem(x, y);
    if (!item) {
      if (target) Audio.sfx('ui_hover', { volume: 0.4 });
      return;
    }
    if (ctx.blocked) {
      ctx.notifyBlocked();
      return;
    }
    this.startDrag(item, x, y);
  }

  update(): void {
    const ctx = this.room.ctx;
    const p = this.room.pointerWorld();
    if (this.dragging) {
      this.dragging.dragTo(p.x, p.y);
      const z = this.findZone(p.x, p.y, this.dragging);
      if (z !== this.hoverZone) {
        this.hoverZone?.setTargetState('candidate');
        this.hoverZone = z;
        z?.setTargetState('hover');
        if (z) Audio.sfx('ui_hover', { volume: 0.4 });
      }
      App.stage.setCursor('drag');
      return;
    }
    if (ctx.handsBusy || ctx.cinematic || modalOpen()) {
      this.setHover(null, null);
      App.stage.setCursor(ctx.handsBusy && !ctx.cinematic ? 'none' : 'default');
      this.onHoverLabel(null);
      return;
    }
    const item = this.pickItem(p.x, p.y);
    const inter = item ? null : this.pickInteractable(p.x, p.y);
    this.setHover(item, inter);
    App.stage.setCursor(item ? 'grab' : inter ? 'hand' : 'default');
    this.onHoverLabel(inter ? `${inter.label}: klik 2x` : item ? item.label : null);
  }

  private setHover(item: Item | null, inter: Interactable | null): void {
    if (item !== this.hoverItem) {
      this.hoverItem?.setHover(false);
      this.hoverItem = item;
      item?.setHover(true);
    }
    if (inter !== this.hoverInteract) {
      this.hoverInteract?.setHover(false);
      this.hoverInteract = inter;
      inter?.setHover(true);
    }
  }

  private startDrag(item: Item, x: number, y: number): void {
    this.setHover(null, null);
    this.dragging = item;
    this.room.ctx.dragging = true;
    item.beginDrag(x, y);
    Audio.sfx('pickup', { detune: 120 });
    for (const z of this.room.zones) if (z.canAccept(item)) z.setTargetState('candidate');
  }

  private drop(): void {
    const item = this.dragging;
    if (!item) return;
    this.dragging = null;
    this.room.ctx.dragging = false;
    const p = this.room.pointerWorld();
    const zone = this.findZone(p.x, p.y, item);
    for (const z of this.room.zones) z.setTargetState('off');
    this.hoverZone = null;
    if (zone) {
      zone.receive(item);
      if (item.trash) {
        GameState.addTrash(1);
        Audio.sfx('trash', { detune: 80 });
      } else {
        Audio.sfx(zone.accepts === 'dish' ? 'drip_bucket' : 'drop', { detune: 80 });
      }
      this.room.fx.puffAt(zone.center().x, zone.center().y, 5);
      this.room.ctx.bus.emit('tasksChanged');
    } else {
      item.returnHome();
      Audio.sfx('item_return', { volume: 0.6 });
    }
  }

  private interact(target: Interactable): void {
    const finished = target.interact();
    Audio.sfx('interact', { detune: 80 });
    if (!finished) return;
    const c = target.center();
    this.room.fx.cleanBurst(c.x, c.y);
    if (target.trash) {
      GameState.addTrash(1);
      Audio.sfx('trash');
    }
    this.room.ctx.bus.emit('tasksChanged');
  }

  private pickItem(x: number, y: number): Item | null {
    let best: Item | null = null;
    for (const it of this.room.items) {
      if (it.done || !it.sprite.visible || !it.contains(x, y, PICK_MARGIN)) continue;
      if (!best || it.sprite.depth > best.sprite.depth) best = it;
    }
    return best;
  }

  private pickInteractable(x: number, y: number): Interactable | null {
    let best: Interactable | null = null;
    for (const it of this.interacts) {
      if (it.done || !it.sprite.visible || !it.contains(x, y, PICK_MARGIN)) continue;
      if (!best || it.sprite.depth > best.sprite.depth) best = it;
    }
    return best;
  }

  private findZone(x: number, y: number, item: Item): Zone | null {
    let best: Zone | null = null;
    for (const z of this.room.zones) {
      // A little forgiveness around the target so drops near the edge still count.
      if (!z.canAccept(item) || !z.contains(x, y, 6)) continue;
      if (!best || z.sprite.depth > best.sprite.depth) best = z;
    }
    return best;
  }

  /** Cancel a drag in progress (room leaving, cutscene starting). */
  cancel(): void {
    if (!this.dragging) return;
    this.dragging.returnHome();
    this.dragging = null;
    this.room.ctx.dragging = false;
    for (const z of this.room.zones) z.setTargetState('off');
  }

  destroy(): void {
    window.removeEventListener('pointerup', this.onUp);
    window.removeEventListener('pointercancel', this.onUp);
  }
}
