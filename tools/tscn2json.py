"""Convert a Godot 4 room .tscn into a plain JSON description (nodes, resources, props)."""
import json
import re
import sys

HEADER = re.compile(r'^\[(\w+)(.*)\]$')
ATTR = re.compile(r'(\w+)=("(?:[^"\\]|\\.)*"|\S+)')


def parse_value(s, ext, sub):
    s = s.strip()
    if s in ('true', 'false'):
        return s == 'true'
    if s.startswith('"'):
        return json.loads(s)
    if s.startswith('&"'):
        return json.loads(s[1:])
    m = re.match(r'^Vector2\(([^,]+),([^)]+)\)$', s)
    if m:
        return {'x': float(m.group(1)), 'y': float(m.group(2))}
    m = re.match(r'^Rect2\(([^)]+)\)$', s)
    if m:
        a = [float(v) for v in m.group(1).split(',')]
        return {'x': a[0], 'y': a[1], 'w': a[2], 'h': a[3]}
    m = re.match(r'^Color\(([^)]+)\)$', s)
    if m:
        return {'color': [float(v) for v in m.group(1).split(',')]}
    m = re.match(r'^ExtResource\("([^"]+)"\)$', s)
    if m:
        return {'ext': ext.get(m.group(1), m.group(1))}
    m = re.match(r'^SubResource\("([^"]+)"\)$', s)
    if m:
        return {'sub': m.group(1)}
    m = re.match(r'^NodePath\("([^"]*)"\)$', s)
    if m:
        return {'nodepath': m.group(1)}
    m = re.match(r'^Array\[[^\]]*\]\(\[(.*)\]\)$', s, re.S)
    if m:
        inner = m.group(1).strip()
        if not inner:
            return []
        parts = re.findall(r'(?:ExtResource|SubResource)\("[^"]+"\)', inner)
        return [parse_value(p, ext, sub) for p in parts]
    try:
        return float(s) if ('.' in s or 'e' in s) else int(s)
    except ValueError:
        return {'raw': s}


def main(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    ext, sub, nodes = {}, {}, []
    cur = None
    buf_key = None
    buf = ''
    for line in lines:
        if buf_key is not None:
            buf += '\n' + line
            if buf.count('"') % 2 == 0 and not buf.rstrip().endswith(','):
                cur['props'][buf_key] = buf
                buf_key = None
            continue
        m = HEADER.match(line.strip())
        if m:
            kind, rest = m.group(1), m.group(2)
            attrs = {k: (json.loads(v) if v.startswith('"') else v) for k, v in ATTR.findall(rest)}
            if kind == 'ext_resource':
                ext[attrs['id']] = attrs.get('path')
                cur = None
            elif kind == 'sub_resource':
                cur = {'id': attrs['id'], 'type': attrs.get('type'), 'props': {}}
                sub[attrs['id']] = cur
            elif kind == 'node':
                cur = {'name': attrs['name'], 'parent': attrs.get('parent'), 'type': attrs.get('type'),
                       'instance': None, 'groups': attrs.get('groups'), 'props': {}}
                inst = re.search(r'instance=ExtResource\("([^"]+)"\)', rest)
                if inst:
                    cur['instance'] = ext[inst.group(1)]
                nodes.append(cur)
            else:
                cur = None
            continue
        if cur is None or '=' not in line:
            continue
        k, v = line.split('=', 1)
        k = k.strip()
        if v.strip().startswith('"') and v.count('"') % 2 == 1:
            buf_key, buf = k, v
            continue
        cur['props'][k] = v
    for coll in (list(sub.values()), nodes):
        for item in coll:
            item['props'] = {k: parse_value(v, ext, sub) for k, v in item['props'].items()}
    out = {'ext': ext, 'sub': {k: {'type': v['type'], 'props': v['props']} for k, v in sub.items()}, 'nodes': nodes}
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main(sys.argv[1])
