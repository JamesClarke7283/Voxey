#!/usr/bin/env python3
"""Exercise the installed game's smithing inventory, registration and callbacks."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1]; SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
core.register_on_mods_loaded(function()core.after(0,function()
 local name='mcl_smithing_table:table';local def=core.registered_nodes[name]
 local pos=vector.new(0,40,0);core.get_voxel_manip():read_from_map(vector.subtract(pos,16),vector.add(pos,16))
 local out={profiles={},cases={},minerals={},templates={},permissions={},sorter={},node={hardness=def._mcl_hardness,burntime=def._mcl_burntime,recipes=core.get_all_craft_recipes(name)}}
 local unlocked={};local fields={};local player={get_player_name=function()return 'smithing_oracle'end,get_meta=function()return{get_string=function(_,k)return fields[k]or''end,set_string=function(_,k,v)fields[k]=v end}end}
 awards.unlock=function(_,award)unlocked[#unlocked+1]=award end;mcl_achievements.award_unlocked=function()return false end
 local protected=false;core.is_protected=function()return protected end;core.record_protection_violation=function()end
 local lists={'upgrade_item','mineral','template','upgraded_item'}
 local function stack(r)
  if not r or not r.name then return ItemStack('')end
  local s=ItemStack(r.name);s:set_count(r.count or 1)
  if r.enchanted then local n=mcl_enchanting.get_enchanted_itemstring(s:get_name());if n then s:set_name(n)end end
  s:set_wear(r.wear or 0);s:get_meta():set_string('name',r.label or 'Remembered name');s:get_meta():set_string('junk','kept');s:get_meta():set_int('mcl_enchanting:pwp',3)
  if r.enchanted and mcl_enchanting.is_enchanted(s:get_name()) then mcl_enchanting.set_enchantments(s,{unbreaking=2,curse_of_vanishing=1})end
  if r.trim then mcl_armor.trim(s,r.trim,ItemStack(r.trim_material or 'mcl_core:gold_ingot'))end
  return s
 end
 local function snap(s)
  return {name=s:get_name(),count=s:get_count(),wear=s:get_wear(),label=s:get_meta():get_string('name'),junk=s:get_meta():get_string('junk'),pwp=s:get_meta():get_int('mcl_enchanting:pwp'),enchants=mcl_enchanting.get_enchantments(s),trim=s:get_meta():get_string('mcl_armor:trim_overlay'):match('%((.-)%_')or'',material=s:get_meta():get_string('mcl_armor:trim_material')}
 end
 local function setup(a,m,t)
  core.set_node(pos,{name=name});local inv=core.get_meta(pos):get_inventory()
  inv:set_stack(lists[1],1,stack(a));inv:set_stack(lists[2],1,stack(m));inv:set_stack(lists[3],1,stack(t));def.on_metadata_inventory_put(pos,'upgrade_item',1,inv:get_stack('upgrade_item',1));return inv
 end
 local function run(a,m,t)
  unlocked={};fields={};local inv=setup(a,m,t);local result=inv:get_stack('upgraded_item',1)
  local row={a=a or{},m=m or{},t=t or{},preview=snap(result)}
  if not result:is_empty()then inv:set_stack('upgraded_item',1,'');def.on_metadata_inventory_take(pos,'upgraded_item',1,result,player)end
  row.after={};for _,l in ipairs(lists)do row.after[#row.after+1]=snap(inv:get_stack(l,1))end
  row.awards=unlocked;row.distinct=core.deserialize(fields['mcl_smithing_table:achievement_trims']or'')or{}
  out.cases[#out.cases+1]=row
 end
 local seen={};local armors={};local upgrades={};local bound={}
 for id,n in pairs(BINDINGS)do
  local d=core.registered_items[n]
  if d then
   local profiles={}
   for _,v in ipairs({'base','enchanted'})do
    local variant=v=='enchanted'and(mcl_enchanting.get_enchanted_itemstring(n)or n)or n
    local s=ItemStack(variant);local vd=s:get_definition();local allowed={}
    for _,l in ipairs(lists)do allowed[l]=def.allow_metadata_inventory_put(pos,l,1,s,player)>0 end
    profiles[v]={name=variant,allowed=allowed,upgradable=vd._mcl_upgradable or false,armor=vd._mcl_armor_element or'',armor_texture=not not vd._mcl_armor_texture,blacklisted=not not mcl_armor.trims.blacklisted[variant],color=vd._mcl_armor_trim_color or''}
   end
   out.profiles[id]=profiles;bound[n]=true
   if not seen[n]then
    seen[n]=true
    if d._mcl_upgradable then upgrades[#upgrades+1]=n end
    if d._mcl_armor_element and not mcl_armor.trims.blacklisted[n]then armors[#armors+1]=n end
    if profiles.base.allowed.mineral then out.minerals[n]=d._mcl_armor_trim_color end
    if core.get_item_group(n,'smithing_template')>0 then out.templates[n]=mcl_armor.trims.overlays[n:gsub('mcl_armor:','')]end
   end
  end
 end
 for _,n in ipairs(upgrades)do for _,wear in ipairs({0,12345,65534})do for _,enchanted in ipairs({false,true})do
  run({name=n,wear=wear,enchanted=enchanted},{name='mcl_nether:netherite_ingot',count=3},{name='mcl_nether:netherite_upgrade_template',count=2})
 end end end
 for _,n in ipairs(armors)do
  for t in pairs(out.templates)do for m in pairs(out.minerals)do
   run({name=n,wear=32000,enchanted=true},{name=m,count=3},{name=t,count=2})
  end end
  run({name=n,wear=12345,trim='sentry'},{name='mcl_core:gold_ingot'},{name='mcl_armor:sentry'})
  run({name=n,wear=54321,trim='sentry',enchanted=true},{name='mcl_core:iron_ingot'},{name='mcl_armor:sentry'})
  run({name=n,wear=24000,trim='sentry',enchanted=true},{name='mcl_nether:netherite_ingot'},{name='mcl_nether:netherite_upgrade_template'})
 end
 for _,n in ipairs({'mcl_tools:pick_iron','mcl_armor:elytra','mcl_enchanting:book_enchanted','mcl_core:dirt'})do
  run({name=n},{name='mcl_core:gold_ingot'},{name='mcl_armor:sentry'})
  run({name=n},{name='mcl_core:diamond'},{name='mcl_nether:netherite_upgrade_template'})
 end
 for _,list in ipairs(lists)do for _,guard in ipairs({false,true})do
  protected=guard;local inv=setup({name='mcl_armor:helmet_diamond'},{name='mcl_nether:netherite_ingot'},{name='mcl_nether:netherite_upgrade_template'})
  out.permissions[#out.permissions+1]={list=list,protected=guard,take=def.allow_metadata_inventory_take(pos,list,1,ItemStack('mcl_core:diamond 3'),player),move=def.allow_metadata_inventory_move()}
 end end
 protected=false
 for n in pairs(bound)do
  local inv=setup();local s=ItemStack(n);s:set_count(s:get_stack_max())
  local allowed=def.allow_metadata_inventory_put(pos,'sorter',1,s,player)
  local row={name=n,empty=allowed,blocked=0,partial=0}
  if allowed>0 then
   inv:set_stack('sorter',1,s);def.on_metadata_inventory_put(pos,'sorter',1,s)
   for _,l in ipairs(lists)do if l~='upgraded_item'and not inv:get_stack(l,1):is_empty()then row.target=l;row.blocked=def.allow_metadata_inventory_put(pos,'sorter',1,s,player);local almost=inv:get_stack(l,1);almost:take_item(1);inv:set_stack(l,1,almost);row.partial=def.allow_metadata_inventory_put(pos,'sorter',1,s,player)end end
  end
  out.sorter[#out.sorter+1]=row
 end
 core.safe_file_write(core.get_worldpath()..'/result.json',core.write_json(out,true));core.request_shutdown('Smithing reference complete',false,0)
end)end)
'''
def main():
 bindings=json.loads((ROOT/'assets/data/stonecutting_reference.json').read_text())['bindings']
 keys=['sentry','dune','coast','wild','tide','ward','vex','rib','snout','eye','spire','silence','wayfinder','bolt','flow','host','raiser']
 bindings.update({str(11490+i):'mcl_armor:'+key for i,key in enumerate(keys)})
 world=Path(tempfile.mkdtemp(prefix='voxey-smithing-oracle-'));mod=world/'worldmods/smithing_oracle';mod.mkdir(parents=True)
 (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31520\nserver_announce = false\nenable_ipv6 = false\n')
 (mod/'mod.conf').write_text('name = smithing_oracle\ndepends = mcl_smithing_table\n');(mod/'init.lua').write_text('local BINDINGS='+lua(bindings)+'\n'+BODY)
 run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=240)
 if not(world/'result.json').exists():raise RuntimeError(str(world)+'\n'+run.stdout[-5000:]+run.stderr[-5000:])
 data=json.loads((world/'result.json').read_text());data['source_hashes']={str(p.relative_to(SOURCE)):hashlib.sha256(p.read_bytes()).hexdigest()for p in sorted((SOURCE/'mods').rglob('*.lua'))};data['license']='GPL-3.0-or-later'
 (ROOT/'assets/data/smithing_reference.json').write_text(json.dumps(data,indent=2)+'\n')
 runtime={k:data[k]for k in ['profiles','minerals','templates','source_hashes','license']}
 (ROOT/'assets/data/smithing.json').write_text(json.dumps(runtime,indent=2)+'\n')
 print(world);print('Profiles',len(data['profiles']),'cases',len(data['cases']),'minerals',len(data['minerals']),'templates',len(data['templates']))
if __name__=='__main__':main()
