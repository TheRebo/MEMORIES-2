import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { Settings } from '@/core/settings';
import { ROOMS, ROOM_ORDER, nextRoom } from '@/data/rooms';
import { SPRITES } from '@/data/sprites';
import { CANDLE_KEY, TOOLS } from '@/data/tools';
import type { RoomId, ToolId } from '@/data/types';
import type { GroupStatus } from '@/systems/TaskTracker';
import { h } from './dom';
import { Typewriter } from './Typewriter';

export interface HudCallbacks {
  onMenu: () => void;
  onToolPointerDown: (tool: ToolId, e: PointerEvent) => void;
  onToolActivate: (tool: ToolId) => void;
  onCandlePointerDown: (e: PointerEvent) => void;
  onGoRoom: (room: RoomId) => void;
  onGoHome: () => void;
  onTodoToggle: (open: boolean) => void;
}

type PointerGetter = () => { x: number; y: number } | null;

const sprite = (key: keyof typeof SPRITES): string => `assets/${SPRITES[key].file}`;

/** In-room HUD (DOM). Everything here is presentation; game logic lives in the room systems. */
export class Hud {
  private readonly root: HTMLDivElement;
  private readonly progressFill: HTMLDivElement;
  private readonly progressText: HTMLSpanElement;
  private readonly progressBar: HTMLDivElement;
  private readonly todo: HTMLElement;
  private readonly todoList: HTMLUListElement;
  private readonly todoBtn: HTMLButtonElement;
  private readonly slots = new Map<ToolId, { el: HTMLButtonElement; level: HTMLSpanElement }>();
  private readonly candleSlot: HTMLButtonElement;
  private readonly candleCount: HTMLSpanElement;
  private readonly trashCount: HTMLSpanElement;
  private readonly nav: HTMLElement;
  private readonly toastEl: HTMLDivElement;
  private readonly dialogEl: HTMLDivElement;
  private readonly dialogSpeaker: HTMLParagraphElement;
  private readonly dialogText: HTMLParagraphElement;
  private readonly dialogHintEl: HTMLParagraphElement;
  private readonly objectiveEl: HTMLDivElement;
  private readonly eventBarEl: HTMLDivElement;
  private readonly eventBarFill: HTMLDivElement;
  private readonly eventBarLabel: HTMLSpanElement;
  private readonly bannerEl: HTMLDivElement;
  private readonly hintEl: HTMLDivElement;
  private readonly cursorEl: HTMLImageElement;
  private readonly pointerLayer: HTMLDivElement;
  private readonly fadeEl: HTMLDivElement;
  private readonly vignette: HTMLDivElement;
  private readonly glow: HTMLDivElement;
  private readonly letterbox: HTMLDivElement;
  private readonly live: HTMLDivElement;
  private readonly tw: Typewriter;
  private readonly pointers = new Map<string, { get: PointerGetter; el: HTMLDivElement }>();
  private toastTimer = 0;
  private dialogTimer = 0;
  private hintTimer = 0;
  private bannerTimer = 0;
  private dialogSeq = 0;
  private todoOpen = true;
  private lastGroups = new Map<string, GroupStatus>();

