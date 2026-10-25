#!/usr/bin/env python3
"""Export the supplied Mineclonia trail-ruin templates, pools and archaeology loot."""
import hashlib
import json
import re
from pathlib import Path
from export_trial_templates import ROOT, read_template

OUT = Path(__file__).resolve().parents[1] / 'assets/data'


def table(text, start):
    depth = 0
    quoted = False
    escaped = False
    for i in range(start, len(text)):
        c = text[i]
        if c == '"' and not escaped:
            quoted = not quoted
        if not quoted:
            depth += (c == '{') - (c == '}')
            if depth == 0:
                return text[start:i + 1]
        escaped = c == '\\' and not escaped
    raise ValueError('Unclosed table')


def export():
    templates, hashes = {}, {}
    for path in sorted((ROOT / 'templates').glob('trail_ruins_*.dat')):
        templates[path.stem] = read_template(path)
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    source = (ROOT / 'trail_ruins.lua').read_text()
    hashes['trail_ruins.lua'] = hashlib.sha256(source.encode()).hexdigest()
    processors = {}
    for match in re.finditer(r'local (trail_ruins_\w+_archaeology) = \{', source):
        body = table(source, source.index('{', match.start()))
        count = re.search(r'archaeology_processor \((\d+), (\d+)\)', body)
        processors[match[1]] = {'common': int(count[1]), 'rare': int(count[2]),
                                'degrade': 'degrade_gravel_and_mud_bricks' in body}
    pools = {}
    for match in re.finditer(r'register_template_pool \("mcl_levelgen:([^"]+)"', source):
        body = table(source, source.index('{', match.end()))
        current = list(re.finditer(r'^processors = (\w+)', source[:match.start()], re.M))[-1][1]
        entries = []
        for item in re.finditer(r'L \("([^"]+)", (\d+)(, true)?\)', body):
            entries.append({'name': item[1], 'weight': int(item[2]),
                            'no_terrain_adaptation': bool(item[3]), **processors[current]})
        pools[match[1]] = entries
    (OUT / 'trail_templates.json').write_text(json.dumps({
        'license': 'GPL-3.0-or-later', 'source_hashes': hashes,
        'pools': pools, 'templates': templates}, separators=(',', ':')) + '\n')

    path = ROOT.parents[1] / 'ITEMS/mcl_sus_nodes/init.lua'
    text = path.read_text()
    clean = re.sub(r'--[^\n]*', '', text)
    loot = {}
    for name in ['trail_ruins_common', 'trail_ruins_rare', 'desert_pyramid_archeology', 'ocean_ruins_warm', 'ocean_ruins_cold', 'desert_well_loot']:
        start = clean.index('{', clean.index(name + ' ='))
        body = table(clean, start)
        items = []
        for match in re.finditer(r'itemstring\s*=\s*"([^"]+)"', body):
            begin = body.rfind('{', 0, match.start())
            item = table(body, begin)
            weight = re.search(r'weight\s*=\s*(\d+)', item)
            entry = {'item': match[1], 'weight': int(weight[1]) if weight else 1}
            if 'set_candle_properties' in item:
                colors = table(item, item.index('{', item.index('local colors')))
                entry['candle_colors'] = re.findall(r'"([^"]+)"', colors)
            items.append(entry)
        loot['desert_well' if name == 'desert_well_loot' else name] = items
    (OUT / 'archaeology_loot.json').write_text(json.dumps({
        'license': 'GPL-3.0-or-later', 'source_hashes': {
            'mods/ITEMS/mcl_sus_nodes/init.lua': hashlib.sha256(text.encode()).hexdigest()},
        'tables': loot}, indent=2) + '\n')
    print(f'Exported {len(templates)} trail templates, {len(pools)} pools and {sum(map(len, loot.values()))} archaeology entries')


if __name__ == '__main__':
    export()
