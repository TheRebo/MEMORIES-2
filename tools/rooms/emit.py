"""Write src/data/rooms/<room>.ts from the layout JSON, with efforts from one tuning table."""
import json, os, re, sys

# Scrub distance per tool for a 16x16 spot; larger spots scale with their perimeter.
# DIFFICULTY multiplies everything: the redesigned rooms are meant to be a real chore.
DIFFICULTY = 1.45
BASE = {'broom': 96, 'mop': 108, 'cloth': 84, 'duster': 78}
PER_PX = {'broom': 1.6, 'mop': 1.9, 'cloth': 1.5, 'duster': 1.1}


def effort(d):
    e = (BASE[d['tool']] + PER_PX[d['tool']] * (d['w'] + d['h'])) * DIFFICULTY
    return int(round(e / 6) * 6)


def ts(v, ind=0):
    pad = '  ' * ind
    if isinstance(v, dict):
        if not v: return '{}'
        parts = [f"{k if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', k) else json.dumps(k)}: {ts(x, ind + 1)}" for k, x in v.items() if x is not None]
        one = '{ ' + ', '.join(parts) + ' }'
        if len(one) + len(pad) < 150 and '\n' not in one: return one
        return '{\n' + ''.join(f'{pad}  {p},\n' for p in parts) + pad + '}'
    if isinstance(v, list):
        if not v: return '[]'
        items = [ts(x, ind + 1) for x in v]
        one = '[' + ', '.join(items) + ']'
        if len(one) + len(pad) < 150 and '\n' not in one: return one
        return '[\n' + ''.join(f'{pad}  {i},\n' for i in items) + pad + ']'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, float) and v.is_integer(): return str(int(v))
    if isinstance(v, str): return "'" + v.replace('\\', '\\\\').replace("'", "\\'") + "'"
    return json.dumps(v)


def emit(src, const, out):
    d = json.load(open(src))
    for p in d['props'] + d['zones']:
        for x in p.get('dirt') or []: x['effort'] = effort(x)
        if not p.get('dirt'): p.pop('dirt', None)
    for x in d['floorDirt']: x['effort'] = effort(x)
    order = ['id', 'name', 'short', 'size', 'wallHeight', 'background', 'flashbackTint', 'floorDirt', 'props', 'zones', 'items', 'interacts', 'actors', 'flashback', 'events']
    d = {k: d[k] for k in order}
    body = ts(d)
    open(out, 'w').write("// Room layout: written in tools-free data, laid out against the 512x352 backgrounds.\n"
                         "// Efforts come from one tuning table (see work notes: BASE, PER_PX, DIFFICULTY).\n"
                         "import type { RoomDef } from '../types';\n\n"
                         f"export const {const}: RoomDef = {body};\n")


if __name__ == '__main__':
    R = os.path.join(os.path.dirname(__file__), '..', '..', 'src', 'data', 'rooms') + '/'
    emit(os.path.join(os.path.dirname(__file__), 'out_living_room.json'), 'livingRoom', R + 'livingRoom.ts')
    emit(os.path.join(os.path.dirname(__file__), 'out_kitchen.json'), 'kitchen', R + 'kitchen.ts')
    emit(os.path.join(os.path.dirname(__file__), 'out_bedroom.json'), 'bedroom', R + 'bedroom.ts')