  constructor(layer: HTMLDivElement, private readonly roomId: RoomId, private readonly cb: HudCallbacks) {
    this.root = layer;
    const room = ROOMS[roomId];

    // Ambient overlays (bottom-most, never interactive)
    this.vignette = h('div', { class: 'hud-vignette', 'aria-hidden': 'true' });
    this.glow = h('div', { class: 'hud-glow', 'aria-hidden': 'true' });
    this.pointerLayer = h('div', { class: 'hud-pointers', 'aria-hidden': 'true' });
    this.letterbox = h('div', { class: 'hud-letterbox', 'aria-hidden': 'true' }, h('div'), h('div'));

    // Top bar
    this.progressFill = h('div', { class: 'progress-fill' });
    this.progressText = h('span', { class: 'progress-text display' }, '0%');
    this.progressBar = h('div', { class: 'progress', role: 'progressbar', 'aria-label': `Kebersihan ${room.name}`, 'aria-valuemin': 0, 'aria-valuemax': 100, 'aria-valuenow': 0 },
      this.progressFill, this.progressText);
    this.todoBtn = h('button', { class: 'btn small interactive', type: 'button', 'aria-expanded': 'true', 'aria-controls': 'todo' }, 'Tugas ', h('kbd', {}, 'T'));
    this.todoBtn.addEventListener('click', () => this.toggleTodo());
    const menuBtn = h('button', { class: 'icon-btn interactive', type: 'button', 'aria-label': 'Jeda (Esc)', title: 'Jeda (Esc)',
      style: "background-image:url('assets/ui/btn_menu.png')" });
    menuBtn.addEventListener('click', () => {
      Audio.uiClick();
      cb.onMenu();
    });
    const top = h('header', { class: 'hud-top' },
      h('h1', { class: 'room-name display' }, room.name),
      this.progressBar,
      h('div', { class: 'hud-top-actions' }, this.todoBtn, menuBtn));

    // To-do panel
    this.todoList = h('ul', { class: 'todo-list' });
    this.todo = h('aside', { class: 'todo panel interactive', id: 'todo', 'aria-label': 'Daftar tugas' },
      h('h2', { class: 'todo-title display' }, 'Daftar Tugas'), this.todoList);

    // Bottom bar: tools, candle, trash, navigation
    const toolbar = h('div', { class: 'toolbar', role: 'toolbar', 'aria-label': 'Alat bersih-bersih' });
    for (const t of TOOLS) {
      const level = h('span', { class: 'slot-level' }, `Lv.${GameState.toolLevel(t.id)}`);
      const el = h('button', { class: 'slot interactive', type: 'button', 'aria-pressed': 'false',
        'aria-label': `${t.name}, tahan tombol ${t.keyLabel}` },
        h('img', { src: sprite(t.icon), alt: '', width: 48, height: 48, draggable: 'false' }),
        h('span', { class: 'slot-name' }, t.name),
        h('kbd', { class: 'slot-key' }, t.keyLabel),
        level);
      el.addEventListener('pointerdown', (e) => cb.onToolPointerDown(t.id, e));
      el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          cb.onToolActivate(t.id);
        }
      });
      el.addEventListener('pointerenter', () => Audio.uiHover());
      toolbar.append(el);
      this.slots.set(t.id, { el, level });
    }
    this.candleCount = h('span', { class: 'slot-level' }, 'x0');
    this.candleSlot = h('button', { class: 'slot slot-candle interactive', type: 'button', hidden: true,
      'aria-label': `Lilin, tahan tombol ${CANDLE_KEY.label} lalu lepas di lantai` },
      h('img', { src: sprite('lilin'), alt: '', width: 48, height: 48, draggable: 'false' }),
      h('span', { class: 'slot-name' }, 'Lilin'),
      h('kbd', { class: 'slot-key' }, CANDLE_KEY.label),
      this.candleCount);
    this.candleSlot.addEventListener('pointerdown', (e) => cb.onCandlePointerDown(e));
    toolbar.append(this.candleSlot);

    this.trashCount = h('span', { class: 'display' }, String(GameState.trashTotal));
    const trash = h('div', { class: 'trash-counter', title: 'Sampah terkumpul' },
      h('img', { src: sprite('trash_bag'), alt: 'Sampah terkumpul', width: 40, height: 40 }), this.trashCount);
    this.nav = h('nav', { class: 'room-nav', 'aria-label': 'Pindah ruangan', hidden: true });
    const bottom = h('footer', { class: 'hud-bottom' }, toolbar, this.nav, trash);

    // Messages
    this.toastEl = h('div', { class: 'toast', role: 'status', 'aria-live': 'polite' });
    this.objectiveEl = h('div', { class: 'objective panel', role: 'status', hidden: true });
    this.eventBarFill = h('div', { class: 'eventbar-fill' });
    this.eventBarLabel = h('span', { class: 'display' });
    this.eventBarEl = h('div', { class: 'eventbar panel', hidden: true }, this.eventBarLabel, h('div', { class: 'eventbar-track' }, this.eventBarFill));
    this.dialogSpeaker = h('p', { class: 'dialog-speaker display' });
    this.dialogText = h('p', { class: 'dialog-text' });
    this.dialogHintEl = h('p', { class: 'dialog-hint muted' }, 'Klik atau Enter untuk lanjut, Esc untuk lewati');
    this.dialogEl = h('div', { class: 'dialog panel', role: 'region', 'aria-label': 'Dialog', 'aria-live': 'polite' },
      this.dialogSpeaker, this.dialogText, this.dialogHintEl);
    this.tw = new Typewriter(this.dialogText);
    this.bannerEl = h('div', { class: 'banner display', 'aria-hidden': 'true' });
    this.hintEl = h('div', { class: 'hint-chip', 'aria-hidden': 'true' });
    this.cursorEl = h('img', { class: 'tool-cursor', alt: '', width: 64, height: 64, hidden: true, draggable: 'false' });
    this.fadeEl = h('div', { class: 'hud-fade', 'aria-hidden': 'true' });
    this.live = h('div', { class: 'sr-only', 'aria-live': 'assertive' });

    this.root.append(this.vignette, this.glow, this.pointerLayer, this.letterbox, top, this.todo, bottom,
      this.objectiveEl, this.eventBarEl, this.toastEl, this.dialogEl, this.bannerEl, this.hintEl, this.cursorEl, this.fadeEl, this.live);
  }

  // ---------- Progress & tasks ----------
  setProgress(pct: number): void {
    const v = Math.round(pct);
    this.progressFill.style.width = `${pct}%`;
    this.progressText.textContent = `${v}%`;
    this.progressBar.setAttribute('aria-valuenow', String(v));
    this.progressBar.classList.toggle('full', v >= 100);
  }

  setGroups(groups: GroupStatus[]): void {
    const rows: HTMLLIElement[] = [];
    const sorted = [...groups].sort((a, b) => Number(a.done >= a.total) - Number(b.done >= b.total));
    for (const g of sorted) {
      const fin = g.done >= g.total;
      const prev = this.lastGroups.get(g.name);
      const li = h('li', { class: `todo-item${fin ? ' done' : ''}` },
        h('span', { class: 'todo-check', 'aria-hidden': 'true' }),
        h('span', { class: 'todo-name' }, g.name),
        h('span', { class: 'todo-count' }, `${g.done}/${g.total}`));
      li.setAttribute('aria-label', `${g.name}: ${g.done} dari ${g.total}${fin ? ', selesai' : ''}`);
      if (prev && prev.total < g.total) li.classList.add('grew');
      rows.push(li);
    }
    this.todoList.replaceChildren(...rows);
    this.lastGroups = new Map(groups.map((g) => [g.name, g]));
  }

  flashGroup(name: string): void {
    for (const li of this.todoList.children) {
      if (li.querySelector('.todo-name')?.textContent === name) {
        li.classList.remove('just-done');
        void (li as HTMLElement).offsetWidth;
        li.classList.add('just-done');
      }
    }
    this.announce(`${name} selesai`);
  }

  toggleTodo(force?: boolean): void {
    this.todoOpen = force ?? !this.todoOpen;
    this.todo.classList.toggle('closed', !this.todoOpen);
    this.todoBtn.setAttribute('aria-expanded', String(this.todoOpen));
    Audio.sfx(this.todoOpen ? 'slide_in' : 'tool_drop', { volume: 0.5 });
    this.cb.onTodoToggle(this.todoOpen);
  }

  /** Width of the panel covering the left side of the world (for the camera). */
  todoInset(): number {
    return this.todoOpen && !this.root.classList.contains('cinematic') ? 336 : 0;
  }

  // ---------- Tools ----------
  setTool(tool: ToolId | null): void {
    for (const [id, s] of this.slots) {
      const on = id === tool;
      s.el.classList.toggle('active', on);
      s.el.classList.toggle('dim', tool !== null && !on);
      s.el.setAttribute('aria-pressed', String(on));
    }
    const info = TOOLS.find((t) => t.id === tool);
    if (info) this.cursorEl.src = sprite(info.icon);
    this.cursorEl.hidden = info === undefined;
  }

  setCandleHeld(on: boolean): void {
    this.candleSlot.classList.toggle('active', on);
    if (on) this.cursorEl.src = sprite('lilin');
    this.cursorEl.hidden = !on && !this.root.querySelector('.slot.active');
  }

  setToolLevel(tool: ToolId, level: number, leveledUp: boolean): void {
    const s = this.slots.get(tool);
    if (!s) return;
    s.level.textContent = `Lv.${level}`;
    if (leveledUp) {
      s.el.classList.remove('level-up');
      void s.el.offsetWidth;
      s.el.classList.add('level-up');
    }
  }

  /** Tool sprite that follows the pointer; wiggles while it is actually cleaning. */
  moveCursor(x: number, y: number, working: boolean): void {
    if (this.cursorEl.hidden) return;
    const rot = working ? Math.sin(performance.now() / 45) * 14 : 0;
    this.cursorEl.style.transform = `translate(${x - 18}px, ${y - 50}px) rotate(${rot}deg)`;
  }

  setCandles(n: number): void {
    this.candleCount.textContent = `x${n}`;
    this.candleSlot.hidden = n <= 0 && !this.candleSlot.classList.contains('active');
  }

  setTrash(n: number): void {
    this.trashCount.textContent = String(n);
    const box = this.trashCount.parentElement;
    box?.classList.remove('bump');
    void box?.offsetWidth;
    box?.classList.add('bump');
  }

  // ---------- Messages ----------
  toast(text: string): void {
    this.toastEl.textContent = text;
    this.toastEl.classList.add('on');
    Audio.sfx('slide_in', { volume: 0.45, minGap: 300 });
    window.clearTimeout(this.toastTimer);
    this.toastTimer = window.setTimeout(() => this.toastEl.classList.remove('on'), 3000);
  }

  /** In-map dialog line. duration 0 = stays until hidden (cutscenes). */
  dialog(speaker: string, text: string, duration: number): void {
    this.dialogSeq += 1;
    const seq = this.dialogSeq;
    this.dialogSpeaker.textContent = speaker;
    this.dialogSpeaker.hidden = speaker === '';
    this.dialogHintEl.classList.remove('on');
    this.dialogEl.classList.add('on');
    this.tw.start(text, Settings.charsPerSecond);
    window.clearTimeout(this.dialogTimer);
    if (duration > 0) this.dialogTimer = window.setTimeout(() => seq === this.dialogSeq && this.hideDialog(), duration * 1000);
  }

  get typing(): boolean {
    return this.tw.running;
  }

  finishTyping(): void {
    this.tw.finish();
  }

  hideDialog(): void {
    this.dialogEl.classList.remove('on');
    this.tw.stop();
  }

  dialogHint(on: boolean): void {
    this.dialogHintEl.classList.toggle('on', on);
  }

  objective(text: string): void {
    this.objectiveEl.textContent = text;
    this.objectiveEl.hidden = text === '';
  }

  eventBar(data: { label: string; value: number } | null): void {
    this.eventBarEl.hidden = data === null;
    if (!data) return;
    this.eventBarLabel.textContent = data.label;
    this.eventBarFill.style.width = `${Math.round(data.value * 100)}%`;
    this.eventBarFill.classList.toggle('half', data.value >= 0.5);
  }

  banner(text: string, hold = 1.8): void {
    this.bannerEl.textContent = text;
    this.bannerEl.classList.remove('on');
    void this.bannerEl.offsetWidth;
    this.bannerEl.classList.add('on');
    window.clearTimeout(this.bannerTimer);
    this.bannerTimer = window.setTimeout(() => this.bannerEl.classList.remove('on'), (hold + 0.6) * 1000);
    this.announce(text);
  }

  /** Small tip near the pointer, e.g. "Butuh: Kain Lap". */
  hint(x: number, y: number, text: string): void {
    this.hintEl.textContent = text;
    this.hintEl.style.transform = `translate(${Math.round(x + 18)}px, ${Math.round(y - 34)}px)`;
    this.hintEl.classList.add('on');
    window.clearTimeout(this.hintTimer);
    this.hintTimer = window.setTimeout(() => this.hintEl.classList.remove('on'), 1100);
  }

  /** Persistent hover label (e.g. "Klik 2x"). Pass null to hide. */
  hoverLabel(x: number, y: number, text: string | null): void {
    if (text === null) {
      if (!this.hintTimer) this.hintEl.classList.remove('on');
      return;
    }
    this.hintEl.textContent = text;
    this.hintEl.style.transform = `translate(${Math.round(x + 18)}px, ${Math.round(y - 34)}px)`;
    this.hintEl.classList.add('on');
  }

  announce(text: string): void {
    this.live.textContent = '';
    window.setTimeout(() => {
      this.live.textContent = text;
    }, 30);
  }

  // ---------- Pointers to event locations ----------
  setPointer(id: string, get: PointerGetter): void {
    this.clearPointer(id);
    const el = h('div', { class: 'pointer-arrow' });
    this.pointerLayer.append(el);
    this.pointers.set(id, { get, el });
  }

  clearPointer(id: string): void {
    this.pointers.get(id)?.el.remove();
    this.pointers.delete(id);
  }

  updatePointers(toScreen: (x: number, y: number) => { x: number; y: number }, usable: { x: number; y: number; w: number; h: number }): void {
    const t = performance.now() / 1000;
    for (const [id, p] of this.pointers) {
      const w = p.get();
      if (!w) {
        this.clearPointer(id);
        continue;
      }
      const s = toScreen(w.x, w.y);
      const inner = { x0: usable.x + 24, y0: usable.y + 24, x1: usable.x + usable.w - 24, y1: usable.y + usable.h - 24 };
      const inside = s.x >= inner.x0 && s.x <= inner.x1 && s.y >= inner.y0 && s.y <= inner.y1;
      if (inside) {
        const bob = Math.sin(t * 6) * 4;
        p.el.style.transform = `translate(${s.x - 14}px, ${s.y - 34 + bob}px)`;
        p.el.classList.remove('edge');
      } else {
        const cx = (inner.x0 + inner.x1) / 2;
        const cy = (inner.y0 + inner.y1) / 2;
        const ang = Math.atan2(s.y - cy, s.x - cx);
        const px = Math.min(inner.x1, Math.max(inner.x0, s.x));
        const py = Math.min(inner.y1, Math.max(inner.y0, s.y));
        p.el.style.transform = `translate(${px - 14}px, ${py - 14}px) rotate(${ang - Math.PI / 2}rad)`;
        p.el.classList.add('edge');
      }
    }
  }

  // ---------- Navigation ----------
  showNav(): void {
    this.nav.replaceChildren();
    if (!GameState.isCompleted(this.roomId)) {
      this.nav.hidden = true;
      return;
    }
    const nxt = nextRoom(this.roomId);
    for (const id of ROOM_ORDER) {
      if (id === this.roomId) continue;
      const done = GameState.isCompleted(id);
      if (!done && id !== nxt) continue;
      const label = !done ? `Lanjut: ${ROOMS[id].short}` : `Ke: ${ROOMS[id].short}`;
      this.nav.append(this.navButton(label, () => this.cb.onGoRoom(id), !done));
    }
    if (GameState.allCompleted()) this.nav.append(this.navButton('Pulang', () => this.cb.onGoHome(), true));
    this.nav.hidden = false;
    this.nav.classList.add('appear');
  }

  private navButton(label: string, fn: () => void, primary: boolean): HTMLButtonElement {
    const b = h('button', { class: `btn small interactive${primary ? ' primary' : ''}`, type: 'button' }, label);
    b.addEventListener('click', () => {
      Audio.uiClick();
      fn();
    });
    b.addEventListener('pointerenter', () => Audio.uiHover());
    return b;
  }

  // ---------- Screen ----------
  setCinematic(on: boolean): void {
    this.root.classList.toggle('cinematic', on);
  }

  fade(toBlack: boolean, ms: number): void {
    this.fadeEl.style.transitionDuration = `${ms}ms`;
    this.fadeEl.classList.toggle('on', toBlack);
  }

  setVignette(strength: number): void {
    this.vignette.style.opacity = String(strength);
  }

  setGlow(on: boolean, instant = false): void {
    this.glow.style.transitionDuration = instant ? '0ms' : '2000ms';
    this.glow.classList.toggle('on', on);
  }

  destroy(): void {
    this.tw.stop();
    window.clearTimeout(this.toastTimer);
    window.clearTimeout(this.dialogTimer);
    window.clearTimeout(this.hintTimer);
    window.clearTimeout(this.bannerTimer);
    this.root.remove();
  }
}
