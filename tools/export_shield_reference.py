#!/usr/bin/env python3
"""Exercise the installed Mineclonia shield decoration callbacks in Luanti."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
PATHS = ['mods/ITEMS/mcl_shields/init.lua', 'mods/ITEMS/mcl_banners/init.lua',
         'mods/ENTITIES/mobs_mc/villager.lua', 'mods/MAPGEN/mcl_nether_fortresses/init.lua']
BODY = r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local colors={'white','grey','silver','black','yellow','orange','red','magenta','purple','blue','cyan','lime','green','pink','light_blue','brown'}
 local unis,uniids,shieldcolors={},{},{}
 for i,c in ipairs(colors)do
  unis[i]='unicolor_'..mcl_dyes.colors[c].unicolor;uniids[unis[i]]=i-1
  shieldcolors['mcl_shields:shield_'..c]=i-1;shieldcolors['mcl_shields:shield_'..c..'_enchanted']=i-1
 end
 local ench={Unbreaking='unbreaking',Mending='mending'}
 local function make(v)
  if not v or v.id==0 then return ItemStack('')end
  local d=v.data or {};local name
  if v.id==813 then name='mcl_shields:shield'..(d.shield_color and '_'..colors[d.shield_color+1]or'')..(d.enchantments and '_enchanted'or'')
  elseif v.id>=635 and v.id<651 then name='mcl_banners:banner_item_'..colors[v.id-634]
  else name='mcl_core:stone'end
  local s=ItemStack(name);s:set_count(v.count or 1);s:set_wear(v.wear or 0)
  local layers={};for _,l in ipairs(d.layers or {})do layers[#layers+1]={pattern=l.pattern,color=unis[l.color+1]}end
  mcl_banners.write_layers(s:get_meta(),layers);s:get_meta():set_string('name',d.custom_name or '')
  s:get_meta():set_int('mcl_enchanting:pwp',7)
  if d.enchantments then local e={};for k,n in pairs(d.enchantments)do e[ench[k]]=n end;mcl_enchanting.set_enchantments(s,e)end
  return s
 end
 local function record(s)
  if s:is_empty()then return {id=0,count=0,wear=0}end
  local d={shield_color=assert(shieldcolors[s:get_name()],s:get_name())}
  local layers={};for _,l in ipairs(mcl_banners.read_layers(s:get_meta()))do layers[#layers+1]={pattern=l.pattern,color=uniids[l.color]}end
  if #layers>0 then d.layers=layers end
  local name=s:get_meta():get_string('name');if name~=''then d.custom_name=name end
  local ee=mcl_enchanting.get_enchantments(s);local e={};for k,v in pairs(ench)do if ee[v]then e[k]=ee[v]end end
  if next(e)then d.enchantments=e end
  assert(s:get_meta():get_int('mcl_enchanting:pwp')==0,'source copied prior work')
  return {id=813,count=s:get_count(),wear=s:get_wear(),data=d}
 end
 local result={cases={},limit=mcl_banners.max_craftable_layers}
 local function run(input,label)
  local grid={};for i=1,9 do grid[i]=make(input[i])end
  local inv={get_size=function()return 9 end};local player={get_inventory=function()return inv end}
  local out=core.get_craft_result({method='normal',width=3,items=grid}).item
  for _,fn in ipairs(core.registered_craft_predicts)do if debug.getinfo(fn,'S').source:find('/mcl_shields/')then out=fn(out,player,grid,inv)or out end end
  local expected=record(out);local remaining={}
  if not out:is_empty()then
   local old={};for i=1,9 do old[i]=ItemStack(grid[i]);grid[i]:take_item()end
   for _,fn in ipairs(core.registered_on_crafts)do if debug.getinfo(fn,'S').source:find('/mcl_shields/')then out=fn(out,player,old,inv)or out end end
   expected=record(out)
  end
  local inputs={};for i=1,9 do remaining[i]=grid[i]:get_count();inputs[i]=input[i]or{id=0,count=0,wear=0}end
  result.cases[#result.cases+1]={label=label,input=inputs,output=expected,remaining=remaining}
 end
 local profiles={{wear=0},{wear=97,banner='Banner name',ench=true},{wear=335,shield='Shield name'},{wear=31,banner='Other name',shield='My shield',ench=true},{wear=0,ench=true},{wear=84,banner='Same',shield='Same'}}
 for color=0,15 do for _,n in ipairs({0,1,6,12,13})do for k,p in ipairs(profiles)do for _,positions in ipairs({{1,2},{9,5}})do
  local layers={};for i=1,n do layers[#layers+1]={pattern=({"border","rhombus","stripe_center"})[(i-1)%3+1],color=(color+i)%16}end
  local sd={pwp=7};if p.shield then sd.custom_name=p.shield end;if p.ench then sd.enchantments={Unbreaking=2,Mending=1}end
  local bd={layers=layers};if p.banner then bd.custom_name=p.banner end
  local input={};input[positions[1]]={id=813,count=1,wear=p.wear,data=sd};input[positions[2]]={id=635+color,count=3,wear=0,data=bd}
  run(input,color..':'..n..':'..k..':'..positions[1])
 end end end end
 for color=0,15 do run({{id=813,count=1,wear=17,data={shield_color=color}},{id=635,count=1}},'already-coloured:'..color)end
 run({{id=813,count=1},{id=635,count=1},{id=636,count=1}},'two banners')
 run({{id=813,count=1},{id=813,count=1},{id=635,count=1}},'two shields')
 run({{id=813,count=1},{id=635,count=1},{id=3,count=1}},'extra item')
 local globe=mobs_mc.villager_trades.cartographer[5][1]
 result.globe={cost=globe[1][2],count=globe[2][2],stock=globe[3],xp=globe[4]}
 for _,group in ipairs(mcl_structures.registered_structures.nether_bulwark.loot['mcl_chests:chest_small'])do
  for _,entry in ipairs(group.items)do if entry.itemstring=='mcl_banners:pattern_piglin'then result.piglin={weight=entry.weight,stacks_min=group.stacks_min,stacks_max=group.stacks_max}end end
 end
 assert(result.piglin,'source Piglin reward missing')
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true));core.request_shutdown('Shield reference complete',false,0)
end)end)
'''


def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-shield-oracle-'))
    fixture = world/'worldmods'/'voxey_shield_fixture'
    fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_shield_fixture = true\n')
    # Voxey's current bastion is the source's legacy nether_bulwark. Keep that
    # generator enabled in this isolated oracle world so its loot is registered.
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31496\nserver_announce = false\nenable_ipv6 = false\nmcl_levelgen_enable_ersatz = false\n')
    (fixture/'mod.conf').write_text('name = voxey_shield_fixture\ndepends = mcl_shields, mobs_mc\n')
    (fixture/'init.lua').write_text(BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world/'oracle.conf'), '--logfile', str(world/'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world/'oracle.json').exists():
        raise RuntimeError(str(world)+'\n'+run.stdout[-500:]+'\n'+run.stderr[-3000:])
    result = json.loads((world/'oracle.json').read_text())
    result['source_hashes'] = {p: hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    (ROOT/'assets/data/shield_reference.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')
    print('Exported', len(result['cases']), 'shield crafts; Globe trade:', result['globe'])


if __name__ == '__main__':
    export()
