"""Render a room spec (same JSON shape as RoomDef) the way RoomScene draws it, for layout work."""
import json, sys
from PIL import Image, ImageDraw
import os
SPR = os.path.join(os.path.dirname(__file__), '..', '..', 'public', 'assets', 'sprites') + '/'
def tex(k):
    return Image.open(SPR + k + '.png').convert('RGBA')
def render(room, out, scale=3, boxes=False):
    W, H = room['size']['w'], room['size']['h']
    can = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    can.alpha_composite(tex(room['background']), (0, 0))
    draws = []  # (depth, image, x, y)
    def place(o, kind, base):
        if not o.get('tex'):
            return
        im = tex(o['tex'])
        sx, sy = (o.get('scale') or [1, 1])
        if (sx, sy) != (1, 1):
            im = im.resize((max(1, round(im.width * abs(sx))), max(1, round(im.height * abs(sy)))), Image.NEAREST)
            if sx < 0: im = im.transpose(Image.FLIP_LEFT_RIGHT)
        x = round(o['x'] - im.width / 2)
        y = round(o['y'] - im.height) if base else round(o['y'] - im.height / 2)
        layer = o.get('layer', 'ysort')
        z = o.get('z', 0) or 0
        d = (0 + z * 10 + o['y'] * 0.01) if layer == 'ground' else ((5000 if z > 0 else 1000) + o['y'])
        if kind == 'dirt': d = 500 + o['y'] * 0.01 if layer == 'ground' else 1000 + o['y'] + 0.5
        draws.append((d, im, x, y, o, kind))
    for d in room.get('floorDirt', []): place(d, 'dirt', False)
    for p in room['props']:
        place(p, 'prop', p.get('originAtBase', True))
        for d in p.get('dirt') or []: place(d, 'dirt', False)
    for z in room['zones']:
        place({**z, 'layer': 'ysort'}, 'zone', True)
        for d in z.get('dirt') or []: place(d, 'dirt', False)
    for i in room['items']: place({**i, 'layer': 'ysort'}, 'item', True)
    for i in room['interacts']: place({**i, 'layer': 'ysort'}, 'inter', True)
    for d, im, x, y, o, kind in sorted(draws, key=lambda t: t[0]):
        if o.get('shadow') and kind in ('prop', 'zone'):
            sh = Image.new('RGBA', can.size, (0, 0, 0, 0)); g = ImageDraw.Draw(sh)
            w = max(6, o['w'] * 0.8); g.ellipse([o['x'] - w / 2, o['y'] - 4, o['x'] + w / 2, o['y'] + 2], fill=(0, 0, 0, 56)); can.alpha_composite(sh)
        can.alpha_composite(im, (x, y))
    if boxes:
        g = ImageDraw.Draw(can)
        def rect(o, col):
            g.rectangle([o['x'] - o['w'] / 2, o['y'] - o['h'] / 2, o['x'] + o['w'] / 2, o['y'] + o['h'] / 2], outline=col)
        for p in room['props'] + room['zones']:
            for d in p.get('dirt') or []: rect(d, (255, 80, 80, 255) if d['tool'] == 'cloth' else (160, 120, 255, 255))
    can = can.resize((W * scale, H * scale), Image.NEAREST)
    can.save(out)
if __name__ == '__main__':
    room = json.load(open(sys.argv[1]))
    render(room, sys.argv[2], boxes='--boxes' in sys.argv)
