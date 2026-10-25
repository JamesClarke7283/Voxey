#!/usr/bin/env python3
"""Run skeleton/stray bow AI and shooting in the user's installed Mineclonia."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ENTITIES/mcl_mobs/combat.lua', 'mods/ENTITIES/mcl_mobs/api.lua',
         'mods/ENTITIES/mcl_mobs/items.lua', 'mods/ENTITIES/mobs_mc/skeleton+stray.lua', 'mods/ENTITIES/mobs_mc/skeleton_wither.lua',
         'mods/ITEMS/mcl_bows/bow.lua', 'mods/ITEMS/mcl_bows/arrow.lua']
BODY = r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local class=mcl_mobs.mob_class
 local result={sequences={},shots={},kills={},wear={},registered={},samples={0.1,0.8,0.2,0.3,0.7,0.9,0.4,0.6}}
 local original_random=math.random;local roll=1;local unit=0
 math.random=function(a,b)if not a then return unit elseif not b then return math.min(a,math.max(1,roll))else return math.max(a,math.min(b,roll))end end
 for _,kind in ipairs({'skeleton','stray'})do
  local def=core.registered_entities['mobs_mc:'..kind]
  result.registered[kind]={collisionbox=def.initial_properties.collisionbox,range=def.view_range,tracking=def.tracking_distance,despawn=def.can_despawn,shoot_offset=def.shoot_offset}
 end
 local function actor(interval)
  local obj={is_player=function()return false end,get_pos=function()return vector.new(0,0,0)end}
  local target={get_properties=function()return{collisionbox={-0.3,0,-0.3,0.3,1.8,0.3}}end}
  local a=setmetatable({object=obj,attack=target,_wielditem='mcl_bows:bow',_timers={},_timers_fired={},shoot_offset=1.5,shoot_interval=interval,pursuit_bonus=1,movement_speed=5,movement_goal=''}, {__index=class})
  a.events={}
  a.cancel_navigation=function(self)self.events[#self.events+1]={'cancel'};self.waypoints=nil end
  a.halt_in_tracks=function(self)self.events[#self.events+1]={'halt'};self.movement_goal='' end
  a.look_at=function(self)self.events[#self.events+1]={'look'}end
  a.gopath=function(self,_,speed)self.events[#self.events+1]={'path',speed};self.waypoints={1};self.movement_goal='path' end
  a.mob_controlling_movement=function(self)return self end
  a.set_animation=function(self)self.events[#self.events+1]={'walk'}end
  a.use_wielditem=function(self)self._using_wielditem=0;self.events[#self.events+1]={'use'}end
  a.release_wielditem=function(self)self._using_wielditem=nil;self.events[#self.events+1]={'release'}end
  a.shoot_arrow=function(self)self.events[#self.events+1]={'fire'}end
  return a
 end
 for difficulty=1,3 do for _,unit_roll in ipairs({0,1})do for _,flip_roll in ipairs({1,10})do
 for _,scenario in ipairs({'clear','hidden','gap','near','far','retreat'})do
  unit=unit_roll;roll=flip_roll
  local a=actor(difficulty<3 and 2 or 1);local rows={};local dt=0.1
  for tick=1,80 do
   local visible=scenario~='hidden' and not(scenario=='gap' and tick>=15 and tick<=50)
   local distance=scenario=='near' and 6 or ((scenario=='far' or scenario=='retreat' and tick>=35)and 15 or 10)
   a.events={};class.update_timers(a,dt);class.wielditem_step(a,dt)
   class.attack_bowshoot(a,vector.new(0,0,0),vector.new(0,0,0),dt,vector.new(distance,0,0),visible)
   rows[#rows+1]={visible=a._target_visible_time,strafe=a._strafe_time,x=a._x_strafe,z=a._z_strafe,cooldown=a._shoot_timer,using=a._using_wielditem or -1,path_timer=a._timers.bowshoot_pathfind or 0,path_set=a._timers.bowshoot_pathfind~=nil,mode=a.movement_goal,events=a.events,distance=distance,sight=visible}
  end
  result.sequences[#result.sequences+1]={difficulty=difficulty,unit=unit_roll,roll=flip_roll,scenario=scenario,dt=dt,rows=rows}
 end end end end
 core.sound_play=function()end
 local index=0;local _,rng=debug.getupvalue(mcl_util.dist_triangular,1)
 debug.setupvalue(mcl_util.dist_triangular,1,{next=function()index=index%8+1;return math.floor(result.samples[index]*2147483647)end})
 local projectile
 core.add_entity=function(pos,name)
  local le={player=''};projectile={position={pos.x,pos.y,pos.z},entity=le,name=name,flame=false}
  return{get_pos=function()return pos end,get_luaentity=function()return le end,set_velocity=function(_,v)projectile.velocity={v.x,v.y,v.z}end,set_acceleration=function()end,set_yaw=function()end}
 end
 mcl_burning.set_on_fire=function()projectile.flame=true end
 for difficulty=1,3 do for _,kind in ipairs({'skeleton','stray'})do for _,power in ipairs({0,1,5})do
 for _,target in ipairs({{10,0,0,1.8},{0,5,-15,1.8},{-12,-3,7,2.69},{0,0,-30,1.99},{0,10,-1,0.8}})do
  mcl_vars.difficulty=difficulty;index=0
  local a=actor(2);local weapon=ItemStack('mcl_bows:bow');local ench={}
  if power>0 then ench.power=power;ench.punch=2;ench.flame=1 end
  mcl_enchanting.set_enchantments(weapon,ench);a._wielditem=weapon:to_string();a._using_wielditem=1.1
  a.get_yaw=function()return 0.7 end;a.shoot_arrow=core.registered_entities['mobs_mc:'..kind].shoot_arrow
  a.attack.get_properties=function()return{collisionbox={-0.3,0,-0.3,0.3,target[4],0.3}}end
  class.attack_bowshoot(a,vector.new(0,0,0),vector.new(0,0,0),0.1,vector.new(target[1],target[2],target[3]),true)
  result.shots[#result.shots+1]={difficulty=difficulty,kind=kind,power=power,target=target,position=projectile.position,velocity=projectile.velocity,damage=projectile.entity._damage,critical=projectile.entity._is_critical==true,collectable=projectile.entity._collectable==true,punch=projectile.entity._knockback,flame=projectile.flame,name=projectile.name}
 end end end end
 local awarded=false;awards.unlock=function()awarded=true end
 for _,kind in ipairs({'skeleton','stray','wither_skeleton'})do for _,reason in ipairs({'arrow','trident','punch'})do
 for _,distance in ipairs({0,20,20.001,50})do for _,player in ipairs({false,true})do
  awarded=false
  core.registered_entities['mobs_mc:'..(kind=='wither_skeleton' and 'witherskeleton' or kind)].on_die({},vector.new(0,0,0),{type=reason,source={is_player=function()return player end,get_player_name=function()return 'fixture' end,get_pos=function()return vector.new(distance,0,0)end}})
  result.kills[#result.kills+1]={kind=kind,reason=reason,distance=distance,player=player,awarded=awarded}
 end end end end
 for level=0,3 do for _,maxroll in ipairs({0,1,50,300,1000})do
  roll=maxroll;local item=ItemStack('mcl_bows:bow')
  if level>0 then mcl_enchanting.set_enchantments(item,{unbreaking=level})end
  class.scale_durability_for_drop({},item,0.085)
  result.wear[#result.wear+1]={level=level,roll=maxroll,wear=item:get_wear(),uses=mcl_util.calculate_durability(item)}
 end end
 debug.setupvalue(mcl_util.dist_triangular,1,rng);math.random=original_random
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Mob bow reference complete',false,0)
end)end)
'''


def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-mob-bow-'))
    fixture = world/'worldmods'/'voxey_mob_bow_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_mob_bow_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31502\nserver_announce = false\nenable_ipv6 = false\nsecure.enable_security = false\n')
    (fixture/'mod.conf').write_text('name = voxey_mob_bow_fixture\ndepends = mobs_mc, mcl_bows\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists():
        raise RuntimeError(str(world)+'\n'+run.stderr[-3500:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT/'assets/data/mob_bow_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print('Exported', len(result['sequences']), 'AI sequences and', len(result['shots']), 'shots')


if __name__ == '__main__':
    export()
