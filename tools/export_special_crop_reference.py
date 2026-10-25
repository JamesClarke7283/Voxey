#!/usr/bin/env python3
"""Execute Mineclonia's specialized crop callbacks in a real Luanti server."""
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
FILES = [
    'mods/ITEMS/mcl_cocoas/init.lua',
    'mods/ITEMS/mcl_nether/nether_wart.lua',
    'mods/ITEMS/mcl_farming/sweet_berry.lua',
    'mods/ITEMS/mcl_farming/shared_functions.lua',
    'mods/ITEMS/mcl_bone_meal/init.lua',
    'mods/CORE/mcl_util/environment.lua',
]
BODY = r'''
core.register_on_mods_loaded(function() core.after(0,function()
 local out={bone={},harvest={},growth={},timers={}}
 local pos=vector.new(0,40,0);local nodes,metas={},{}
 local function key(p)return p.x..','..p.y..','..p.z end
 local function meta(p)
  local k=key(p);if not metas[k]then metas[k]={}end
  return {get_int=function(_,n)return math.floor(tonumber(metas[k][n])or 0)end,set_int=function(_,n,v)metas[k][n]=v end,get_string=function(_,n)return tostring(metas[k][n]or'')end,set_string=function(_,n,v)metas[k][n]=v end}
 end
 core.get_meta=meta
 core.get_node=function(p)return table.copy(nodes[key(p)]or{name='air'})end
 core.get_node_or_nil=function(p)return core.get_node(p)end
 core.set_node=function(p,n)nodes[key(p)]=table.copy(n);metas[key(p)]={};return true end
 core.swap_node=function(p,n)nodes[key(p)]=table.copy(n);return true end
 core.remove_node=function(p)nodes[key(p)]={name='air'};return true end
 core.get_node_light=function()return 15 end
 core.get_day_count=function()return 10 end
 core.get_timeofday=function()return 0.5 end
 core.is_protected=function()return false end
 core.is_creative_enabled=function()return false end
 core.record_protection_violation=function()end
 core.sound_play=function()end
 local particles=0;local prevented=0;local added={}
 mcl_bone_meal.add_bone_meal_particle=function()particles=particles+1 end
 mcl_hunger.prevent_eating=function()prevented=prevented+1 end
 core.add_item=function(p,item)added[#added+1]=tostring(item)end
 local player={is_player=function()return true end,get_player_name=function()return 'probe'end,get_player_control=function()return {}end}
 local oldrandom=math.random
 math.random=function(a,b)if not a then return 0.25 end;if not b then b=a;a=1 end;return a end
 local function reset(name)
  nodes={};metas={};added={};particles=0;prevented=0
  nodes[key(pos)]={name=name,param2=3}
  nodes[key(vector.offset(pos,0,-1,0))]={name=name:find('nether_wart',1,true)and'mcl_nether:soul_sand'or'mcl_core:dirt_with_grass'}
 end
 local function bone(name)
  reset(name);local stack=ItemStack('mcl_bone_meal:bone_meal 4')
  local pt={type='node',under=vector.new(pos),above=vector.offset(pos,0,1,0)}
  local ret=core.registered_items['mcl_bone_meal:bone_meal'].on_place(stack,player,pt)
  out.bone[#out.bone+1]={name=name,after=core.get_node(pos).name,count=ret:get_count(),particles=particles,prevented=prevented,added=added,meta=metas[key(pos)]}
 end
 for i=1,3 do bone('mcl_cocoas:cocoa_'..i)end
 for i=0,3 do bone('mcl_farming:sweet_berry_bush_'..i)end
 for i=0,2 do bone('mcl_nether:nether_wart_'..i)end
 bone('mcl_nether:nether_wart')
 local function harvest(name,item)
  reset(name);added={};local stack=ItemStack(item or 'mcl_farming:sweet_berry 2')
  local pt={type='node',under=vector.new(pos),above=vector.offset(pos,0,1,0)}
  local callback=core.registered_nodes[name].on_rightclick
  local ret=callback and callback(pos,core.get_node(pos),player,stack,pt) or stack
  out.harvest[#out.harvest+1]={name=name,item=item,after=core.get_node(pos).name,count=ret and ret:get_count() or -1,added=added,handled=callback~=nil}
 end
 for i=0,3 do harvest('mcl_farming:sweet_berry_bush_'..i)end
 harvest('mcl_farming:sweet_berry_bush_3','mcl_bone_meal:bone_meal 2')
 local actions={}
 for _,abm in ipairs(core.registered_abms)do
  if abm.label=='Cocoa pod growth' or abm.label=='Nether wart growth' or abm.label=='Farming plant growth (plant_sweet_berry_bush)'then
   actions[abm.label]=abm.action
   out.timers[abm.label]={interval=abm.interval,chance=abm.chance,names=abm.nodenames}
  end
 end
 local function grow(label,name)
  reset(name);actions[label](pos,core.get_node(pos))
  out.growth[#out.growth+1]={label=label,name=name,after=core.get_node(pos).name,param2=core.get_node(pos).param2,meta=metas[key(pos)]}
 end
 for i=1,2 do grow('Cocoa pod growth','mcl_cocoas:cocoa_'..i)end
 for i=0,2 do grow('Nether wart growth','mcl_nether:nether_wart_'..i)end
 for i=0,2 do grow('Farming plant growth (plant_sweet_berry_bush)','mcl_farming:sweet_berry_bush_'..i)end
 reset('mcl_nether:nether_wart_0');nodes[key(vector.offset(pos,0,-1,0))]={name='mcl_core:dirt'}
 actions['Nether wart growth'](pos,core.get_node(pos))
 out.growth[#out.growth+1]={label='Nether wart growth',name='mcl_nether:nether_wart_0',soil='mcl_core:dirt',after=core.get_node(vector.new(0,40,0)).name,param2=core.get_node(vector.new(0,40,0)).param2,meta=metas[key(pos)]}
 math.random=oldrandom
 core.safe_file_write(core.get_worldpath()..'/special_crops.json',core.write_json(out,true));core.request_shutdown('Special crop reference complete',false,0)
end)end)
'''


def main():
    world = Path(tempfile.mkdtemp(prefix='voxey-special-crops-'))
    mod = world/'worldmods/special_crop_oracle'
    mod.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_special_crop_oracle = true\n')
    (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31617\nserver_announce = false\nenable_ipv6 = false\n')
    (mod/'mod.conf').write_text('name = special_crop_oracle\ndepends = mcl_farming, mcl_nether, mcl_cocoas, mcl_bone_meal\n')
    (mod/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=180)
    output = world/'special_crops.json'
    if not output.exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-3000:]+'\n'+run.stderr[-3000:])
    result = json.loads(output.read_text())
    result['source_hashes'] = {p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in FILES}
    result['license'] = 'GPL-3.0-or-later'
    (ROOT/'assets/data/special_crop_reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print(world)
    print({k:len(result[k]) for k in ['bone','harvest','growth','timers']})


if __name__ == '__main__':
    main()
