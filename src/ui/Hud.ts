import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { Settings } from '@/core/settings';
import { HUD_TODO_W } from '@/config';
import { ROOMS, ROOM_ORDER, nextRoom } from '@/data/rooms';
import { SPRITES } from '@/data/sprites';
import { CANDLE_KEY, TOOLS, TOOL_LEVELS } from '@/data/tools';
import type { RoomId, ToolId } from '@/data/types';
import type { GroupStatus } from '@/systems/TaskTracker';
import { h, reducedMotion } from './dom';
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

interface Slot {
  el: HTMLButtonElement;
  pips: HTMLSpanElement[];
}

interface Alert {
  el: HTMLDivElement;
  text: HTMLParagraphElement;
  bar: HTMLDivElement;
  barLabel: HTMLSpanElement;
  barFill: HTMLDivElement;
  barValue: HTMLSpanElement;
}

const sprite = (key: keyof typeof SPRITES): string => `assets/${SPRITES[key].file}`;
const TOOL_NAMES: Record<ToolId, string> = { broom: 'Sapu', mop: 'Pel', cloth: 'Kain Lap', duster: 'Kemoceng' };

/**
 * In-room HUD (DOM). Everything here is presentation; game logic lives in the room systems.
 *
 * Layout (1280x720 stage):
 * - top bar: which room this is, how clean it is, the notes toggle and pause;
 * - left: the task note, written on paper because these are MC's own notes;
 * - top right: one card per running event (stacked); top centre: toasts;
 * - bottom: trash total, the tool belt in the middle, room navigation once the room is done.
 */
export class Hud {
  private readonly root: HTMLDivElement;
  private readonly progressFill: HTMLDivElement;
  private readonly progressText: HTMLSpanElement;
  private readonly progressBar: HTMLDivElement;
  private readonly todo: HTMLElement;
  private readonly todoList: HTMLUListElement;
  private readonly todoDone: HTMLDetailsElement;
  private readonly todoDoneSummary: HTMLElement;
  private readonly todoDoneList: HTMLUListElement;
  private readonly todoCount: HTMLSpanElement;
  private readonly todoBtn: HTMLButtonElement;
  private readonly slots = new Map<ToolId, Slot>();
  private readonly candleSlot: HTMLButtonElement;
  private readonly candleCount: HTMLSpanElement;
  private readonly trashCount: HTMLSpanElement;
  private readonly trashBox: HTMLDivElement;
  private readonly nav: HTMLElement;
  private readonly msgs: HTMLDivElement;
  private readonly alertsEl: HTMLDivElement;
  private readonly alerts = new Map<string, Alert>();
  private readonly toastEl: HTMLDivElement;
  private readonly dialogEl: HTMLDivElement;
  private readonly dialogSpeaker: HTMLParagraphElement;
  private readonly dialogText: HTMLParagraphElement;
  private readonly dialogHintEl: HTMLParagraphElement;
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
  // Short screens (phones in landscape) start with the note folded so the room stays visible.
  private todoOpen = window.innerHeight >= 500;
  private heldTool: ToolId | null = null;
  private candleHeld = false;
  private lastGroups = new Map<string, GroupStatus>();

