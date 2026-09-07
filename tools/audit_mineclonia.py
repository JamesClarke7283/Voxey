#!/usr/bin/env python3
"""Inventory local Mineclonia modules and literal registrations; never infer parity."""
import argparse
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', nargs='?', default='/home/impulse/.minetest/games/mineclonia')
parser.add_argument('--output', default='docs/mineclonia-audit.json')
args = parser.parse_args()
root = Path(args.source).resolve()
registrations = re.compile(r'\b(?:core|minetest|mcl_[a-z_]+|mobs):?\.?register_([a-z_]+)\s*\(\s*[\"\']([^\"\']+)[\"\']')
modules = []
for conf in sorted((root/'mods').rglob('mod.conf')):
    folder = conf.parent
    config = dict(re.findall(r'^\s*(\w+)\s*=\s*(.*?)\s*$', conf.read_text(), re.M))
    files = sorted(folder.rglob('*.lua'))
    records = []
    for file in files:
        source = file.read_text()
        for match in registrations.finditer(source):
            records.append({'kind': match[1], 'name': match[2], 'file': str(file.relative_to(root)), 'line': source.count('\n',0,match.start())+1})
    modules.append({'name':config.get('name',folder.name), 'path':str(folder.relative_to(root)),
                    'description':config.get('description',''), 'lua_files':len(files),
                    'source_hashes': {str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},
                    'literal_registrations':records, 'parity_status':'unreviewed'})
result = {'source':str(root),'game_conf':(root/'game.conf').read_text(),
          'scope':'All source modules. Literal registrations are navigation hints; generated definitions and callbacks need runtime and behavioral review.',
          'module_count':len(modules),'lua_file_count':sum(m['lua_files'] for m in modules),
          'literal_registration_count':sum(len(m['literal_registrations']) for m in modules),
          'modules':modules}
Path(args.output).write_text(json.dumps(result,indent=2)+'\n')
print(f"Inventoried {result['module_count']} modules, {result['lua_file_count']} Lua files and {result['literal_registration_count']} literal registrations.")
