#!/usr/bin/env python3
"""Execute Mineclonia's mob armor generation, comparisons, drops and damage."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from export_enchanting_reference import lua

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ENTITIES/mcl_mobs/combat.lua', 'mods/ENTITIES/mcl_mobs/items.lua',
         'mods/ENTITIES/mcl_mobs/physics.lua', 'mods/ITEMS/mcl_armor/damage.lua',
         'mods/ITEMS/mcl_armor/register.lua', 'mods/ITEMS/mcl_enchanting/engine.lua']
BODY = r'''
local profiles=PROFILES_VALUE
local labels=LABELS_VALUE
local ids={};local names={}
for _,p in ipairs(profiles)do ids[p.name]=p.id;ids[p.name..'_enchanted']=p.id;names[p.id]=p.name end
local stream=1;local forced=nil;local cursor=0
local function random(a,b)
 if forced then cursor=cursor+1;return assert(forced[cursor],'ran out of fixture draws')end
 stream=(stream*1664525+1013904223)%4294967296
 if not a then return stream/4294967295 end
 if not b then b=a;a=1 end
 a=math.floor(a);b=math.floor(b)
 return a+stream%(b-a+1)
end
local function snapshot(stack)
 local item=ItemStack(stack);local ench={}
 for k,v in pairs(mcl_enchanting.get_enchantments(item))do ench[labels[k] or k]=v end
 return {id=ids[item:get_name()] or 0,wear=item:get_wear(),enchantments=ench}
end
local function make_stack(row)
 local item=ItemStack(names[row.id] or '')
 for k,v in pairs(row.enchantments or {})do mcl_enchanting.enchant(item,k,v)end
 item:set_wear(row.wear or 0)
 return item
end
core.register_on_mods_loaded(function()core.after(0,function()
 local class=mcl_mobs.mob_class;local old_random=math.random;math.random=random
 local result={generated={},fixed={},better={},drops={},damage={},sunlight={}}
 local function actor()
  local a=setmetatable({armor_list={head='',torso='',legs='',feet=''},armor_drop_probability={head=0.085,torso=0.085,legs=0.085,feet=0.085}},{__index=class})
  a.object={get_pos=function()return vector.new(0,0,0)end};a.set_armor_texture=function()end
  return a
 end
 local slots={'head','torso','legs','feet'}
 local function equipment(a)
  local out={};for i,k in ipairs(slots)do out[i]=snapshot(a.armor_list[k])end;return out
 end
 for difficulty=1,3 do for _,factor in ipairs({0,0.5,1})do for seed=1,60 do
  stream=seed;forced=nil;mcl_vars.difficulty=difficulty
  local a=actor();class.generate_default_equipment(a,factor,true,false)
  result.generated[#result.generated+1]={seed=seed,difficulty=difficulty,factor=factor,slots=equipment(a),state=stream}
 end end end
 for _,difficulty in ipairs({1,3})do for base=1,3 do for promotions=0,3 do for count=0,4 do
  local values={0,base};for i=1,3 do values[#values+1]=i<=promotions and 0 or 1 end
  for i=1,4 do values[#values+1]=i<=count and 2 or 1;if i<=count then values[#values+1]=1 else break end end
  forced=values;cursor=0;mcl_vars.difficulty=difficulty;local a=actor()
  class.generate_default_equipment(a,1,true,false)
  result.fixed[#result.fixed+1]={rolls=values,difficulty=difficulty,slots=equipment(a),used=cursor}
 end end end end
 forced=nil
 local armors={};for _,p in ipairs(profiles)do if p.id~=45 and p.id~=7560 then armors[#armors+1]=p end end
 for _,old in ipairs(armors)do for _,new in ipairs(armors)do if old.piece==new.piece then
 for variant=0,3 do
  local a={id=old.id,wear=variant==0 and 65000 or 0,enchantments={}}
  local b={id=new.id,wear=0,enchantments={}}
  if variant==1 then a.enchantments.curse_of_binding=1 end
  if variant==2 then a.enchantments.unbreaking=3 end
  if variant==3 then b.enchantments.protection=1 end
  result.better[#result.better+1]={old=a,new=b,value=class.armor_better_than({},make_stack(b),make_stack(a))==true}
 end end end end
 local drop_result
 local old_drop=mcl_util.drop_item_stack;mcl_util.drop_item_stack=function(_,item)drop_result=snapshot(item)end
 for _,p in ipairs(armors)do for _,prob in ipairs({0.085,2})do for _,loot in ipairs({0,3})do
 for _,vanish in ipairs({false,true})do for _,sample in ipairs({0,0.085,0.115,0.9})do
  local a=actor();local row={id=p.id,wear=12000,enchantments=vanish and {curse_of_vanishing=1} or {unbreaking=2}}
  a.armor_list.head=make_stack(row):to_string();a._armor_drop_probabilities={head=prob};drop_result=nil
  local after_first=false;stream=33;math.random=function(x,y)if not x and not after_first then after_first=true;return sample end;return random(x,y)end
  class.drop_armor(a,loot*0.01)
  result.drops[#result.drops+1]={item=row,probability=prob,looting=loot,sample=sample,result=drop_result or false}
 end end end end end
 math.random=random;mcl_util.drop_item_stack=old_drop
 local old_update=mcl_armor.update;local old_deal=mcl_util.deal_damage;mcl_armor.update=function()end
 local order={};for _,e in pairs(mcl_armor.elements)do order[#order+1]=e.index-2 end;result.order=order
 for _,p in ipairs(profiles)do local d=core.registered_items[p.name];if d then d._on_break=nil end end
 local sets={ {}, {{id=11568},{id=11569},{id=11570},{id=11571}},
  {{id=108,enchantments={protection=3}},{id=113,enchantments={thorns=3}},{id=106},{id=11571,enchantments={feather_falling=4}}},
  {{id=108,wear=65500,enchantments={thorns=2}},{id=105,wear=65500,enchantments={thorns=3,unbreaking=2}}} }
 local reasons={{'mob',{}},{'arrow',{is_projectile=true}},{'fall',{bypasses_armor=true}}, {'on_fire',{is_fire=true,bypasses_armor=true}}, {'out_of_world',{bypasses_armor=true,bypasses_magic=true}}}
 for _,set in ipairs(sets)do for _,reason in ipairs(reasons)do for _,amount in ipairs({1,8,30})do for _,seed in ipairs({4,17})do
  stream=seed;local a=actor();a.is_mob=true;local reflected=0
  for i,k in ipairs(slots)do a.armor_list[k]=make_stack(set[i] or {}):to_string()end
  local obj={is_player=function()return false end,get_luaentity=function()return a end}
  local attacker={get_pos=function()return vector.new(0,0,0)end}
  mcl_util.deal_damage=function(_,damage)reflected=reflected+damage end
  local actual=armor_damage(obj,amount,{type=reason[1],flags=reason[2],source=attacker})
  result.damage[#result.damage+1]={input=set,reason=reason[1],flags=reason[2],amount=amount,seed=seed,slots=equipment(a),damage=actual or amount,reflected=reflected,state=stream}
 end end end end
 mcl_armor.update=old_update;mcl_util.deal_damage=old_deal
 for _,id in ipairs({0,104,11568,45})do for _,wear in ipairs({0,65530})do for _,gate in ipairs({1,2})do for _,wear_gate in ipairs({1,2})do
  local a=actor();a.armor_list.head=make_stack({id=id,wear=wear}):to_string();a.ignited_by_sunlight=true;a._frozen_for=0;a._collision_count=0;a.standing_on='air'
  a.check_timer=function()return false end;a.step_drowning=function()return false end;a.get_eye_height=function()return 1.74 end
  a.get_weather_with_light=function()return 15,15,false end;local ignited=0;a.fast_ignite=function(_,duration)ignited=duration end
  forced={gate,wear_gate};cursor=0
  class.apply_environment_damage(a,vector.new(0,0,0),0,'none',{dps=0},0.05)
  result.sunlight[#result.sunlight+1]={id=id,wear=wear,gate=gate,wear_gate=wear_gate,head=snapshot(a.armor_list.head),ignited=ignited}
 end end end end
 math.random=old_random
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Mob armor reference complete',false,0)
end)end)
'''


def export():
    durability = json.loads((ROOT/'assets/data/durability.json').read_text())['profiles']
    profiles = []
    for p in durability.values():
        if p['armor'] and not p['elytra']:
            name = p['name']
            piece = next((i for i, word in enumerate(['helmet', 'chestplate', 'leggings', 'boots']) if word in name), -1)
            if piece >= 0 and not name.endswith('_netherite'):
                profiles.append({'id': p['id'], 'name': name, 'piece': piece})
    profiles += [{'id': 45, 'name': 'mcl_farming:pumpkin_face', 'piece': 0}, {'id': 7560, 'name': 'mcl_farming:pumpkin_face_light', 'piece': 0}]
    definitions = json.loads((ROOT/'assets/data/enchanting.json').read_text())['definitions']
    labels = {value['source_key']: key for key, value in definitions.items()}
    armor_text = (SOURCE/PATHS[3]).read_text()
    prefix = armor_text[:armor_text.index('mcl_damage.register_modifier(')]
    callback = armor_text.split('mcl_damage.register_modifier(', 1)[1].rsplit('end, 0)', 1)[0]+'end'
    script = prefix+'\nlocal armor_damage='+callback+'\n'+BODY.replace('PROFILES_VALUE', lua(profiles)).replace('LABELS_VALUE', lua(labels))
    world = Path(tempfile.mkdtemp(prefix='voxey-mob-armor-'))
    fixture = world/'worldmods'/'voxey_mob_armor_fixture'; fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_mob_armor_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31503\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_mob_armor_fixture\ndepends = mobs_mc, mcl_armor, mcl_enchanting\n')
    (fixture/'init.lua').write_text(script)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists(): raise RuntimeError(str(world)+'\n'+run.stderr[-4000:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    result['labels'] = labels
    (ROOT/'assets/data/mob_armor_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print({key: len(value) for key, value in result.items() if isinstance(value, list)})


if __name__ == '__main__': export()
