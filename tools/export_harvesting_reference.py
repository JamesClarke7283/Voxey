#!/usr/bin/env python3
"""Export the reference's live harvest eligibility and node-drop definitions."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from export_enchanting_reference import lua

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/CORE/_mcl_autogroup/init.lua', 'mods/ENTITIES/mcl_item_entity/init.lua',
         'mods/ITEMS/mcl_core/nodes_base.lua', 'mods/ITEMS/mcl_enchanting/enchantments.lua']
BODY = r'''
local function data(v)
 if type(v)=='table' then
  local array=true;local count=0
  for k in pairs(v)do count=count+1;if type(k)~='number' or k<1 or k%1~=0 then array=false end end
  if count~=#v then array=false end
  local t={};for k,x in pairs(v)do if type(x)~='function'then t[array and k or tostring(k)]=data(x)end end;return t
 elseif type(v)=='function' then return nil
 else return v end
end
core.register_on_mods_loaded(function()
 core.after(0,function()
  local result={nodes={},tools={},items={},aliases=core.registered_aliases}
  local diggroups={dig_immediate=true,xp=true}
  for id,name in pairs(PROFILES)do
   local d=assert(core.registered_items[name],name)
   local groups={};for g,v in pairs(d._mcl_diggroups or {})do groups[g]=v.level;diggroups[g]=true end
   result.tools[id]={name=name,groups=groups,tags=data(d.groups),is_book=mcl_enchanting.is_book(name),shears=((d._mcl_diggroups or {}).shearsy or {}).level or 0}
  end
  for name,def in pairs(core.registered_nodes)do
   if not name:find('^voxey_') and name~='ignore' then
    local groups={};for g in pairs(diggroups)do if def.groups[g]then groups[g]=def.groups[g]end end
    local fortune=data(def._mcl_fortune_drop)
    if fortune and def._mcl_fortune_drop.get_chance then
     fortune.chances={};for level=1,5 do fortune.chances[#fortune.chances+1]=def._mcl_fortune_drop.get_chance(level)end
    end
    result.nodes[name]={groups=groups,drop=data(def.drop),drop_kind=type(def.drop),silk=data(def._mcl_silk_touch_drop),shears=data(def._mcl_shears_drop),fortune=fortune,
     paramtype2=def.paramtype2,after_dig=def.after_dig_node~=nil,custom_dig=def.on_dig~=nil and def.on_dig~=core.node_dig}
   end
  end
  for name,def in pairs(core.registered_items)do result.items[name]={description=core.strip_colors(core.get_translated_string('en',def.description or '')),stack=def.stack_max or 99}end
  core.safe_file_write(core.get_worldpath()..'/rules.json',core.write_json(result,true))
  local oracle={eligibility={},cases={}}
  local wield=ItemStack('');local node={name='air',param2=0};local items={};local xp=0;local state=1
  local old_random=math.random;local old_node=core.get_node;local old_add=core.add_item;local old_xp=mcl_experience.throw_xp
  local inv={get_stack=function()return ItemStack(PROFILES['0'])end}
  local player={is_player=function()return true end,get_player_name=function()return 'voxey_oracle' end,get_inventory=function()return inv end,get_wielded_item=function()return wield end}
  local function random(a,b)
   state=(state*1664525+1013904223)%4294967296
   if not a then return state/4294967295 end
   if not b then b=a;a=1 end
   return a+state%(b-a+1)
  end
  math.random=random;core.get_node=function()return node end
  core.add_item=function(_,item)local s=ItemStack(item);local n=s:get_name();items[n]=(items[n]or 0)+s:get_count();return nil end
  mcl_experience.throw_xp=function(_,amount)xp=xp+amount end
  local function test(name,id,fortune,silk,seed)
   node={name=name,param2=0};state=seed;items={};xp=0
   wield=ItemStack(id<=0 and '' or PROFILES[tostring(id)])
   local enchantable=wield:get_definition()._mcl_enchanting_enchanted_tool~=nil
   if fortune>0 and enchantable then mcl_enchanting.enchant(wield,'fortune',fortune)end
   if silk and enchantable then mcl_enchanting.enchant(wield,'silk_touch',1)end
   local drops=core.get_node_drops(node,wield:get_name())
   local eligible=id<0 or mcl_autogroup.can_harvest(name,wield:get_name(),player)
   core.handle_node_drops({x=0,y=0,z=0},drops,id>=0 and player or nil)
   local list={};for n,count in pairs(items)do list[#list+1]={n,count}end;table.sort(list,function(a,b)return a[1]<b[1]end)
   oracle.cases[#oracle.cases+1]={name=name,id=id,fortune=enchantable and fortune or 0,silk=enchantable and silk or false,seed=seed,drops=list,xp=xp,eligible=eligible,state=state}
  end
  for _,name in ipairs(NODES)do
   local eligible={};for id,n in pairs(PROFILES)do eligible[id]=mcl_autogroup.can_harvest(name,id=='0' and '' or n,player)end
   oracle.eligibility[name]=eligible
   test(name,-1,0,false,17)
   for _,id in ipairs({0,80,85,90,95,98,84,123})do
    test(name,id,0,false,17);test(name,id,3,false,19);test(name,id,0,true,23)
   end
   if result.nodes[name].fortune or type(result.nodes[name].drop)=='table'then
    for _,seed in ipairs({1,2,3,8,42,4001,4002,65535})do for level=1,3 do test(name,95,level,false,seed)end end
    test(name,126,3,false,42);test(name,791,0,true,42)
   end
  end
  math.random=old_random;core.get_node=old_node;core.add_item=old_add;mcl_experience.throw_xp=old_xp
  core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(oracle,true))
  core.request_shutdown('Harvest rules complete',false,0)
 end)
end)
'''


def export():
    profiles = {k: v['name'] for k, v in json.loads((ROOT / 'assets/data/digging.json').read_text())['tools'].items()}
    profiles.update({'126': 'mcl_books:book', '791': 'mcl_enchanting:book_enchanted'})
    world = Path(tempfile.mkdtemp(prefix='voxey-harvesting-oracle-'))
    fixture = world / 'worldmods/voxey_harvesting_fixture'
    fixture.mkdir(parents=True)
    (world / 'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_harvesting_fixture = true\n')
    (world / 'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31493\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture / 'mod.conf').write_text('name = voxey_harvesting_fixture\ndepends = mcl_potions, mcl_enchanting, mcl_tools, mcl_meshhand, mcl_item_entity\n')
    nodes = [n['name'] for n in json.loads((ROOT / 'assets/data/mining_reference.json').read_text())['nodes']]
    (fixture / 'init.lua').write_text('local PROFILES=' + lua(profiles) + '\nlocal NODES=' + lua(nodes) + '\n' + BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world / 'oracle.conf'), '--logfile', str(world / 'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world / 'rules.json').exists() or not (world / 'oracle.json').exists():
        raise RuntimeError(str(world) + '\n' + run.stderr[-4000:])
    result = json.loads((world / 'rules.json').read_text())
    result.update(license='GPL-3.0-or-later', source=str(SOURCE))
    result['source_hashes'] = {p: hashlib.sha256((SOURCE / p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT / 'assets/data/harvesting.json').write_text(json.dumps(result, separators=(',', ':')) + '\n')
    oracle = json.loads((world / 'oracle.json').read_text())
    oracle.update(license='GPL-3.0-or-later', source_hashes=result['source_hashes'])
    (ROOT / 'assets/data/harvesting_reference.json').write_text(json.dumps(oracle, separators=(',', ':')) + '\n')
    print(f'Exported {len(result["nodes"])} node drop definitions, {len(result["tools"])} tool profiles and {len(oracle["cases"])} drop cases: {world}')


if __name__ == '__main__':
    export()
