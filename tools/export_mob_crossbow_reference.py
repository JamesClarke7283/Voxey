#!/usr/bin/env python3
"""Execute the installed mob crossbow state machine and pillager shot callbacks."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ENTITIES/mcl_mobs/combat.lua', 'mods/ENTITIES/mcl_mobs/items.lua',
         'mods/ENTITIES/mobs_mc/pillager.lua', 'mods/ITEMS/mcl_bows/crossbow.lua']
BODY = r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local class=mcl_mobs.mob_class
 local pillager=core.registered_entities['mobs_mc:pillager']
 local result={sequences={},shots={},wear={},samples={0.1,0.2,0.8,0.3,0.7,0.9}}
 local original_random=math.random;local roll=0;local unit=0
 math.random=function(a,b)if not a then return unit elseif not b then return math.min(a,math.max(1,roll))else return math.max(a,math.min(b,roll))end end
 local function actor(loaded,quick)
  local item=ItemStack(loaded and 'mcl_bows:crossbow_loaded' or 'mcl_bows:crossbow')
  if quick>0 then mcl_enchanting.set_enchantments(item,{quick_charge=quick})end
  local obj={is_player=function()return false end,get_pos=function()return vector.new(0,0,0)end}
  local a=setmetatable({object=obj,_wielditem=item:to_string(),ranged_attack_radius=20,pursuit_bonus=1,movement_speed=7,collisionbox=pillager.initial_properties.collisionbox,shoot_offset=0.5,_projectile_gravity=true},{__index=class})
  a.events={}
  a.set_wielditem=function(self,stack)self._wielditem=stack:to_string();self._using_wielditem=nil end
  a.cancel_navigation=function(self)self.events[#self.events+1]={'cancel'}end
  a.halt_in_tracks=function(self)self.events[#self.events+1]={'halt'}end
  a.look_at=function(self)self.events[#self.events+1]={'look'}end
  a.gopath=function(self,_,speed)self.events[#self.events+1]={'path',speed}end
  a.mob_controlling_movement=function(self)return self end
  a.set_animation=function()end
  a.discharge_ranged=function(self)self.events[#self.events+1]={'fire'}end
  return a
 end
 for _,loaded in ipairs({false,true})do for _,quick in ipairs({0,3})do for _,delay_roll in ipairs({0,20})do
 for _,scenario in ipairs({'clear','hidden','gap','far','approach','retreat'})do
  roll=delay_roll
  local a=actor(loaded,quick);local rows={};local dt=0.1
  for tick=1,65 do
   local visible=scenario~='hidden' and not(scenario=='gap' and tick>=20 and tick<=45)
   local distance=(scenario=='far' or scenario=='approach' and tick<15 or scenario=='retreat' and tick>=15)and 25 or 10
   a.events={};class.wielditem_step(a,dt)
   class.attack_crossbow(a,vector.new(0,0,0),vector.new(0,0,0),dt,vector.new(distance,0,0),visible)
   rows[#rows+1]={state=a._crossbow_state,visible=a._vistime,repath=a._time_to_next_repath,delay=a._shoot_delay,using=a._using_wielditem or -1,loaded=class.is_crossbow_loaded(a),events=a.events,distance=distance,sight=visible}
  end
  result.sequences[#result.sequences+1]={loaded=loaded,quick=quick,roll=delay_roll,scenario=scenario,dt=dt,rows=rows}
 end end end end
 core.sound_play=function()end
 local index=0;local _,rng=debug.getupvalue(mcl_util.dist_triangular,1)
 debug.setupvalue(mcl_util.dist_triangular,1,{next=function()index=index%6+1;return math.floor(result.samples[index]*2147483647)end})
 local projectiles
 core.add_entity=function(pos)
  local le={player=''};local row={position={pos.x,pos.y,pos.z},entity=le};projectiles[#projectiles+1]=row
  return{get_pos=function()return pos end,get_luaentity=function()return le end,set_velocity=function(_,v)row.velocity={v.x,v.y,v.z}end,set_acceleration=function()end,set_yaw=function()end}
 end
 for difficulty=1,3 do for _,multi in ipairs({0,1})do for _,piercing in ipairs({0,4})do
 for _,target in ipairs({{10,0,0},{0,5,-15},{-12,-3,7},{0,0,-30},{0,10,-1}})do
  mcl_vars.difficulty=difficulty;index=0;projectiles={}
  local a=actor(false,0);local item=ItemStack(a._wielditem);local ench={}
  if multi>0 then ench.multishot=multi end;if piercing>0 then ench.piercing=piercing end
  mcl_enchanting.set_enchantments(item,ench);a._wielditem=item:to_string()
  a.get_yaw=function()return 0.7 end;a.mob_sound=function()end
  a.shoot_arrow=pillager.shoot_arrow
  class.discharge_ranged(a,vector.new(0,0,0),vector.new(target[1],target[2],target[3]))
  local shots={};for _,p in ipairs(projectiles)do shots[#shots+1]={position=p.position,velocity=p.velocity,damage=p.entity._damage,critical=p.entity._is_critical,piercing=p.entity._piercing,collectable=p.entity._collectable}end
  result.shots[#result.shots+1]={difficulty=difficulty,multishot=multi,piercing=piercing,target=target,yaw=0.7,shots=shots}
 end end end end
 for level=0,3 do for _,maxroll in ipairs({0,1,50,100,300,1000})do
  roll=maxroll
  local item=ItemStack('mcl_bows:crossbow');if level>0 then mcl_enchanting.set_enchantments(item,{unbreaking=level})end
  local a=actor(false,0);class.scale_durability_for_drop(a,item,0.085)
  result.wear[#result.wear+1]={level=level,roll=maxroll,wear=item:get_wear(),uses=mcl_util.calculate_durability(item)}
 end end
 debug.setupvalue(mcl_util.dist_triangular,1,rng);math.random=original_random
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Mob crossbow reference complete',false,0)
end)end)
'''

def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-mob-crossbow-'))
    fixture = world/'worldmods'/'voxey_mob_crossbow_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_mob_crossbow_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31501\nserver_announce = false\nenable_ipv6 = false\nsecure.enable_security = false\n')
    (fixture/'mod.conf').write_text('name = voxey_mob_crossbow_fixture\ndepends = mobs_mc, mcl_bows\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'oracle.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists(): raise RuntimeError(str(world)+'\n'+run.stderr[-3500:])
    result=json.loads((world/'oracle.json').read_text())
    result['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT/'assets/data/mob_crossbow_reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('Exported',len(result['sequences']),'AI sequences,',len(result['shots']),'shots and',len(result['wear']),'wear cases')

if __name__=='__main__': export()
