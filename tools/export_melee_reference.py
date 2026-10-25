#!/usr/bin/env python3
"""Exercise Mineclonia's real mob punch and mace callbacks with real ItemStacks."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from export_enchanting_reference import lua

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ENTITIES/mcl_mobs/combat.lua', 'mods/ITEMS/mcl_tools/register.lua',
         'mods/ITEMS/mcl_tools/init.lua', 'mods/ITEMS/mcl_tools/mace.lua',
         'mods/ITEMS/mcl_enchanting/enchantments.lua', 'mods/PLAYER/mcl_criticals/init.lua',
         'mods/CORE/mcl_util/misc.lua', 'mods/ITEMS/mcl_potions/functions.lua',
         'mods/ENTITIES/mcl_mobs/physics.lua']

def modifier(path, start, end):
    text = (SOURCE / path).read_text()
    a = text.index(start) + len(start)
    return text[a:text.index(end, a)] + '\nend'

BODY = r'''
local stream=1
local function random(a,b)
 stream=(stream*1664525+1013904223)%4294967296
 if not a then return stream/4294967295 end
 if not b then b=a;a=1 end
 return a+stream%(b-a+1)
end
local function vec(v)return vector.new(v[1],v[2],v[3])end
local function arr(v)return {v.x,v.y,v.z}end
local names={}
local probe_direction,probe_caps,probe_elapsed
core.register_entity('voxey_melee_fixture:probe',{
 initial_properties={physical=false,visual='sprite',textures={'blank.png'}},
 on_activate=function(self)self.object:set_armor_groups({immortal=1})end,
 on_punch=function(_,_,elapsed,caps,dir)probe_direction=dir;probe_caps=caps;probe_elapsed=elapsed;return true end,
})
core.register_on_mods_loaded(function()
 core.after(0,function()
  local result={profiles={},cases={},resistances={}}
  for name,def in pairs(core.registered_entities)do
   if name:sub(1,8)=='mobs_mc:' and def.knockback_resistance then
    result.resistances[name:sub(9)]=def.knockback_resistance
   end
  end
  local a=core.add_entity(vector.new(0,100,0),'voxey_melee_fixture:probe')
  local b=core.add_entity(vector.new(0,100,2),'voxey_melee_fixture:probe')
  b:punch(a,1,{full_punch_interval=1,damage_groups={fleshy=1}},nil)
  result.engine_direction=arr(probe_direction)
  for _,p in ipairs(PROFILES)do
   names[p.id]=p.name
   local def=core.registered_items[p.name]
   local caps=def.tool_capabilities and ItemStack(p.name):get_tool_capabilities() or mcl_meshhand.survival_hand_tool_caps
   result.profiles[tostring(p.id)]={name=p.name,custom=def.tool_capabilities~=nil,interval=caps.full_punch_interval or 1.4,
    groups=caps.damage_groups or {},uses=caps.punch_attack_uses or 0}
  end
  local hand=mcl_meshhand.survival_hand_tool_caps
  result.profiles['0']={name='',interval=hand.full_punch_interval,groups=hand.damage_groups,uses=0}
  math.random=random
  doc.mark_entry_as_revealed=function()end
  mcl_potions.update_haste_and_fatigue=function()end
  mcl_hunger.exhaust=function()end
  core.sound_play=function()end
  core.add_particlespawner=function()end
  for _,case in ipairs(CASES)do
   stream=case.seed
   local weapon=ItemStack(names[case.id] or '')
   weapon:set_wear(case.wear)
   if case.id~=0 then
    for key,level in pairs(case.enchantments)do mcl_enchanting.enchant(weapon,key,level)end
   end
   local damage=0;local burning=0;local slowness=0;local swings=0;local looting=0
   a:set_velocity(vec(case.velocity));b:set_velocity(vec(case.target_velocity))
   local pv=a:get_velocity();local tv=b:get_velocity()
   local hitter={is_player=function()return true end,get_player_name=function()return 'oracle' end,
    get_luaentity=function()end,get_velocity=function()return pv end,
    add_velocity=function(_,v)pv=pv+v end,get_pos=function()return vector.zero()end,
    get_wielded_item=function()return ItemStack(weapon)end,
    set_wielded_item=function(_,v)weapon=ItemStack(v)end,get_hp=function()return 20 end}
   local obj={is_player=function()return false end,get_luaentity=function()return {}end,
    get_armor_groups=function()return case.armor end,get_velocity=function()return tv end,
    add_velocity=function(_,v)tv=tv+v end,set_velocity=function(_,v)tv=v end,
    get_pos=function()return vector.new(0,0,case.distance)end,
    get_properties=function()return {collisionbox={-.3,0,-.3,.3,1.8,.3}}end}
   local mob={object=obj,name='oracle',knock_back=true,knockback_resistance=case.resistance,
    standing_on_walkable=function()return case.standing end,damage_effect=function()end}
   obj.punch=function(_,_,elapsed,caps,dir)
    swings=swings+1
    assert(a:get_pos() and b:get_pos(),'Engine capability probes must remain alive')
    probe_caps=nil
    b:punch(a,elapsed,caps,dir)
    assert(probe_caps,'Engine probe must receive this punch')
    mcl_mobs.mob_class.on_punch(mob,hitter,probe_elapsed,probe_caps,probe_direction)
   end
   mcl_potions.get_effect=function(who,key)
    local f=case[key] or 1
    if who==hitter and f~=1 then return {factor=f}end
   end
   mcl_potions.give_effect_by_level=function(_,_,_,duration)slowness=duration end
   mcl_burning.set_on_fire=function(_,duration)burning=duration end
   core.is_creative_enabled=function()return case.creative end
   core.get_gametime=function()return case.time end
   mcl_sprint.is_sprinting=function()return case.sprinting end
   EF.strength[hitter]=case.strength~=1 and {factor=case.strength} or nil
   EF.weakness[hitter]=case.weakness~=1 and {factor=case.weakness} or nil
   mcl_util.deal_damage=function(_,amount,reason)
    looting=mcl_enchanting.get_enchantment(weapon,'looting')
    amount=critical(obj,amount,reason) or amount
    amount=potions(obj,amount,reason) or amount
    damage=damage+amount
    return amount
   end
   local caps=weapon:get_definition().tool_capabilities and weapon:get_tool_capabilities() or hand
   if case.id==947 then
    mcl_tools.mace_cooldown[hitter]=case.last_mace
    local v=core.registered_items['mcl_tools:mace'].on_use(weapon,hitter,{type='object',ref=obj})
    if v then weapon=v end
   else
    obj:punch(hitter,case.elapsed,caps,vec(case.direction))
   end
   result.cases[#result.cases+1]={case=case,damage=damage,burning=burning,slowness=slowness,looting=looting,
    swings=swings,wear=weapon:is_empty() and -1 or weapon:get_wear(),
    player_velocity=arr(pv),target_velocity=arr(tv),state=stream,
    mace_stamp=mcl_tools.mace_cooldown[hitter] or case.last_mace}
   mcl_tools.mace_cooldown[hitter]=nil;EF.strength[hitter]=nil;EF.weakness[hitter]=nil
  end
  a:remove();b:remove()
  core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true))
  core.request_shutdown('Melee oracle complete',false,0)
 end)
end)
'''

def export():
    profiles = [{'id': int(k), 'name': v['name']} for k, v in json.loads((ROOT/'assets/data/durability.json').read_text())['profiles'].items()]
    profiles += [{'id': 946, 'name': 'mcl_tridents:trident'}]
    cases = []
    def add(id_, **overrides):
        case = dict(id=id_, wear=12000, enchantments={}, seed=73, velocity=[0,0,0],
                    target_velocity=[0,0,0], armor={'fleshy':100}, elapsed=3.0,
                    resistance=0, standing=True, direction=[0,0,1], distance=2.0,
                    creative=False, time=100, last_mace=0, sprinting=False, strength=1, weakness=1)
        case.update(overrides); cases.append(case)
    for id_ in [0]+[p['id'] for p in profiles]:
        for elapsed in [0,0.1,0.5,3.0]:
            for ench in [{},{'sharpness':5,'unbreaking':3},{'smite':3,'fire_aspect':2},{'bane_of_arthropods':3,'knockback':2}]:
                add(id_,elapsed=elapsed,enchantments=ench if id_ else {},armor={'fleshy':90,'undead':80,'arthropod':60})
    for seed in [1,7,73]:
        for vy in [-10,0,3]:
            for sprint in [False,True]:
                for creative in [False,True]:
                    add(98,seed=seed,velocity=[2,vy,1],sprinting=sprint,creative=creative,
                        strength=1.6,weakness=.8,enchantments={'sharpness':2,'knockback':1},
                        target_velocity=[3,-2,1],resistance=.6,standing=False)
    for vy in [0,-1,-6.3245553203,-8,-10.9544511501,-14,-17.88854382,-20,-25,10]:
        for elapsed in [1,2,3]:
            for ench in [{},{'density':5,'wind_burst':3},{'smite':5,'bane_of_arthropods':3,'unbreaking':3}]:
                add(947,velocity=[1,vy,2],time=elapsed,last_mace=0,enchantments=ench)
    for id_ in [83,88,93,98,1093,947]:
        for wear in [65500,65535]:
            for unbreaking in [0,3]:add(id_,wear=wear,enchantments={'unbreaking':unbreaking,'knockback':2,'looting':3})
    critical=modifier(PATHS[5],'mcl_damage.register_modifier(', '\nend, -100)')
    potions=modifier(PATHS[7],'-- implementation of strength and weakness effects\n-- mobs have this implemented in mcl_mobs/combat.lua in mob_class:on_punch()\nmcl_damage.register_modifier(', '\nend, 0)')
    prefix='local PROFILES='+lua(profiles)+'\nlocal CASES='+lua(cases)+'\nlocal EF={strength={},weakness={}}\nlocal critical='+critical+'\nlocal potions='+potions+'\n'
    world=Path(tempfile.mkdtemp(prefix='voxey-melee-oracle-'))
    fixture=world/'worldmods'/'voxey_melee_fixture';fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_melee_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31492\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_melee_fixture\ndepends = mcl_mobs, mcl_tools, mcl_potions, mcl_enchanting, mcl_meshhand\n')
    (fixture/'init.lua').write_text(prefix+BODY)
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'oracle.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3500:])
    output=json.loads((world/'oracle.json').read_text())
    output['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    output['license']='GPL-3.0-or-later'
    (ROOT/'assets/data/melee_reference.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
    (ROOT/'assets/data/melee.json').write_text(json.dumps({k:output[k] for k in ['profiles','resistances','source_hashes','license']},indent=2)+'\n')
    print('Exported',len(output['profiles']),'profiles and',len(output['cases']),'real source punch/mace cases:',world)

if __name__=='__main__':export()
