#!/usr/bin/env python3
"""Run the installed game's stonecutter registry and inventory callbacks."""
import argparse,hashlib,json,subprocess,tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1]; SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local out={recipes={},traces={},permissions={},aliases=core.registered_aliases,bindings=BINDINGS}
 local pos=vector.new(0,40,0);core.get_voxel_manip():read_from_map(vector.subtract(pos,16),vector.add(pos,16))
 local name='mcl_stonecutter:stonecutter';local def=core.registered_nodes[name]
 local player={get_player_name=function()return 'stonecutting_oracle'end}
 local protected=false;core.is_protected=function()return protected end;core.record_protection_violation=function()end
 local function setup(input,count)
  core.set_node(pos,{name=name});local inv=core.get_meta(pos):get_inventory();inv:set_stack('input',1,ItemStack(input..' '..(count or 1)));return inv
 end
 local function snapshot(inv)
  local i=inv:get_stack('input',1);local o=inv:get_stack('output',1)
  return {input=i:get_name(),count=i:get_count(),output=o:get_name(),amount=o:get_count()}
 end
 for result,d in pairs(core.registered_nodes)do if d._mcl_stonecutter_recipes and core.get_item_group(result,'not_in_creative_inventory')==0 then
  for _,input in ipairs(d._mcl_stonecutter_recipes)do if core.get_item_group(input,'stonecuttable')>0 then
   local inv=setup(input,64);def.on_receive_fields(pos,'',{['item_button_'..result]=true},player)
   local stack=inv:get_stack('output',1)
   if stack:get_name()==result then
    out.recipes[input]=out.recipes[input]or{};out.recipes[input][result]=stack:get_count()
   end
  end end
 end end
 local cases={{'mcl_core:stone','mcl_stairs:slab_stone_rough'},{'mcl_core:stone','mcl_walls:stonebrick_short_pillar'},{'mcl_copper:block','mcl_stairs:slab_copper_cut'},{'mcl_copper:block','mcl_copper:block_cut'},{'mcl_copper:block','mcl_copper:grate'},{'mcl_core:sandstone','mcl_core:sandstonesmooth'},{'mcl_core:redsandstone','mcl_walls:redsandstone_short_pillar'}}
 for _,pair in ipairs(cases)do if out.recipes[pair[1]]and out.recipes[pair[1]][pair[2]]then for _,count in ipairs({1,2,9,32,64})do
  local inv=setup(pair[1],count);local row={input=pair[1],count=count,frames={}}
  local function record(action)row.frames[#row.frames+1]={action=action,state=snapshot(inv)}end
  def.on_receive_fields(pos,'',{['item_button_'..pair[2]]=true},player);record({'select',pair[2]})
  def.on_receive_fields(pos,'',{['item_button_'..pair[2]]=true},player);record({'select',pair[2]})
  def.on_receive_fields(pos,'',{__mcl_crafting_fillgrid=true},player);record({'fill'})
  for _,take in ipairs({1,3,16})do
   local stack=inv:get_stack('output',1);stack:set_count(math.min(stack:get_count(),take))
   if not stack:is_empty()then
    local allowed=def.allow_metadata_inventory_take(pos,'output',1,stack,player);stack:set_count(math.min(stack:get_count(),allowed))
    local left=inv:get_stack('output',1);left:take_item(stack:get_count());inv:set_stack('output',1,left)
    def.on_metadata_inventory_take(pos,'output',1,stack,player)
   end;record({'take',take,stack:get_count()})
   def.on_receive_fields(pos,'',{['item_button_'..pair[2]]=true},player);record({'select',pair[2]})
  end
  def.on_metadata_inventory_put(pos,'input',1,inv:get_stack('input',1),player);record({'put_callback'})
  def.on_receive_fields(pos,'',{['item_button_'..pair[2]]=true},player);record({'select',pair[2]})
  def.on_rightclick(pos,{name=name},{get_player_control=function()return {sneak=false}end});record({'open'})
  out.traces[#out.traces+1]=row
 end end end
 for _,input in ipairs({'mcl_core:stone','mcl_core:dirt'})do for _,guard in ipairs({false,true})do
  protected=guard;local inv=setup(input,4)
  for _,list in ipairs({'input','output'})do
   out.permissions[#out.permissions+1]={input=input,protected=guard,list=list,put=def.allow_metadata_inventory_put(pos,list,1,ItemStack(input..' 3'),player),take=list=='input'and def.allow_metadata_inventory_take(pos,list,1,ItemStack(input..' 3'),player)or 0}
  end
 end end

 out.orientations={}
 for param=0,23 do
  core.swap_node(pos,{name=name,param2=param})
  local boxes=core.get_node_boxes('collision_box',pos);local b=boxes[1]
  local up=vector.new(-(b[1]+b[4])/0.4375,-(b[2]+b[5])/0.4375,-(b[3]+b[6])/0.4375)
  local front=core.facedir_to_dir(param);local right=vector.cross(up,front)
  out.orientations[tostring(param)]={body=boxes,selection=core.get_node_boxes('selection_box',pos),up=up,front=front,right=right,rotate={screwdriver.rotate.facedir(pos,{param2=param},1),screwdriver.rotate.facedir(pos,{param2=param},2)}}
 end
 out.node={box=def.node_box,collision=def.collision_box,hardness=def._mcl_hardness,groups=def.groups,recipes=core.get_all_craft_recipes(name)}
 core.safe_file_write(core.get_worldpath()..'/registry.json',core.write_json(out,true));core.request_shutdown('Stonecutter reference complete',false,0)
end)end)
'''
def main():
 p=argparse.ArgumentParser();p.add_argument('--project',default=str(ROOT));args=p.parse_args()
 target=Path(tempfile.mktemp(prefix='voxey-stonecutting-bindings-',suffix='.json'))
 r=subprocess.run(['godot','--headless','--path',args.project,'--script','res://tests/enchanting_registry_bindings.gd','--',str(target)],capture_output=True,text=True,timeout=120)
 if not target.exists()or'SCRIPT ERROR'in r.stdout+r.stderr:raise RuntimeError(r.stdout+r.stderr)
 bindings=json.loads(target.read_text())['bindings'];world=Path(tempfile.mkdtemp(prefix='voxey-stonecutting-oracle-'));mod=world/'worldmods/stonecutting_oracle';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31518\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = stonecutting_oracle\ndepends = mcl_stonecutter\n');(mod/'init.lua').write_text('local BINDINGS='+lua(bindings)+'\n'+BODY)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=240)
 if not(world/'registry.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-4000:])
 data=json.loads((world/'registry.json').read_text());data['source_hashes']={str(f.relative_to(SOURCE)):hashlib.sha256(f.read_bytes()).hexdigest()for f in(SOURCE/'mods').rglob('*.lua')if '_mcl_stonecutter_recipes'in f.read_text(errors='replace')or'mcl_stonecutter'in str(f)or f.name=='init.lua'and f.parent.name=='screwdriver'}
 data['license']='GPL-3.0-or-later';(ROOT/'assets/data/stonecutting_reference.json').write_text(json.dumps(data,indent=2)+'\n')
 names={}
 def canonical(n):
  for _ in range(16):
   if n not in data['aliases']:break
   n=data['aliases'][n]
  return n
 for key,n in bindings.items():names.setdefault(canonical(n),int(key))
 def mapped(n):return names.get(canonical(n.removesuffix('_preserved')),0)
 missing=set();mapped_recipes={}
 for input,outputs in data['recipes'].items():
  if not mapped(input):missing.add(input)
  for output in outputs:
   if not mapped(output):missing.add(output)
 print(world);print('Source inputs',len(data['recipes']),'outputs',sum(map(len,data['recipes'].values())),'traces',len(data['traces']));print('Unmapped',sorted(missing))
if __name__=='__main__':main()
