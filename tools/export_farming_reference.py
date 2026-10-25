#!/usr/bin/env python3
"""Exercise the installed farming and soil callbacks in a real Luanti registry."""
import hashlib, json, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
BODY = r'''
core.register_on_mods_loaded(function() core.after(0,function()
 local out={nodes={},growth={},hydration={},placement={},covered={},timers={},plants={}}
 local selected={'solid','plant','dirtifier','dirtifies_below_solid','soil','cultivatable','water'}
 for name,def in pairs(core.registered_nodes)do
  local groups={};for _,key in ipairs(selected)do groups[key]=core.get_item_group(name,key)end
  out.nodes[name]=groups
 end
 local hydration,covered
 for _,abm in ipairs(core.registered_abms)do
  if abm.label=='Farmland hydration'then hydration=abm.action;out.timers.hydration={interval=abm.interval,chance=abm.chance}end
  if abm.label=='Turn dirtifies_below_solid below solid block into Dirt'then covered=abm.action;out.timers.covered={interval=abm.interval,chance=abm.chance}end
 end
 assert(hydration and covered,'Missing soil ABMs')
 local placement={}
 for _,callback in ipairs(core.registered_on_placenodes)do
  local info=debug.getinfo(callback,'S')
  if info.source:find('/mcl_core/functions.lua',1,true) and info.linedefined>=300 and info.linedefined<324 then placement[#placement+1]=callback end
 end
 assert(#placement==2,'Expected both source dirtifier placement callbacks')
 local pos=vector.new(0,40,0);local nodes,metas={},{}
 local function key(p)return p.x..','..p.y..','..p.z end
 local function meta(p)
  local k=key(p);if not metas[k]then metas[k]={}end
  return {get_int=function(_,n)return math.floor(tonumber(metas[k][n])or 0)end,set_int=function(_,n,v)metas[k][n]=v end,get_string=function(_,n)return tostring(metas[k][n]or'')end,set_string=function(_,n,v)metas[k][n]=v end}
 end
 local function reset(name,fields)nodes={};metas={};nodes[key(pos)]={name=name};metas[key(pos)]=table.copy(fields or{})end
 core.get_meta=meta
 core.get_node=function(p)return table.copy(nodes[key(p)]or{name='air'})end
 core.get_node_or_nil=function(p)local n=core.get_node(p);if n.name~='ignore'then return n end end
 core.set_node=function(p,node)nodes[key(p)]=table.copy(node);metas[key(p)]={};local d=core.registered_nodes[node.name];if d and d.on_construct then d.on_construct(vector.new(p))end;return true end
 core.swap_node=function(p,node)nodes[key(p)]=table.copy(node);return true end
 local water,unknown,rain,outdoor
 core.find_nodes_in_area=function(a,b,names)
  assert(a.x==-4 and a.y==40 and a.z==-4 and b.x==4 and b.y==41 and b.z==4)
  return ((names[1]=='group:water'and water)or(names[1]=='ignore'and unknown))and{vector.new(4,41,4)}or{}
 end
 mcl_weather.is_outdoor=function()return outdoor end
 for _,name in ipairs({'mcl_farming:soil','mcl_farming:soil_wet'})do for wet=0,7 do for _,w in ipairs({false,true})do for _,u in ipairs({false,true})do for _,r in ipairs({false,true})do for _,o in ipairs({false,true})do for _,above in ipairs({'air','mcl_farming:wheat_1','mcl_core:stone','ignore','mcl_lush_caves:hanging_roots'})do
  reset(name,{wet=wet});nodes[key(vector.offset(pos,0,1,0))]={name=above};water=w;unknown=u;rain=r;outdoor=o;mcl_weather.rain.raining=r
  hydration(pos,{name=name})
  out.hydration[#out.hydration+1]={name=name,wet=wet,water=w,unknown=u,rain=r,outdoor=o,above=above,after=core.get_node(pos).name,after_wet=meta(pos):get_int('wet')}
 end end end end end end end
 local covers={'air','mcl_core:stone','mcl_core:glass','mcl_farming:soil','mcl_core:grass_path','mcl_composters:composter','mcl_chests:chest_small','mcl_hoppers:hopper','mcl_pistons:piston_pusher','mcl_stairs:slab_oak','mcl_farming:wheat_1','mcl_honey:honey_block'}
 for _,name in ipairs({'mcl_farming:soil','mcl_farming:soil_wet','mcl_core:grass_path'})do for _,above in ipairs(covers)do
  reset(name,{wet=5});nodes[key(vector.offset(pos,0,1,0))]={name=above};covered(pos)
  out.covered[#out.covered+1]={name=name,above=above,after=core.get_node(pos).name}
  for _,which in ipairs({'above','below'})do
   reset(name,{wet=5});local top=vector.offset(pos,0,1,0);nodes[key(top)]={name=above}
   local at=which=='above'and top or pos
   for _,callback in ipairs(placement)do callback(at,core.get_node(at))end
   out.placement[#out.placement+1]={name=name,above=above,which=which,after=core.get_node(pos).name}
  end
 end end
 local light,current,roll
 core.get_node_light=function()return light end
 core.get_day_count=function()return math.floor(current/1200)end
 core.get_timeofday=function()return current/1200-math.floor(current/1200)end
 core.settings:set('time_speed','72')
 local original_random=math.random
 math.random=function(a,b)assert(a==0 and b==9);return roll end
 for _,identifier in ipairs({'plant_wheat','plant_carrot','plant_potato','plant_beetroot'})do
  local def=mcl_farming.plant_lists[identifier];assert(def,identifier)
  out.plants[identifier]=table.copy(def)
  for _,name in ipairs(def.names)do for _,history in ipairs({{0,0,0},{1000,0,0},{1000,3,27},{1000,100,901},{1000,101,1001},{1000000,2,30}})do for _,time in ipairs({999.5,1000,1000.001,1750,6000,1000000.001})do for _,level in ipairs({0,9,10,15})do for _,ignore in ipairs({false,true})do for _,slow in ipairs({false,true})do for _,pick in ipairs({0,1})do
   reset(name,{last_gametime=tostring(history[1]),avg_light_count=history[2],avg_light_summary=history[3]});light=level;current=time;roll=pick
   local ret=mcl_farming:grow_plant(identifier,pos,{name=name,param2=3},1,ignore,slow)
   out.growth[#out.growth+1]={plant=identifier,name=name,time=(core.get_day_count()+core.get_timeofday())*1200,light=level,last=history[1],count=history[2],total=history[3],ignore=ignore,slow=slow,roll=pick,after=core.get_node(pos).name,result=ret==nil and'nil'or tostring(ret),meta=table.copy(metas[key(pos)])}
  end end end end end end end
 end
 math.random=original_random
 core.safe_file_write(core.get_worldpath()..'/farming.json',core.write_json(out));core.request_shutdown('Farming reference complete',false,0)
end)end)
'''
def main():
    world=Path(tempfile.mkdtemp(prefix='voxey-farming-oracle-'))
    mod=world/'worldmods/farming_oracle';mod.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
    (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31522\nserver_announce = false\nenable_ipv6 = false\n')
    (mod/'mod.conf').write_text('name = farming_oracle\ndepends = mcl_farming, mcl_core, mcl_weather\n')
    (mod/'init.lua').write_text(BODY)
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=240)
    if not (world/'farming.json').exists():raise RuntimeError(str(world)+'\n'+run.stdout[-4000:]+run.stderr[-4000:])
    result=json.loads((world/'farming.json').read_text())
    result['source_hashes']={str(p.relative_to(SOURCE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((SOURCE/'mods').rglob('*.lua'))}
    result['license']='GPL-3.0-or-later'
    (ROOT/'assets/data/farming_reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    runtime={key:result[key] for key in ['nodes','timers','plants','source_hashes','license']}
    (ROOT/'assets/data/farming.json').write_text(json.dumps(runtime,separators=(',',':'))+'\n')
    print(world)
    print({k:len(result[k]) for k in ['nodes','growth','hydration','covered','placement']})
if __name__=='__main__':main()
