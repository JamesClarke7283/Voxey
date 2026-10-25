#!/usr/bin/env python3
"""Exercise the installed villager field/fertilizer state machines in Luanti."""
import hashlib,json,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
PATHS=['mods/ENTITIES/mobs_mc/villager.lua','mods/ITEMS/mcl_farming/beetroot.lua','mods/ITEMS/mcl_farming/shared_functions.lua']
BODY=r'''
local stream=1;local r=1/2147483647
local function random(a,b)stream=(stream*1664525+1013904223)%4294967296;return a+stream%(b-a+1)end
local pr={next=function(_,a,b)return random(a,b)end}
DISPATCH_FUNCTIONS
core.register_on_mods_loaded(function()core.after(0,function()
 local out={farm={},fertilize={},seeds={},dispatch={}}
 local v=core.registered_entities['mobs_mc:villager'];local class=mcl_mobs.mob_class;local pos=vector.zero();local target=vector.zero()
 local actions=0;core.get_node=function()return {name='mcl_farming:wheat'}end;core.is_protected=function()return false end
 core.dig_node=function()actions=actions+1 end
 for _,active in ipairs({false,true})do for _,current in ipairs({false,true})do for _,elapsed in ipairs({0,9.9,10,10.1})do
 for _,cooldown in ipairs({-0.1,0,0.1})do for _,sensor in ipairs({false,true})do for _,queued in ipairs({false,true})do for _,moving in ipairs({false,true})do for _,distance in ipairs({1.74,1.75})do
  if active or not current then
   local a={_farming=active and (queued and {target} or {}) or false,_target_farmland=current and target or nil,_farmed_for=elapsed,_farming_cooldown=cooldown,_profession='farmer',_job_site=pos}
   a.run_sensor=function()return sensor and {target} or {}end;a.do_navigate=function()return moving,nil,distance end
   actions=0;local result=v.farm(a,pos,0.1)
   out.farm[#out.farm+1]={active=active,current=current,elapsed=elapsed,cooldown=cooldown,sensor=sensor,queued=queued,moving=moving,distance=distance,result=result and true or false,after_active=a._farming and true or false,after_target=a._target_farmland~=nil,after_elapsed=a._farmed_for,after_cooldown=a._farming_cooldown,after_queue=type(a._farming)=='table' and #a._farming or 0,actions=actions}
  end
 end end end end end end end end
 local old_bone=core.registered_nodes['mcl_farming:wheat_1']._on_bone_meal
 core.get_node=function()return {name='mcl_farming:wheat_1'}end;mcl_bone_meal.add_bone_meal_particle=function()end
 for _,active in ipairs({false,true})do for _,current in ipairs({false,true})do for _,elapsed in ipairs({0,3.8,3.9,4})do
 for _,cooldown in ipairs({-0.1,0,0.2})do for _,sensor in ipairs({false,true})do for _,moving in ipairs({false,true})do for _,distance in ipairs({1.5,1.501})do for _,success in ipairs({false,true})do
  if active or not current then
   local a=setmetatable({_fertilizing_farmland=active,_fertilize_farmland=current and target or nil,_fertilizing_for=elapsed,_fertilize_cooldown=cooldown,_profession='farmer',_inventory_size=8,_inventory={'mcl_bone_meal:bone_meal 3'}},{__index=class})
   a.run_sensor=function()return sensor and target or nil end;a.do_navigate=function()return moving,nil,distance end;a.check_timer=function()return true end
   actions=0;core.registered_nodes['mcl_farming:wheat_1']._on_bone_meal=function()actions=actions+1;return success end
   local result=v.fertilize_farmland(a,pos,0.1)
   out.fertilize[#out.fertilize+1]={active=active,current=current,elapsed=elapsed,cooldown=cooldown,sensor=sensor,moving=moving,distance=distance,success=success,result=result and true or false,after_active=a._fertilizing_farmland and true or false,after_target=a._fertilize_farmland~=nil,after_elapsed=a._fertilizing_for,after_cooldown=a._fertilize_cooldown,actions=actions,meal=ItemStack(a._inventory[1]):get_count()}
  end
 end end end end end end end end
 core.registered_nodes['mcl_farming:wheat_1']._on_bone_meal=old_bone
 local seednames={'mcl_farming:wheat_seeds','mcl_farming:potato_item','mcl_farming:carrot_item','mcl_farming:beetroot_seeds','mcl_farming:bread','mcl_core:stone'}
 for first=1,6 do for second=1,6 do for _,count in ipairs({1,2,64})do
  local a={_inventory={seednames[first]..' '..count,seednames[second]..' '..count}};local result=v.get_farmable_seed(a)
  out.seeds[#out.seeds+1]={first=first,second=second,count=count,result=result and result:get_name() or '',left={ItemStack(a._inventory[1]):get_count(),ItemStack(a._inventory[2]):get_count()}}
 end end end
 for seed=1,100 do stream=seed;local result=evaluate_dispatch({{2,'pace'},{5,'move'},{2,'farm'},{4,'fertilize'},{5,'visit'},{7,'work'}});local order={};for _,x in ipairs(result)do order[#order+1]=x[2]end;out.dispatch[#out.dispatch+1]={seed=seed,order=order,state=stream}end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Farmer field fixture complete',false,0)
end)end)
'''
def main():
 src=(SOURCE/PATHS[0]).read_text();fns='\n'.join(re.search(r'local function '+n+r' \([^\n]*\)\n.*?\nend',src,re.S)[0] for n in ['evaluate_one_dispatch','evaluate_dispatch'])
 world=Path(tempfile.mkdtemp(prefix='voxey-farmer-fields-'));mod=world/'worldmods/farmer_fields_fixture';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31509\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = farmer_fields_fixture\ndepends = mobs_mc\n');(mod/'init.lua').write_text(BODY.replace('DISPATCH_FUNCTIONS',fns))
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
 if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3000:])
 d=json.loads((world/'oracle.json').read_text());d['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
 (ROOT/'assets/data/farmer_fields_reference.json').write_text(json.dumps(d,separators=(',',':'))+'\n');print({k:len(v) for k,v in d.items()})
if __name__=='__main__':main()
