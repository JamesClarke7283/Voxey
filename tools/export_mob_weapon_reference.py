#!/usr/bin/env python3
"""Execute source held-item generation, selection, attack caps and drop callbacks."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from export_enchanting_reference import lua

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ENTITIES/mcl_mobs/combat.lua', 'mods/ENTITIES/mcl_mobs/items.lua',
         'mods/CORE/mcl_util/item.lua', 'mods/ITEMS/mcl_enchanting/groupcaps.lua',
         'mods/CORE/mcl_damage/init.lua',
         'mods/ITEMS/mcl_enchanting/enchantments.lua',
         'mods/ENTITIES/mobs_mc/zombie.lua', 'mods/ENTITIES/mobs_mc/skeleton+stray.lua',
         'mods/ENTITIES/mobs_mc/skeleton_wither.lua', 'mods/ENTITIES/mobs_mc/drowned.lua']
BODY = r'''
local profiles=PROFILES_VALUE;local labels=LABELS_VALUE
local names={};local ids={}
for _,p in ipairs(profiles)do names[p.id]=p.name;ids[p.name]=p.id;ids[p.name..'_enchanted']=p.id end
local stream=1
local function random(a,b)
 stream=(stream*1664525+1013904223)%4294967296
 if not a then return stream/4294967295 end
 if not b then b=a;a=1 end
 a=math.floor(a);b=math.floor(b);return a+stream%(b-a+1)
end
local function stack(row)
 local item=ItemStack(names[row.id] or '')
 for key,value in pairs(row.enchantments or {})do mcl_enchanting.enchant(item,key,value)end
 item:set_wear(row.wear or 0);return item
end
local function snapshot(item)
 item=ItemStack(item);local enchantments={}
 for key,value in pairs(mcl_enchanting.get_enchantments(item))do enchantments[labels[key] or key]=value end
 return {id=ids[item:get_name()] or 0,wear=item:get_wear(),count=item:get_count(),enchantments=enchantments}
end
core.register_on_mods_loaded(function()core.after(0,function()
 local class=mcl_mobs.mob_class;local old_random=math.random;math.random=random
 local result={generated={},preferences={},caps={},drops={},modes={},tags={},player_scale={}}
 local scale;for _,modifier in ipairs(mcl_damage.modifiers)do if modifier.priority==-1000 then scale=modifier.func;break end end
 local player={is_player=function()return true end};local source={get_luaentity=function()return {is_mob=true}end}
 for level=0,3 do mcl_vars.difficulty=level;for _,amount in ipairs({0,0.5,1,2,3,5,10,20})do
  result.player_scale[#result.player_scale+1]={difficulty=level,amount=amount,result=scale(player,amount,{flags={},source=source})}
 end end
 for _,p in ipairs(profiles)do
  result.tags[tostring(p.id)]={tool=core.get_item_group(p.name,'tool')>0,weapon=core.get_item_group(p.name,'weapon')>0,sword=core.get_item_group(p.name,'sword')>0}
  local uses={};for level=0,3 do
   local s=ItemStack(p.name);if level>0 and mcl_enchanting.get_enchanted_itemstring(p.name) then mcl_enchanting.enchant(s,'unbreaking',level)end
   uses[#uses+1]=mcl_util.calculate_durability(s)
  end
  result.tags[tostring(p.id)].uses=uses
 end
 local function actor(item,base)
  local a=setmetatable({_wielditem=item,damage=base or 3,can_wield_items=true,wielditem_drop_probability=0.085,animation={}}, {__index=class})
  a.display_wielditem=function()end;a.mob_sound=function()end;a.object={get_pos=function()return vector.new(0,0,0)end}
  return a
 end
 for difficulty=1,3 do for _,factor in ipairs({0,0.5,1})do for seed=1,80 do
  stream=seed;mcl_vars.difficulty=difficulty;local a=actor(nil)
  class.generate_default_equipment(a,factor,false,true)
  result.generated[#result.generated+1]={seed=seed,factor=factor,difficulty=difficulty,item=snapshot(a._wielditem),state=stream}
 end end end
 local chosen={0,83,88,93,98,1113,92,134,790,946,789,3,79}
 for _,old in ipairs(chosen)do for _,new in ipairs(chosen)do for variant=0,2 do
  local oldrow={id=old,wear=variant==0 and 65000 or 0,enchantments={}}
  local newrow={id=new,wear=0,enchantments={}}
  if variant==1 and core.get_item_group(names[old] or '', 'tool')>0 then oldrow.enchantments.unbreaking=3 end
  if variant==2 and mcl_enchanting.get_enchanted_itemstring(names[new] or '') then newrow.enchantments.curse_of_vanishing=1 end
  for _,kind in ipairs({'skeleton','drowned'})do
   local a=actor(stack(oldrow):to_string())
   local fn=kind=='drowned' and core.registered_entities['mobs_mc:drowned'].wielditem_better_than or class.wielditem_better_than
   result.preferences[#result.preferences+1]={old=oldrow,new=newrow,kind=kind,value=fn(a,stack(newrow),stack(oldrow))==true,dur_old=mcl_util.calculate_durability(stack(oldrow)),dur_new=mcl_util.calculate_durability(stack(newrow))}
  end
 end end end
 for _,id in ipairs(chosen)do for _,base in ipairs({2,3,4})do for variant=0,2 do
  local row={id=id,wear=0,enchantments={}}
  if variant==1 and core.get_item_group(names[id] or '', 'sword')>0 then row.enchantments.sharpness=5;row.enchantments.fire_aspect=2 end
  if variant==2 and core.get_item_group(names[id] or '', 'sword')>0 then row.enchantments.smite=5 end
  local a=actor(stack(row):to_string(),base);local caps
  a.attack={punch=function(_,_,elapsed,properties) caps=properties end}
  class.custom_attack(a)
  result.caps[#result.caps+1]={item=row,base=base,interval=caps.full_punch_interval,groups=caps.damage_groups}
 end end end
 local dropped;local old_drop=mcl_util.drop_item_stack
 mcl_util.drop_item_stack=function(_,item)dropped=snapshot(item)end
 for _,id in ipairs({83,88,93,98,134,946})do for _,probability in ipairs({0,0.085,2})do
 for _,looting in ipairs({0,3})do for _,sample in ipairs({0,0.085,0.115,0.9})do
  stream=33;local once=false;math.random=function(a,b)if not a and not once then once=true;return sample end;return random(a,b)end
  local item={id=id,wear=12000,enchantments={unbreaking=2}};local a=actor(stack(item):to_string())
  a._effective_wielditem_drop_probability=probability;dropped=nil
  class.drop_wielditem(a,looting*0.01)
  result.drops[#result.drops+1]={item=item,probability=probability,looting=looting,sample=sample,result=dropped or false,cleared=a._wielditem==nil}
 end end end end
 math.random=random;mcl_util.drop_item_stack=old_drop
 for _,kind in ipairs({'skeleton','stray','witherskeleton','drowned'})do for _,id in ipairs(chosen)do
  local a=actor(stack({id=id}):to_string());a.reset_attack_type=function(self,kind)self.attack_type=kind end
  core.registered_entities['mobs_mc:'..kind].reconfigure_attack_type(a,stack({id=id}))
  result.modes[#result.modes+1]={kind=kind=='witherskeleton' and 'wither_skeleton' or kind,id=id,mode=a.attack_type}
 end end
 math.random=old_random
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Mob weapons complete',false,0)
end)end)
'''


def export():
    profile_map = {}
    for file in ['durability.json', 'melee.json']:
        for id_, info in json.loads((ROOT/'assets/data'/file).read_text())['profiles'].items():
            profile_map[int(id_)] = info['name']
    profile_map.update({0: '', 3: 'mcl_core:stone', 79: 'mcl_mobitems:bone', 1201: 'mcl_mobitems:nautilus_shell'})
    profiles = [{'id': id_, 'name': name} for id_, name in profile_map.items()]
    definitions = json.loads((ROOT/'assets/data/enchanting.json').read_text())['definitions']
    labels = {info['source_key']: key for key, info in definitions.items()}
    world = Path(tempfile.mkdtemp(prefix='voxey-mob-weapons-')); fixture = world/'worldmods'/'voxey_weapon_fixture'; fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_weapon_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31504\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_weapon_fixture\ndepends = mobs_mc, mcl_enchanting\n')
    (fixture/'init.lua').write_text(BODY.replace('PROFILES_VALUE', lua(profiles)).replace('LABELS_VALUE', lua(labels)))
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists(): raise RuntimeError(str(world)+'\n'+run.stderr[-4000:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}; result['labels'] = labels
    (ROOT/'assets/data/mob_weapon_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    (ROOT/'assets/data/mob_weapon_items.json').write_text(json.dumps(result['tags'], separators=(',', ':'))+'\n')
    print({key: len(value) for key, value in result.items() if isinstance(value, list)})


if __name__ == '__main__': export()
