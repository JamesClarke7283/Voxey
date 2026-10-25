#!/usr/bin/env python3
"""Export registered digging capabilities and run Luanti's actual dig calculations."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from export_enchanting_reference import lua

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
PATHS=['mods/CORE/_mcl_autogroup/init.lua','mods/ITEMS/mcl_potions/functions.lua',
       'mods/ITEMS/mcl_enchanting/groupcaps.lua','mods/PLAYER/mcl_meshhand/init.lua']

BODY=r'''
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function factors(h,f,c,wet)
 for name,level in pairs({haste=h,fatigue=f,conduit_power=c})do
  EF[name].oracle=level>0 and {factor=mcl_potions.registered_effects[name].level_to_factor(level),blocked=name=='conduit_power' and not wet} or nil
 end
 return total_haste('oracle'),total_fatigue('oracle')
end
core.register_on_mods_loaded(function()
 core.after(0,function()
  local hands={}
  for name,def in pairs(core.registered_items)do
   if name:sub(1,13)=='mcl_meshhand:' and not (def.tool_capabilities.groupcaps or {}).creative_breakable then hands[#hands+1]=name end
  end
  table.sort(hands);local hand=ItemStack(assert(hands[1]));local handcaps=hand:get_tool_capabilities()
  local output={tools={},nodes={},aliases={},effects={},digging={}}
  local groupnames={level=true,dig_immediate=true}
  local function profile(id,name)
   local def=core.registered_items[name]
   local entry={name=name,tool=(def.groups.tool or 0)==1,own=def.tool_capabilities~=nil,levels={}}
   for efficiency=0,5 do
    local stack=ItemStack(name)
    if efficiency>0 and def._mcl_enchanting_enchanted_tool then mcl_enchanting.enchant(stack,'efficiency',efficiency)end
    local caps=def.tool_capabilities and stack:get_tool_capabilities() or handcaps
    local raw=def._mcl_diggroups and mcl_autogroup.get_groupcaps(name,efficiency) or {}
    for group,v in pairs(caps.groupcaps or {})do if raw[group]then v.exact_uses=raw[group].uses end end
    local kept={full_punch_interval=caps.full_punch_interval,groupcaps=caps.groupcaps or {}}
    entry.levels[#entry.levels+1]=kept
    for group in pairs(kept.groupcaps)do groupnames[group]=true end
   end
   if def._mcl_enchanting_enchanted_tool and def.tool_capabilities then
    local item=ItemStack(name);mcl_enchanting.enchant(item,'unbreaking',1)
    entry.enchanted_zero=item:get_tool_capabilities()
    local raw=mcl_autogroup.get_groupcaps(name,0)
    for group,v in pairs(entry.enchanted_zero.groupcaps or {})do
     if raw[group]then v.uses=math.floor(raw[group].uses);v.exact_uses=raw[group].uses end
    end
   end
   output.tools[tostring(id)]=entry
  end
  profile(0,hands[1]);output.tools['0'].tool=false
  for _,p in ipairs(PROFILES)do profile(p.id,p.name)end
  for name,def in pairs(core.registered_nodes)do
   if not name:find('^voxey_') and name~='ignore' then
    local groups={};for group,value in pairs(def.groups or {})do if groupnames[group]then groups[group]=value end end
    local recipes={};for _,value in pairs(type(def._mcl_stonecutter_recipes)=='table' and def._mcl_stonecutter_recipes or {})do
     if type(value)=='string'then recipes[#recipes+1]=value end
    end
    local hardness=def._mcl_hardness or 0
    if type(hardness)~='number' or hardness~=hardness or math.abs(hardness)==math.huge then hardness=0 end
    output.nodes[name]={groups=groups,diggable=def.diggable~=false,hardness=hardness,
     description=core.strip_colors(tostring(def.description or '')),
     baseitem=type(def._mcl_baseitem)=='string' and def._mcl_baseitem or nil,
     stonecutter=recipes,fence_material=type(def._mcl_fences_baseitem)=='string' and def._mcl_fences_baseitem or nil}
   end
  end
  for alias,target in pairs(core.registered_aliases)do output.aliases[alias]=target end
  for _,h in ipairs({0,1,2,4})do for _,f in ipairs({0,1,2,3,4,6})do for _,c in ipairs({0,1,2})do for _,wet in ipairs({false,true})do
   local hf,ff=factors(h,f,c,wet)
   for _,interval in ipairs({.25,.625,1.6,10,15})do
    local caps={full_punch_interval=interval,groupcaps={test={times={0,.05,.1,.55,5,299,300,301,1000},uses=100,maxlevel=0}}}
    local result=mcl_potions.apply_haste_fatigue(copy(caps),hf,ff)
    output.effects[#output.effects+1]={haste=h,fatigue=f,conduit=c,wet=wet,haste_factor=hf,fatigue_factor=ff,base=interval,result=result}
   end
  end end end end
  for _,p in ipairs(PROFILES)do
   local prof=output.tools[tostring(p.id)]
   for _,eff in ipairs({0,1,3,5})do
    for node_index,node in ipairs(NODES)do
     local def=assert(output.nodes[node],node)
     for _,fx in ipairs({{0,0,0,false},{1,0,0,false},{0,3,0,false},{2,2,1,true}})do for _,unbreaking in ipairs({0,3})do
      local hf,ff=factors(unpack(fx))
      local item=ItemStack(p.name)
      if eff>0 and core.registered_items[p.name]._mcl_enchanting_enchanted_tool then mcl_enchanting.enchant(item,'efficiency',eff)end
      if unbreaking>0 and core.registered_items[p.name]._mcl_enchanting_enchanted_tool then mcl_enchanting.enchant(item,'unbreaking',unbreaking)end
      local caps=prof.own and item:get_tool_capabilities() or copy(handcaps)
      caps=mcl_potions.apply_haste_fatigue(caps,hf,ff)
      local initial=({0,32000,65000,65535})[(node_index+eff+unbreaking)%4+1]
      local value=core.get_dig_params(def.groups,caps,initial)
      output.digging[#output.digging+1]={id=p.id,node=node,efficiency=eff,unbreaking=unbreaking,haste=fx[1],fatigue=fx[2],conduit=fx[3],wet=fx[4],initial=initial,result={diggable=def.diggable and value.diggable,time=value.time,wear=value.wear}}
     end end
    end
   end
  end
  core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(output,true))
  core.request_shutdown('Digging oracle complete',false,0)
 end)
end)
'''

def export():
    profiles=[{'id':int(k),'name':v['name']} for k,v in json.loads((ROOT/'assets/data/melee.json').read_text())['profiles'].items() if k!='0']
    nodes=['mcl_core:stone','mcl_core:dirt','mcl_core:obsidian','mcl_core:sand',
           'mcl_core:stone_with_iron','mcl_core:cobweb','mcl_trees:tree_oak',
           'mcl_trees:leaves_oak','mcl_nether:netherrack','mcl_core:bedrock','air']
    world=Path(tempfile.mkdtemp(prefix='voxey-digging-oracle-'));fixture=world/'worldmods'/'voxey_digging_fixture';fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_digging_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31493\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_digging_fixture\ndepends = mcl_potions, mcl_enchanting, mcl_tools, mcl_meshhand\n')
    text=(SOURCE/PATHS[1]).read_text()
    def body(name,next_name):
        start=text.index('function mcl_potions.'+name+'(object)')+len('function mcl_potions.'+name+'(object)')
        end=text.index('\nfunction mcl_potions.'+next_name,start)
        return 'function(object)'+text[start:end].strip()+'\n'
    prefix='local EF={haste={},fatigue={},conduit_power={}}\nlocal item_speed_effects={haste={factor_is_positive=true},fatigue={},conduit_power={factor_is_positive=true}}\n'
    prefix+='local total_haste='+body('get_total_haste','get_total_fatigue')
    prefix+='local total_fatigue='+body('get_total_fatigue','clear_effect')
    (fixture/'init.lua').write_text('local PROFILES='+lua(profiles)+'\nlocal NODES='+lua(nodes)+'\n'+prefix+BODY)
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'oracle.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3000:])
    data=json.loads((world/'oracle.json').read_text())
    data['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    data['license']='GPL-3.0-or-later'
    (ROOT/'assets/data/digging_reference.json').write_text(json.dumps({k:v for k,v in data.items() if k not in ['nodes','tools','aliases']},separators=(',',':'))+'\n')
    (ROOT/'assets/data/digging.json').write_text(json.dumps({k:data[k] for k in ['tools','nodes','aliases','source_hashes','license']},separators=(',',':'))+'\n')
    print('Exported',len(data['tools']),'tool profiles,',len(data['nodes']),'node profiles,',len(data['effects']),'effect cases and',len(data['digging']),'dig cases:',world)

if __name__=='__main__':export()
