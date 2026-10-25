#!/usr/bin/env python3
"""Run Mineclonia's private-inventory sharing and courtship callbacks."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
FILES=['mods/ENTITIES/mobs_mc/villager.lua','mods/ENTITIES/mcl_mobs/items.lua','mods/ENTITIES/mcl_mobs/breeding.lua']
BODY=r'''
local names=NAMES;local ids={};for id,name in pairs(names)do ids[name]=tonumber(id)end
local stream=1
local function random(a,b)stream=(stream*1664525+1013904223)%4294967296;return a+stream%(b-a+1)end
core.register_on_mods_loaded(function()core.after(0,function()
 local v=core.registered_entities['mobs_mc:villager'];local class=mcl_mobs.mob_class;local out={food={},sharing={},reclaim={},courtship={}}
 local function snapshot(a)local out={};for _,s in ipairs(a._inventory)do local q=ItemStack(s);out[#out+1]={id=ids[q:get_name()] or 0,count=q:get_count()}end;return out end
 local function actor(rows,food,profession)
  local a=setmetatable({_food_level=food or 0,_profession=profession or 'farmer',_inventory={},_inventory_size=8,child=false,_sleeping=false},{__index=function(_,k)return v[k] or class[k]end})
  for i=1,8 do local row=rows[i]or{id=0,count=0};local st=ItemStack(names[tostring(row.id)]or'');st:set_count(row.count);a._inventory[i]=st:to_string()end
  a.object={get_pos=function()return vector.zero()end};return a
 end
 local choices={73,770,769,772,71,72}
 for seed=1,400 do
  stream=seed;local rows={};for i=1,8 do rows[i]={id=choices[random(1,#choices)],count=random(0,64)}end
  local level=random(-12,24);local a=actor(rows,level);local points=a:count_food_points();local possible=a:breeding_possible();local surplus=a:has_surplus_food();local needs=a:need_more_food()
  a:eat_before_breeding();local fed=a._food_level;local after=snapshot(a);a:digest_before_breeding()
  out.food[#out.food+1]={items=rows,level=level,points=points,possible=possible,surplus=surplus,needs=needs,fed=fed,digested=a._food_level,after=after}
 end
 for _,id in ipairs({73,770,769,772,71,72})do for _,count in ipairs({0,1,2,3,4,11,12,13,24,25,64})do for _,level in ipairs({-12,-1,0,1,11,12,13})do
  local rows={{id=id,count=count}};local a=actor(rows,level);local points=a:count_food_points();local possible=a:breeding_possible();local surplus=a:has_surplus_food();local needs=a:need_more_food()
  a:eat_before_breeding();local fed=a._food_level;local after=snapshot(a);a:digest_before_breeding()
  out.food[#out.food+1]={items=rows,level=level,points=points,possible=possible,surplus=surplus,needs=needs,fed=fed,digested=a._food_level,after=after}
 end end end
 mcl_mobs.effect=function()end
 for seed=1,240 do
  stream=seed;local rows={};for i=1,8 do rows[i]={id=choices[random(1,#choices)],count=random(0,64)}end
  local sender=seed%2==0 and 'farmer' or 'librarian';local receiver=seed%3==0 and 'farmer' or 'librarian';local target_rows={{id=73,count=seed%5}}
  local a=actor(rows,0,sender);local b=actor(target_rows,0,receiver);b.name='mobs_mc:villager';local target={get_pos=function()return vector.new(1,0,0)end,get_luaentity=function()return b end}
  local thrown={};core.add_item=function(_,s)local st=ItemStack(s);thrown[#thrown+1]={id=ids[st:get_name()]or 0,count=st:get_count()};return {get_luaentity=function()return {}end,set_velocity=function()end}end
  a.look_at=function()end;a._interaction_target=target;a._gossiping=true;a._gossip_trades=a:get_villager_trades(b);a.gossip_with=function()end;a.do_navigate=function()return false,nil,2 end
  a:gossip_and_trade(vector.zero(),0.1)
  out.sharing[#out.sharing+1]={items=rows,target_items=target_rows,sender=sender,receiver=receiver,thrown=thrown,after=snapshot(a),extra_count=#a._gossip_trades}
 end
 for _,same in ipairs({false,true})do for _,has_time in ipairs({false,true})do for _,now in ipairs({8,9,10,11,11.999,12,12.001,13,30})do
  local a=actor({},0);local removed=false;core.get_gametime=function()return now end
  local entity={_dropped_by_villager=same and a.object or {},_dropped_by_villager_gmt=has_time and 10 or nil}
  local object={get_luaentity=function()return entity end,remove=function()removed=true end};a:default_pickup(object,ItemStack('mcl_farming:bread'),{},'mcl_farming:bread')
  out.reclaim[#out.reclaim+1]={same=same,has_time=has_time,now=now,picked=removed}
 end end end
 core.get_gametime=function()return 100 end
 for _,timer in ipairs({-1,0,0.1,15})do for _,dt in ipairs({0.05,0.1,1})do for _,distance in ipairs({2.49,2.5,2.51})do for _,moving in ipairs({false,true})do for _,reciprocal in ipairs({false,true})do for _,bed in ipairs({false,true})do
  local a=actor({{id=73,count=4}},0);local b=actor({{id=73,count=4}},0);local b_object={get_pos=function()return vector.new(distance,0,0)end,get_luaentity=function()return b end}
  a._lovemaking=b_object;b._lovemaking=reciprocal and a.object or nil;a._birth_time=timer~=-1 and timer or nil
  a.navigation_finished=function()return true end;a.do_navigate=function()return moving,nil,distance end;a.cancel_navigation=function()end;a.halt_in_tracks=function()end;a.look_at=function()end
  a.run_sensor=function()return bed and {vector.zero()}or{}end;local births=0;a.conceive_child=function()births=births+1;return true end;a.angry_villager_effect=function()end;b.angry_villager_effect=function()end
  local result=a:make_love(vector.zero(),dt)
  out.courtship[#out.courtship+1]={timer=timer,dt=dt,distance=distance,moving=moving,reciprocal=reciprocal,bed=bed,result=result==true,active=a._lovemaking~=nil,after_timer=a._birth_time or -1,births=births,food=a._food_level,mate_food=b._food_level,after=snapshot(a),mate_after=snapshot(b)}
 end end end end end end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Social fixture complete',false,0)
end)end)
'''
def main():
 names={'73':'mcl_farming:bread','770':'mcl_farming:potato_item','769':'mcl_farming:carrot_item','772':'mcl_farming:beetroot_item','71':'mcl_farming:wheat_item','72':'mcl_farming:wheat_seeds'}
 world=Path(tempfile.mkdtemp(prefix='voxey-social-'));mod=world/'worldmods/social_fixture';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n');(world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31510\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = social_fixture\ndepends = mobs_mc\n');(mod/'init.lua').write_text(BODY.replace('NAMES',lua(names)))
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
 if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3000:])
 d=json.loads((world/'oracle.json').read_text());d['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in FILES}
 (ROOT/'assets/data/villager_social_reference.json').write_text(json.dumps(d,separators=(',',':'))+'\n');print({k:len(v) for k,v in d.items()})
if __name__=='__main__':main()
