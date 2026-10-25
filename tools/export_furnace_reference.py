#!/usr/bin/env python3
"""Load Mineclonia's cooking registry and exercise its actual furnace timer."""
import argparse, hashlib, json, subprocess, tempfile
from pathlib import Path
from export_enchanting_reference import lua

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local out={items={},bindings={},aliases=core.registered_aliases}
 local ref={timers={},permissions={},sorters={},clocks={}}
 local banner_colors={'white','grey','silver','black','yellow','orange','red','magenta','purple','blue','cyan','lime','green','pink','light_blue','brown'}
 for i,color in ipairs(banner_colors)do if BINDINGS[tostring(634+i)]then BINDINGS[tostring(634+i)]='mcl_banners:banner_item_'..color end end
 local bound={};for id,name in pairs(BINDINGS)do
  -- Native door items also represent their placed bottom node. Fuel uses the
  -- source inventory item, whose registration is separate from that node.
  if name:sub(-4)=='_b_1' and core.registered_items[name:sub(1,-5)]then name=name:sub(1,-5)end
  if tonumber(id)~=0 and core.registered_items[name]then out.bindings[id]=name;bound[name]=true end
 end
 local function item(s)return {name=s:get_name(),count=s:get_count(),wear=s:get_wear()}end
 for name,d in pairs(core.registered_items)do
  local st=ItemStack(name)
  local cooked,after=core.get_craft_result({method='cooking',width=1,items={st}})
  local fuel,burned=core.get_craft_result({method='fuel',width=1,items={st}})
  if bound[name]or cooked.time>0 or fuel.time>0 then
   out.items[name]={tool=d.type=='tool',stack=d.stack_max or 99,cook={time=cooked.time,item=item(cooked.item),after=item(after.items[1])},fuel={time=fuel.time,after=item(burned.items[1])},blast=core.get_item_group(name,'blast_furnace_smeltable')>0,smoker=core.get_item_group(name,'smoker_cookable')>0}
  end
 end
 local pos=vector.new(0,40,0);core.get_voxel_manip():read_from_map(vector.subtract(pos,16),vector.add(pos,16))
 local devices={'mcl_furnaces:furnace','mcl_blast_furnace:blast_furnace','mcl_smoker:smoker'}
 local player={get_player_name=function()return 'furnace_oracle'end}
 core.is_protected=function()return false end;core.sound_play=function()end
 local original_delta=mcl_furnaces.furnace_get_delta_time
 mcl_furnaces.furnace_get_delta_time=function(p,elapsed)return core.get_meta(p),elapsed end
 local function setup(device,initial)
  core.set_node(pos,{name=device})
  local meta=core.get_meta(pos);local inv=meta:get_inventory()
  for i,list in ipairs({'src','fuel','dst'})do inv:set_stack(list,1,ItemStack((initial.slots or{})[i]or''))end
  meta:set_float('src_time',initial.progress or 0);meta:set_float('fuel_time',initial.used or 0);meta:set_float('fuel_totaltime',initial.total or 0);meta:set_string('src_item',initial.input or'');meta:set_int('xp',initial.xp or 0)
  return meta,inv
 end
 local function snapshot(meta,inv,active)
  return {slots={item(inv:get_stack('src',1)),item(inv:get_stack('fuel',1)),item(inv:get_stack('dst',1))},used=meta:get_float('fuel_time'),total=meta:get_float('fuel_totaltime'),progress=meta:get_float('src_time'),input=meta:get_string('src_item'),xp=meta:get_int('xp'),active=active}
 end
 local function run(device,initial,steps,label)
  local meta,inv=setup(device,initial);local timer=core.registered_nodes[device].on_timer
  local row={device=device,initial=initial,steps=steps,label=label,frames={}}
  for _,step in ipairs(steps)do
   if type(step)=='table'then
    for i,list in ipairs({'src','fuel','dst'})do if step[i]then inv:set_stack(list,1,ItemStack(step[i]))end end
   else row.frames[#row.frames+1]=snapshot(meta,inv,timer(pos,step))end
  end
  ref.timers[#ref.timers+1]=row
 end
 local cooks={};for name in pairs(bound)do if out.items[name].cook.time>0 then cooks[#cooks+1]=name end end;table.sort(cooks)
 for _,device in ipairs(devices)do
  for _,name in ipairs(cooks)do run(device,{slots={name..' 2','mcl_core:coal_lump 8',''}},{.25,.75,1,8,1,20},name)end
  for _,count in ipairs({0,63,64})do for _,fuel in ipairs({'','mcl_core:stick 2','mcl_core:coal_lump','mcl_buckets:bucket_lava'})do
   run(device,{slots={'mcl_raw_ores:raw_iron 3',fuel,count>0 and 'mcl_core:iron_ingot '..count or''}},{1,1,3,5,10,20},'output and fuel boundaries')
  end end
  run(device,{slots={'mcl_core:cobble 2','mcl_core:coal_lump','mcl_core:dirt'},progress=3,input='mcl_core:cobble',total=8,used=2},{1,{false,false,''},1,8,1},'blocked output retains progress')
  run(device,{slots={'mcl_core:cobble 3','mcl_core:coal_lump',''}},{3,{'mcl_core:sand 2'},1,8,1},'new source resets progress')
  run(device,{slots={'mcl_raw_ores:raw_iron 3','',''},progress=4,input='mcl_raw_ores:raw_iron',total=1,used=.75},{.5,1,{false,'mcl_core:coal_lump'},1,10},'exhaustion clears progress')
  run(device,{slots={'mcl_sponges:sponge_wet','mcl_buckets:bucket_empty',''},total=30},{1,9,1},'sponge water replacement')
  run(device,{slots={'mcl_sponges:sponge_wet_river_water','mcl_buckets:bucket_empty',''},total=30},{1,9,1},'river sponge replacement')
  run(device,{slots={'','mcl_core:coal_lump',''},total=10,used=3},{1,1,12,1},'empty source still burns')
  run(device,{slots={'mcl_core:cobble 3','mcl_core:coal_lump 2',''},progress=9.5,input='mcl_core:cobble',total=80,used=4},{.25,.25,.5,40},'fractional completion and multiple results')
  for id,name in pairs(out.bindings)do
   for _,occupied in ipairs({false,true})do
    local meta,inv=setup(device,{slots={'',occupied and 'mcl_core:coal_lump'or'',''}})
    local values={};for i,list in ipairs({'src','fuel','dst'})do values[i]=mcl_furnaces.allow_metadata_inventory_put(pos,list,1,ItemStack(name..' 3'),player)end
    ref.permissions[#ref.permissions+1]={id=tonumber(id),occupied=occupied,device=device,values=values}
   end
  end
  for _,name in ipairs({'mcl_core:coal_lump','mcl_core:tree','mcl_trees:tree_oak','mcl_core:stick','mcl_raw_ores:raw_iron','mcl_core:stone','mcl_buckets:bucket_empty','mcl_buckets:bucket_lava','mcl_mobitems:beef','mcl_sponges:sponge_wet'})do
   for _,full in ipairs({false,true})do
    local initial={slots={full and 'mcl_core:cobble 64'or'','',''}}
    local meta,inv=setup(device,initial);local stack=ItemStack(name..' 3')
    local allowed=mcl_furnaces.allow_metadata_inventory_put(pos,'sorter',1,stack,player)
    if allowed>0 then stack:set_count(allowed);inv:set_stack('sorter',1,stack);mcl_furnaces.on_metadata_inventory_put(pos,'sorter',1,stack,player)end
    ref.sorters[#ref.sorters+1]={device=device,initial=initial,name=name,allowed=allowed,slots=snapshot(meta,inv,false).slots}
   end
  end
 end
 local old_day,old_time=core.get_day_count,core.get_timeofday
 local now=100
 core.get_day_count=function()return math.floor(now/1200)end;core.get_timeofday=function()return (now%1200)/1200 end
 for _,initial in ipairs({0,1,98.5,100,101.5,105})do for _,reset in ipairs({false,true})do
  local meta=core.get_meta(pos);meta:set_string('last_gametime',tostring(initial));local row={initial=initial,reset=reset,frames={}}
  for _,clock in ipairs({100,100,100.5,99,130,130,2500})do
   now=clock;local elapsed
   if reset then mcl_furnaces.furnace_reset_delta_time(pos)else local _;_,elapsed=original_delta(pos,.25)end
   row.frames[#row.frames+1]={clock=clock,elapsed=elapsed or 0,last=tonumber(meta:get_string('last_gametime'))or 0}
  end
  ref.clocks[#ref.clocks+1]=row
 end end
 core.get_day_count,core.get_timeofday=old_day,old_time
 core.safe_file_write(core.get_worldpath()..'/registry.json',core.write_json(out,true));core.safe_file_write(core.get_worldpath()..'/reference.json',core.write_json(ref,true));core.request_shutdown('Furnace fixture complete',false,0)
end)end)
'''

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--project',default=str(ROOT));parser.add_argument('--bindings');args=parser.parse_args()
    if args.bindings: bindings=json.loads(Path(args.bindings).read_text())
    else:
        output=Path(tempfile.mktemp(prefix='voxey-furnace-bindings-',suffix='.json'))
        run=subprocess.run(['godot','--headless','--path',args.project,'--script','res://tests/enchanting_registry_bindings.gd','--',str(output)],capture_output=True,text=True,timeout=120)
        if run.returncode or not output.exists() or 'SCRIPT ERROR:' in run.stdout+run.stderr:raise RuntimeError((run.stdout+run.stderr)[-2500:])
        bindings=json.loads(output.read_text())
    world=Path(tempfile.mkdtemp(prefix='voxey-furnace-oracle-'));mod=world/'worldmods/furnace_oracle';mod.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
    (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31515\nserver_announce = false\nenable_ipv6 = false\n')
    (mod/'mod.conf').write_text('name = furnace_oracle\ndepends = mcl_furnaces, mcl_blast_furnace, mcl_smoker\n')
    (mod/'init.lua').write_text('local BINDINGS='+lua(bindings['bindings'])+'\n'+BODY)
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=240)
    if not (world/'registry.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3500:])
    data=json.loads((world/'registry.json').read_text());ref=json.loads((world/'reference.json').read_text())
    hashes={str(p.relative_to(SOURCE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((SOURCE/'mods').rglob('*.lua')) if any(word in p.read_text(errors='replace')for word in ['cooking','burntime','get_timer_function'])}
    data.update(license='GPL-3.0-or-later',source_hashes=hashes);ref['source_hashes']=hashes
    (ROOT/'assets/data/furnaces.json').write_text(json.dumps(data,indent=2)+'\n');(ROOT/'assets/data/furnace_reference.json').write_text(json.dumps(ref,separators=(',',':'))+'\n')
    print(world);print('Registry',len(data['items']),'items,',len(data['bindings']),'bindings;', {k:len(v)for k,v in ref.items()})

if __name__=='__main__':main()