  constructor(layer: HTMLDivElement, private readonly roomId: RoomId, private readonly cb: HudCallbacks) {
    this.root = layer;
    const room = ROOMS[roomId];
    const step = ROOM_ORDER.indexOf(roomId) + 1;

    // Ambient overlays (bottom-most, never interactive)
    this.vignette = h('div', { class: 'hud-vignette', 'aria-hidden': 'true' });
    this.glow = h('div', { class: 'hud-glow', 'aria-hidden': 'true' });
    this.pointerLayer = h('div', { class: 'hud-pointers', 'aria-hidden': 'true' });
    this.letterbox = h('div', { class: 'hud-letterbox', 'aria-hidden': 'true' }, h('div'), h('div'));

    // ---------- Top bar ----------
    this.progressFill = h('div', { class: 'progress-fill' });
    this.progressBar = h('div', { class: 'progress', role: 'progressbar', 'aria-label': `Kebersihan ${room.name}`, 'aria-valuemin': 0, 'aria-valuemax': 100, 'aria-valuenow': 0 },
      this.progressFill);
    this.progressText = h('span', { class: 'progress-text display' }, '0%');
    this.todoBtn = h('button', { class: 'btn small interactive', type: 'button', 'aria-expanded': 'true', 'aria-controls': 'todo', title: 'Buka/tutup catatan (T)' },
      'Catatan', h('kbd', {}, 'T'));
    this.todoBtn.addEventListener('click', () => this.toggleTodo());
    const menuBtn = h('button', { class: 'icon-btn interactive', type: 'button', 'aria-label': 'Jeda (Esc)', title: 'Jeda (Esc)',
      style: "background-image:url('assets/ui/btn_menu.png')" });
    menuBtn.addEventListener('click', () => {
      Audio.uiClick();
      cb.onMenu();
    });
    const top = h('header', { class: 'hud-top' },
      h('div', { class: 'room-id' },
        h('span', { class: 'room-step display', title: `Ruangan ${step} dari ${ROOM_ORDER.length}` }, `${step}/${ROOM_ORDER.length}`),
        h('h1', { class: 'room-name display' }, room.name)),
      h('div', { class: 'progress-wrap' }, h('span', { class: 'progress-label' }, 'Kebersihan'), this.progressBar, this.progressText),
      h('div', { class: 'hud-top-actions' }, this.todoBtn, menuBtn));

    // ---------- Task note ----------
    this.todoCount = h('span', { class: 'note-count display' });
    this.todoList = h('ul', { class: 'todo-list' });
    this.todoDoneList = h('ul', { class: 'todo-list' });
    this.todoDoneSummary = h('summary', { class: 'interactive' });
    this.todoDone = h('details', { class: 'todo-done', hidden: true }, this.todoDoneSummary, this.todoDoneList);
    this.todo = h('aside', { class: 'todo note interactive', id: 'todo', 'aria-label': 'Catatan tugas' },
      h('div', { class: 'note-head' }, h('h2', { class: 'note-title display' }, 'Catatan'), this.todoCount),
      this.todoList, this.todoDone);

    // ---------- Bottom bar ----------
    const toolbar = h('div', { class: 'toolbar', role: 'toolbar', 'aria-label': 'Alat bersih-bersih' });
    for (const t of TOOLS) {
      const pips = Array.from({ length: TOOL_LEVELS.maxLevel }, () => h('span', { class: 'pip' }));
      const el = h('button', { class: 'slot interactive', type: 'button', 'aria-pressed': 'false' },
        h('kbd', { class: 'slot-key' }, t.keyLabel),
        h('img', { src: sprite(t.icon), alt: '', width: 40, height: 40, draggable: 'false' }),
        h('span', { class: 'slot-name' }, t.name),
        h('span', { class: 'slot-pips', 'aria-hidden': 'true' }, ...pips));
      el.addEventListener('pointerdown', (e) => cb.onToolPointerDown(t.id, e));
      el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          cb.onToolActivate(t.id);
        }
      });
      el.addEventListener('pointerenter', () => Audio.uiHover());
      toolbar.append(el);
      this.slots.set(t.id, { el, pips });
      this.setToolLevel(t.id, GameState.toolLevel(t.id), false);
    }
    this.candleCount = h('span', { class: 'slot-count display' }, '0');
    this.candleSlot = h('button', { class: 'slot slot-candle interactive', type: 'button', hidden: true,
      'aria-label': `Lilin, tahan tombol ${CANDLE_KEY.label} lalu lepas di lantai` },
      h('kbd', { class: 'slot-key' }, CANDLE_KEY.label),
      h('img', { src: sprite('lilin'), alt: '', width: 40, height: 40, draggable: 'false' }),
      h('span', { class: 'slot-name' }, 'Lilin'),
      this.candleCount);
    this.candleSlot.addEventListener('pointerdown', (e) => cb.onCandlePointerDown(e));
    toolbar.append(this.candleSlot);

    this.trashCount = h('span', { class: 'display' }, String(GameState.trashTotal));
    this.trashBox = h('div', { class: 'trash-counter', title: 'Sampah terkumpul' },
      h('img', { src: sprite('trash_bag'), alt: '', width: 32, height: 32 }),
      h('span', { class: 'trash-label' }, 'Sampah'), this.trashCount);
    this.nav = h('nav', { class: 'room-nav', 'aria-label': 'Pindah ruangan', hidden: true });
    const bottom = h('footer', { class: 'hud-bottom' },
      h('div', { class: 'hud-bottom-side' }, this.trashBox), toolbar, h('div', { class: 'hud-bottom-side right' }, this.nav));

    // ---------- Messages ----------
    this.alertsEl = h('div', { class: 'alerts' });
    this.toastEl = h('div', { class: 'toast', role: 'status', 'aria-live': 'polite' });
    this.msgs = h('div', { class: 'hud-msgs' }, this.toastEl);
    this.dialogSpeaker = h('p', { class: 'dialog-speaker display' });
    this.dialogText = h('p', { class: 'dialog-text' });
    this.dialogHintEl = h('p', { class: 'dialog-hint' }, 'Klik atau Enter untuk lanjut, Esc untuk lewati');
    this.dialogEl = h('div', { class: 'dialog', role: 'region', 'aria-label': 'Dialog', 'aria-live': 'polite' },
      this.dialogSpeaker, this.dialogText, this.dialogHintEl);
    this.tw = new Typewriter(this.dialogText);
    this.bannerEl = h('div', { class: 'banner display', 'aria-hidden': 'true' });
    this.hintEl = h('div', { class: 'hint-chip', 'aria-hidden': 'true' });
    this.cursorEl = h('img', { class: 'tool-cursor', alt: '', width: 64, height: 64, hidden: true, draggable: 'false' });
    this.fadeEl = h('div', { class: 'hud-fade', 'aria-hidden': 'true' });
    this.live = h('div', { class: 'sr-only', 'aria-live': 'assertive' });

    // The fade sits under the dialog: a cutscene line shown over black must stay readable.
    this.root.append(this.vignette, this.glow, this.pointerLayer, top, this.todo, bottom, this.fadeEl, this.letterbox,
      this.msgs, this.alertsEl, this.dialogEl, this.bannerEl, this.hintEl, this.cursorEl, this.live);
    this.todo.classList.toggle('closed', !this.todoOpen);
    this.todoBtn.setAttribute('aria-expanded', String(this.todoOpen));
    this.applyInset();
  }

  // ---------- Progress & tasks ----------
  setProgress(pct: number): void {
    const v = Math.round(pct);
    this.progressFill.style.width = `${pct}%`;
    this.progressText.textContent = `${v}%`;
    this.progressBar.setAttribute('aria-valuenow', String(v));
    this.root.classList.toggle('room-clean', v >= 100);
  }

  setGroups(groups: GroupStatus[]): void {
    const open: HTMLLIElement[] = [];
    const done: HTMLLIElement[] = [];
    let tasksDone = 0;
    let tasksTotal = 0;
    for (const g of groups) {
      tasksDone += g.done;
      tasksTotal += g.total;
      const fin = g.done >= g.total;
      const prev = this.lastGroups.get(g.name);
      const li = h('li', { class: `todo-item${fin ? ' done' : ''}` },
        h('span', { class: 'todo-check', 'aria-hidden': 'true' }),
        h('span', { class: 'todo-name' }, g.name),
        h('span', { class: 'todo-count' }, fin ? '' : `${g.done}/${g.total}`));
      li.setAttribute('aria-label', `${g.name}: ${g.done} dari ${g.total}${fin ? ', selesai' : ''}`);
      li.dataset['group'] = g.name;
      // An event added work to a list item (new puddles): flash it so the change is noticed.
      if (prev && prev.total < g.total) li.classList.add('grew');
      if (!prev && this.lastGroups.size > 0) li.classList.add('grew');
      (fin ? done : open).push(li);
    }
    if (open.length === 0) open.push(h('li', { class: 'todo-empty' }, groups.length ? 'Semua beres!' : 'Tidak ada tugas.'));
    this.todoList.replaceChildren(...open);
    this.todoDoneList.replaceChildren(...done);
    this.todoDone.hidden = done.length === 0;
    this.todoDoneSummary.textContent = `Sudah selesai (${done.length})`;
    this.todoCount.textContent = `${tasksDone}/${tasksTotal}`;
    this.todoCount.title = `${tasksTotal - tasksDone} bagian lagi`;
    this.lastGroups = new Map(groups.map((g) => [g.name, g]));
  }

  flashGroup(name: string): void {
    const li = [...this.todoDoneList.children].find((el) => (el as HTMLElement).dataset['group'] === name);
    if (li) {
      li.classList.remove('just-done');
      void (li as HTMLElement).offsetWidth;
      li.classList.add('just-done');
    }
    this.toast(`Selesai: ${name}`);
    this.announce(`${name} selesai`);
  }

  toggleTodo(force?: boolean): void {
    this.todoOpen = force ?? !this.todoOpen;
    this.todo.classList.toggle('closed', !this.todoOpen);
    this.todoBtn.setAttribute('aria-expanded', String(this.todoOpen));
    Audio.sfx(this.todoOpen ? 'slide_in' : 'tool_drop', { volume: 0.5 });
    this.applyInset();
    this.cb.onTodoToggle(this.todoOpen);
  }

  /** Width of the note covering the left side of the world (for the camera). */
  todoInset(): number {
    return this.todoOpen && !this.root.classList.contains('cinematic') ? HUD_TODO_W : 0;
  }

  /** Messages centre on the part of the room that is still visible. */
  private applyInset(): void {
    this.root.style.setProperty('--inset', `${this.todoInset()}px`);
  }

  // ---------- Tools ----------
  setTool(tool: ToolId | null): void {
    this.heldTool = tool;
    for (const [id, s] of this.slots) {
      const on = id === tool;
      s.el.classList.toggle('active', on);
      s.el.classList.toggle('dim', tool !== null && !on);
      s.el.setAttribute('aria-pressed', String(on));
    }
    this.updateCursor();
  }

  setCandleHeld(on: boolean): void {
    this.candleHeld = on;
    this.candleSlot.classList.toggle('active', on);
    this.updateCursor();
  }

  private updateCursor(): void {
    const info = TOOLS.find((t) => t.id === this.heldTool);
    if (this.candleHeld) this.cursorEl.src = sprite('lilin');
    else if (info) this.cursorEl.src = sprite(info.icon);
    this.cursorEl.hidden = !this.candleHeld && info === undefined;
  }

  setToolLevel(tool: ToolId, level: number, leveledUp: boolean): void {
    const s = this.slots.get(tool);
    if (!s) return;
    s.pips.forEach((p, i) => p.classList.toggle('on', i < level));
    const key = TOOLS.find((t) => t.id === tool)?.keyLabel ?? '';
    s.el.setAttribute('aria-label', `${TOOL_NAMES[tool]}, level ${level} dari ${TOOL_LEVELS.maxLevel}. Tahan tombol ${key} atau tahan slot ini.`);
    s.el.title = `${TOOL_NAMES[tool]} - level ${level}/${TOOL_LEVELS.maxLevel}`;
    if (leveledUp) {
      s.el.classList.remove('level-up');
      void s.el.offsetWidth;
      s.el.classList.add('level-up');
    }
  }

  /** Tool sprite that follows the pointer; wiggles while it is actually cleaning. */
  moveCursor(x: number, y: number, working: boolean): void {
    if (this.cursorEl.hidden) return;
    const rot = working && !reducedMotion() ? Math.sin(performance.now() / 45) * 14 : 0;
    this.cursorEl.style.transform = `translate(${x - 18}px, ${y - 50}px) rotate(${rot}deg)`;
  }

  setCandles(n: number): void {
    this.candleCount.textContent = String(n);
    this.candleSlot.hidden = n <= 0 && !this.candleHeld;
  }

  setTrash(n: number): void {
    this.trashCount.textContent = String(n);
    this.trashBox.classList.remove('bump');
    void this.trashBox.offsetWidth;
    this.trashBox.classList.add('bump');
  }

  // ---------- Messages ----------
  toast(text: string): void {
    this.toastEl.textContent = text;
    this.toastEl.classList.add('on');
    Audio.sfx('slide_in', { volume: 0.45, minGap: 300 });
    window.clearTimeout(this.toastTimer);
    this.toastTimer = window.setTimeout(() => this.toastEl.classList.remove('on'), 3200);
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
    if (duration > 0) {
      // Long lines stay up long enough to read at the chosen text speed.
      const readMs = Math.max(duration * 1000, (text.length / Settings.charsPerSecond) * 1000 + 1800);
      this.dialogTimer = window.setTimeout(() => seq === this.dialogSeq && this.hideDialog(), readMs);
    }
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

  /** One instruction card per running event. Empty text removes that event's card. */
  objective(id: string, text: string): void {
    if (text === '') {
      this.alerts.get(id)?.el.remove();
      this.alerts.delete(id);
      return;
    }
    const a = this.alerts.get(id) ?? this.makeAlert(id);
    a.text.textContent = text;
  }

  eventBar(id: string, data: { label: string; value: number } | null): void {
    const a = data ? (this.alerts.get(id) ?? this.makeAlert(id)) : this.alerts.get(id);
    if (!a) return;
    a.bar.hidden = data === null;
    if (!data) return;
    const v = Math.max(0, Math.min(1, data.value));
    a.barLabel.textContent = data.label;
    a.barFill.style.width = `${Math.round(v * 100)}%`;
    a.barFill.classList.toggle('half', v >= 0.5);
    a.barValue.textContent = `${Math.round(v * 100)}%`;
  }

  private makeAlert(id: string): Alert {
    const text = h('p', { class: 'alert-text' });
    const barLabel = h('span', { class: 'alert-bar-label display' });
    const barFill = h('div', { class: 'alert-bar-fill' });
    const barValue = h('span', { class: 'alert-bar-value display' });
    const bar = h('div', { class: 'alert-bar', hidden: true }, barLabel, h('div', { class: 'alert-bar-track' }, barFill), barValue);
    const el = h('div', { class: 'alert', role: 'status' }, h('span', { class: 'alert-mark display', 'aria-hidden': 'true' }, '!'), h('div', { class: 'alert-body' }, text, bar));
    const a: Alert = { el, text, bar, barLabel, barFill, barValue };
    this.alertsEl.append(el);
    this.alerts.set(id, a);
    return a;
  }

  banner(text: string, hold = 1.8): void {
    this.bannerEl.textContent = text;
    this.bannerEl.classList.remove('on');
    void this.bannerEl.offsetWidth;
    this.bannerEl.style.setProperty('--hold', `${hold + 0.8}s`);
    this.bannerEl.classList.add('on');
    window.clearTimeout(this.bannerTimer);
    this.bannerTimer = window.setTimeout(() => this.bannerEl.classList.remove('on'), (hold + 0.8) * 1000);
    this.announce(text);
  }

  /** Small tip near the pointer, e.g. "Butuh: Kain Lap". */
  hint(x: number, y: number, text: string): void {
    this.hintEl.textContent = text;
    this.hintEl.classList.add('warn');
    this.placeHint(x, y);
    this.hintEl.classList.add('on');
    window.clearTimeout(this.hintTimer);
    this.hintTimer = window.setTimeout(() => {
      this.hintTimer = 0;
      this.hintEl.classList.remove('on', 'warn');
    }, 1200);
  }

  /** Persistent hover label (e.g. "Klik 2x"). Pass null to hide. */
  hoverLabel(x: number, y: number, text: string | null): void {
    // A timed hint (wrong tool) has priority until it expires.
    if (this.hintTimer) return;
    if (text === null) {
      this.hintEl.classList.remove('on');
      return;
    }
    if (this.hintEl.textContent !== text) this.hintEl.textContent = text;
    this.placeHint(x, y);
    this.hintEl.classList.add('on');
  }

  /** Next to the pointer, kept inside the 1280x720 stage. */
  private placeHint(x: number, y: number): void {
    const w = this.hintEl.offsetWidth || 160;
    const px = x + 18 + w > 1272 ? x - 18 - w : x + 18;
    const py = Math.max(8, y - 34);
    this.hintEl.style.transform = `translate(${Math.round(px)}px, ${Math.round(py)}px)`;
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
    const still = reducedMotion();
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
        const bob = still ? 0 : Math.sin(t * 6) * 4;
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
    let first: HTMLButtonElement | null = null;
    if (GameState.allCompleted()) first = this.navButton('Pulang', () => this.cb.onGoHome(), true);
    for (const id of ROOM_ORDER) {
      if (id === this.roomId) continue;
      const done = GameState.isCompleted(id);
      if (!done && id !== nxt) continue;
      const b = this.navButton(done ? ROOMS[id].short : `Lanjut: ${ROOMS[id].short}`, () => this.cb.onGoRoom(id), !done);
      if (!done) first = b;
      b.title = done ? `Kunjungi lagi ${ROOMS[id].name}` : `Pergi ke ${ROOMS[id].name}`;
    }
    // Primary action sits closest to the room (rightmost reads last otherwise).
    if (first) this.nav.prepend(first);
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
    this.nav.append(b);
    return b;
  }

  // ---------- Screen ----------
  setCinematic(on: boolean): void {
    this.root.classList.toggle('cinematic', on);
    this.applyInset();
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
