#!/usr/bin/env python3
"""Export direct Overworld biome queries from a real Mineclonia Luanti server."""
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
FILES = [
    'mods/MAPGEN/mcl_levelgen/random.lua',
    'mods/MAPGEN/mcl_levelgen/md5.lua',
    'mods/MAPGEN/mcl_levelgen/noise.lua',
    'mods/MAPGEN/mcl_levelgen/presets.lua',
    'mods/MAPGEN/mcl_levelgen/density_funcs.lua',
    'mods/MAPGEN/mcl_levelgen/biomes.lua',
]
BODY = r'''
core.register_on_mods_loaded(function() core.after(0,function()
 local out={seeds={0,1,-1,8675309,3228473,-8675309,4294967297,-4294967297},cases={},targets={}}
 local function ull(seed)
  return mcl_levelgen.ull(math.floor(seed/4294967296),seed%4294967296)
 end
 local source_tree,nodes=mcl_levelgen.construct_overworld_lut()
 local function export_node(node)
  local row={extents=node.extents,value=node.value}
  if node.children then
   row.children={}
   for _,child in ipairs(node.children)do row.children[#row.children+1]=export_node(child)end
  end
  return row
 end
 core.safe_file_write(core.get_worldpath()..'/biome_lut.json',core.write_json({root=export_node(source_tree),leaf_count=#nodes},false))
 out.lut_cases={};out.lut_coverage={}
 local function rtz(n)return n<0 and math.ceil(n)or math.floor(n)end
 local covered={}
 for _,node in ipairs(nodes)do
  local coordinates={}
  for axis=1,7 do coordinates[axis]=rtz((node.extents[axis][1]+node.extents[axis][2])/2)end
  local id=mcl_levelgen.rtree_index_closest(coordinates,source_tree)
  out.lut_cases[#out.lut_cases+1]={coordinates=coordinates,biome=id}
  covered[id]=true
 end
 for i=#nodes,1,-1 do
  local row=out.lut_cases[i]
  local id=mcl_levelgen.rtree_index_closest(row.coordinates,source_tree)
  row.reverse_biome=id;covered[id]=true
 end
 for id in pairs(covered)do out.lut_coverage[#out.lut_coverage+1]=id end
 table.sort(out.lut_coverage)
 local positions={
  {0,0,0},{1,1,1},{-1,-1,-1},{3,3,3},{4,4,4},{5,5,5},
  {-3,-3,-3},{-4,-4,-4},{-5,-5,-5},{-9,63,7},{31,-65,-33},
  {-3,60,-3},{4,60,4},{-5,64,-5},{-4,68,-4},{-1,320,-1},{0,321,0},
 }
 for _,y in ipairs({-68,-65,-64,-63,-61,-4,-1,0,1,3,4,63,64,127,128,319,320,321})do
  positions[#positions+1]={-12,y,20}
 end
 local function record(preset,seed,p,target)
  local coordinates=preset:biome_coordinates(p[1],p[2],p[3])
  local id=preset:index_biomes_block(p[1],p[2],p[3])
  local row={seed=seed,position={p[1],p[2],p[3]},coordinates=coordinates,biome=id}
  if target then row.target=target end
  out.cases[#out.cases+1]=row
  return row
 end
 local wanted={Taiga=true,OldGrowthSpruceTaiga=true,OldGrowthPineTaiga=true,BambooJungle=true,MushroomIslands=true,LushCaves=true}
 local scan_seeds={8675309,3228473,1,-1}
 for _,seed in ipairs(out.seeds)do
  local preset=mcl_levelgen.make_overworld_preset(ull(seed),false)
  for _,p in ipairs(positions)do record(preset,seed,p)end
 end
 -- Source-side deterministic discovery: no guessed Minecraft locations are in
 -- the fixture. Concentric square rings retain exact reproducible positions.
 local remaining=6
 for _,seed in ipairs(scan_seeds)do
  if remaining>0 then
   local preset=mcl_levelgen.make_overworld_preset(ull(seed),false)
   local radius=0
   while radius<=262144 and remaining>0 do
    local points={{0,0}}
    if radius>0 then
     points={}
     for d=-radius,radius,256 do
      points[#points+1]={d,-radius};points[#points+1]={d,radius}
      points[#points+1]={-radius,d};points[#points+1]={radius,d}
     end
    end
    for _,xz in ipairs(points)do
     if remaining>0 then
      local p={xz[1],64,xz[2]}
      local id=preset:index_biomes_block(p[1],p[2],p[3])
      if wanted[id] and not out.targets[id]then
       out.targets[id]=record(preset,seed,p,id);remaining=remaining-1
      end
      if not out.targets.LushCaves then
       p={xz[1],0,xz[2]};id=preset:index_biomes_block(p[1],p[2],p[3])
       if id=='LushCaves'then
        out.targets.LushCaves=record(preset,seed,p,id);remaining=remaining-1
       end
      end
     end
    end
    radius=radius+256
   end
  end
 end
 assert(remaining==0,'Deterministic source scan did not cover every target biome')
 core.safe_file_write(core.get_worldpath()..'/biome_reference.json',core.write_json(out,true))
 core.request_shutdown('Biome reference complete',false,0)
end)end)
'''


def main():
    world = Path(tempfile.mkdtemp(prefix='voxey-biome-oracle-'))
    mod = world/'worldmods/biome_oracle'
    mod.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_biome_oracle = true\n')
    (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31619\nserver_announce = false\nenable_ipv6 = false\n')
    (mod/'mod.conf').write_text('name = biome_oracle\ndepends = mcl_levelgen\n')
    (mod/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=600)
    output = world/'biome_reference.json'
    lut_output = world/'biome_lut.json'
    if not output.exists() or not lut_output.exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-6000:]+'\n'+run.stderr[-6000:])
    result = json.loads(output.read_text())
    result['source_hashes'] = {p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in FILES}
    result['license'] = 'GPL-3.0-or-later'
    result['coordinate_order'] = ['temperature','humidity','continentalness','erosion','depth','weirdness','offset']
    lut_result = json.loads(lut_output.read_text())
    lut_result['source_hashes'] = result['source_hashes']
    lut_result['license'] = result['license']
    lut_result['coordinate_order'] = result['coordinate_order']
    (ROOT/'assets/data/biome_reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    (ROOT/'assets/data/biome_lut.json').write_text(json.dumps(lut_result,separators=(',',':'))+'\n')
    print(world)
    print({'cases':len(result['cases']),'targets':sorted(result['targets']),'lut_cases':len(result['lut_cases']),'lut_coverage':len(result['lut_coverage']),'leaves':lut_result['leaf_count']})


if __name__ == '__main__':
    main()
