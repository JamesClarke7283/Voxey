#!/usr/bin/env python3
"""Exercise the installed Mineclonia banner craft callbacks in real Luanti."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ITEMS/mcl_banners/init.lua', 'mods/ITEMS/mcl_banners/items.lua',
         'mods/ITEMS/mcl_banners/patterncraft.lua', 'mods/ITEMS/mcl_loom/init.lua']
BODY = r'''
core.register_on_mods_loaded(function() core.after(0,function()
 local colors={'white','grey','silver','black','yellow','orange','red','magenta','purple','blue','cyan','lime','green','pink','light_blue','brown'}
 local keys={'thing','skull','creeper','flower','bricks','curly_border','globe','piglin','guster','flow'}
 local ids,names,unis={}, {}, {}
 for i,c in ipairs(colors)do
  local n='mcl_banners:banner_item_'..c;assert(core.registered_items[n],n)
  ids[n]=634+i;names[634+i]=n;unis[i]='unicolor_'..mcl_dyes.colors[c].unicolor
  ids['mcl_dyes:'..c]=820+i;names[820+i]='mcl_dyes:'..c
 end
 for i,k in ipairs(keys)do ids['mcl_banners:pattern_'..k]=1379+i;names[1379+i]='mcl_banners:pattern_'..k end
 for n,id in pairs({['mcl_core:brick_block']=20,['mcl_core:vine']=41,['mcl_flowers:oxeye_daisy']=5612,['mcl_heads:creeper']=1277,['mcl_heads:wither_skeleton']=1280})do ids[n]=id;names[id]=n end
 local uniids={};for i,u in ipairs(unis)do uniids[u]=i-1 end
 local function stack(v)
  local s=ItemStack(names[v.id] or '');s:set_count(v.count or 1)
  if v.data then
   local layers={};for _,l in ipairs(v.data.layers or {})do layers[#layers+1]={pattern=l.pattern,color=unis[l.color+1]}end
   mcl_banners.write_layers(s:get_meta(),layers);s:get_meta():set_string('name',v.data.custom_name or '')
  end
  return s
 end
 local function record(s)
  if s:is_empty()then return {id=0,count=0}end
  local result={id=assert(ids[s:get_name()],s:get_name()),count=s:get_count()};local data={};local layers={}
  for _,l in ipairs(mcl_banners.read_layers(s:get_meta()))do layers[#layers+1]={pattern=l.pattern,color=uniids[l.color]}end
  if #layers>0 then data.layers=layers end
  local name=s:get_meta():get_string('name');if name~='' then data.custom_name=name end
  if next(data)then result.data=data end
  return result
 end
 local result={limit=mcl_banners.max_craftable_layers,patterns={},cases={}}
 local function run(input,label)
  local grid={};for i=1,9 do grid[i]=stack(input[i] or {id=0})end
  local inv={get_size=function()return 9 end,set_stack=function(_,_,i,s)grid[i]=ItemStack(s)end}
  local player={get_inventory=function()return inv end}
  local output=core.get_craft_result({method='normal',width=3,items=grid}).item
  mcl_crafting_table.has_crafting_table=function()return true end
  for _,fn in ipairs(core.registered_craft_predicts)do if debug.getinfo(fn,'S').source:find('/mcl_banners/')then output=fn(output,player,grid,inv) or output end end
  local expected=record(output);local keep={}
  if not output:is_empty()then
   local old={};for i,s in ipairs(grid)do old[i]=ItemStack(s);grid[i]:take_item()end
   for _,fn in ipairs(core.registered_on_crafts)do if debug.getinfo(fn,'S').source:find('/mcl_banners/')then output=fn(output,player,old,inv) or output end end
   expected=record(output)
   for i=1,9 do if old[i]:get_count()>0 and grid[i]:get_count()==old[i]:get_count()then keep[#keep+1]=i-1 end end
  end
  local normalized={};for i=1,9 do normalized[i]=input[i] or {id=0,count=0}end
  result.cases[#result.cases+1]={label=label,input=normalized,output=expected,keep=keep}
 end
 local function layers(n)local a={};for i=1,n do a[#a+1]={pattern='border',color=i%16}end;return a end
 for key,p in pairs(mcl_banners.patterns)do
  local entry={name=p.name};local positions={};local mask=''
  if p.signature then entry.signature=assert(ids[p.signature],p.signature)
  else for row=1,3 do for col=1,3 do local dye=p[row][col]~='';mask=mask..(dye and 'd' or 'e');if not dye then positions[#positions+1]=(row-1)*3+col end end end;entry.grid=mask end
  result.patterns[key]=entry
  for _,count in ipairs({0,11,12})do for _,color in ipairs({0,6,15})do
   local base=(color+3)%16;local b={id=635+base,count=3,data={layers=layers(count),custom_name='Keep me'}}
   if p.signature then run({b,{id=821+color,count=3},{id=ids[p.signature],count=2}},key..':'..count..':'..color)
   else for _,pos in ipairs(positions)do
    local grid={};for i=1,9 do grid[i]=mask:sub(i,i)=='d' and {id=821+color,count=2} or {id=0,count=0}end;grid[pos]=b
    run(grid,key..':'..count..':'..color..':'..pos)
   end end
  end end
 end
 for _,count in ipairs({0,1,6,11,12,13})do for _,same in ipairs({true,false})do for _,reverse in ipairs({true,false})do
  local a={id=635,count=4,data={layers=layers(count),custom_name='Named original'}};local b={id=same and 635 or 636,count=3}
  run(reverse and {b,a} or {a,b},'copy:'..count..':'..tostring(same)..':'..tostring(reverse))
 end end end
 run({{id=635,count=1},{id=821,count=1},{id=827,count=1}},'mixed dyes')
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true))
 core.request_shutdown('Banner reference complete',false,0)
end)end)
'''


def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-banner-oracle-'))
    fixture = world/'worldmods'/'voxey_banner_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_banner_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31493\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_banner_fixture\ndepends = mcl_banners, mcl_loom, mcl_crafting_table\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-1000:]+'\n'+run.stderr[-3000:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT/'assets/data/banner_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print('Exported', len(result['cases']), 'banner crafts; source layer limit:', result['limit'])


if __name__ == '__main__':
    export()
