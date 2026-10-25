#!/usr/bin/env python3
"""Measure the installed shield and projectile callbacks in a real Luanti world."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ITEMS/mcl_shields/init.lua', 'mods/ITEMS/mcl_bows/arrow.lua',
         'mods/ITEMS/mcl_tridents/init.lua', 'mods/CORE/mcl_util/item.lua',
         'mods/ITEMS/mcl_bows/bow.lua']
BODY = r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local result={angles={},wear={},arrows={},tridents={},cosine=-math.cos(180/2)}
 local creative=false;local original_creative=core.is_creative_enabled
 core.is_creative_enabled=function()return creative end
 mcl_inventory.update_inventory_formspec=function()end
 local serial=0
 local function player(hand,wear,unbreaking)
  serial=serial+1
  local name='ShieldFixture'..serial
  local item=ItemStack(unbreaking>0 and 'mcl_shields:shield_red_enchanted' or 'mcl_shields:shield_red')
  if unbreaking>0 then mcl_enchanting.set_enchantments(item,{unbreaking=unbreaking})end
  item:set_wear(wear)
  local p={}
  p.is_player=function()return true end;p.is_valid=function()return true end
  p.get_player_name=function()return name end
  p.get_pos=function()return vector.new(0,0,0)end
  p.get_properties=function()return{eye_height=1.62}end
  p.get_look_dir=function()return vector.new(0,0,-1)end
  p.get_wielded_item=function()return hand==2 and ItemStack(item)or ItemStack('')end
  p.set_wielded_item=function(_,v)item=ItemStack(v)end
  p.get_inventory=function()return{get_stack=function()return ItemStack(item)end,set_stack=function(_,_,_,v)item=ItemStack(v)end}end
  p.get_luaentity=function()return nil end
  mcl_shields.players[p]={blocking=hand}
  return p,function()return item end
 end
 for _,dot in ipairs({-1,-0.7,0,0.3,result.cosine-1e-9,result.cosine,result.cosine+1e-9,0.7,1})do
  for _,kind in ipairs({'mob','player','arrow','generic','explosion','dragon_breath','trident','fire','fall','out_of_world'})do
   for _,active in ipairs({true,false})do
    local p=player(active and 2 or 0,0,0)
    local ok,reason=mcl_shields.can_block(p,dot,{type=kind})
    result.angles[#result.angles+1]={dot=dot,kind=kind,active=active,blocked=not not ok,reason=type(reason)=='string'and reason or ''}
   end
  end
 end
 for _,before in ipairs({0,1,16335,32767,65000,65535})do for _,damage in ipairs({2.9,3,4.5,5,18,336})do for level=0,3 do for hand=1,2 do for _,enabled in ipairs({false,true})do
  creative=enabled
  local p,get=player(hand,before,level)
  local ok,reason=mcl_shields.add_wear(p,damage)
  local item=get()
  result.wear[#result.wear+1]={before=before,damage=damage,unbreaking=level,hand=hand,creative=enabled,applied=not not ok,wear=item:get_wear(),count=item:get_count(),reason=reason or ''}
 end end end end end
 creative=false
 local arrow=core.registered_entities['mcl_bows:arrow_entity']
 local shield_modifier
 for _,modifier in ipairs(mcl_damage.modifiers)do if debug.getinfo(modifier.func,'S').source:find('/mcl_shields/')then shield_modifier=modifier.func end end
 assert(shield_modifier)
 for _,dot in ipairs({-1,0,0.3,result.cosine+1e-8,1})do for _,v in ipairs({vector.new(0,0,20),vector.new(6,4,32),vector.new(0,-5,50)})do for _,piercing in ipairs({0,1,3})do
  local p,get=player(2,0,1);local velocity=vector.copy(v);local at=vector.new(1,1.2,0.3)
  local applied=false;local knock=false;local dealt=0;local a
  local origin=vector.new(math.sqrt(1-dot*dot)*4,1.08,dot*4)
  local shooter={is_valid=function()return true end,get_pos=function()return vector.copy(origin)end}
  local obj={get_velocity=function()return vector.copy(velocity)end,set_velocity=function(_,new)velocity=vector.copy(new)end,set_pos=function(_,new)at=vector.copy(new)end,set_attach=function()end,is_player=function()return false end,is_valid=function()return true end,get_luaentity=function()return a end}
  a={object=obj,_damage=2,_piercing=piercing,_is_critical=false,calculate_damage=arrow.calculate_damage,_shooter=shooter,
   get_last_pos=function()return vector.new(math.sqrt(1-dot*dot)*4,1.08,dot*4)end,
   apply_effects=function()applied=true;local damage=arrow.calculate_damage(a);dealt=shield_modifier(p,damage,{type='arrow',direct=obj})or damage end,arrow_knockback=function()knock=true end,cut_off=function()end}
  local hit=arrow.on_hit_player(a,p,nil,{intersection_point=vector.new(0,1.2,0)})
  result.arrows[#result.arrows+1]={dot=dot,velocity={v.x,v.y,v.z},piercing=piercing,result=hit,after={velocity.x,velocity.y,velocity.z},position={at.x,at.y,at.z},effects=applied,damage=dealt,knock=knock,blocked=not not a._blocked,wear=get():get_wear()}
 end end end
 local trident=core.registered_entities['mcl_tridents:trident']
 local old_raycast=mcl_attachments.raycast;local old_intercept=mcl_attachments.raycast_intercept
 mcl_attachments.raycast_intercept=function()end
 for _,v in ipairs({vector.new(0,0,50),vector.new(8,-4,32),vector.new(-20,12,5)})do
  local p=player(2,0,0);local sent=false
  mcl_attachments.raycast=function()return function()if not sent then sent=true;return{type='object',ref=p,intersection_normal=vector.new(0,0,-1),intersection_point=vector.new(0,1,0)}end end end
  local after,target,point=trident.raycast_entities({_objects_seen={},object={},_riptide_player=nil},v,vector.new(0,1,-1),vector.new(0,1,1))
  result.tridents[#result.tridents+1]={velocity={v.x,v.y,v.z},after={after.x,after.y,after.z},position={point.x,point.y,point.z},hit=target==p}
 end
 mcl_attachments.raycast=old_raycast;mcl_attachments.raycast_intercept=old_intercept
 core.is_creative_enabled=original_creative
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Shield combat reference complete',false,0)
end)end)
'''

def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-shield-combat-oracle-'))
    fixture = world/'worldmods'/'voxey_shield_combat_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_shield_combat_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31497\nserver_announce = false\nenable_ipv6 = false\nenable_pvp = true\n')
    (fixture/'mod.conf').write_text('name = voxey_shield_combat_fixture\ndepends = mcl_shields, mcl_bows, mcl_tridents\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-500:]+'\n'+run.stderr[-3000:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT/'assets/data/shield_combat_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print('Exported:', {key:len(result[key]) for key in ['angles','wear','arrows','tridents']}, 'cosine:', result['cosine'])

if __name__ == '__main__':
    export()
