import Phaser from 'phaser';
import { App } from '@/app';
import { Audio } from '@/core/audio';
import { GameState } from '@/core/gameState';
import { DEPTH } from '@/config';
import { ROOMS } from '@/data/rooms';
import { START_TUTORIAL } from '@/data/story';
import type { RoomDef, RoomId, TutorialPage } from '@/data/types';
import { createEvent } from '@/events';
import type { RoomEvent } from '@/events/RoomEvent';
import { CandleSystem } from '@/room/CandleSystem';
import { HandSystem } from '@/room/HandSystem';
import type { RoomApi } from '@/room/RoomApi';
import { RoomContext } from '@/room/RoomContext';
import { RoomCutscene } from '@/room/RoomCutscene';
import { ToolSystem } from '@/room/ToolSystem';
import { CameraRig } from '@/systems/CameraRig';
import { Fx } from '@/systems/Fx';
import { Lighting } from '@/systems/Lighting';
import { TaskTracker } from '@/systems/TaskTracker';
import { Hud } from '@/ui/Hud';
import { modalOpen } from '@/ui/Modal';
import { PauseDialog } from '@/ui/PauseDialog';
import { TutorialDialog } from '@/ui/TutorialDialog';
import { Actor } from '@/world/Actor';
import { Dirt, type DirtSpec } from '@/world/Dirt';
import { Interactable } from '@/world/Interactable';
import { Item } from '@/world/Item';
import { Thing } from '@/world/Thing';
import { Zone } from '@/world/Zone';

interface RoomData {
  room: RoomId;
}

/** One room of the house: cleaning, events, completion, flashback, navigation. */
export class RoomScene extends Phaser.Scene implements RoomApi {
  def!: RoomDef;
  ctx!: RoomContext;
  camera!: CameraRig;
  lighting!: Lighting;
  fx!: Fx;
  candles!: CandleSystem;
  items: Item[] = [];
  zones: Zone[] = [];
  furniture: Thing[] = [];
  dirt: Dirt[] = [];
  finished = false;

  private interacts: Interactable[] = [];
  private actors: Actor[] = [];
  private tracker!: TaskTracker;
  private hud!: Hud;
  private layer!: HTMLDivElement;
  private tools!: ToolSystem;
  private hands!: HandSystem;
  private events_: RoomEvent[] = [];
  private interceptors: ((x: number, y: number) => boolean)[] = [];
  private screenPointer = { x: 640, y: 360 };
  private completedVisit = false;
  private disposers: (() => void)[] = [];

  constructor() {
    super('Room');
  }

  get phaser(): Phaser.Scene {
    return this;
  }

  init(data: RoomData): void {
    this.def = ROOMS[data.room] ?? ROOMS.living_room;
    this.items = [];
    this.zones = [];
    this.furniture = [];
    this.dirt = [];
    this.interacts = [];
    this.actors = [];
    this.events_ = [];
    this.interceptors = [];
    this.disposers = [];
    this.finished = false;
  }

