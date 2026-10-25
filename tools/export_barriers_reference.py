#!/usr/bin/env python3
"""Read the live wall/fence registry and execute source wall and gate callbacks."""
import argparse,hashlib,json,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local out={walls={},fences={},nodes={},wall_cases={},gate_cases={},aliases=core.registered_aliases}
 local function info(name)
  local d=core.registered_nodes[name];local f=core.get_craft_result({method='fuel',width=1,items={ItemStack(name)}})
  return {name=name,description=d.description,groups=d.groups,hardness=d._mcl_hardness,resistance=d._mcl_blast_resistance,tiles=d.tiles,box=d.node_box,collision=d.collision_box or d.node_box,selection=d.selection_box or d.node_box,walkable=d.walkable,drop=core.get_node_drops(name),cuts=d._mcl_stonecutter_recipes or {},recipes=core.get_all_craft_recipes(name) or {},fuel=f.time,connects=d.connects_to,connect_sides=d.connect_sides,base=d._mcl_fences_baseitem}
 end
 for name,d in pairs(core.registered_nodes)do
  if d._mcl_walls_name_root then
   local root=d._mcl_walls_name_root;out.walls[root]=out.walls[root]or{}
   out.walls[root][name:sub(#root+2)]=info(name)
  elseif core.get_item_group(name,'fence')>0 or core.get_item_group(name,'fence_gate')>0 then out.fences[name]=info(name)end
  out.nodes[name]={groups=d.groups or {},connect_sides=d.connect_sides}
 end
 local pos=vector.new(0,40,0);local sides={vector.new(1,0,0),vector.new(0,0,1),vector.new(-1,0,0),vector.new(0,0,-1)}
 local current,neighbors,top,upper,swaps,metadata,power
 local old={get=core.get_node,swap=core.swap_node,set=core.set_node,meta=core.get_meta,sound=core.sound_play,notify=mcl_redstone._notify_observer_neighbours,power=mcl_redstone.get_power}
 core.get_node=function(p)
  if vector.equals(p,pos)then return table.copy(current)end
  if vector.equals(p,vector.offset(pos,0,1,0))then return {name=top,param2=0}end
  for i,d in ipairs(sides)do if vector.equals(p,vector.add(pos,d))then return {name=neighbors[i],param2=0}end;if vector.equals(p,vector.offset(vector.add(pos,d),0,1,0))then return {name=upper[i],param2=0}end end
  return {name='air',param2=0}
 end
 core.swap_node=function(p,n)if vector.equals(p,pos)then current=table.copy(n);swaps=swaps+1 end end
 core.set_node=core.swap_node
 mcl_redstone._notify_observer_neighbours=function()end;core.sound_play=function()end
 core.get_meta=function()return {get_int=function(_,k)return metadata[k]or 0 end,set_int=function(_,k,v)metadata[k]=v end}end
 mcl_redstone.get_power=function()return power end
 local root='mcl_walls:cobble'
 local tops={'air','mcl_core:stone','mcl_core:glass','mcl_stairs:slab_oak','mcl_fences:oak_fence','mcl_torches:torch','mcl_pressureplates:pressure_plate_oak_off','mcl_signs:standing_sign_oak','mcl_banners:standing_banner',root..'_short_pillar',root..'_short_flat'}
 for _,name in ipairs(tops)do assert(core.registered_nodes[name],name)end
 for _,state in ipairs({'short_pillar','tall_pillar','short_flat','tall_flat'})do for facing=0,1 do for mask=0,15 do for ti,tname in ipairs(tops)do for uppermask=0,(core.get_item_group(tname,'wall')>0 and 15 or 0)do
  current={name=root..'_'..state,param2=facing};top=tname;neighbors={};upper={};swaps=0
  for i=1,4 do neighbors[i]=math.floor(mask/2^(i-1))%2==1 and 'mcl_core:stone'or'air';upper[i]=math.floor(uppermask/2^(i-1))%2==1 and'mcl_core:stone'or'air'end
  local initial=table.copy(current);mcl_walls.update_wall(vector.copy(pos))
  out.wall_cases[#out.wall_cases+1]={initial=initial,mask=mask,top=top,upper=uppermask,result=table.copy(current),swaps=swaps}
 end end end end end
 for name,d in pairs(out.fences)do if (d.groups.fence_gate or 0)>0 then for state=0,1 do for p=0,1 do for _,event in ipairs({'manual','redstone','wind'})do
  current={name=name,param2=2};metadata={state=state};power=p;swaps=0;top='air';neighbors={};upper={}
  local def=core.registered_nodes[name]
  if event=='manual'then def.on_rightclick(pos,table.copy(current),{})elseif event=='redstone'then def._mcl_redstone.update(pos)else def._on_wind_charge_hit(pos)end
  out.gate_cases[#out.gate_cases+1]={initial={name=name,param2=2,state=state},power=p,event=event,result={name=current.name,param2=current.param2,state=metadata.state},swaps=swaps}
 end end end end end
 core.get_node=old.get;core.swap_node=old.swap;core.set_node=old.set;core.get_meta=old.meta;core.sound_play=old.sound;mcl_redstone._notify_observer_neighbours=old.notify;mcl_redstone.get_power=old.power

 out.crafting={}
 local craftdefs={};for _,family in pairs(out.walls)do craftdefs[#craftdefs+1]=family.short_pillar end;for _,def in pairs(out.fences)do craftdefs[#craftdefs+1]=def end
 for _,def in ipairs(craftdefs)do for _,recipe in ipairs(def.recipes or {})do if recipe.method=='normal'then for dy=0,1 do for flip=0,1 do for invalid=0,1 do
  local input={};for i=1,9 do input[i]=''end
  for i,n in ipairs(recipe.items)do input[(math.floor((i-1)/3)+dy)*3+(flip==1 and 2-(i-1)%3 or (i-1)%3)+1]=n or ''end
  if invalid==1 then for i=1,9 do if input[i]~=''then input[i]='mcl_core:sand';break end end end
  local stacks={};for i=1,9 do stacks[i]=ItemStack(input[i]~=''and input[i]..' 2'or'')end
  local output,after=core.get_craft_result({method='normal',width=3,items=stacks});local counts={};for i=1,9 do counts[i]=after.items[i]:get_count()end
  out.crafting[#out.crafting+1]={input=input,output=output.item:get_name(),count=output.item:get_count(),after=counts}
 end end end end end end
 out.geometry={}
 assert(type(core.get_node_boxes)=='function','Engine lacks get_node_boxes')
 core.get_voxel_manip():read_from_map(vector.subtract(pos,16),vector.add(pos,16))
 local geometry_names={root..'_short_pillar',root..'_tall_pillar',root..'_short_flat',root..'_tall_flat','mcl_fences:oak_fence','mcl_fences:oak_fence_gate','mcl_fences:oak_fence_gate_open'}
 for _,name in ipairs(geometry_names)do for facing=0,3 do for mask=0,15 do
  core.swap_node(pos,{name=name,param2=facing})
  for i,d in ipairs(sides)do core.swap_node(vector.add(pos,d),{name=math.floor(mask/2^(i-1))%2==1 and'mcl_core:stone'or'air'})end
  local row={name=name,facing=facing,mask=mask,boxes={}}
  for _,kind in ipairs({'node_box','collision_box','selection_box'})do row.boxes[kind]=core.get_node_boxes(kind,pos)end
  out.geometry[#out.geometry+1]=row
 end end end
 core.safe_file_write(core.get_worldpath()..'/registry.json',core.write_json(out,true));core.request_shutdown('Barrier reference complete',false,0)
end)end)
'''
def main():
 p=argparse.ArgumentParser();p.add_argument('--project',default=str(ROOT));args=p.parse_args()
 dest=Path(tempfile.mktemp(prefix='voxey-barrier-bindings-',suffix='.json'))
 run=subprocess.run(['godot','--headless','--path',args.project,'--script','res://tests/barrier_registry_bindings.gd','--',str(dest)],capture_output=True,text=True,timeout=120)
 if not dest.exists() or 'SCRIPT ERROR' in run.stdout+run.stderr:raise RuntimeError(run.stdout+run.stderr)
 native=json.loads(dest.read_text());world=Path(tempfile.mkdtemp(prefix='voxey-barrier-oracle-'));mod=world/'worldmods/barrier_oracle';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31517\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = barrier_oracle\ndepends = mcl_walls, mcl_fences, mclx_fences\n');(mod/'init.lua').write_text(BODY)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=180)
 if not (world/'registry.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-4000:])
 data=json.loads((world/'registry.json').read_text());data['native']=native;data['license']='GPL-3.0-or-later'
 data['source_hashes']={str(f.relative_to(SOURCE)):hashlib.sha256(f.read_bytes()).hexdigest()for f in (SOURCE/'mods').rglob('*.lua')if any(t in f.read_text(errors='replace')for t in ['register_wall','register_fence','mcl_walls.update_wall'])}
 (ROOT/'assets/data/barriers_reference.json').write_text(json.dumps(data,indent=2)+'\n')
 print(world);print('Walls',len(data['walls']),'fences and gate states',len(data['fences']),'wall cases',len(data['wall_cases']),'gate cases',len(data['gate_cases']))
if __name__=='__main__':main()
