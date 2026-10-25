#!/usr/bin/env python3
"""Inventory the loaded game's complete stair/slab registrations and recipes."""
import argparse,hashlib,json,subprocess,tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local out={families={},bases={},crafting={},placements={},aliases=core.registered_aliases}
 local function info(name)
  local d=core.registered_nodes[name];if not d then return false end
  local recipes={};for _,r in ipairs(core.get_all_craft_recipes(name)or{})do if r.method=='normal'then recipes[#recipes+1]=r end end
  local fuel=core.get_craft_result({method='fuel',width=1,items={ItemStack(name)}})
  return {name=name,description=d.description,groups=d.groups,hardness=d._mcl_hardness,resistance=d._mcl_blast_resistance,tiles=d.tiles,box=d.node_box,selection=d.selection_box,collision=d.collision_box,drop=core.get_node_drops(name),cuts=d._mcl_stonecutter_recipes or{},recipes=recipes,fuel=fuel.time}
 end
 for name,d in pairs(core.registered_nodes)do
  if name:sub(1,16)=='mcl_stairs:slab_' and core.get_item_group(name,'slab')>0 and core.get_item_group(name,'slab_top')==0 and not name:match('_double$')and not name:match('_preserved$')then
   local key=name:sub(17);out.families[key]={slab=info(name),stair=info('mcl_stairs:stair_'..key),top=info(name..'_top'),double=info(name..'_double')}
   for _,recipe in ipairs(core.get_all_craft_recipes(name)or{})do for _,base in ipairs(recipe.items or{})do if base~=''and core.registered_nodes[base]then out.bases[base]=info(base)end end end
  end
 end
 for _,name in ipairs({'mcl_core:redsand','mcl_core:redsandstonecarved'})do out.bases[name]=info(name)end
 local groups={wool_slab='mcl_stairs:slab_wool_white',wool_stair='mcl_stairs:stair_wool_white',wool_stairs='mcl_stairs:stair_wool_white',quartz_block='mcl_nether:quartz_block',purpur_block='mcl_end:purpur_block'}
 local function record(input)
  local stacks={};for i=1,9 do stacks[i]=ItemStack((input[i]or'')..((input[i]or'')~=''and' 2'or''))end
  local value,after=core.get_craft_result({method='normal',width=3,items=stacks})
  local names,left={},{};for i=1,9 do names[i]=input[i]or'';left[i]=after.items[i]:get_count()end
  out.crafting[#out.crafting+1]={input=names,output=value.item:get_name(),count=value.item:get_count(),after=left}
 end
 for _,family in pairs(out.families)do for _,shape in ipairs({family.slab,family.stair})do
  for _,recipe in ipairs(shape.recipes or{})do
   local width=recipe.width>0 and recipe.width or #recipe.items;local height=math.ceil(#recipe.items/width)
   for dy=0,3-height do for flip=0,1 do
    local input={};for i=1,9 do input[i]=''end
    for i=1,#recipe.items do local name=recipe.items[i]or'';if name:sub(1,6)=='group:'then name=assert(groups[name:sub(7)],name)end;local x=(i-1)%width;local y=math.floor((i-1)/width)+dy;input[y*3+(flip==1 and width-1-x or x)+1]=name end
    record(input)
    local wrong=table.copy(input);for i=1,9 do if wrong[i]~=''then wrong[i]='mcl_core:sand';break end end;record(wrong)
   end end
  end
 end end

 -- Execute the registered placement callbacks while capturing the engine node
 -- placement boundary. Physics/collision is exercised separately in Godot.
 local under=vector.new(0,40,0)
 local normals={vector.new(0,1,0),vector.new(0,-1,0),vector.new(1,0,0),vector.new(-1,0,0),vector.new(0,0,1),vector.new(0,0,-1)}
 local original={place=core.item_place_node,face=core.pointed_thing_to_face_pos,get=core.get_node,set=core.set_node,rightclick=mcl_util.call_on_rightclick,creative=core.is_creative_enabled,protected=core.is_protected}
 local captured,point,unode,anode
 mcl_util.call_on_rightclick=function()end;core.is_creative_enabled=function()return false end;core.is_protected=function()return false end
 core.pointed_thing_to_face_pos=function()return point end
 core.item_place_node=function(stack,placer,pt,param2)captured={path='place',name=stack:get_name(),param2=param2 or 0,at='above'};return stack end
 core.get_node=function(p)return {name=vector.equals(p,under)and unode or anode,param2=0}end
 core.set_node=function(p,node)captured={path='combine',name=node.name,param2=node.param2 or 0,at=vector.equals(p,under)and'under'or'above'}end
 local player={is_player=function()return true end,get_player_name=function()return 'shape_oracle'end}
 local positions={vector.new(4,1,0),vector.new(-4,1,0),vector.new(0,1,4),vector.new(0,1,-4),vector.new(3,1,3),vector.new(-3,1,-3),vector.new(.25,1,.1)}
 for _,normal in ipairs(normals)do for _,h in ipairs({.1,.5,.55,.551,.9})do
  local above=vector.add(under,normal);point=vector.add(under,vector.new(normal.x*.5,normal.y~=0 and normal.y*.5 or h-.5,normal.z*.5))
  unode='mcl_core:stone';anode='air'
  for _,relative in ipairs(positions)do
   player.get_pos=function()return vector.add(above,relative)end;captured=nil
   core.registered_nodes['mcl_stairs:stair_oak'].on_place(ItemStack('mcl_stairs:stair_oak 2'),player,{type='node',under=under,above=above})
   out.placements[#out.placements+1]={kind='stair',normal=normal,height=h,relative=relative,result=captured}
  end
  for _,pair in ipairs({{'mcl_core:stone','air'},{'mcl_stairs:slab_oak','air'},{'mcl_stairs:slab_oak_top','air'},{'mcl_core:stone','mcl_stairs:slab_oak'},{'mcl_core:stone','mcl_stairs:slab_oak_top'},{'mcl_stairs:slab_cobble','air'}})do
   unode,anode=pair[1],pair[2];captured=nil
   core.registered_nodes['mcl_stairs:slab_oak'].on_place(ItemStack('mcl_stairs:slab_oak 2'),player,{type='node',under=under,above=above})
   out.placements[#out.placements+1]={kind='slab',normal=normal,height=h,under=unode,above=anode,result=captured}
  end
 end end
 core.item_place_node=original.place;core.pointed_thing_to_face_pos=original.face;core.get_node=original.get;core.set_node=original.set;mcl_util.call_on_rightclick=original.rightclick;core.is_creative_enabled=original.creative;core.is_protected=original.protected
 core.safe_file_write(core.get_worldpath()..'/registry.json',core.write_json(out,true));core.request_shutdown('Shape census complete',false,0)
end)end)
'''
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--project',default=str(ROOT));args=parser.parse_args()
 dest=Path(tempfile.mktemp(prefix='voxey-shape-bindings-',suffix='.json'))
 p=subprocess.run(['godot','--headless','--path',args.project,'--script','res://tests/shape_registry_bindings.gd','--',str(dest)],capture_output=True,text=True,timeout=120)
 if p.returncode or not dest.exists() or 'SCRIPT ERROR:'in p.stdout+p.stderr:raise RuntimeError((p.stdout+p.stderr)[-3000:])
 bindings=json.loads(dest.read_text())
 world=Path(tempfile.mkdtemp(prefix='voxey-shape-oracle-'));mod=world/'worldmods/shape_oracle';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31516\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = shape_oracle\ndepends = mcl_stairs, mclx_stairs\n');(mod/'init.lua').write_text(BODY)
 p=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=180)
 if not (world/'registry.json').exists():raise RuntimeError(str(world)+'\n'+p.stderr[-3000:])
 data=json.loads((world/'registry.json').read_text());data['native']=bindings
 data['license']='GPL-3.0-or-later';data['source_hashes']={str(f.relative_to(SOURCE)):hashlib.sha256(f.read_bytes()).hexdigest()for f in (SOURCE/'mods').rglob('*.lua') if 'register_stair'in f.read_text(errors='replace')or 'cornerstair'in str(f)}
 (ROOT/'assets/data/shapes_reference.json').write_text(json.dumps(data,indent=2)+'\n')
 print(world);print('Registered',len(data['families']),'source families;',len(bindings['families']),'native families')
if __name__=='__main__':main()
