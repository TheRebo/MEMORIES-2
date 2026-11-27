"""Generate src/data/rooms/*.ts and src/data/sprites.ts from the converted Godot room JSON.

Usage:
  python3 tools/tscn2json.py $GODOT_PROJECT/scenes/rooms/kitchen.tscn > .cache/json/kitchen.json  (per room)
  GODOT_PROJECT=... DRIVE_ASSETS=... python3 tools/gen_rooms.py

Also copies every referenced sprite into public/assets/sprites/ under a URL-safe key.
Untextured Godot objects (rendered as colored boxes in the old build) get sprites from the
team's own asset folders via OVERRIDES below.
"""
import json
import os
import re
import shutil
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get('GODOT_PROJECT', '../MEMORIES')
DRIVE = os.environ.get('DRIVE_ASSETS', '../drive')
OUT_SPR = f'{REPO}/public/assets/sprites'
JSON_DIR = os.environ.get('ROOM_JSON', os.path.join(REPO, '.cache', 'json'))
KAMAR = 'assets/items/Item Dapur/Item Kamar Tidur-20261127T115325Z-1-001/Item Kamar Tidur'

TOOL = {0: 'broom', 1: 'mop', 2: 'cloth', 3: 'duster'}
ROOM_META = {
    'living_room': {'short': 'R. Keluarga', 'music': 'present'},
    'kitchen': {'short': 'Dapur', 'music': 'present'},
    'bedroom': {'short': 'Kamar', 'music': 'present'},
}

sprites = {}  # key -> dict(src, w, h, bbox)


def slug(path):
    base = os.path.splitext(os.path.basename(path))[0]
    base = base.replace('Document from Zulfa Rahma Ayu', 'doc')
    s = re.sub(r'[^a-zA-Z0-9]+', '_', base).strip('_').lower()
    if '/Item Dapur/' in path and 'Kamar' not in path:
        s = 'dapur_' + s
    elif 'Kamar Tidur' in path:
        s = 'kamar_' + s
    elif '/aset_potongan/' in path:
        s = 'pot_' + s
    elif '/scenes/objects/' in path:
        s = 'actor_' + s
    return s


CROPPED_DIR = os.path.join(REPO, '.cache', 'cropped')


def sprite(path, crop=False):
    """Register an image (absolute path or res:// path) and return its key.

    crop=True trims transparent padding, for sprites that are anchored by their base and were
    not hand-placed in the Godot editor.
    """
    if path.startswith('res://'):
        path = os.path.join(GODOT, path[len('res://'):])
    if path.endswith('.gif'):
        # Animated GIFs become spritesheets loaded separately (see PreloadScene).
        return slug(path)
    key = slug(path)
    if crop:
        im = Image.open(path).convert('RGBA')
        bb = im.getbbox()
        if bb and bb != (0, 0, im.width, im.height):
            os.makedirs(CROPPED_DIR, exist_ok=True)
            key = key + '_trim'
            path2 = os.path.join(CROPPED_DIR, key + '.png')
            im.crop(bb).save(path2)
            path = path2
    if key in sprites:
        assert sprites[key]['src'] == path, (key, path, sprites[key]['src'])
        return key
    im = Image.open(path).convert('RGBA')
    bb = im.getbbox() or (0, 0, im.width, im.height)
    sprites[key] = {'src': path, 'w': im.width, 'h': im.height,
                    'bbox': [bb[0], bb[1], bb[2] - bb[0], bb[3] - bb[1]]}
    return key


def G(rel):
    return os.path.join(GODOT, rel)


