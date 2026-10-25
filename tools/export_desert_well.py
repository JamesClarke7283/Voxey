#!/usr/bin/env python3
"""Build geometry fixtures by running the source well function in a data-only sandbox."""
import hashlib
import json
import subprocess
from pathlib import Path

SOURCE = Path('/home/impulse/.minetest/games/mineclonia/mods/MAPGEN/mcl_levelgen/default_features.lua')
OUT = Path(__file__).resolve().parents[1] / 'assets/data/desert_well_reference.json'

LUA = r'''
local source = io.read('*a')
local selected
local blocks, meta, case_a, case_b
local function key(x,y,z) return x..','..y..','..z end
local function get(x,y,z) return blocks[key(x,y,z)] or (y<=0 and 'mcl_core:sand' or 'air'),0 end
local env = {
  core={get_content_id=function(s)return s end},
  mathabs=math.abs, run_minp={y=-10}, run_maxp={y=10},
  cid_water_source='mcl_core:water_source',
  in_range=function()return true end,
  is_air=function(x,y,z)return get(x,y,z)=='air' end,
  get_block=get,
  set_block=function(x,y,z,id) blocks[key(x,y,z)]=id end,
  ipos3=function(x1,y1,z1,x2,y2,z2)
    local x,y,z=x1,y1,z1-1
    return function()
      z=z+1
      if z>z2 then z=z1;y=y+1 end
      if y>y2 then y=y1;x=x+1 end
      if x>x2 then return nil end
      return x,y,z
    end
  end,
}
env.mcl_levelgen={
  is_solid=function(x,y,z)local n=get(x,y,z);return n~='air' and n~='mcl_core:water_source' end,
  convert_level_position=function(x,y,z)return x,y,z end,
  notify_generated=function(_,v)meta[#meta+1]=v end,
  register_feature=function(_,def)selected=def.place end,
}
env.vector={new=function(x,y,z)return{x=x,y=y,z=z}end}
env.fix_lighting=function()end
assert(load(source,'source well','t',env))()
for a=0,3 do for b=0,3 do
  blocks={};meta={};local calls=0
  local rng={next_within=function(_,n) calls=calls+1;return calls==1 and a or b end,
             next_integer=function()return 12345 end}
  assert(selected(nil,0,1,0,{},rng))
  io.write('CASE\t'..a..'\t'..b..'\n')
  local keys={};for k in pairs(blocks)do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do io.write('NODE\t'..k..'\t'..blocks[k]..'\n')end
  for _,m in ipairs(meta)do io.write('META\t'..key(m.pos.x,m.pos.y,m.pos.z)..'\n')end
end end
'''


def export():
    text = SOURCE.read_text()
    start = text.index('-- Desert Well.')
    section = text[start:text.index('-- Ice Spike.', start)]
    output = subprocess.run(['lua', '-e', LUA], input=section, text=True,
                            capture_output=True, check=True).stdout
    cases = []
    for line in output.splitlines():
        parts = line.split('\t')
        if parts[0] == 'CASE':
            cases.append({'directions': list(map(int, parts[1:])), 'nodes': [], 'suspicious': []})
        elif parts[0] == 'NODE':
            cases[-1]['nodes'].append([*map(int, parts[1].split(',')), parts[2]])
        elif parts[0] == 'META':
            cases[-1]['suspicious'].append(list(map(int, parts[1].split(','))))
    OUT.write_text(json.dumps({'license': 'GPL-3.0-or-later',
        'source': 'mods/MAPGEN/mcl_levelgen/default_features.lua',
        'sha256': hashlib.sha256(text.encode()).hexdigest(), 'cases': cases},
        separators=(',', ':')) + '\n')
    print(f'Exported {len(cases)} source well geometry cases to {OUT.name}')


if __name__ == '__main__':
    export()
