type Handler<T> = (payload: T) => void;

/** Minimal typed event emitter. `on` returns an unsubscribe function. */
export class Emitter<Events extends Record<string, unknown>> {
  private readonly handlers = new Map<keyof Events, Set<Handler<never>>>();

  on<K extends keyof Events>(event: K, fn: Handler<Events[K]>): () => void {
    let set = this.handlers.get(event);
    if (!set) {
      set = new Set();
      this.handlers.set(event, set);
    }
    set.add(fn as Handler<never>);
    return () => this.off(event, fn);
  }

  off<K extends keyof Events>(event: K, fn: Handler<Events[K]>): void {
    this.handlers.get(event)?.delete(fn as Handler<never>);
  }

  emit<K extends keyof Events>(event: K, ...args: Events[K] extends void ? [] : [Events[K]]): void {
    const set = this.handlers.get(event);
    if (!set) return;
    for (const fn of [...set]) (fn as Handler<Events[K]>)(args[0] as Events[K]);
  }

  clear(): void {
    this.handlers.clear();
  }
}