# Sprites for objects that had no texture in the Godot scenes. Values are paths in the
# team's own asset folders.
OVERRIDES = {
    'living_room': {
        'MejaSamping': G('assets/items/Meja_Bundar.png'),
        'Tanaman': G('assets/items/aset_potongan/tanaman_pot.png'),
        'MCDewasa': G('scenes/objects/Document from Zulfa Rahma Ayu.png'),
        'Jaring5': G('assets/dirt/JaringLabaLaba_Sudut.png'),
    },
    'kitchen': {
        'Kompor': G('assets/items/Item Dapur/Document from Zulfa Rahma Ayu(1).png'),
        'MejaMasak': G('assets/items/Item Dapur/Document from Zulfa Rahma Ayu.png'),
        'MejaSiap': G('assets/items/aset_potongan/meja_kotak.png'),
        'LemariDapur': G('assets/items/Lemari_Tutup.png'),
        'Tanaman': G('assets/items/aset_potongan/tanaman_mangkuk.png'),
        'Nenek': G('scenes/objects/Document from Zulfa Rahma Ayu (1).png'),
        'MCKecil': G('scenes/objects/Document from Zulfa Rahma Ayu.png'),
        'MCDewasa': G('scenes/objects/Document from Zulfa Rahma Ayu.png'),
    },
    'bedroom': {
        'Cermin': G(KAMAR + '/Document from Zulfa Rahma Ayu.png'),
        'FotoBingkai': G('assets/items/Document from Zulfa Rahma Ayu(4).png'),
        'NightstandL': G('assets/items/aset_potongan/laci_kecil.png'),
        'NightstandR': G('assets/items/aset_potongan/laci_kecil.png'),
        'Keranjang': G('assets/items/aset_potongan/peti_kayu_kecil_1.png'),
        'Tanaman': G('assets/items/aset_potongan/tanaman_bunga_putih.png'),
        'RakMeja': G('assets/items/Document from Zulfa Rahma Ayu(7).png'),
        'Nenek': G('scenes/objects/Document from Zulfa Rahma Ayu (1).png'),
        'MCKecil': G('scenes/objects/Document from Zulfa Rahma Ayu.png'),
        'BarangMeja1': G(KAMAR + '/pensil.png'),
        'BarangMeja2': G('assets/items/buku kuning.png'),
        'BarangMeja3': G('assets/items/buku merah.png'),
        'Baju1': G(KAMAR + '/baju merah.png'),
        'Baju2': G(KAMAR + '/baju ungu.png'),
        'Baju3': G(KAMAR + '/baju kuning.png'),
    },
}
TRASH = [f'{DRIVE}/items/trash_apple.png', f'{DRIVE}/items/trash_paper.png',
         f'{DRIVE}/items/trash_can1.png', f'{DRIVE}/items/trash_can2.png']
BIN_STATES = [G('assets/tools/Item-Bak Sampah-Kosong.png'), f'{DRIVE}/items/bin_full1.png',
              f'{DRIVE}/items/bin_full2.png']
DUST_TEX = G('assets/dirt/debu ulahan daus.png')
MOP_TEX = [G(f'assets/dirt/kamar_Ground_PelNoda{i}.png') for i in (1, 2, 3, 4)]
WEB_TEX = [G('assets/dirt/JaringLabaLaba_Sudut.png'),
           G('assets/dirt/Jaring laba laba pro maxx by Faris, better than punya Zulfa.png')]
PUDDLE = G('assets/dirt/Genangan Air.png')


def tex_of(props, key='texture'):
    v = props.get(key)
    if isinstance(v, dict) and 'ext' in v:
        return v['ext']
    return None


def vec(v, default=(0.0, 0.0)):
    if isinstance(v, dict) and 'x' in v:
        return (v['x'], v['y'])
    return default


def color(v, default):
    if isinstance(v, dict) and 'color' in v:
        c = v['color']
        return [round(x, 3) for x in c]
    return default


def kind_of(node):
    inst = node.get('instance') or ''
    for k in ('world_object', 'dirt_spot', 'draggable_item', 'drop_zone', 'interactable_object', 'actor'):
        if inst.endswith(k + '.tscn'):
            return k
    return None


