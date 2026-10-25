#!/usr/bin/env python3
"""Exercise the installed Mineclonia grindstone callbacks and registered tools."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
core.register_on_mods_loaded(function() core.after(0,function()
 local name='mcl_grindstone:grindstone';local def=core.registered_nodes[name]
 local pos=vector.new(0,40,0);core.get_voxel_manip():read_from_map(vector.subtract(pos,16),vector.add(pos,16))
 local out={cases={},profiles={},orientations={},placements={},permissions={},node={groups=def.groups,hardness=def._mcl_hardness,recipes=core.get_all_craft_recipes(name)}}
 local function stack(spec)
  if not spec or not spec.name or spec.name=='' then return ItemStack('') end
  local s=ItemStack(spec.name);s:set_count(spec.count or 1);s:set_wear(spec.wear or 0)
  if spec.enchanted then local n=mcl_enchanting.get_enchanted_itemstring(s:get_name());if n then s:set_name(n)end end
  s:get_meta():set_string('name',spec.label or '')
  s:get_meta():set_string('junk','discard me');s:get_meta():set_int('mcl_enchanting:pwp',9)
  mcl_enchanting.set_enchantments(s,spec.enchants or {})
  return s
 end
 local function snap(s)
  return {name=s:get_name(),count=s:get_count(),wear=s:get_wear(),label=s:get_meta():get_string('name'),enchants=mcl_enchanting.get_enchantments(s),junk=s:get_meta():get_string('junk'),pwp=s:get_meta():get_int('mcl_enchanting:pwp')}
 end
 local function inventory(inv)return{snap(inv:get_stack('input',1)),snap(inv:get_stack('input',2)),snap(inv:get_stack('output',1))}end
 local function run(a,b,roll)
  core.set_node(pos,{name=name});local inv=core.get_meta(pos):get_inventory()
  inv:set_stack('input',1,stack(a));inv:set_stack('input',2,stack(b));def.on_metadata_inventory_put(pos)
  local row={a=a or{},b=b or{},roll=roll or 7,preview=snap(inv:get_stack('output',1))}
  local taken=inv:get_stack('output',1);local xp=0
  if not taken:is_empty()then
   local random=math.random;math.random=function(lo,hi)assert(lo==7 and hi==13);return row.roll end
   local throw=mcl_experience.throw_xp;mcl_experience.throw_xp=function(_,value)xp=xp+value end
   inv:set_stack('output',1,'');def.on_metadata_inventory_take(pos,'output',1,taken)
   math.random=random;mcl_experience.throw_xp=throw
  end
  row.xp=xp;row.after=inventory(inv)
  def.on_rightclick(pos,{}, {is_player=function()return true end,get_player_control=function()return{sneak=false}end})
  row.reopened=snap(inv:get_stack('output',1));out.cases[#out.cases+1]=row
 end
 local seen={}
 for id,n in pairs(BINDINGS)do
  local d=core.registered_items[n]
  if d then
   out.profiles[id]={name=n,tool=d.type=='tool',enchanted=mcl_enchanting.get_enchanted_itemstring(n) or '',stack_max=d.stack_max}
   if d.type=='tool' and not seen[n]then
    seen[n]=true
    run({name=n,wear=0},{name=n,wear=0})
    run({name=n,wear=50000,label='First'},{name=n,wear=40000,label='Second'})
    run({name=n,wear=65535},{name=n,wear=65535})
    run({name=n,wear=12345},nil)
    if mcl_enchanting.get_enchanted_itemstring(n)then
     run({name=n,wear=12345,enchanted=true,enchants={efficiency=3,curse_of_vanishing=1},label='Named'},nil,13)
     run(nil,{name=n,wear=54321,enchanted=true,enchants={curse_of_binding=1}},9)
     run({name=n,wear=50000,enchanted=true,enchants={unbreaking=2,curse_of_vanishing=1}},{name=n,wear=40000,enchanted=true,enchants={mending=1,curse_of_binding=1}},10)
    end
   end
  end
 end
 for _,n in ipairs({'mcl_enchanting:book_enchanted','mcl_books:book','mcl_core:dirt'})do
  for _,count in ipairs({1,8})do
   run({name=n,count=count,enchants={efficiency=2,curse_of_binding=1},label='Book'},nil,11)
   run(nil,{name=n,count=count,enchants={efficiency=1}},8)
   run({name=n,count=count},{name=n,count=count})
  end
 end
 for _,w1 in ipairs({0,1,32000,50000,65534,65535})do for _,w2 in ipairs({0,1,32000,50000,65534,65535})do
  run({name='mcl_tools:pick_iron',wear=w1},{name='mcl_tools:pick_iron',wear=w2})
 end end
 run({name='mcl_tools:pick_iron',wear=50000},{name='mcl_tools:axe_iron',wear=40000})
 for p=0,23 do
  core.swap_node(pos,{name=name,param2=p});out.orientations[tostring(p)]={boxes=core.get_node_boxes('collision_box',pos),rotate={screwdriver.rotate.facedir(pos,{param2=p},1),screwdriver.rotate.facedir(pos,{param2=p},2)}}
 end
 for _,dir in ipairs({vector.new(1,0,0),vector.new(-1,0,0),vector.new(0,1,0),vector.new(0,-1,0),vector.new(0,0,1),vector.new(0,0,-1)})do
  for _,offset in ipairs({vector.new(3,1,2),vector.new(2,1,3),vector.new(-3,1,-2),vector.new(-2,1,-3)})do
   def.after_place_node(pos,{get_pos=function()return pos+offset end},ItemStack(name),{under=pos+dir,above=pos})
   out.placements[#out.placements+1]={dir=dir,offset=offset,param=core.get_node(pos).param2}
  end
 end
 for _,guard in ipairs({false,true})do
  core.is_protected=function()return guard end;core.record_protection_violation=function()end
  local player={get_player_name=function()return 'grindstone_oracle'end}
  for _,list in ipairs({'input','output'})do
   out.permissions[#out.permissions+1]={protected=guard,list=list,put=def.allow_metadata_inventory_put(pos,list,1,ItemStack('mcl_core:dirt 3'),player),take=def.allow_metadata_inventory_take(pos,list,1,ItemStack('mcl_core:dirt 3'),player)}
  end
 end
 core.safe_file_write(core.get_worldpath()..'/result.json',core.write_json(out,true));core.request_shutdown('Grindstone reference complete',false,0)
end)end)
'''
def main():
 bindings=json.loads((ROOT/'assets/data/stonecutting_reference.json').read_text())['bindings']
 world=Path(tempfile.mkdtemp(prefix='voxey-grindstone-oracle-'));mod=world/'worldmods/grindstone_oracle';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31519\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = grindstone_oracle\ndepends = mcl_grindstone\n')
 (mod/'init.lua').write_text('local BINDINGS='+lua(bindings)+'\n'+BODY)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=180)
 if not (world/'result.json').exists():raise RuntimeError(str(world)+'\n'+run.stdout[-5000:]+run.stderr[-5000:])
 data=json.loads((world/'result.json').read_text())
 data['source_hashes']={str(p.relative_to(SOURCE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((SOURCE/'mods').rglob('*.lua'))};data['license']='GPL-3.0-or-later'
 (ROOT/'assets/data/grindstone_reference.json').write_text(json.dumps(data,indent=2)+'\n')
 # Gameplay needs only the completed registration and oriented geometry, not test traces.
 runtime={k:data[k]for k in ['profiles','orientations','source_hashes','license']}
 (ROOT/'assets/data/grindstone.json').write_text(json.dumps(runtime,indent=2)+'\n')
 print(world);print('Profiles',len(data['profiles']),'cases',len(data['cases']),'orientations',len(data['orientations']))
if __name__=='__main__':main()
