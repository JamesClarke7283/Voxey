#!/usr/bin/env python3
"""Run source targeting and POI heat propagation, retaining callback results."""
import hashlib,json,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
FILES=['mods/ENTITIES/mcl_mobs/combat.lua','mods/ENTITIES/mcl_mobs/api.lua','mods/ENTITIES/mobs_mc/zombie.lua','mods/ENTITIES/mobs_mc/piglin.lua','mods/ENTITIES/mobs_mc/drowned.lua','mods/ITEMS/mcl_armor/api.lua','mods/MAPGEN/mcl_villages/pois.lua']
def local_fn(name):
 s=(SOURCE/FILES[-1]).read_text();m=re.search(r'local function '+name+r' \([^\n]*\)\n.*?\nend',s,re.S)
 return m[0]
BODY=r'''
local stream=1
local function random(a,b)stream=(stream*1664525+1013904223)%4294967296;if not a then return stream/4294967295 end;if not b then b=a;a=1 end;return a+stream%(b-a+1)end
local function hashpos(x,y,z)return x..','..y..','..z end
local floor=math.floor
local poi_heat={};local poi_insertion_pdl={};local MAX_HEAT=6
local directions={};for x=-1,1 do for y=-1,1 do for z=-1,1 do if x~=0 or y~=0 or z~=0 then directions[#directions+1]={x,y,z}end end end end
HEAT_FUNCTIONS
core.register_on_mods_loaded(function()core.after(0,function()
 local class=mcl_mobs.mob_class;local out={tracking={},alerts={},retaliation={},heat={},pacing={},detection={}}
 local function object(pos)
  return {get_pos=function()return pos end,get_attach=function()return nil end,is_valid=function()return true end,is_player=function()return true end,get_hp=function()return 20 end,get_luaentity=function()return nil end}
 end
 local target=object(vector.zero())
 local old_invisible=mcl_potions.get_effect;local old_coverage=mcl_armor.get_armor_coverage;local old_head=mcl_armor.get_headpiece_factor
 for _,invisible in ipairs({false,true})do for pieces=0,4 do for _,head in ipairs({0.5,1})do
  mcl_potions.get_effect=function()return invisible end;mcl_armor.get_armor_coverage=function()return pieces/4 end;mcl_armor.get_headpiece_factor=function()return head end
  out.detection[#out.detection+1]={invisible=invisible,pieces=pieces,head=head,value=class.detection_multiplier_for_object({},target)}
 end end end
 mcl_potions.get_effect=old_invisible;mcl_armor.get_armor_coverage=old_coverage;mcl_armor.get_headpiece_factor=old_head
 for _,persist in ipairs({3,15})do for _,dt in ipairs({0.05,0.5,1})do for _,distance in ipairs({0,35,35.001})do
  local a={test_object_and_restriction=function()return true end,target_visible=function()return false end}
  for i=1,math.ceil((persist+2)/dt)do
   local result=class.track_current_target(a,vector.new(distance,0,0),dt,target,35*35,persist)
   out.tracking[#out.tracking+1]={persist=persist,dt=dt,distance=distance,step=i,active=result~=nil,timer=a.target_invisible_time or false}
  end
 end end end
 local alert=mcl_mobs.build_alert_receiver_rule()
 for _,distance in ipairs({0,35,60,71.999,72,72.001})do for _,allowed in ipairs({false,true})do
  local a={tracking_distance=35,test_object_and_restriction=function()return allowed end,target_visible=function()return true end,_alert_receiver_target=target,track_current_target=class.track_current_target}
  local pos=vector.new(distance,0,0);local result=alert(a,pos,0.5,nil,false)
  out.alerts[#out.alerts+1]={distance=distance,allowed=allowed,current=false,active=result~=nil,time=a._alert_receiver_time or false}
  for i=1,44 do
   if not a._alert_receiver_time then break end
   result=alert(a,pos,0.5,target,true)
   out.alerts[#out.alerts+1]={distance=distance,allowed=allowed,current=true,step=i,active=result~=nil,time=a._alert_receiver_time}
  end
 end end
 local retaliation=mcl_mobs.build_retaliation_target_rule(nil,true,{'mobs_mc:zombie'})
 for _,distance in ipairs({0,34.999,35,36})do for _,allowed in ipairs({false,true})do for _,owner in ipairs({false,true})do
  local sent=0;local ally={is_valid=function()return true end,is_player=function()return false end,get_luaentity=function()return {name='mobs_mc:zombie',receive_attack=function()sent=sent+1 end}end}
  local a={object=object(vector.new(100,0,0)),tracking_distance=35,view_range=35,_last_attack_id=1,_last_attacker=target,
   read_last_attacker=class.read_last_attacker,test_object_and_restriction=function()return allowed end,target_owner_p=function()return owner end,
   objects_for_targeting=function()return {ally}end,broadcast_attack=class.broadcast_attack}
  local result=retaliation(a,vector.new(distance,0,0),0.1,nil,false)
  out.retaliation[#out.retaliation+1]={distance=distance,allowed=allowed,owner=owner,active=result~=nil,sent=sent,recorded=a._last_recorded_attack_id}
 end end end
 for scenario=1,3 do
  poi_heat={};poi_insertion_pdl={}
  local sources= scenario==1 and {{0,0,0}} or scenario==2 and {{-17,-16,15},{48,32,-32}} or {{0,0,0},{0,0,0},{0,96,0}}
  for _,p in ipairs(sources)do local section=section_position(vector.new(unpack(p)));local node=get_poi_section(section.x,section.y,section.z);node.heat=6;push(poi_insertion_pdl,node)end
  propagate_poi_heat(-1)
  stream=29
  for i=1,500 do
   local p=vector.new(random(-120,120),random(-120,120),random(-120,120));local section=section_position(p)
   local value=poi_heat[hashpos(section.x,section.y,section.z)]
   out.heat[#out.heat+1]={sources=sources,pos={p.x,p.y,p.z},value=value and value.heat or 0}
  end
 end
 local old_heat=mcl_villages.get_poi_heat;local old_random=math.random
 poi_heat={};poi_insertion_pdl={}
 local center=get_poi_section(0,0,0);center.heat=6;push(poi_insertion_pdl,center);propagate_poi_heat(-1)
 for seed=1,60 do
  local points={{0,0,0},{6,0,6},{12,0,0}};local ids={}
  for _,p in ipairs(points)do ids[#ids+1]=mcl_villages.insert_poi(vector.new(unpack(p)),'mcl_villages:demo_poi')end
  for _,heated in ipairs({false,true})do for _,visited in ipairs({{},{{0,0,0}},{{0,0,0},{6,0,6}}})do
   stream=seed;math.random=random;mcl_villages.get_poi_heat=function(p)if not heated then return 0 end;local c=section_position(p);local v=poi_heat[hashpos(c.x,c.y,c.z)];return v and v.heat or 0 end
   local a=setmetatable({_visited_pois={}}, {__index=core.registered_entities['mobs_mc:zombie']})
   for _,p in ipairs(visited)do a._visited_pois[#a._visited_pois+1]=vector.new(unpack(p))end
   local result=a:poi_pacing_target(vector.zero(),15,7)
   out.pacing[#out.pacing+1]={seed=seed,heated=heated,visited=visited,points=points,result=result and result[2] and {result[2].x,result[2].y,result[2].z} or false,state=stream}
  end
  end
  for _,id in ipairs(ids)do mcl_villages.remove_poi(id)end
 end
 mcl_villages.get_poi_heat=old_heat;math.random=old_random
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Targeting oracle complete',false,0)
end)end)
'''
def export():
 world=Path(tempfile.mkdtemp(prefix='voxey-zombie-target-'));mod=world/'worldmods/zombie_target_fixture';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31507\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = zombie_target_fixture\ndepends = mobs_mc\n')
 funcs='\n'.join(local_fn(n) for n in ['get_poi_section','pop','push','propagate_poi_heat','section_position'])
 (mod/'init.lua').write_text(BODY.replace('HEAT_FUNCTIONS',funcs))
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
 if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3500:])
 data=json.loads((world/'oracle.json').read_text());data['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in FILES}
 (ROOT/'assets/data/zombie_target_reference.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
 print({k:len(v) for k,v in data.items()})
if __name__=='__main__':export()