def build(room_id):
    d = json.load(open(os.path.join(JSON_DIR, f'{room_id}.json')))
    nodes = d['nodes']
    subs = d['sub']
    over = OVERRIDES.get(room_id, {})
    root = nodes[0]['props']
    room = {
        'id': room_id,
        'name': root.get('room_name', 'Ruang Keluarga'),
        'short': ROOM_META[room_id]['short'],
        'size': dict(zip(('w', 'h'), vec(root.get('room_size'), (512, 352)))),
        'wallHeight': root.get('wall_height', 64),
        'background': sprite(tex_of(root, 'background_texture')),
    }
    by_path = {}
    props, zones, items, interacts, actors, floor = [], [], [], [], [], []
    counters = {'trash': 0, 'mop': 0, 'web': 0}

    def resolve_size(p, tex_path):
        size = vec(p.get('size'), (32, 16))
        if tex_path and p.get('use_texture_size', True):
            s = sprites[sprite(tex_path)]
            size = (s['w'], s['h'])
        return size

    def dirt_def(n, p, parent=None):
        tool = int(p.get('required_tool', 0))
        tex = tex_of(p) or over.get(n['name'] if parent is None else None)
        if not tex:
            if tool == 0 and parent is None:
                tex = DUST_TEX
            elif tool == 1:
                tex = MOP_TEX[counters['mop'] % 4]
                counters['mop'] += 1
            elif tool == 3 and parent is None:
                tex = WEB_TEX[counters['web'] % 2]
                counters['web'] += 1
        x, y = vec(p.get('position'))
        size = vec(p.get('size'), (32, 16))
        if tex and p.get('use_texture_size', True) and parent is None:
            s = sprites[sprite(tex)]
            size = (s['w'], s['h'])
        out = {
            'id': n['name'] if parent is None else f"{parent['id']}.{n['name']}",
            'x': x, 'y': y, 'w': size[0], 'h': size[1],
            'tool': TOOL[tool],
            'effort': p.get('clean_effort', 500.0),
            'group': p.get('task_group', ''),
        }
        if tex and parent is None:
            out['tex'] = sprite(tex)
        if parent is not None:
            sx, sy = parent.get('scale', (1, 1))
            out['x'] = round(parent['x'] + x * sx, 2)
            out['y'] = round(parent['y'] + y * sy, 2)
            out['w'] = round(size[0] * sx, 2)
            out['h'] = round(size[1] * sy, 2)
            out['parent'] = parent['id']
        if p.get('rotation'):
            out['rotation'] = round(p['rotation'], 4)
        if p.get('reward_item'):
            out['reward'] = {'item': p['reward_item'], 'amount': p.get('reward_amount', 1),
                             'message': p.get('reward_message', '')}
        return out

    for n in nodes[1:]:
        k = kind_of(n)
        p = n['props']
        parent_path = n['parent'] or ''
        path = n['name'] if parent_path in ('.', '') else f"{parent_path}/{n['name']}"
        if k is None:
            continue
        layer = 'ground' if parent_path == 'Ground' else 'ysort'
        if k == 'dirt_spot':
            parent = by_path.get(parent_path)
            dd = dirt_def(n, p, parent)
            if parent is None:
                dd['layer'] = layer
                floor.append(dd)
            else:
                parent.setdefault('dirt', []).append(dd)
            continue
        tex = tex_of(p)
        crop = False
        if not tex and n['name'] in over and k != 'actor':
            tex, crop = over[n['name']], True
        elif not tex and k == 'actor':
            tex = over.get(n['name'])
        if k == 'draggable_item' and not tex and p.get('counts_as_trash'):
            tex = TRASH[counters['trash'] % len(TRASH)]
            counters['trash'] += 1
            crop = True
        if tex and crop:
            tex = sprites[sprite(tex, crop=True)]['src']
        x, y = vec(p.get('position'))
        size = resolve_size(p, tex)
        base = {
            'id': n['name'], 'x': x, 'y': y, 'w': size[0], 'h': size[1],
            'label': p.get('display_name', '') or n['name'],
        }
        if tex:
            base['tex'] = sprite(tex)
        if p.get('z_index'):
            base['z'] = p['z_index']
        sc = p.get('scale')
        if isinstance(sc, dict):
            base['scale'] = [sc['x'], sc['y']]
        if k == 'world_object':
            base['layer'] = layer
            base['originAtBase'] = p.get('origin_at_base', True)
            base['shadow'] = p.get('show_shadow', True) and base['originAtBase']
            props.append(base)
            by_path[path] = base
        elif k == 'drop_zone':
            states = [sprite(t['ext']) for t in p.get('state_textures', []) if isinstance(t, dict) and 'ext' in t]
            accepts = p.get('accepted_type', 'trash')
            if accepts == 'trash' and not p.get('limit_to_capacity', True):
                states = [sprite(s, crop=True) for s in BIN_STATES]
                base['tex'] = states[0]
                s0 = sprites[states[0]]
                base['w'], base['h'] = s0['w'], s0['h']
            base.update({
                'accepts': accepts,
                'capacity': (len(states) - 1) if len(states) > 1 and p.get('limit_to_capacity', True)
                else p.get('expected_items', 3),
                'limit': p.get('limit_to_capacity', True),
                'states': states,
                'showCounter': p.get('show_counter_label', True),
                'shadow': p.get('show_shadow', True),
            })
            if accepts == 'trash' and not p.get('limit_to_capacity', True):
                base['statesByFill'] = True
            zones.append(base)
            by_path[path] = base
        elif k == 'draggable_item':
            base.update({'type': p.get('item_type', 'trash'), 'trash': bool(p.get('counts_as_trash', False)),
                         'group': p.get('task_group', '')})
            items.append(base)
        elif k == 'interactable_object':
            after = tex_of(p, 'after_texture')
            base.update({'group': p.get('task_group', ''), 'hideAfter': bool(p.get('hide_after', False)),
                         'trash': bool(p.get('counts_as_trash', False)),
                         'needed': p.get('interactions_needed', 1),
                         'shadow': p.get('show_shadow', True)})
            if after:
                base['after'] = sprite(after)
            interacts.append(base)
        elif k == 'actor':
            aid = p.get('actor_id', 'mc')
            base.update({'actor': aid, 'cutscene': p.get('cutscene_id', 'flashback')})
            actors.append(base)

    # Cutscene lines
    lines = []
    for n in nodes:
        if n['name'] == 'Flashback':
            for ref in n['props'].get('lines', []):
                sp = subs[ref['sub']]['props']
                line = {'speaker': sp.get('speaker', ''), 'text': sp.get('text', '')}
                for src, dst in (('show_actors', 'show'), ('hide_actors', 'hide')):
                    if sp.get(src):
                        line[dst] = [s.strip() for s in sp[src].split(',') if s.strip()]
                moves = []
                for a, m in (('actor_a', 'move_a_to'), ('actor_b', 'move_b_to')):
                    if sp.get(a) and sp.get(m):
                        moves.append({'actor': sp[a], 'x': sp[m]['x'], 'y': sp[m]['y']})
                if moves:
                    line['moves'] = moves
                if sp.get('set_tint'):
                    line['tint'] = color(sp.get('tint_color'), [1, 1, 1, 1])
                if sp.get('screen_fade') == 1:
                    line['fadeToBlack'] = True
                if sp.get('camera_focus'):
                    line['focus'] = list(vec(sp['camera_focus']))
                if sp.get('camera_zoom'):
                    line['zoom'] = sp['camera_zoom']
                if sp.get('hold_time'):
                    line['hold'] = sp['hold_time']
                lines.append(line)
            fp = n['props']
            room['flashbackTint'] = color(fp.get('tint'), [1, 1, 1, 1])

    # Events
    events = []
    for n in nodes:
        if n['parent'] != 'RoomEvents':
            continue
        p = n['props']
        ev = {'kind': n['name'].replace('Event', '').lower()}
        for k2, v in p.items():
            if k2 in ('script', 'unique_id', 'dirt_spot_scene', 'roach_scene', 'spawn_parent', 'window_path'):
                continue
            if k2 == 'tutorial_pages':
                ev['tutorial'] = [{'title': subs[r['sub']]['props'].get('title', ''),
                                   'text': subs[r['sub']]['props'].get('text', '')} for r in v]
                continue
            if isinstance(v, dict) and 'ext' in v:
                ev[camel(k2)] = sprite(v['ext'])
            elif isinstance(v, dict) and 'color' in v:
                ev[camel(k2)] = color(v, None)
            elif isinstance(v, dict) and 'x' in v and 'w' in v:
                ev[camel(k2)] = v
            elif isinstance(v, dict) and 'x' in v:
                ev[camel(k2)] = {'x': v['x'], 'y': v['y']}
            else:
                ev[camel(k2)] = v
        events.append(ev)

    room.update({'floorDirt': floor, 'props': props, 'zones': zones, 'items': items,
                 'interacts': interacts, 'actors': actors, 'flashback': lines, 'events': events})
    return room


