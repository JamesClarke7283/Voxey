#!/usr/bin/env python3
"""Run installed mcl_bows.player_shoot and shoot_arrow in a real Luanti world."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ITEMS/mcl_bows/bow.lua', 'mods/ITEMS/mcl_bows/arrow.lua',
         'mods/CORE/mcl_util/misc.lua', 'minetest.conf']
BODY = r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local result={shots={},samples={0.1,0.2,0.8,0.3,0.7,0.9}}
 local creative=false;core.is_creative_enabled=function()return creative end
 -- Replace engine object boundaries, preserving the real bow/arrow functions.
 local captured;local entity;local sample_index=0
 core.sound_play=function()end
 mcl_util.target_eye_pos=function()return vector.new(5,7,9)end
 local _,rng=debug.getupvalue(mcl_util.dist_triangular,1)
 assert(type(rng)=='userdata','Expected source triangular RNG upvalue')
 local fake_rng={next=function()
  sample_index=sample_index%6+1
  return math.floor(result.samples[sample_index]*2147483647)
 end}
 debug.setupvalue(mcl_util.dist_triangular,1,fake_rng)
 core.add_entity=function(pos,name)
  captured={position={pos.x,pos.y,pos.z},name=name};entity={player=''}
  return{get_pos=function()return pos end,set_velocity=function(_,v)captured.velocity={v.x,v.y,v.z}end,
   set_acceleration=function(_,a)captured.acceleration={a.x,a.y,a.z}end,set_yaw=function()end,get_luaentity=function()return entity end}
 end
 mcl_burning.set_on_fire=function()captured.flame=true end
 for _,charge in ipairs({-1,0,1,199999,200000,499999,500000,1000000})do
 for _,kind in ipairs({'none','regular','tipped'})do
 for _,infinity in ipairs({0,1})do for _,power in ipairs({0,1,5})do
 for unbreaking=0,3 do for _,enabled in ipairs({false,true})do for _,before in ipairs({0,65500})do
  creative=enabled;captured=nil;sample_index=0
  local bow=ItemStack('mcl_bows:bow')
  local ench={};if infinity>0 then ench.infinity=infinity end;if power>0 then ench.power=power;ench.punch=2;ench.flame=1 end;if unbreaking>0 then ench.unbreaking=unbreaking end
  mcl_enchanting.set_enchantments(bow,ench);bow:set_wear(before)
  local ammo=ItemStack(kind=='none' and '' or kind=='regular' and 'mcl_bows:arrow 3' or 'mcl_potions:poison_arrow 3')
  assert(kind=='none' or core.get_item_group(ammo:get_name(),'ammo_bow')>0,ammo:get_name())
  local inv={get_size=function()return 3 end,get_stack=function(_,_,i)return ItemStack(i==2 and ammo or i==1 and bow or '')end,
   set_stack=function(_,_,i,v)if i==2 then ammo=ItemStack(v)end end}
  local p={is_player=function()return true end,get_player_name=function()return 'BowFixture'end,
   get_inventory=function()return inv end,get_wielded_item=function()return ItemStack(bow)end,
   set_wielded_item=function(_,v)bow=ItemStack(v)end,get_look_dir=function()return vector.new(0,0,-1)end,get_look_horizontal=function()return 0 end}
  mcl_bows.player_shoot(p,ItemStack(bow),charge)
  local row={charge=charge,ammo=kind,infinity=infinity,power=power,unbreaking=unbreaking,creative=creative,before=before,
   fires=captured~=nil,count=ammo:get_count(),wear=bow:get_wear(),bow_count=bow:get_count()}
  if captured then row.velocity=captured.velocity;row.position=captured.position;row.acceleration=captured.acceleration;
   row.critical=entity._is_critical;row.damage=entity._damage;row.punch=entity._knockback;row.flame=not not captured.flame;row.collectable=entity._collectable
  end
  result.shots[#result.shots+1]=row
 end end end end end end end
 result.speed_factor=tonumber(core.settings:get('movement_speed_crouch'))/tonumber(core.settings:get('movement_speed_walk'))
 debug.setupvalue(mcl_util.dist_triangular,1,rng)
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Bow reference complete',false,0)
end)end)
'''

def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-bow-oracle-'))
    fixture = world/'worldmods'/'voxey_bow_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_bow_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31498\nserver_announce = false\nenable_ipv6 = false\nsecure.enable_security = false\n')
    (fixture/'mod.conf').write_text('name = voxey_bow_fixture\ndepends = mcl_bows, mcl_potions\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-500:]+'\n'+run.stderr[-3500:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT/'assets/data/bow_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print('Exported', len(result['shots']), 'real bow shots; movement multiplier', result['speed_factor'])

if __name__ == '__main__':
    export()
