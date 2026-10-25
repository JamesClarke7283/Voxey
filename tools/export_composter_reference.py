#!/usr/bin/env python3
"""Evaluate installed Mineclonia composter and farmer callbacks in Luanti."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
FILES=['mods/ITEMS/mcl_composters/init.lua','mods/ENTITIES/mobs_mc/villager.lua','mods/ENTITIES/mcl_mobs/items.lua']
BODY=r'''
local names=NAMES
local ids={};for id,name in pairs(names)do ids[name]=tonumber(id)end
local stream=1
local function random(a,b)stream=(stream*1664525+1013904223)%4294967296;if not a then return stream/4294967295 end;if not b then b=a;a=1 end;return a+stream%(b-a+1)end
core.register_on_mods_loaded(function()core.after(0,function()
 local result={items={},geometry={},add={},farmers={},bread={},pickup={}}
 for name,def in pairs(core.registered_items)do result.items[name]=core.get_item_group(name,'compostability')end
 for alias,name in pairs(core.registered_aliases)do result.items[alias]=core.get_item_group(name,'compostability')end
 local function node(level)return {name=level==0 and 'mcl_composters:composter' or level==8 and 'mcl_composters:composter_ready' or 'mcl_composters:composter_'..level}end
 for level=0,8 do result.geometry[#result.geometry+1]=core.registered_nodes[node(level).name].node_box.fixed end
 local pos=vector.new(0,0,0);local level=0;local drops=0;local timers=0
 core.get_node=function()return node(level)end
 core.get_node_timer=function()return {start=function()timers=timers+1 end,stop=function()end}end
 mcl_redstone.swap_node=function(_,n)level=core.registered_nodes[n.name]._mcl_compost_level end
 core.add_item=function(_,s)drops=drops+ItemStack(s):get_count()end
 core.sound_play=function()end;mcl_bone_meal.add_bone_meal_particle=function()end
 local def=core.registered_nodes['mcl_composters:composter'];local player={get_player_control=function()return {}end,get_player_name=function()return 'fixture'end}
 core.is_protected=function()return false end;core.is_creative_enabled=function()return false end
 for start=0,8 do for _,id in ipairs({NATIVE_ITEMS})do for _,roll in ipairs({1,30,31,50,51,65,66,85,86,100})do for _,auto in ipairs({false,true})do
  level=start;drops=0;timers=0;math.random=function()return roll end
  local stack=ItemStack(names[tostring(id)]);stack:set_count(4);local accepted
  if auto then accepted=mcl_composters.farmer_add_compost(pos,node(level),stack)
  else local old=stack:get_count();core.registered_nodes[node(level).name].on_rightclick(pos,node(level),player,stack);accepted=stack:get_count()<old end
  result.add[#result.add+1]={start=start,id=id,roll=roll,auto=auto,accepted=accepted==true,level=level,drops=drops,timers=timers}
 end end end end
 local class=mcl_mobs.mob_class;local villager=core.registered_entities['mobs_mc:villager']
 local function inventory(a)local out={};for _,s in ipairs(a._inventory)do local st=ItemStack(s);out[#out+1]={id=ids[st:get_name()] or 0,count=st:get_count()}end;return out end
 local function actor(rows)local a=setmetatable({_inventory_size=8,_inventory={},_profession='farmer'},{__index=class});for i=1,8 do local row=rows[i] or {id=0,count=0};local s=ItemStack(names[tostring(row.id)] or '');s:set_count(row.count);if row.label then s:get_meta():set_string('description',row.label)end;a._inventory[i]=s:to_string()end;return a end
 local options={FARM_OPTIONS}
 for seed=1,240 do
  stream=seed;local rows={};for i=1,8 do rows[i]={id=options[random(1,#options)],count=random(0,64)}end
  local a=actor(rows);level=seed%9;local start=level;drops=0;math.random=random
  local state=stream;villager.compost(a,pos)
  result.farmers[#result.farmers+1]={items=rows,start=start,seed=state,items_after=inventory(a),level=level,drops=drops,state=stream}
 end
 local old_drop=mcl_util.drop_item_stack
 mcl_util.drop_item_stack=function(_,s)drops=drops+ItemStack(s):get_count()end
 for _,bread in ipairs({0,35,36,37,38,64})do for _,wheat in ipairs({0,2,3,6,8,9,32,64})do for _,full in ipairs({false,true})do
  local rows={{id=BREAD_ID,count=bread},{id=WHEAT_ID,count=wheat}}
  for i=3,8 do rows[i]={id=STONE_ID,count=full and 64 or 0}end
  local a=actor(rows);drops=0;villager.craft_bread(a,pos)
  result.bread[#result.bread+1]={items=rows,items_after=inventory(a),drops=drops}
 end end end
 for _,n in ipairs({2,3,6})do
  local rows={{id=WHEAT_ID,count=n,label='Named wheat'},{id=WHEAT_ID,count=9,label='Other wheat'}}
  for i=3,8 do rows[i]={id=0,count=0}end
  local a=actor(rows);drops=0;villager.craft_bread(a,pos)
  result.bread[#result.bread+1]={items=rows,items_after=inventory(a),drops=drops}
 end
 mcl_util.drop_item_stack=old_drop
 for _,profession in ipairs({'farmer','librarian','unemployed'})do for _,id in ipairs({FARM_OPTIONS,BONE_ID,STONE_ID})do for _,capacity in ipairs({0,1,20,64})do
  local rows={};for i=1,8 do rows[i]={id=STONE_ID,count=64}end;rows[1]={id=id,count=64-capacity}
  local a=actor(rows);a._profession=profession~='unemployed' and profession or nil;local st=ItemStack(names[tostring(id)]);st:set_count(20)
  result.pickup[#result.pickup+1]={items=rows,id=id,count=20,profession=profession,accepted=villager.should_pick_up(a,st)==true}
 end end end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Composter fixture complete',false,0)
end)end)
'''
def main():
 mapping=json.load(open(ROOT/'assets/data/harvest_items.json'))['items']
 names=['mcl_farming:wheat_seeds','mcl_farming:beetroot_seeds','mcl_farming:wheat_item','mcl_farming:bread','mcl_bone_meal:bone_meal','mcl_farming:carrot_item','mcl_farming:potato_item','mcl_farming:beetroot_item','mcl_core:stone','mcl_core:vine','mcl_core:apple','mcl_farming:pumpkin_pie']
 # Keep the repository's established source/native item correspondence.
 mapping.update({'mcl_core:stone':3,'mcl_core:vine':41})
 ids={n:mapping[n] for n in names};profiles={str(i):n for n,i in ids.items()}
 body=BODY.replace('NAMES',lua(profiles)).replace('NATIVE_ITEMS',','.join(str(ids[n]) for n in names[:2]+names[8:])).replace('FARM_OPTIONS',','.join(str(ids[n]) for n in names[:4]+names[5:8])).replace('BREAD_ID',str(ids[names[3]])).replace('WHEAT_ID',str(ids[names[2]])).replace('STONE_ID',str(ids[names[8]])).replace('BONE_ID',str(ids[names[4]]))
 world=Path(tempfile.mkdtemp(prefix='voxey-composter-'));mod=world/'worldmods/composter_fixture';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31508\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = composter_fixture\ndepends = mobs_mc,mcl_composters\n');(mod/'init.lua').write_text(body)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
 if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3000:])
 d=json.loads((world/'oracle.json').read_text());paths=set(FILES)
 for path in (SOURCE/'mods').rglob('*.lua'):
  if b'compostability' in path.read_bytes(): paths.add(str(path.relative_to(SOURCE)))
 d['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in sorted(paths)}
 (ROOT/'assets/data/compost_items.json').write_text(json.dumps({'items':d['items'],'source_hashes':d['source_hashes']},separators=(',',':'))+'\n')
 (ROOT/'assets/data/composter_reference.json').write_text(json.dumps(d,separators=(',',':'))+'\n');print({k:len(v) for k,v in d.items()})
if __name__=='__main__':main()
