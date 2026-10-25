#!/usr/bin/env python3
"""Capture actual map registration, fill/copy, HUD and compositor callbacks."""
import hashlib,json,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local out={origins={},fills={},markers={},copies={},registry={},pixels={},columns={}}
 local callbacks={}
 local function from_maps(f)return(debug.getinfo(f,'S').source or''):find('/mcl_maps/init.lua',1,true)end
 for _,f in ipairs(core.registered_on_joinplayers)do if from_maps(f)then callbacks.join=f end end
 for _,f in ipairs(mcl_player.registered_globalsteps)do if from_maps(f)then callbacks.step=f end end
 for _,f in ipairs(core.registered_on_crafts)do if from_maps(f)then callbacks.craft=f end end
 local pending={};core.emerge_area=function(minp,maxp,cb)pending[#pending+1]={minp=minp,maxp=maxp,cb=cb}end
 os.time=function()return 1700000000 end
 local function snap(s)return {name=s:get_name(),count=s:get_count(),id=s:get_meta():get_string('mcl_maps:id'),min=s:get_meta():get_string('mcl_maps:minp'),max=s:get_meta():get_string('mcl_maps:maxp'),date=s:get_meta():get_int('date'),label=s:get_meta():get_string('name'),junk=s:get_meta():get_string('junk')}end
 for _,name in ipairs({'mcl_maps:empty_map','mcl_maps:filled_map','mcl_cartography_table:cartography_table'})do
  local d=core.registered_items[name];out.registry[name]={stack=d.stack_max,groups=d.groups,hardness=d._mcl_hardness,burn=d._mcl_burntime,paramtype2=d.paramtype2 or'none',gui=not not d.on_rightclick,recipes=core.get_all_craft_recipes(name)}
 end
 for _,x in ipairs({-256.5,-128,-0.5,0,127.5,128})do for _,y in ipairs({-128,0,640})do for _,z in ipairs({-128.5,0,127.5,128})do
  local pos=vector.new(x,y,z);out.origins[#out.origins+1]={pos=pos,item=snap(mcl_maps.create_map(pos))}
 end end end
 local inv=core.create_detached_inventory('map_oracle',{});inv:set_size('main',9);inv:set_size('hand',1)
 local pos=vector.new(8,650,9);local hud={};local next_hud=0;local held=ItemStack('mcl_maps:filled_map')
 local player={get_player_name=function()return 'maps_oracle'end,get_pos=function()return pos end,get_inventory=function()return inv end,get_wielded_item=function()return held end,set_wielded_item=function(_,s)held=s end,get_look_horizontal=function()return 0 end,hud_add=function(_,d)next_hud=next_hud+1;return next_hud end,hud_change=function(_,id,key,val)hud[id]=hud[id]or{};hud[id][key]=val end}
 local drops={};core.add_item=function(_,s)drops[#drops+1]=snap(s)end
 for _,count in ipairs({1,2,64})do for _,full in ipairs({false,true})do
  inv:set_list('main',{});for i=2,9 do if full then inv:set_stack('main',i,'mcl_core:stone 64')end end
  inv:set_stack('main',1,ItemStack('mcl_maps:empty_map '..count));drops={}
  local result=core.registered_items['mcl_maps:empty_map'].on_place(inv:get_stack('main',1),player,nil);inv:set_stack('main',1,result)
  local items={};for i=1,9 do items[#items+1]=snap(inv:get_stack('main',i))end
  out.fills[#out.fills+1]={count=count,full=full,result=snap(result),items=items,drops=drops}
 end end
 local original=ItemStack('mcl_maps:filled_map');original:get_meta():set_string('mcl_maps:id','5');original:get_meta():set_string('name','Remembered map');original:get_meta():set_string('junk','kept')
 for slot=1,9 do local old={};for i=1,9 do old[i]=ItemStack('')end;old[slot]=original;local copy=ItemStack('mcl_maps:filled_map 2');callbacks.craft(copy,player,old,nil);out.copies[#out.copies+1]=snap(copy)end
 -- Markers are evaluated only after source media loading has completed.
 callbacks.join(player)
 core.dynamic_add_media=function(_,cb)if cb then cb()end;return true end
 held=ItemStack('mcl_maps:filled_map');held:get_meta():set_string('mcl_maps:id','fixture');held:get_meta():set_string('mcl_maps:minp','(-128,0,0)');held:get_meta():set_string('mcl_maps:maxp','(-1,127,127)')
 for _,x in ipairs({-129,-128.5,-128,-127.5,-1.5,-1,-0.5,0})do for _,z in ipairs({-0.5,0,0.5,126.5,127,127.5,128})do for _,yaw in ipairs({-math.pi,-math.pi/4,0,math.pi/4,math.pi/2,7*math.pi/4,2*math.pi})do
  pos=vector.new(x,650,z);player.get_look_horizontal=function()return yaw end;callbacks.step(player)
  out.markers[#out.markers+1]={pos=pos,yaw=yaw,marker=table.copy(hud[2])}
 end end end
 -- Drive create_map's real voxel compositor with a small repeating column fixture.
 local raw_palette=core.parse_json(assert(io.open(core.get_modpath('mcl_maps')..'/colors.json','r')):read('*all'))
 local names={'mcl_core:stone','mcl_core:glass','mcl_core:water_source','mcl_core:leaves','mcl_core:dirt','mcl_core:goldblock'}
 local c_air=core.get_content_id('air');local data=setmetatable({},{__index=function()return c_air end});local param=setmetatable({},{__index=function()return 0 end})
 local area=VoxelArea:new({MinEdge=vector.new(0,0,0),MaxEdge=vector.new(127,127,127)})
 for x=0,127 do for z=0,127 do
  local layers={};local h=(x*3+z*5)%70+5
  if z%9~=0 then layers[#layers+1]={y=h,name=names[x%6+1]};if x%6~=0 then layers[#layers+1]={y=h-2,name=names[1]}end end
  if z%13==0 then layers={{y=126,name=names[2]},{y=125,name=names[2]},{y=124,name=names[2]}}end
  for _,l in ipairs(layers)do data[area:index(x,l.y,z)]=core.get_content_id(l.name)end
  out.columns[#out.columns+1]={x=x,z=z,layers=layers}
 end end
 core.get_voxel_manip=function()return{read_from_map=function()return vector.new(0,0,0),vector.new(127,127,127)end,get_data=function()return data end,get_param2_data=function()return param end}end
 tga_encoder.image=function(pixels)out.pixels=pixels;return{save=function(_,_,options)out.format=options.color_format end}end
 mcl_maps.create_map(vector.new(0,0,0));pending[#pending].cb(nil,nil,0)
 out.palette={};for _,n in ipairs(names)do out.palette[n]=raw_palette[core.get_name_from_content_id(core.get_content_id(n))]end
 core.safe_file_write(core.get_worldpath()..'/result.json',core.write_json(out,true));core.request_shutdown('Map reference complete',false,0)
end)end)
'''
def main():
 world=Path(tempfile.mkdtemp(prefix='voxey-maps-oracle-'));mod=world/'worldmods/maps_oracle';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31521\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = maps_oracle\ndepends = mcl_maps, mcl_cartography_table\n');(mod/'init.lua').write_text(BODY)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=240)
 if not(world/'result.json').exists():raise RuntimeError(str(world)+'\n'+run.stdout[-6000:]+run.stderr[-6000:])
 d=json.loads((world/'result.json').read_text());d['source_hashes']={str(p.relative_to(SOURCE)):hashlib.sha256(p.read_bytes()).hexdigest()for p in sorted((SOURCE/'mods').rglob('*.lua'))};d['license']='GPL-3.0-or-later'
 for row in d['origins']:
  for key in ['min','max']:row['item'][key]=list(map(int,re.findall(r'-?\d+',row['item'][key])))
 (ROOT/'assets/data/maps_reference.json').write_text(json.dumps(d,indent=2)+'\n')
 print(world);print('Origins',len(d['origins']),'fills',len(d['fills']),'copies',len(d['copies']),'markers',len(d['markers']),'pixels',len(d['columns']))
if __name__=='__main__':main()
