#!/usr/bin/env python3
"""Exercise Mineclonia's real chiseled-bookshelf callbacks and inventories."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ITEMS/mcl_books/chiseled_bookshelf.lua', 'mods/CORE/mcl_util/environment.lua']
BODY = r'''
core.register_on_mods_loaded(function() core.after(0,function()
 local pos=vector.new(0,100,0);core.load_area(vector.new(-16,80,-16),vector.new(16,112,16))
 local names={[0]='',[126]='mcl_books:book',[263]='mcl_books:writable_book',[264]='mcl_books:written_book',[791]='mcl_enchanting:book_enchanted',[3]='mcl_core:stone'}
 local ids={};for id,name in pairs(names)do ids[name]=id end
 local source='mcl_books:chiseled_bookshelf';local def=core.registered_nodes[source]
 local function stack(v)local s=ItemStack(names[v[1]]);s:set_count(v[2]);s:get_meta():set_string('name',v[3]or'');return s end
 local function record(s)return {ids[s:get_name()]or 0,s:get_count(),s:get_meta():get_string('name')}end
 local function stored(i)return {({126,263,264,791})[(i-1)%4+1],1,'Volume '..i}end
 local function reset(mask,face)
  core.set_node(pos,{name=source,param2=face});def.on_construct(pos)
  local inv=core.get_meta(pos):get_inventory()
  for i=1,6 do inv:set_stack('main',i,stack(bit.band(mask,bit.lshift(1,i-1))~=0 and stored(i)or{0,0,''}))end
  core.swap_node(pos,{name=source..(mask==0 and ''or'_'..string.format('%02x',mask)),param2=face})
  return inv
 end
 local function snapshot(inv)local b={};for i=1,6 do b[i]=record(inv:get_stack('main',i))end;return b end
 local drops,notifications={},0
 mcl_util.drop_item_stack=function(_,s)drops[#drops+1]=record(s)end
 mcl_redstone._notify_observer_neighbours=function()notifications=notifications+1 end
 mcl_redstone.update_comparators=function()end
 local point
 core.pointed_thing_to_face_pos=function()return point end
 local player={is_player=function()return true end,get_player_name=function()return 'Voxey fixture' end}
 local result={clicks={},hoppers={},insertions={}}
 for mask=0,63 do for face=0,3 do for i=1,6 do for mode=0,4 do
  local inv=reset(mask,face);local target=stored(i)
  local hand=mode==0 and {0,0,''}or mode==1 and {126,2,''}or mode==2 and {3,2,''}or{target[1],mode==3 and core.registered_items[names[target[1]]].stack_max or 1,target[3]}
  local u=((i-1)%3+0.5)/3;local v=i<=3 and 0.75 or 0.25
  local hit=face==0 and {u,v,0}or face==1 and {0,v,1-u}or face==2 and {1-u,v,1}or{1,v,u}
  point=vector.new(pos.x+hit[1]-0.5,pos.y+hit[2]-0.5,pos.z+hit[3]-0.5)
  local item=stack(hand);drops={};notifications=0
  local out=def.on_rightclick(pos,core.get_node(pos),player,item,{})or item
  result.clicks[#result.clicks+1]={mask=mask,face=face,hit=hit,input=hand,books=snapshot(inv),hand=record(out),drops=drops,last=core.get_meta(pos):get_float('last_slot_used'),notifications=notifications}
 end end end end
 local hopper=vector.new(0,99,0);core.set_node(hopper,{name='mcl_hoppers:hopper'});core.registered_nodes['mcl_hoppers:hopper'].on_construct(hopper)
 local dest=core.get_meta(hopper):get_inventory()
 for mask=0,63 do for mode=0,2 do
  local inv=reset(mask,0);for i=1,dest:get_size('main')do dest:set_stack('main',i,stack(mode==0 and {0,0,''}or{3,64,''}))end
  if mode==2 then dest:set_stack('main',1,stack({126,1,'Volume 1'}))end
  drops={};notifications=0
  local success=def._on_hopper_out(pos,hopper)
  local cargo={};for i=1,dest:get_size('main')do cargo[i]=record(dest:get_stack('main',i))end
  result.hoppers[#result.hoppers+1]={mask=mask,mode=mode,success=success or false,books=snapshot(inv),cargo=cargo,last=core.get_meta(pos):get_float('last_slot_used')}
 end end
 for mask=0,63 do for mode=0,4 do
  local inv=reset(mask,0);for i=1,dest:get_size('main')do dest:set_stack('main',i,stack({0,0,''}))end
  dest:set_stack('main',1,stack({3,2,''}))
  if mode<4 then dest:set_stack('main',2,stack({({126,263,264,791})[mode+1],1,'Incoming'}))end
  local success=def._on_hopper_in(hopper,pos)
  local cargo={};for i=1,dest:get_size('main')do cargo[i]=record(dest:get_stack('main',i))end
  result.insertions[#result.insertions+1]={mask=mask,mode=mode,success=success or false,books=snapshot(inv),cargo=cargo,last=core.get_meta(pos):get_float('last_slot_used')}
 end end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Bookshelf fixture complete',false,0)
end)end)
'''

def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-bookshelf-oracle-'))
    fixture = world/'worldmods'/'voxey_bookshelf_fixture'; fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_bookshelf_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31494\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_bookshelf_fixture\ndepends = mcl_books, mcl_hoppers, mcl_redstone\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'oracle.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists(): raise RuntimeError(str(world)+'\n'+run.stdout[-500:]+'\n'+run.stderr[-2500:])
    result=json.loads((world/'oracle.json').read_text())
    result['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest()for p in PATHS}
    (ROOT/'assets/data/bookshelf_reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('Exported',len(result['clicks']),'clicks,',len(result['hoppers']),'hopper extractions and',len(result['insertions']),'insertions')

if __name__=='__main__': export()
