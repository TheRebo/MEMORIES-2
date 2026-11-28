# Room layouts

Rooms are laid out in Python and emitted as `src/data/rooms/*.ts`.

- `dsl.py` places props, zones, items and grime; grime is given relative to the art it sits on.
- `living.py`, `kitchen.py`, `bedroom.py` are the layouts. They start from `base_*.json`
  (the text of flashbacks, events and tutorials) and write `out_*.json`.
- `compose.py out_kitchen.json preview.png [--boxes]` renders a room exactly like `RoomScene`.
- `emit.py` writes the TypeScript, computing every scrub effort from one table
  (`BASE`, `PER_PX`, `DIFFICULTY`), so difficulty is tuned in one place.

The flashback camera points are patched in the layout files' output by hand; re-check them
after moving furniture the flashback looks at (family photo, dining table).
