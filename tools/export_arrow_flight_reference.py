#!/usr/bin/env python3
"""Measure real Mineclonia arrow drag, embedding, release and pickup callbacks."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
BODY = r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local def=core.registered_entities['mcl_bows:arrow_entity']
 local result={drag={},liquids={},stuck={},pickup={}}
 local node='mcl_core:stone';local nearby=false;local creative=false;local burning=false;local dropped
 core.get_node=function()return{name=node,param2=0}end
 core.is_creative_enabled=function()return creative end
 core.sound_play=function()end;core.add_particlespawner=function()return 1 end;core.delete_particlespawner=function()end
 mcl_burning.tick=function()end;mcl_burning.extinguish=function()burning=false end;mcl_burning.set_on_fire=function()burning=true end
 mcl_attachments.raycast=function()return function()return nil end end
 core.objects_inside_radius=function()return function()if nearby then nearby=false;return{is_valid=function()return true end,is_player=function()return true end,get_player_name=function()return'ArrowFixture'end}end end end
 core.add_item=function(pos,item)
  local stack=ItemStack(item);dropped={name=stack:get_name(),count=stack:get_count(),meta=stack:get_meta():to_table(),position={pos.x,pos.y,pos.z}}
  return{get_luaentity=function()return{}end,set_velocity=function()end,set_yaw=function()end}
 end
 local function arrow(v)
  local at=vector.new(0,0,0);local velocity=vector.copy(v);local acceleration=vector.new(0,-9.81,0);local removed=false
  local obj={get_pos=function()return vector.copy(at)end,set_pos=function(_,p)at=vector.copy(p)end,move_to=function(_,p)at=vector.copy(p)end,
   get_velocity=function()return vector.copy(velocity)end,set_velocity=function(_,v2)velocity=vector.copy(v2)end,
   set_acceleration=function(_,a)acceleration=vector.copy(a)end,set_rotation=function()end,set_properties=function()end,set_animation=function()end,
   get_yaw=function()return 0 end,remove=function()removed=true end}
  local a=setmetatable({object=obj,_lastpos=vector.new(0,0,0),_startpos=vector.new(0,0,0),_lifetime=0,_dragtime=0,_is_critical=false,_collectable=true},{__index=def})
  return a,function()return{velocity={velocity.x,velocity.y,velocity.z},position={at.x,at.y,at.z},acceleration={acceleration.x,acceleration.y,acceleration.z},removed=removed,life=a._lifetime,drag=a._dragtime,stuck=not not a._stuck,critical=not not a._is_critical,piercing=a._piercing or 0}end
 end
 for _,v in ipairs({{30,4,-5},{0,0,0},{-3,-8,20}})do
  for _,sequence in ipairs({{0.01,0.039,0.001,0.05},{0.05,0.05,0.05},{0.2,0.7,1.2},{119.99,0.01,0.0001}})do
   local a,get=arrow(vector.new(v[1],v[2],v[3]));local steps={}
   for _,dt in ipairs(sequence)do a:on_step(dt,{collisions={}});steps[#steps+1]=get()end
   result.drag[#result.drag+1]={initial=v,deltas=sequence,steps=steps}
  end
 end
 for _,names in ipairs({{'mcl_core:water_source'},{'mcl_core:lava_source'},{'mcl_fire:fire'},{'mcl_core:water_source','mcl_core:water_source'},{'mcl_core:lava_source','mcl_core:water_source','mcl_core:lava_source'}})do
  for _,same in ipairs({false,true})do
   local a,get=arrow(vector.new(30,4,-5));burning=false
   local stages={}
   for i,name in ipairs(names)do node=name;a:on_intersect({type='node',under=vector.new(same and 0 or i,0,0)})
    local value=get();value.burning=burning;stages[#stages+1]=value
   end
   result.liquids[#result.liquids+1]={names=names,same=same,stages=stages}
  end
 end
 for _,support in ipairs({'air','mcl_core:stone','mcl_core:water_source'})do
  for _,dt in ipairs({0.249,0.25,0.3,60,60.001})do
   node='mcl_core:stone';local a,get=arrow(vector.new(30,4,-5));a._is_critical=true;a._piercing=3
   a._stuckin=vector.new(0,0,0);a:on_solid_hit(vector.new(0,0,0),{name=node},{old_vel=vector.new(30,4,-5),new_pos=vector.new(0.5,0,0),collision_pos=vector.new(0,0,0)})
   local initial=get();node=support;nearby=false;a:on_step(dt,{collisions={}})
   result.stuck[#result.stuck+1]={support=support,dt=dt,initial=initial,after=get()}
  end
 end
 for _,name in ipairs({'mcl_bows:arrow','mcl_potions:poison_arrow'})do
  for _,enabled in ipairs({false,true})do for _,collectable in ipairs({false,true})do
   node='mcl_core:stone';local a,get=arrow(vector.new(30,0,0));creative=enabled;burning=false;dropped=nil
   local item=ItemStack(name);item:get_meta():set_string('description','Named arrow');a._itemstring=item:to_string();a._collectable=collectable
   a._stuckin=vector.new(0,0,0);a:on_solid_hit(vector.new(0,0,0),{name=node},{old_vel=vector.new(30,0,0),new_pos=vector.new(0.5,0,0),collision_pos=vector.new(0,0,0)})
   nearby=true;a:on_step(0.25,{collisions={}})
   result.pickup[#result.pickup+1]={name=name,creative=enabled,collectable=collectable,dropped=dropped,after=get()}
  end end
 end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Arrow flight fixture complete',false,0)
end)end)
'''

def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-arrow-flight-'))
    fixture = world/'worldmods'/'voxey_arrow_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_arrow_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31500\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_arrow_fixture\ndepends = mcl_bows, mcl_potions\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-500:]+'\n'+run.stderr[-3500:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {'mods/ITEMS/mcl_bows/arrow.lua':hashlib.sha256((SOURCE/'mods/ITEMS/mcl_bows/arrow.lua').read_bytes()).hexdigest()}
    (ROOT/'assets/data/arrow_flight_reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('Exported', {key:len(result[key]) for key in ['drag','liquids','stuck','pickup']})
    print('Pickup outputs:', [(r['name'],r.get('dropped',{})) for r in result['pickup'] if r.get('dropped')])

if __name__ == '__main__':
    export()