  create(): void {
    const def = this.def;
    // Back to the last save: a room abandoned halfway must not keep its rewards, trash or tool XP.
    GameState.load();
    this.ctx = new RoomContext(def);
    this.tracker = new TaskTracker();
    this.completedVisit = GameState.isCompleted(def.id);
    this.cameras.main.setBackgroundColor('#0d0907');

    this.add.image(0, 0, def.background).setOrigin(0).setDepth(DEPTH.background);
    this.buildWorld();

    this.lighting = new Lighting(this, def.size.w, def.size.h);
    this.fx = new Fx(this, def.size.w, def.size.h);
    this.camera = new CameraRig(this, def.size);
    this.layer = App.layer('room');
    this.hud = new Hud(this.layer, def.id, {
      onMenu: () => this.openPause(),
      onToolPointerDown: (t, e) => this.tools.slotDown(t, e),
      onToolActivate: (t) => this.tools.slotActivate(t),
      onCandlePointerDown: (e) => this.candles.slotDown(e),
      onGoRoom: (r) => this.leave(() => App.go('Room', { room: r })),
      onGoHome: () => this.leave(() => App.go('Story', { which: 'ending' }, 1600)),
      onTodoToggle: () => this.camera.setInsetLeft(this.hud.todoInset()),
    });
    this.camera.setInsetLeft(this.hud.todoInset());

    this.candles = new CandleSystem(this, this.ctx, () => this.pointerWorld(), () => this.pointerOverUi());
    this.tools = new ToolSystem(this, () => this.screenPointer);
    this.hands = new HandSystem(this, this.interacts, (text) => this.hud.hoverLabel(this.screenPointer.x, this.screenPointer.y, text), () => this.pointerInWorld());

    this.wireBus();
    this.wireInput();
    for (const e of def.events) this.events_.push(createEvent(this, e));

    Audio.playMusic('present', 1.4);
    Audio.sfx('room_enter', { volume: 0.6 });
    this.hud.banner(def.name, 1.6);
    if (this.completedVisit) {
      this.enterCompletedState();
    } else {
      this.refresh();
      if (!GameState.tutorialSeen) {
        GameState.markTutorialSeen();
        this.time.delayedCall(1700, () => this.showTutorial(START_TUTORIAL, 'Cara bermain'));
      }
    }

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.cleanup());
    // Test hook for automated play-throughs: only with ?debug in the URL.
    if (new URLSearchParams(window.location.search).has('debug')) (window as unknown as { __room?: RoomScene }).__room = this;
  }

  /** Debug helper (see ?debug): finish every task except `leave` of them. */
  debugFinish(leave = 0): void {
    const todo = [...this.dirt.filter((d) => !d.done), ...this.interacts.filter((i) => !i.done)];
    for (const d of todo.slice(leave)) {
      if (d instanceof Dirt) d.scrub(d.tool, d.effort);
      else d.interact();
    }
    for (const it of this.items) {
      if (it.done) continue;
      const z = this.zones.find((zz) => zz.canAccept(it));
      if (z) z.receive(it);
    }
    this.ctx.bus.emit('tasksChanged');
  }

  // ================== World ==================
  private buildWorld(): void {
    const def = this.def;
    const addDirtChildren = (parent: Thing, list: readonly import('@/data/types').DirtDef[] | undefined): void => {
      for (const d of list ?? []) this.spawnDirt({ ...d, parent });
    };
    for (const p of def.props) {
      const t = new Thing(this, { ...p, placeholderColor: 0x7a5a42 });
      this.furniture.push(t);
      addDirtChildren(t, p.dirt);
    }
    for (const z of def.zones) {
      const zone = new Zone(this, z);
      this.zones.push(zone);
      this.furniture.push(zone);
      addDirtChildren(zone, z.dirt);
    }
    for (const d of def.floorDirt) this.spawnDirt({ ...d, parent: undefined });
    for (const i of def.items) {
      const it = new Item(this, i);
      this.items.push(it);
      this.tracker.add(it);
    }
    for (const i of def.interacts) {
      const it = new Interactable(this, i);
      this.interacts.push(it);
      this.tracker.add(it);
    }
    for (const a of def.actors) this.actors.push(new Actor(this, a));
  }

  spawnDirt(spec: DirtSpec): Dirt {
    const d = new Dirt(this, spec);
    this.dirt.push(d);
    this.tracker.add(d);
    return d;
  }

  findThing(id: string): Thing | undefined {
    return this.furniture.find((f) => f.id === id);
  }

  // ================== Wiring ==================
  private wireBus(): void {
    const bus = this.ctx.bus;
    const on = <K extends Parameters<typeof bus.on>[0]>(k: K, fn: Parameters<typeof bus.on<K>>[1]): void => {
      this.disposers.push(bus.on(k, fn));
    };
    on('tasksChanged', () => this.refresh());
    on('toast', (t) => this.hud.toast(t));
    on('dialog', (d) => {
      this.hud.dialog(d.speaker, d.text, d.duration);
      Audio.sfx('pause_open', { volume: 0.35, minGap: 400 });
    });
    on('dialogHide', () => this.hud.hideDialog());
    on('objective', (t) => this.hud.objective(t));
    on('eventBar', (b) => this.hud.eventBar(b));
    on('hint', (h) => this.hud.hint(h.x, h.y, h.text));
    on('shake', (s) => this.camera.shake(s.strength, s.duration));
    on('attend', (a) => this.camera.attend(a.x, a.y));
    on('pointer', (p) => this.hud.setPointer(p.id, typeof p.target === 'function' ? p.target : () => p.target as { x: number; y: number }));
    on('pointerClear', (id) => this.hud.clearPointer(id));
    on('toolChanged', (t) => this.hud.setTool(t.tool));
    on('candleHeld', (h) => this.hud.setCandleHeld(h));
    on('cinematic', (c) => {
      this.hud.setCinematic(c);
      this.camera.setInsetLeft(this.hud.todoInset());
    });

    const st = GameState.events;
    this.disposers.push(
      st.on('inventory', () => this.hud.setCandles(GameState.count('candle'))),
      st.on('trash', (n) => this.hud.setTrash(n)),
      st.on('toolLevel', ({ tool, level, leveledUp }) => {
        this.hud.setToolLevel(tool, level, leveledUp);
        if (leveledUp) {
          Audio.sfx('patch_done', { volume: 0.8 });
          this.hud.toast(`Alat naik level! ${tool === 'broom' ? 'Sapu' : tool === 'mop' ? 'Pel' : tool === 'cloth' ? 'Kain Lap' : 'Kemoceng'} Lv.${level}: membersihkan lebih cepat.`);
        }
      }),
    );
    this.hud.setCandles(GameState.count('candle'));
  }

  private wireInput(): void {
    const onMove = (e: PointerEvent): void => {
      this.screenPointer = App.stage.toLogical(e.clientX, e.clientY);
    };
    const onKey = (e: KeyboardEvent): void => {
      if (modalOpen() || this.ctx.cinematic) return;
      if (e.key === 'Escape') {
        e.preventDefault();
        if (!this.tools.releaseSticky()) this.openPause();
      } else if (e.code === 'KeyT' && !e.repeat) {
        this.hud.toggleTodo();
      }
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerdown', onMove);
    window.addEventListener('keydown', onKey);
    this.disposers.push(() => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerdown', onMove);
      window.removeEventListener('keydown', onKey);
    });

    this.input.on(Phaser.Input.Events.POINTER_DOWN, (p: Phaser.Input.Pointer) => {
      if (modalOpen() || this.ctx.cinematic) return;
      this.screenPointer = { x: p.x, y: p.y };
      const w = this.pointerWorld();
      // Event clicks (cockroach, window) work even with a tool in hand.
      if (p.button === 0) {
        for (const fn of [...this.interceptors]) if (fn(w.x, w.y)) return;
      }
      this.hands.pointerDown(w.x, w.y, p.button);
    });
  }

  addClickInterceptor(fn: (x: number, y: number) => boolean): () => void {
    this.interceptors.push(fn);
    return () => {
      this.interceptors = this.interceptors.filter((f) => f !== fn);
    };
  }

  pointerWorld(): { x: number; y: number } {
    return this.camera.screenToWorld(this.screenPointer.x, this.screenPointer.y);
  }

  /** Pointer over the visible room, not over a HUD panel. */
  pointerInWorld(): boolean {
    return this.camera.usable().contains(this.screenPointer.x, this.screenPointer.y);
  }

  private pointerOverUi(): boolean {
    const r = this.layer.getBoundingClientRect();
    const scale = r.width / 1280;
    const el = document.elementFromPoint(r.left + this.screenPointer.x * scale, r.top + this.screenPointer.y * scale);
    return !!el?.closest('.hud-top, .hud-bottom, .todo:not(.closed), .modal-backdrop');
  }

  // ================== Progress ==================
  percent(): number {
    return this.finished || this.completedVisit ? 100 : this.tracker.percent();
  }

  private refresh(): void {
    const pct = this.percent();
    this.hud.setGroups(this.tracker.groups());
    for (const g of this.tracker.newlyFinished()) {
      this.hud.flashGroup(g);
      Audio.sfx('group_done', { volume: 0.7 });
    }
    this.hud.setProgress(pct);
    if (this.finished || this.completedVisit) return;
    GameState.setProgress(this.def.id, pct);
    const t = pct / 100;
    this.lighting.setCleanliness(t);
    this.fx.setMotes(0.55 - 0.45 * t, 0xd9d0c0);
    this.hud.setVignette(0.6 - 0.45 * t);
    this.ctx.bus.emit('progress', pct);
    if (this.tracker.allDone() && !this.ctx.eventsActive) {
      this.finished = true;
      void this.runCompletion();
    }
  }

  // ================== Completion ==================
  private async runCompletion(): Promise<void> {
    this.tools.release();
    // Save at once: leaving during the celebration or flashback must not lose the room.
    GameState.completeRoom(this.def.id);
    await this.wait(1200);
    this.hud.setProgress(100);
    Audio.sfx('room_complete', { volume: 0.9 });
    this.hud.banner(`${this.def.name} bersih!`, 2.2);
    this.celebrate(false);
    await this.wait(2600);
    this.hands.cancel();
    await new RoomCutscene(this, this.actors, {
      dialog: (s, t) => this.hud.dialog(s, t, 0),
      hideDialog: () => this.hud.hideDialog(),
      hint: (on) => this.hud.dialogHint(on),
      typing: () => this.hud.typing,
      finishTyping: () => this.hud.finishTyping(),
      fade: (b, ms) => this.hud.fade(b, ms),
    }).play(this.def.flashback);
    Audio.playMusic('present', 1.6);
    this.hud.showNav();
    this.hud.toast(GameState.allCompleted() ? 'Semua ruangan bersih. Saatnya pulang.' : 'Ruangan selesai! Pilih ruangan berikutnya di bar bawah.');
  }

  private celebrate(instant: boolean): void {
    if (!instant) {
      this.camera.zoomPulse(0.35, 1.3);
      this.lighting.pulseFlash(0.8, 1.6);
      this.fx.celebrate(this.def.size.w, this.def.size.h);
    }
    this.lighting.setWarm(instant);
    this.fx.setMotes(0.6, 0xf2c46a);
    this.hud.setVignette(0.2);
    this.hud.setGlow(true, instant);
  }

  /** Revisiting a finished room: everything already clean and put away. */
  private enterCompletedState(): void {
    this.finished = true;
    for (const d of this.dirt) d.restoreDone();
    for (const i of this.interacts) i.restoreDone();
    for (const z of this.zones) {
      const mine = this.items.filter((it) => it.type === z.accepts && !it.done);
      let n = 0;
      for (const it of mine) {
        if (z.limit && n >= z.capacity) break;
        it.restoreDone(z);
        n += 1;
      }
      z.setFill(n);
    }
    this.refresh();
    this.hud.setProgress(100);
    this.celebrate(true);
    this.hud.showNav();
  }

  // ================== Overlays ==================
  showTutorial(pages: readonly TutorialPage[], title: string): void {
    if (this.ctx.cinematic) return;
    this.tools.release();
    this.hands.cancel();
    this.scene.pause();
    const d = new TutorialDialog(this.layer, pages, title);
    d.onClose = () => this.scene.resume();
    d.open();
  }

  private openPause(): void {
    if (modalOpen() || this.ctx.cinematic) return;
    this.tools.release();
    this.hands.cancel();
    Audio.sfx('pause_open', { volume: 0.6 });
    this.scene.pause();
    const d = new PauseDialog(this.layer, {
      roomSaved: GameState.isCompleted(this.def.id),
      onTutorial: () => this.time.delayedCall(10, () => this.showTutorial(START_TUTORIAL, 'Cara bermain')),
      onMainMenu: () => this.leave(() => App.go('Menu')),
    });
    d.onClose = () => {
      Audio.sfx('pause_close', { volume: 0.6 });
      if (this.scene.isPaused()) this.scene.resume();
    };
    d.open();
  }

  private leave(go: () => Promise<void>): void {
    this.tools.release();
    this.hands.cancel();
    void go();
  }

  // ================== Loop ==================
  override update(_time: number, delta: number): void {
    const dt = Math.min(0.05, delta / 1000);
    this.camera.update(dt, this.screenPointer);
    this.tools.update();
    this.hands.update();
    this.candles.update(dt);
    this.lighting.update(dt, this.candles.list);
    this.hud.moveCursor(this.screenPointer.x, this.screenPointer.y, this.tools.isWorking);
    const u = this.camera.usable();
    this.hud.updatePointers((x, y) => this.camera.worldToScreen(x, y), { x: u.x, y: u.y, w: u.width, h: u.height });
  }

  private wait(ms: number): Promise<void> {
    return new Promise((r) => this.time.delayedCall(ms, r));
  }

  private cleanup(): void {
    for (const e of this.events_) e.destroy();
    for (const d of this.disposers) d();
    this.tools.destroy();
    this.hands.destroy();
    this.candles.destroy();
    this.ctx.bus.clear();
    Audio.stopAllLoops();
    App.stage.setCursor('default');
    this.hud.destroy();
  }
}
