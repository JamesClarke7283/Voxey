#!/usr/bin/env python3
"""Execute Mineclonia baby/jockey rules in a temporary real Luanti world."""
import hashlib,json,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
PATHS=['mods/ENTITIES/mobs_mc/zombie.lua','mods/ENTITIES/mobs_mc/drowned.lua','mods/ENTITIES/mobs_mc/villager_zombie.lua','mods/ENTITIES/mobs_mc/chicken.lua','mods/ENTITIES/mcl_mobs/breeding.lua','mods/ENTITIES/mcl_mobs/movement.lua','mods/ENTITIES/mcl_mobs/api.lua','mods/ENTITIES/mobs_mc/villager.lua']
def method(file,name,new):
 s=(SOURCE/file).read_text();m=re.search(r'function '+re.escape(name)+r'\s*\(([^\n]*)\)\n(.*?)\nend',s,re.S)
 if not m:raise RuntimeError(name)
 return 'local function '+new+'(self,'+m[1]+')\n'+m[2]+'\nend\n'
BODY=r'''
local CHICKEN_ATTACHMENT_POS=vector.new(0,1.76,0)
local infection_coin=1;local pr={next=function()return infection_coin end}
ZOMBIE_TYPES_VALUE
FUNCTIONS_VALUE
core.register_on_mods_loaded(function()core.after(0,function()
 local out={registered={},spawns={},jockey={},chickens={},aging={},infections={}}
 for _,kind in ipairs({'zombie','baby_zombie','husk','baby_husk','drowned','baby_drowned','villager_zombie','chicken'})do
  local e=core.registered_entities['mobs_mc:'..kind]
  out.registered[kind]={child=e.child or false,box=e.initial_properties.collisionbox,visual=e.initial_properties.visual_size,xp=e.xp_min,speed=e.movement_speed,reach=e.reach,eye=e.head_eye_height}
 end
 for difficulty=1,3 do for coin=1,2 do for _,kind in ipairs({'zombie','baby_zombie','husk','baby_husk','drowned','baby_drowned','villager_zombie','spider'})do
  mcl_vars.difficulty=difficulty;infection_coin=coin;local infected=false
  infect_villager({relinquish_pois=function()end,replace_with=function()infected=true end,export_villager_data=function()return {}end},nil,{source={is_player=function()return false end},mob_name='mobs_mc:'..kind})
  out.infections[#out.infections+1]={difficulty=difficulty,coin=coin,kind=kind,result=infected}
 end end end
 local random=math.random;local add=core.add_entity
 for _,kind in ipairs({'zombie','husk','drowned'})do
  local fn=({zombie=spawn_zombie,husk=spawn_husk,drowned=spawn_drowned})[kind]
  for _,roll in ipairs({0,0.049999,0.05,0.5,0.999999})do for _,forced in ipairs({false,true})do
   math.random=function()return roll end;core.add_entity=function(_,name)return name end
   out.spawns[#out.spawns+1]={kind=kind,roll=roll,forced=forced,result=fn({},vector.zero(),1,forced and {_is_baby_zombie=true} or nil,4)}
  end end
 end
 core.add_entity=add
 for first=1,100 do for _,second in ipairs({1,5,6,100})do for _,found in ipairs({false,true})do
  local used=0;math.random=function()used=used+1;return used==1 and first or second end
  local object={get_luaentity=function()return {}end};local result='none'
  local actor={child=1,find_chicken=function()return found and object or nil end,
   jock_to_existing=function()result='existing';return object end,jock_to=function()result='new';return object end}
  jockey(actor)
  out.jockey[#out.jockey+1]={first=first,second=second,found=found,result=result,used=used}
 end end end
 local chicken=core.registered_entities['mobs_mc:chicken'];local old_add=core.add_item;local sound=core.sound_play
 core.sound_play=function()end
 for _,jock in ipairs({false,true})do for _,child in ipairs({false,true})do for _,timer in ipairs({0.05,1,300})do
  local eggs=0;core.add_item=function()eggs=eggs+1 end
  local actor={_is_chicken_jockey=jock,child=child,egg_timer=timer,object={get_pos=vector.zero},xp_min=1,xp_max=3}
  chicken.do_custom(actor,0.1)
  out.chickens[#out.chickens+1]={jockey=jock,child=child,timer=timer,eggs=eggs,remaining=actor.egg_timer or -1,xp=actor.xp_min}
 end end end
 core.add_item=old_add;core.sound_play=sound
 for _,age in ipairs({0,23999,24001})do
  local actor={child=1,_mob_age=age,_mob_breeding=0,grow_into_adult=function(self)self.grew=true end}
  mcl_mobs.mob_class.tick_breeding(actor,3600)
  out.aging[#out.aging+1]={age=age,result=actor._mob_age,grew=actor.grew or false}
 end
 math.random=random
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Baby oracle done',false,0)
end)end)
'''
def export():
 z=(SOURCE/PATHS[0]).read_text();jock=z[z.index('\tif not self._no_chicken_jockeys then'):z.index('\n\tself:zombie_post_spawn ()')]
 funcs='local function jockey(self)\n'+jock+'\nend\n'
 for file,name,new in [(PATHS[0],'zombie_spawner:spawn','spawn_zombie'),(PATHS[0],'husk_spawner:spawn','spawn_husk'),(PATHS[1],'drowned_spawner:spawn','spawn_drowned')]:funcs+=method(file,name,new)
 funcs+=method(PATHS[-1],'villager:on_die','infect_villager')
 types=re.search(r'local zombie_types = \{.*?\n\}',(SOURCE/PATHS[-1]).read_text(),re.S)[0]
 world=Path(tempfile.mkdtemp(prefix='voxey-baby-source-'));mod=world/'worldmods/voxey_baby_fixture';mod.mkdir(parents=True)
 (mod/'mod.conf').write_text('name = voxey_baby_fixture\ndepends = mobs_mc\n')
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31505\nenable_ipv6 = false\nserver_announce = false\n')
 (mod/'init.lua').write_text(BODY.replace('FUNCTIONS_VALUE',funcs).replace('ZOMBIE_TYPES_VALUE',types))
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
 if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3000:])
 data=json.loads((world/'oracle.json').read_text());data['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
 (ROOT/'assets/data/mob_baby_reference.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
 print({k:len(v) for k,v in data.items()})
if __name__=='__main__':export()