def camel(s):
    parts = s.split('_')
    return parts[0] + ''.join(x.title() for x in parts[1:])


def _prim(v):
    return not isinstance(v, (dict, list)) or (isinstance(v, list) and all(not isinstance(x, (dict, list)) for x in v))


def _scalar(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    if isinstance(v, (int, float)):
        return repr(round(v, 4))
    if isinstance(v, str):
        return "'" + v.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n') + "'"
    if isinstance(v, (list, tuple)):
        return '[' + ', '.join(_scalar(x) for x in v) + ']'
    raise TypeError(v)


def emit(v, ind):
    pad = '  ' * ind
    if isinstance(v, dict):
        if all(_prim(x) for x in v.values()):
            inner = ', '.join(f'{k}: {_scalar(x)}' for k, x in v.items())
            line = '{ ' + inner + ' }'
            if len(line) + len(pad) <= 190:
                return line
        parts = [f'{pad}  {k}: {emit(x, ind + 1)},' for k, x in v.items()]
        return '{\n' + '\n'.join(parts) + '\n' + pad + '}'
    if isinstance(v, (list, tuple)):
        if not v:
            return '[]'
        if all(not isinstance(x, (dict, list)) for x in v):
            return _scalar(list(v))
        parts = [f'{pad}  {emit(x, ind + 1)},' for x in v]
        return '[\n' + '\n'.join(parts) + '\n' + pad + ']'
    return _scalar(v)


def ts_room(room):
    var = camel(room['id'])
    body = emit(room, 0)
    return ("// Generated from the Godot scene by tools/gen_rooms.py, then kept as plain data.\n"
            "import type { RoomDef } from '../types';\n\n"
            f"export const {var}: RoomDef = {body};\n")


def main():
    os.makedirs(OUT_SPR, exist_ok=True)
    os.makedirs(f'{REPO}/src/data/rooms', exist_ok=True)
    # extra sprites used by code (events, tools, UI)
    extra = {
        'cat': G('assets/characters/cat run.gif'),
        'roach': G('assets/characters/kecoa.png'),
        'candle': G('assets/tools/lilin.png'),
        'puddle': PUDDLE,
        'tool_broom': G('assets/tools/Item-Sapu.png'),
        'tool_mop': G('assets/tools/Item-Pel.png'),
        'tool_cloth': G('assets/tools/Item-Kain Lap.png'),
        'tool_duster': G('assets/tools/kemoceng daus.png'),
        'trash_bag': f'{DRIVE}/items/trash_bag.png',
        'glove_open': f'{DRIVE}/items/glove_open.png',
        'glove_close': f'{DRIVE}/items/glove_close.png',
        'smudge': G('assets/dirt/kotor.png'),
        'dust_small': G('assets/dirt/alternatif debu.png'),
        'dust_large': G('assets/dirt/Debu_Large.png'),
        'web_a': WEB_TEX[0], 'web_b': WEB_TEX[1],
    }
    extra_keys = {}
    rooms = {}
    for rid in ('living_room', 'kitchen', 'bedroom'):
        rooms[rid] = build(rid)
    for name, path in extra.items():
        if path.endswith('.gif'):
            continue
        extra_keys[name] = sprite(path)
    for rid, room in rooms.items():
        open(f'{REPO}/src/data/rooms/{camel(rid)}.ts', 'w').write(ts_room(room))
    # copy sprites + manifest
    lines = ["// Generated by tools/gen_rooms.py: every sprite key, its file and alpha bounding box.",
             "export interface SpriteInfo { readonly file: string; readonly w: number; readonly h: number;",
             "  /** Visible-pixel box [x, y, w, h] inside the image, used for precise hit areas. */",
             "  readonly bbox: readonly [number, number, number, number] }", "",
             "export const SPRITES = {"]
    for key in sorted(sprites):
        s = sprites[key]
        shutil.copy(s['src'], f'{OUT_SPR}/{key}.png')
        lines.append(f"  {key}: {{ file: 'sprites/{key}.png', w: {s['w']}, h: {s['h']}, bbox: [{', '.join(map(str, s['bbox']))}] }},")
    lines += ["} as const satisfies Record<string, SpriteInfo>;", "",
              "export type SpriteKey = keyof typeof SPRITES;", "",
              "/** Sprites referenced from code rather than room data. */",
              "export const SPRITE = {"]
    for name, key in sorted(extra_keys.items()):
        lines.append(f"  {name}: '{key}',")
    lines += ["} as const satisfies Record<string, SpriteKey>;", ""]
    open(f'{REPO}/src/data/sprites.ts', 'w').write('\n'.join(lines))
    print('sprites', len(sprites))
    for rid, r in rooms.items():
        print(rid, {k: len(v) for k, v in r.items() if isinstance(v, list)})


if __name__ == '__main__':
    main()
