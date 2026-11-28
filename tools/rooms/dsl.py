"""Small layout DSL: rooms are written as placements, dirt is placed relative to the art it sits on."""
import json, copy
from PIL import Image

import os
SPR = os.path.join(os.path.dirname(__file__), '..', '..', 'public', 'assets', 'sprites') + '/'
_cache = {}


def info(tex):
    if tex not in _cache:
        im = Image.open(SPR + tex + '.png').convert('RGBA')
        bb = im.getbbox() or (0, 0, im.width, im.height)
        _cache[tex] = (im.width, im.height, bb)
    return _cache[tex]


def art_box(tex, x, y, base=True, scale=(1, 1)):
    """World rect (x0, y0, x1, y1) of the visible art of a placed sprite."""
    w, h, (bx0, by0, bx1, by1) = info(tex)
    sx, sy = abs(scale[0]), abs(scale[1])
    left = x - w * sx / 2
    top = y - h * sy if base else y - h * sy / 2
    return (left + bx0 * sx, top + by0 * sy, left + bx1 * sx, top + by1 * sy)


class Room:
    def __init__(self, old, **over):
        self.d = copy.deepcopy(old)
        self.d.update(over)
        self.d['floorDirt'] = []
        self.d['props'] = []
        self.old_zones = {z['id']: z for z in old['zones']}
        self.old_items = {i['id']: i for i in old['items']}
        self.old_inter = {i['id']: i for i in old['interacts']}
        self.old_actors = {a['id']: a for a in old['actors']}
        self.d['zones'] = []
        self.d['items'] = []
        self.d['interacts'] = []
        self.d['actors'] = []

    # ---- dirt on furniture, relative to the art's top-left; fractions allowed (0..1) ----
    def _dirt(self, owner, tex, x, y, base, scale, specs):
        out = []
        x0, y0, x1, y1 = art_box(tex, x, y, base, scale)
        aw, ah = x1 - x0, y1 - y0
        for n, s in enumerate(specs, 1):
            tool, group, rx, ry, rw, rh = s[:6]
            extra = s[6] if len(s) > 6 else {}
            f = lambda v, span: v * span if isinstance(v, float) and v <= 1 else v
            w, h = f(rw, aw), f(rh, ah)
            cx, cy = x0 + f(rx, aw) + w / 2, y0 + f(ry, ah) + h / 2
            tag = 'Debu' if tool == 'duster' else 'Kotor'
            d = {'id': f'{owner}.{tag}{n}', 'x': round(cx), 'y': round(cy), 'w': round(w), 'h': round(h), 'tool': tool,
                 'effort': extra.pop('effort', 0), 'group': group, 'parent': owner}
            d.update(extra)
            out.append(d)
        return out

    def prop(self, id, tex, x, y, label, layer='ysort', base=True, shadow=False, z=None, scale=None, dirt=()):
        p = {'id': id, 'x': x, 'y': y, 'w': 0, 'h': 0, 'label': label, 'tex': tex, 'layer': layer,
             'originAtBase': base, 'shadow': shadow}
        w, h, _ = info(tex)
        p['w'], p['h'] = round(w * abs((scale or (1, 1))[0])), round(h * abs((scale or (1, 1))[1]))
        if z: p['z'] = z
        if scale: p['scale'] = list(scale)
        if dirt: p['dirt'] = self._dirt(id, tex, x, y, base, scale or (1, 1), dirt)
        self.d['props'].append(p)
        return p

    def zone(self, id, x, y, dirt=(), **over):
        z = copy.deepcopy(self.old_zones[id])
        z.update(over)
        z['x'], z['y'] = x, y
        z['dirt'] = self._dirt(id, z['tex'], x, y, True, (1, 1), dirt) if dirt else []
        self.d['zones'].append(z)
        return z

    def new_zone(self, id, x, y, label, tex, accepts, capacity, states, dirt=(), limit=True, show=True, shadow=True):
        w, h, _ = info(tex)
        z = {'id': id, 'x': x, 'y': y, 'w': w, 'h': h, 'label': label, 'tex': tex, 'accepts': accepts, 'capacity': capacity,
             'limit': limit, 'states': states, 'showCounter': show, 'shadow': shadow}
        z['dirt'] = self._dirt(id, tex, x, y, True, (1, 1), dirt) if dirt else []
        self.d['zones'].append(z)
        return z

    def item(self, id, x, y, **over):
        i = copy.deepcopy(self.old_items[id]) if id in self.old_items else {}
        i.update(over)
        i['id'], i['x'], i['y'] = id, x, y
        if 'tex' in over:
            w, h, _ = info(over['tex'])
            i['w'], i['h'] = w, h
        self.d['items'].append(i)

    def inter(self, id, x, y, **over):
        i = copy.deepcopy(self.old_inter[id]) if id in self.old_inter else {}
        i.update(over)
        i['id'], i['x'], i['y'] = id, x, y
        if 'tex' in over and 'w' not in over:
            w, h, _ = info(over['tex'])
            i['w'], i['h'] = w, h
        self.d['interacts'].append(i)

    def actor(self, id, x, y):
        a = copy.deepcopy(self.old_actors[id])
        a['x'], a['y'] = x, y
        self.d['actors'].append(a)

    def floor(self, id, x, y, tool, group, tex, w, h, **extra):
        d = {'id': id, 'x': x, 'y': y, 'w': w, 'h': h, 'tool': tool, 'effort': 0, 'group': group, 'tex': tex, 'layer': 'ground'}
        d.update(extra)
        self.d['floorDirt'].append(d)

    def save(self, path):
        json.dump(self.d, open(path, 'w'), indent=1)
