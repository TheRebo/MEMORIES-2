export interface Task {
  readonly group: string;
  readonly done: boolean;
}

export interface GroupStatus {
  readonly name: string;
  readonly done: number;
  readonly total: number;
}

/**
 * Counts tasks by group. Events can add tasks (new puddles) or undo them (scattered items),
 * so progress is recomputed from the live list rather than incremented.
 */
export class TaskTracker {
  private readonly tasks = new Set<Task>();
  private finished = new Map<string, boolean>();

  add(t: Task): void {
    if (t.group) this.tasks.add(t);
  }

  remove(t: Task): void {
    this.tasks.delete(t);
  }

  groups(): GroupStatus[] {
    const map = new Map<string, { done: number; total: number }>();
    for (const t of this.tasks) {
      const g = map.get(t.group) ?? { done: 0, total: 0 };
      g.total += 1;
      if (t.done) g.done += 1;
      map.set(t.group, g);
    }
    return [...map.entries()].map(([name, g]) => ({ name, ...g }));
  }

  percent(): number {
    let total = 0;
    let done = 0;
    for (const t of this.tasks) {
      total += 1;
      if (t.done) done += 1;
    }
    return total === 0 ? 100 : (100 * done) / total;
  }

  allDone(): boolean {
    for (const t of this.tasks) if (!t.done) return false;
    return this.tasks.size > 0;
  }

  /** Groups that just went from unfinished to finished since the last call. */
  newlyFinished(): string[] {
    const out: string[] = [];
    const next = new Map<string, boolean>();
    for (const g of this.groups()) {
      const fin = g.done >= g.total;
      if (fin && this.finished.get(g.name) === false) out.push(g.name);
      next.set(g.name, fin);
    }
    this.finished = next;
    return out;
  }
}
