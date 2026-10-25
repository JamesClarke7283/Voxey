#!/usr/bin/env python3
"""Export the local Mineclonia trial/vault loot tables without running Lua.

The JSON retains source item names, weights and transformation parameters.
Source: Mineclonia, GPL-3.0-or-later; see docs/licenses.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path('/home/impulse/.minetest/games/mineclonia')
OUT = Path(__file__).resolve().parents[1] / 'assets/data/trial_loot.json'


def balanced(text, start):
    depth = 0
    for end in range(start, len(text)):
        if text[end] == '{':
            depth += 1
        elif text[end] == '}':
            depth -= 1
            if depth == 0:
                return text[start:end + 1]
    raise ValueError('Unclosed source table')


def pools(text):
    result = []
    for part in re.split(r'(?=stacks_min\s*=)', text)[1:]:
        pool = {'min': int(re.search(r'stacks_min\s*=\s*(\d+)', part)[1]),
                'max': int(re.search(r'stacks_max\s*=\s*(\d+)', part)[1]), 'items': []}
        for line in part.splitlines():
            if not re.search(r'itemstring\s*=|nothing\s*=', line):
                continue
            item = {}
            name = re.search(r'itemstring\s*=\s*"([^"]+)"', line)
            item['item'] = name[1] if name else ''
            for key, default in [('weight', 1), ('amount_min', 1), ('amount_max', 1)]:
                match = re.search(r'\b' + key + r'\s*=\s*(\d+)', line)
                item[key] = int(match[1]) if match else default
            if 'wear_min' in line:
                item['wear'] = [int(re.search(k + r'\s*=\s*(\d+)', line)[1]) for k in ['wear_min', 'wear_max']]
            omen = re.search(r'set_bad_omen_level\(stack, pr:next\((\d+),\s*(\d+)\)', line)
            if omen:
                item['omen'] = [int(omen[1]), int(omen[2])]
            potency = re.search(r'set_potency\(stack, (\d+)\)', line)
            if potency:
                item['potency'] = int(potency[1])
            enchant = re.search(r'enchant_random_level\(stack, \{([^}]+)', line)
            if enchant:
                item['enchantments'] = re.findall(r'"([^"]+)"', enchant[1])
            elif 'mcl_enchanting.enchant(stack, "wind_burst", 1)' in line:
                item['enchantments'] = ['wind_burst']
                item['enchantment_level'] = 1
            level = re.search(r'enchant_randomly\(stack, pr:next\((\d+),\s*(\d+)\)', line)
            if level:
                item['enchant_power'] = [int(level[1]), int(level[2])]
            pool['items'].append(item)
        result.append(pool)
    return result


paths = ['mods/ITEMS/mcl_vaults/init.lua', 'mods/ITEMS/mcl_trial_spawners/init.lua']
vault, spawner = [(ROOT / path).read_text() for path in paths]
tables = {}
for name in ['vault', 'ominous_vault']:
    start = vault.index('loot = {', vault.index('register_vault("' + name + '"')) + len('loot = ')
    tables[name] = pools(balanced(vault, start))
for name in ['standard', 'ominous']:
    start = spawner.index('{', spawner.index('local ' + name + '_loot_table'))
    tables[name + '_spawner'] = pools(balanced(spawner, start))
chambers_path = 'mods/MAPGEN/mcl_levelgen/trial_chambers.lua'
chambers = (ROOT / chambers_path).read_text()
for match in re.finditer(r'register_loot_table \("mcl_levelgen:(trial_chambers_[^"]+)"', chambers):
    start = chambers.index('{', match.end())
    tables[match[1]] = pools(balanced(chambers, start))
start = chambers.index('{', chambers.index('local decorated_pot_loot_table'))
tables['trial_chambers_pot'] = pools(balanced(chambers, start))
paths.append(chambers_path)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps({'license': 'GPL-3.0-or-later',
    'source_hashes': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
    'tables': tables}, indent=2) + '\n')
print('Exported', sum(len(p['items']) for ps in tables.values() for p in ps), 'weighted entries to', OUT)
