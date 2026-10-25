#!/usr/bin/env python3
"""Execute Mineclonia zombie attribute, door and reinforcement callbacks."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
PATHS=['mods/ENTITIES/mobs_mc/zombie.lua','mods/ENTITIES/mcl_mobs/physics.lua','mods/ENTITIES/mcl_mobs/combat.lua','mods/ENTITIES/mcl_mobs/spawning.lua','mods/ENTITIES/mobs_mc/spawning.lua','mods/ENTITIES/mobs_mc/drowned.lua','mods/ENTITIES/mobs_mc/villager_zombie.lua']
BODY=r'''
local stream=1
local function random(a,b)
 stream=(stream*1664525+1013904223)%4294967296
 if not a then return stream/4294967295 end
 if not b then b=a;a=1 end
 return a+stream%(b-a+1)
end
core.register_on_mods_loaded(function()core.after(0,function()
 local zombie=core.registered_entities['mobs_mc:zombie'];local class=mcl_mobs.mob_class
 local old_random=math.random;math.random=random
 local out={traits={},doors={},reinforcements={}}
 local function actor()
  local props={hp_max=20};local obj={get_pos=function()return vector.zero()end,set_properties=function(_,v)for k,x in pairs(v)do props[k]=x end end,get_properties=function()return props end}
  local a=setmetatable({_physics_factors={},armor_list={head=''},object=obj,_no_chicken_jockeys=true,health=20,dead=false,removed=false},{__index=zombie})
  a.generate_default_equipment=function()end;a.set_armor_texture=function()end;a.set_animation=function(self,name)self._current_animation=name end
  return a,props
 end
 local special=mcl_worlds.get_special_difficulty;local halloween=mcl_util.is_halloween
 mcl_util.is_halloween=function()return false end
 for _,factor in ipairs({0,0.5,1})do for seed=1,100 do
  stream=seed;mcl_worlds.get_special_difficulty=function()return factor end
  local a,props=actor();a.generate_default_equipment=function()stream=seed end;zombie.on_spawn(a)
  out.traits[#out.traits+1]={factor=factor,seed=seed,state=stream,knockback=a.knockback_resistance,view=a.view_range/35-1,reinforcement=a._spawn_reinforcements_chance,health_bonus=a._zombie_health_bonus or 0,break_doors=a._can_break_doors,hp_max=props.hp_max,health=a.health}
 end end
 mcl_worlds.get_special_difficulty=special;mcl_util.is_halloween=halloween
 local old_ai=class.ai_step;class.ai_step=function()end
 local getnode=core.get_node;local group=core.get_item_group;local opened=mcl_doors.is_open;local protected=core.is_protected;local dig=core.dig_node;local sound=core.sound_play
 core.sound_play=function()end
 for _,x in ipairs({0,0.049,0.05,1.249,1.25,-1.249})do for _,y in ipairs({-0.5,0.99,1.0})do
 for _,velocity in ipairs({{0,0,0},{-2,0,0},{2,0,0},{0,0,2},{0,2,0}})do for _,kind in ipairs({'wood','iron','open','air'})do
 for _,time in ipairs({0,11.9,12.0})do for _,is_protected in ipairs({false,true})do
  local a=actor();a._can_break_doors=true;a._breaking_door=vector.zero();a._door_break_time=time;a._door_break_progress=math.floor(time/12*10);a._zombie_punch_animation_timeout=0
  a.object.get_pos=function()return vector.new(x,y,0)end;a._old_velocity=vector.new(unpack(velocity))
  core.get_node=function()return {name=kind}end;core.get_item_group=function(_,key)return key=='door' and kind~='air' and 1 or key=='door_iron' and kind=='iron' and 1 or 0 end
  mcl_doors.is_open=function()return kind=='open'end;core.is_protected=function()return is_protected end
  local dug=0;core.dig_node=function()dug=dug+1 end;math.random=function()return 20 end;mcl_vars.difficulty=3
  zombie.ai_step(a,0.1)
  out.doors[#out.doors+1]={x=x,y=y,velocity=velocity,kind=kind,time=time,protected=is_protected,active=a._breaking_door~=nil,elapsed=a._door_break_time or -1,stage=a._door_break_progress or -1,dug=dug}
 end end end end end end
 class.ai_step=old_ai;core.get_node=getnode;core.get_item_group=group;mcl_doors.is_open=opened;core.is_protected=protected;core.dig_node=dig;core.sound_play=sound
 local receive=class.receive_damage;class.receive_damage=function(self)return self.accept end
 local spawn=mcl_mobs.spawn_abnormally;local connected=mcl_util.connected_players
 mcl_util.connected_players=function()return function()return nil end end
 local source={is_player=function()return true end,get_luaentity=function()return nil end}
 for difficulty=1,3 do for _,chance in ipairs({0,0.2,1})do for _,sample in ipairs({0,0.199,0.2,0.9})do
 for _,accept in ipairs({false,true})do for _,pattern in ipairs({'none','all','alternate'})do
  stream=17;local once=false;math.random=function(a,b)if not a and not once then once=true;return sample end;return random(a,b)end
  local a=actor();a.accept=accept;a.attack=source;a:set_physics_factor_base('_spawn_reinforcements_chance',chance);a.can_spawn_reinforcements=function()return true end
  local attempts={};local children={}
  mcl_mobs.spawn_abnormally=function(p)
   attempts[#attempts+1]={p.x,p.y,p.z}
   if pattern=='none' or pattern=='alternate' and #attempts%2==0 then return nil end
   local c=actor();c:set_physics_factor_base('_spawn_reinforcements_chance',0.1);c.receive_attack=function()end;children[#children+1]=c
   return {get_luaentity=function()return c end}
  end
  mcl_vars.difficulty=difficulty;zombie.receive_damage(a,{source=source},1)
  local values={};for _,c in ipairs(children)do values[#values+1]=c._spawn_reinforcements_chance end
  out.reinforcements[#out.reinforcements+1]={difficulty=difficulty,chance=chance,sample=sample,accept=accept,pattern=pattern,attempts=attempts,caller=a._spawn_reinforcements_chance,children=values,state=stream}
 end end end end end
 class.receive_damage=receive;mcl_mobs.spawn_abnormally=spawn;mcl_util.connected_players=connected;math.random=old_random
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Zombie behavior complete',false,0)
end)end)
'''
def export():
 world=Path(tempfile.mkdtemp(prefix='voxey-zombie-source-'));mod=world/'worldmods/voxey_zombie_fixture';mod.mkdir(parents=True)
 (mod/'mod.conf').write_text('name = voxey_zombie_fixture\ndepends = mobs_mc\n')
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31506\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'init.lua').write_text(BODY)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
 if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-4000:])
 data=json.loads((world/'oracle.json').read_text());data['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
 (ROOT/'assets/data/zombie_behavior_reference.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
 print({k:len(v) for k,v in data.items()})
if __name__=='__main__':export()
