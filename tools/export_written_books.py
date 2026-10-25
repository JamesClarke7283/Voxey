#!/usr/bin/env python3
"""Run the installed mcl_books copy, UTF-8 and signing callbacks in Luanti."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
PATHS=['mods/ITEMS/mcl_books/init.lua','mods/CORE/mcl_util/misc.lua','mods/ITEMS/mcl_hoppers/init.lua','mods/ITEMS/REDSTONE/mcl_dispensers/init.lua']
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local predict,craft,receive
 local cap=fixture_cap_text_length
 for _,fn in ipairs(core.registered_craft_predicts)do
  if debug.getinfo(fn,'S').source:find('/mcl_books/init.lua')then
   predict=fn
  end
 end
 for _,fn in ipairs(core.registered_on_crafts)do if debug.getinfo(fn,'S').source:find('/mcl_books/init.lua')then craft=fn end end
 for _,fn in ipairs(core.registered_on_player_receive_fields)do if debug.getinfo(fn,'S').source:find('/mcl_books/init.lua')then receive=fn end end
 assert(predict and craft and receive and cap,'source callbacks missing')
 local function stack(data,count)
  local s=ItemStack('mcl_books:written_book '..(count or 1));local m=s:get_meta()
  for k,v in pairs(data)do if type(v)=='number'then m:set_int(k,v)else m:set_string(k,v)end end
  return s
 end
 local function record(s)
  if s:is_empty()then return {id=0,count=0}end
  local m=s:get_meta()
  -- Luanti stores translator control sequences for the generated default title;
  -- compare the displayed English value in the native renderer.
  local data={title=core.get_translated_string('en',m:get_string('title')),text=m:get_string('text')}
  for _,k in ipairs({'author','name'})do local v=m:get_string(k);if v~=''then data[k=='name'and'custom_name'or k]=v end end
  for _,k in ipairs({'generation','date'})do if m:contains(k)then data[k]=m:get_int(k)end end
  return {id=s:get_name()=='mcl_books:written_book'and 264 or 263,count=s:get_count(),data=data}
 end
 local result={copies={},caps={},signs={},plain={}}
 local profiles={
  {title='Field notes',text='A chapter\nwith a second line.',author='Explorer',date=1700000000},
  {title='日本語の物語 🌍',text='éñø\n漢字\n🚀',author='名探検家',date=1700000001,name='A named original'},
  {title='',text='Unsigned author metadata',date=1699999999},
 }
 for profile,data in ipairs(profiles)do for _,generation in ipairs({-4,0,1,2,3,999})do for _,count in ipairs({1,4,16})do for copies=1,8 do for _,where in ipairs({1,5,9})do
  local input=table.copy(data);input.generation=generation
  local grid={};for i=1,9 do grid[i]=ItemStack('')end
  grid[where]=stack(input,count)
  local blanks=0;for i=1,9 do if i~=where and blanks<copies then grid[i]=ItemStack('mcl_books:writable_book');blanks=blanks+1 end end
  local inv={get_size=function()return 9 end,set_stack=function(_,_,i,s)grid[i]=ItemStack(s)end}
  local player={get_inventory=function()return inv end}
  local output=core.get_craft_result({method='normal',width=3,items=grid}).item
  output=predict(output,player,grid,inv)or output
  local final=record(output);local remaining={}
  if not output:is_empty()then
   local old={};for i=1,9 do old[i]=ItemStack(grid[i]);grid[i]:take_item()end
   craft(output,player,old,inv)
  end
  for i=1,9 do remaining[i]=grid[i]:get_count()end
  result.copies[#result.copies+1]={input=input,count=count,copies=copies,where=where-1,output=final,remaining=remaining}
 end end end end end
 local samples={'','ASCII',string.rep('x',63),string.rep('x',64),string.rep('x',65),string.rep('x',12801),string.rep('é',3000),string.rep('漢',3000),string.rep('🚀',3000),string.rep('a',5000)..string.rep('漢',3000)..string.rep('z',5000),string.rep('éa',2500),string.rep('é',3000),'12345678901234567890'..string.rep('漢',12)..'end',string.rep(' ',70)}
 for _,input in ipairs(samples)do for _,limit in ipairs({64,12800})do result.caps[#result.caps+1]={input=input,limit=limit,output=cap(input,limit)}end end
 local old_time=os.time;os.time=function()return 1700000123 end
 for _,title in ipairs({'','A signed book','   ',string.rep('x',70),string.rep('漢',15),'é and 🌍'})do
  local held=ItemStack('mcl_books:writable_book');held:get_meta():set_string('name','Draft label')
  local player={get_player_name=function()return 'The author'end,get_wielded_item=function()return ItemStack(held)end,set_wielded_item=function(_,s)held=ItemStack(s)end}
  local text='Notes\n'..string.rep('é',2400)
  receive(player,'mcl_books:writable_book',{text=text,ok=true})
  local draft=record(held)
  receive(player,'mcl_books:signing',{title=title,sign=true})
  result.signs[#result.signs+1]={title=title,text=text,draft=draft,output=record(held)}
 end
 os.time=old_time
 local p=vector.new(0,90,0);local h=vector.new(1,90,0);local lower=vector.new(0,89,0)
 core.load_area(vector.new(0,89,0),vector.new(1,90,0))
 core.set_node(p,{name='mcl_books:bookshelf'});core.registered_nodes['mcl_books:bookshelf'].on_construct(p)
 for _,pos in ipairs({h,lower})do core.set_node(pos,{name='mcl_hoppers:hopper'});core.get_meta(pos):get_inventory():set_size('main',5)end
 local def=core.registered_nodes['mcl_books:bookshelf'];local inv=core.get_meta(p):get_inventory();local hinv=core.get_meta(h):get_inventory();local linv=core.get_meta(lower):get_inventory()
 local player={get_player_name=function()return 'Reader'end}
 for _,item in ipairs({{'mcl_books:book',126},{'mcl_books:writable_book',263},{'mcl_books:written_book',264},{'mcl_enchanting:book_enchanted',791},{'mcl_core:stone',3},{'mcl_core:paper',125},{'mcl_books:bookshelf',43}})do for _,count in ipairs({1,16,64})do
  local stack=ItemStack(item[1]);stack:set_count(count)
  local row={id=item[2],count=count,put=def.allow_metadata_inventory_put(p,'main',1,stack,player),take=def.allow_metadata_inventory_take(p,'main',1,stack,player)}
  inv:set_list('main',{});hinv:set_list('main',{});linv:set_list('main',{})
  hinv:set_stack('main',1,stack);row.push=fixture_hopper_push(h,p);row.push_remaining=hinv:get_stack('main',1):get_count()
  fixture_activate_dropper(h,p,{x=-1,y=0,z=0},hinv,{stack=ItemStack(stack),stackpos=1});row.dropper_remaining=hinv:get_stack('main',1):get_count()
  inv:set_stack('main',1,stack);row.pull=fixture_hopper_pull(lower);row.pull_remaining=inv:get_stack('main',1):get_count()
  result.plain[#result.plain+1]=row
 end end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Books reference complete',false,0)
end)end)
'''

def export():
    world=Path(tempfile.mkdtemp(prefix='voxey-written-books-oracle-')); fixture=world/'worldmods'/'voxey_books_fixture';fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_books_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31495\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_books_fixture\ndepends = mcl_books, mcl_hoppers, mcl_dispensers\n')
    source=(SOURCE/PATHS[0]).read_text()
    start=source.index('local function cap_text_length')
    end=source.index('local function write(',start)
    cap=source[start:end].replace('local function cap_text_length','local function fixture_cap_text_length',1)
    hopper=(SOURCE/PATHS[2]).read_text()
    pull=hopper[hopper.index('local function hopper_pull('):hopper.index('-- Move an item from the hopper')].replace('local function hopper_pull','local function fixture_hopper_pull',1)
    push=hopper[hopper.index('local function hopper_push('):hopper.index('local function check_hopper_pull_from_mc')].replace('local function hopper_push','local function fixture_hopper_push',1)
    dispenser=(SOURCE/PATHS[3]).read_text()
    dropper=dispenser[dispenser.index('local function activate_dropper('):dispenser.index('local function activate_dispenser(')].replace('local function activate_dropper','local function fixture_activate_dropper',1)
    (fixture/'init.lua').write_text(cap+pull+push+dropper+BODY)
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'oracle.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stdout[-500:]+'\n'+run.stderr[-3000:])
    result=json.loads((world/'oracle.json').read_text());result['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest()for p in PATHS}
    (ROOT/'assets/data/written_books_reference.json').write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
    print('Exported',len(result['copies']),'copies,',len(result['caps']),'text limits,',len(result['signs']),'signatures and',len(result['plain']),'plain-shelf cases')
if __name__=='__main__':export()
