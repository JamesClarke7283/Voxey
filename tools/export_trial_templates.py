#!/usr/bin/env python3
"""Convert Mineclonia's saved trial-chamber templates to portable JSON data.

Only data deserialization runs in Lua, in an empty environment. Source template
art/data is GPL-3.0-or-later; source paths and hashes are retained in the output.
"""
import ctypes
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path('/home/impulse/.minetest/games/mineclonia/mods/MAPGEN/mcl_levelgen')
OUT = Path(__file__).resolve().parents[1] / 'assets/data/trial_templates.json'
zstd = ctypes.CDLL('libzstd.so.1')
zstd.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
zstd.ZSTD_decompress.restype = ctypes.c_size_t

LUA = r'''
local function decode(s) return assert(load(s, "template", "t", {}))() end
local function json(v)
  local t=type(v)
  if t=="string" then
    local s=v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')
    s=s:gsub('[%z\1-\31]',function(c)return string.format('\\u%04x',string.byte(c))end)
    return '"'..s..'"'
  elseif t=="number" or t=="boolean" then return tostring(v)
  elseif t=="table" then
    local out={}
    if #v>0 then for i=1,#v do out[#out+1]=json(v[i]) end; return '['..table.concat(out,',')..']' end
    local keys={}; for k in pairs(v) do keys[#keys+1]=k end; table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    for _,k in ipairs(keys) do out[#out+1]=json(tostring(k))..':'..json(v[k]) end
    return '{'..table.concat(out,',')..'}'
  end
  return 'null'
end
local d=decode(io.read('*a'))
for _,m in ipairs(d.metadata) do
  for k,v in pairs(m.fields) do
    if v:sub(1,7)=='return ' or v:sub(1,6)=='local ' then m.fields[k]=decode(v) end
  end
end
io.write(json(d))
'''

def read_template(path):
    data = path.read_bytes()
    output = ctypes.create_string_buffer(8 * 1024 * 1024)
    n = zstd.ZSTD_decompress(output, len(output), data, len(data))
    if n > len(output):
        raise ValueError(f'Failed to decompress {path}')
    result = subprocess.run(['lua', '-e', LUA], input=output.raw[:n], capture_output=True, check=True)
    template = json.loads(result.stdout)
    runs = []
    for value in template.pop('nodes'):
        if runs and runs[-1][0] == value:
            runs[-1][1] += 1
        else:
            runs.append([value, 1])
    template['runs'] = runs
    return template


def export():
    templates = {}
    hashes = {}
    for path in sorted((ROOT / 'templates').glob('trial_chambers_*.dat')):
        templates[path.stem] = read_template(path)
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()

    source = (ROOT / 'trial_chambers.lua').read_text()
    pools = {}
    for match in re.finditer(r'register_template_pool\s*\("mcl_levelgen:([^"\n]+)"', source):
        # Exclude the source's disabled breeze pool.
        if source[max(0, source.rfind('\n', 0, match.start())):match.start()].lstrip().startswith('--'):
            continue
        end = source.find('\n})', match.end())
        pools[match[1]] = [[name, int(weight)] for name, weight in re.findall(r'L\s*\("([^"\n]+)",\s*(\d+)', source[match.end():end])
                           if name in templates]
    OUT.write_text(json.dumps({'license': 'GPL-3.0-or-later', 'source_hashes': hashes, 'pools': pools, 'templates': templates}, separators=(',', ':')) + '\n')
    print(f'Exported {len(templates)} templates and {len(pools)} pools ({OUT.stat().st_size} bytes)')
    print('Palette:', sorted({v for t in templates.values() for v in t['names'].values()}))


if __name__ == '__main__':
    export()
