#!/usr/bin/env python3
"""Exercise the installed crossbow's real hold/release/press callbacks."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ITEMS/mcl_bows/crossbow.lua', 'mods/ITEMS/mcl_bows/arrow.lua',
         'mods/CORE/mcl_util/misc.lua', 'mods/ITEMS/mcl_enchanting/engine.lua']
BODY = r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local result={loads={},shots={},samples={0.1,0.2,0.8,0.3,0.7,0.9}}
 local callbacks={}
 for _,key in ipairs({'hold','release','press'})do
  for _,f in ipairs(controls['registered_on_'..key])do
   if debug.getinfo(f,'S').source:find('/mcl_bows/crossbow.lua',1,true)then callbacks[key]=f end
  end
  assert(callbacks[key],key)
 end
 local creative=false;local now=1000000;local serial=0;local captured={};local sample=0
 core.is_creative_enabled=function()return creative end
 core.get_us_time=function()return now end
 core.sound_play=function()end
 mcl_serverplayer.is_csm_capable=function()return false end
 playerphysics.add_physics_factor=function()end;playerphysics.remove_physics_factor=function()end
 mcl_util.target_eye_pos=function()return vector.new(5,7,9)end
 local _,rng=debug.getupvalue(mcl_util.dist_triangular,1)
 debug.setupvalue(mcl_util.dist_triangular,1,{next=function()sample=sample%6+1;return math.floor(result.samples[sample]*2147483647)end})
 core.add_entity=function(pos,name)
  local row={position={pos.x,pos.y,pos.z},name=name};captured[#captured+1]=row
  local entity={player=''};row.entity=entity
  return {get_pos=function()return pos end,set_velocity=function(_,v)row.velocity={v.x,v.y,v.z}end,
   set_acceleration=function(_,v)row.acceleration={v.x,v.y,v.z}end,set_yaw=function()end,get_luaentity=function()return entity end}
 end
 local function make(quick,multishot,piercing,kind,before,yaw,pitch)
  serial=serial+1;local name='CrossbowFixture'..serial
  local bow=ItemStack('mcl_bows:crossbow');local ench={}
  if quick>0 then ench.quick_charge=quick end;if multishot>0 then ench.multishot=multishot end;if piercing>0 then ench.piercing=piercing end
  mcl_enchanting.set_enchantments(bow,ench);bow:set_wear(before)
  local ammo=ItemStack(kind=='none' and '' or kind=='regular' and 'mcl_bows:arrow 3' or 'mcl_potions:poison_arrow 3')
  local inv={get_size=function()return 3 end,get_stack=function(_,_,i)return ItemStack(i==2 and ammo or i==1 and bow or '')end,
   set_stack=function(_,_,i,v)if i==2 then ammo=ItemStack(v)end end,
   get_list=function()return{ItemStack(bow),ItemStack(ammo)}end,set_list=function(_,_,list)bow=ItemStack(list[1]);ammo=ItemStack(list[2])end}
  local p={is_player=function()return true end,get_player_name=function()return name end,get_wield_index=function()return 1 end,
   get_inventory=function()return inv end,get_wielded_item=function()return ItemStack(bow)end,set_wielded_item=function(_,v)bow=ItemStack(v)end,
   get_look_dir=function()return vector.new(-math.sin(yaw)*math.cos(pitch),math.sin(pitch),-math.cos(yaw)*math.cos(pitch))end,get_look_horizontal=function()return yaw end}
  bow:get_meta():set_string('active','true')
  return p,function()return bow,ammo end
 end
 for quick=0,3 do for _,kind in ipairs({'none','regular','tipped'})do for _,enabled in ipairs({false,true})do
  local half=350000-quick*65000;local full=900000-quick*130000
  for _,elapsed in ipairs({0,half-1,half,full-1,full,full+1})do
   creative=enabled;now=1000000
   local p,get=make(quick,0,0,kind,0,0,0)
   callbacks.hold(p,'RMB');now=1000000+half; if elapsed>=half then callbacks.hold(p,'RMB')end
   now=1000000+elapsed;callbacks.hold(p,'RMB')
   local b=get();local stage=core.get_item_group(b:get_name(),'crossbow')
   callbacks.release(p,'RMB');local bow,ammo=get()
   result.loads[#result.loads+1]={quick=quick,ammo=kind,creative=creative,elapsed=elapsed,stage=stage,loaded=bow:get_name():find('loaded',1,true)~=nil,count=ammo:get_count(),wear=bow:get_wear()}
  end
 end end end
 for _,kind in ipairs({'none','regular','tipped'})do for _,enabled in ipairs({false,true})do
 for multishot=0,1 do for _,piercing in ipairs({0,4})do for unbreaking=0,3 do
 for _,before in ipairs({0,65000,65500})do for _,view in ipairs({{0,0},{0,0.7},{0,-1.1},{1.2,0.6},{-2.3,-0.4}})do
  creative=enabled;now=1000000;sample=0;captured={}
  local p,get=make(0,multishot,piercing,kind,before,view[1],view[2])
  local original=get();if unbreaking>0 then local ench=mcl_enchanting.get_enchantments(original);ench.unbreaking=unbreaking;mcl_enchanting.set_enchantments(original,ench);p:set_wielded_item(original)end
  callbacks.hold(p,'RMB');now=1400000;callbacks.hold(p,'RMB');now=2000000;callbacks.hold(p,'RMB');callbacks.release(p,'RMB')
  local loaded=get():get_name():find('loaded',1,true)~=nil
  callbacks.press(p,'LMB');local bow,ammo=get()
  local shots={};for _,shot in ipairs(captured)do shots[#shots+1]={velocity=shot.velocity,position=shot.position,acceleration=shot.acceleration,
   damage=shot.entity._damage,critical=shot.entity._is_critical,piercing=shot.entity._piercing,collectable=shot.entity._collectable}end
  result.shots[#result.shots+1]={ammo=kind,creative=creative,multishot=multishot,piercing=piercing,unbreaking=unbreaking,before=before,yaw=view[1],pitch=view[2],
   loaded=loaded,count=ammo:get_count(),wear=bow:get_wear(),bow_count=bow:get_count(),retained_arrow=bow:get_meta():get_string('arrow'),shots=shots}
 end end end end end end end
 debug.setupvalue(mcl_util.dist_triangular,1,rng)
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Crossbow fixture complete',false,0)
end)end)
'''

def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-crossbow-oracle-'))
    fixture = world/'worldmods'/'voxey_crossbow_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_crossbow_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31499\nserver_announce = false\nenable_ipv6 = false\nsecure.enable_security = false\n')
    (fixture/'mod.conf').write_text('name = voxey_crossbow_fixture\ndepends = mcl_bows, mcl_potions\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-500:]+'\n'+run.stderr[-3500:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT/'assets/data/crossbow_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print('Exported', len(result['loads']), 'loads and', len(result['shots']), 'firing cases')
    print('Plain wear:', next(r['wear'] for r in result['shots'] if r['ammo']=='regular' and not r['creative'] and not r['multishot'] and not r['unbreaking'] and not r['before']))

if __name__ == '__main__':
    export()
