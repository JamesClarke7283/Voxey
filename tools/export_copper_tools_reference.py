#!/usr/bin/env python3
"""Exercise the registered copper tools, crafting, recycling and place callbacks."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
FILES=['mods/ITEMS/mcl_tools/register.lua','mods/ITEMS/mcl_tools/init.lua','mods/ITEMS/mcl_farming/hoes.lua','mods/CORE/_mcl_autogroup/init.lua','mods/ITEMS/mcl_copper/init.lua','mods/ITEMS/mcl_copper/decaychains.lua','mods/ITEMS/mcl_core/nodes_base.lua','mods/ITEMS/mcl_trees/api.lua']
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local out={items={},crafting={},actions={},increments={}}
 for id,name in pairs(BINDINGS)do
  local d=core.registered_tools[name]
  if d and d._mcl_diggroups then
   for _,group in ipairs({'pickaxey','axey','shovely','swordy','hoey'})do
    if d._mcl_diggroups[group]then out.increments[#out.increments+1]={id=tonumber(id),name=name,wear=mcl_autogroup.get_wear(name,group)};break end
   end
  end
 end
 local names={'mcl_tools:pick_copper','mcl_tools:axe_copper','mcl_tools:shovel_copper','mcl_tools:sword_copper','mcl_farming:hoe_copper'}
 local map={['mcl_copper:copper_ingot']=77,['mcl_core:stick']=64,['']=0}
 for i,name in ipairs(names)do map[name]=11591+i end
 for i,name in ipairs(names)do
  local d=core.registered_items[name];local item=ItemStack(name)
  local cooking=core.get_craft_result({method='cooking',width=1,items={item}})
  out.items[#out.items+1]={id=11591+i,name=name,stack=d.stack_max,repair=d._repair_material,groups=d.groups,uses=mcl_util.calculate_durability(item),caps=item:get_tool_capabilities(),cooking={item=cooking.item:get_name(),count=cooking.item:get_count(),time=cooking.time}}
  local recipes=core.get_all_craft_recipes(name)
  for _,r in ipairs(recipes or{})do if r.method=='normal'then
   local width=r.width;local height=math.ceil(#r.items/width)
   for dx=0,3-width do for flip=0,1 do
    local cells={};local input={};for n=1,9 do cells[n]=0;input[n]=ItemStack('')end
    for y=0,height-1 do for x=0,width-1 do local name=r.items[y*width+x+1]or'';local target=y*3+dx+(flip==1 and width-1-x or x)+1;cells[target]=map[name]or -1;input[target]=ItemStack(name)end end
    local result,left=core.get_craft_result({method='normal',width=3,items=input})
    local after={};for n=1,9 do after[n]=left.items[n]:get_count()end
    out.crafting[#out.crafting+1]={cells=cells,id=map[result.item:get_name()]or 0,count=result.item:get_count(),after=after}
   end end
  end end
 end
 local pos=vector.new(0,40,0);core.get_voxel_manip():read_from_map(vector.subtract(pos,16),vector.add(pos,16))
 local fake={get_player_name=function()return 'oracle'end,is_player=function()return true end}
 mcl_util.call_on_rightclick=function()return nil end;core.is_protected=function()return false end;core.sound_play=function()end
 local targets={{index=2,node='mcl_trees:tree_oak'},{index=3,node='mcl_core:dirt_with_grass'},{index=5,node='mcl_core:dirt'},{index=2,node='mcl_copper:block_exposed'},{index=2,node='mcl_copper:block_exposed_preserved'},{index=5,node='mcl_core:coarse_dirt'},{index=3,node='mcl_core:coarse_dirt'},{index=5,node='mcl_core:grass_path'}}
 for _,target in ipairs(targets)do for _,unbreaking in ipairs({0,1,3})do for _,initial in ipairs({0,20000,65000,65400})do for _,creative in ipairs({false,true})do for _,blocked in ipairs({false,true})do
  core.set_node(pos,{name=target.node});core.set_node(vector.offset(pos,0,1,0),{name=blocked and 'mcl_core:stone' or 'air'})
  local item=ItemStack(names[target.index]);if unbreaking>0 then mcl_enchanting.enchant(item,'unbreaking',unbreaking)end;item:set_wear(initial)
  core.is_creative_enabled=function()return creative end
  local ret=item:get_definition().on_place(item,fake,{type='node',under=pos,above=vector.offset(pos,0,1,0)})
  out.actions[#out.actions+1]={id=11591+target.index,node=target.node,unbreaking=unbreaking,initial=initial,creative=creative,blocked=blocked,node_after=core.get_node(pos).name,wear=ret and (ret:is_empty()and -1 or ret:get_wear())or (item:is_empty()and -1 or item:get_wear())}
 end end end end end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Copper tool fixture complete',false,0)
end)end)
'''
def main():
 world=Path(tempfile.mkdtemp(prefix='voxey-copper-tools-'));mod=world/'worldmods/copper_tools_fixture';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31514\nserver_announce = false\nenable_ipv6 = false\n')
 bindings={key:value['name']for key,value in json.loads((ROOT/'assets/data/digging.json').read_text())['tools'].items()}
 from export_enchanting_reference import lua
 (mod/'mod.conf').write_text('name = copper_tools_fixture\ndepends = mcl_tools, mcl_farming, mcl_copper\n');(mod/'init.lua').write_text('local BINDINGS='+lua(bindings)+'\n'+BODY)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
 if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3500:])
 data=json.loads((world/'oracle.json').read_text());data['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest()for p in FILES}
 (ROOT/'assets/data/copper_tools_reference.json').write_text(json.dumps(data,separators=(',',':'))+'\n');print({k:len(v)for k,v in data.items()})
if __name__=='__main__':main()
