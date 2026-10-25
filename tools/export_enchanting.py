#!/usr/bin/env python3
"""Read completed Luanti registrations and exercise the actual enchanting API."""
import argparse, hashlib, json, subprocess, tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
BODY=r'''
local names=NATIVE_NAMES;local labels=LABELS;local stream=1
local function random(a,b)
 stream=(stream*1664525+1013904223)%4294967296
 if not a then return stream/4294967295 end
 if not b then b=a;a=1 end
 return a+stream%(b-a+1)
end
local function keys(t)local out={};for k,v in pairs(t or {})do if v then out[#out+1]=k end end;table.sort(out);return out end
local function array(t)local out={};for _,v in ipairs(t or {})do out[#out+1]={v.x,v.y,v.z}end;return out end
core.register_on_mods_loaded(function()core.after(0,function()
 local lib=mcl_enchanting;local sorted=keys(lib.enchantments)
 local out={order={},definitions={},profiles={},materials={tool={},armor={}},bookshelf_positions=array(lib.bookshelf_positions),air_positions=array(lib.air_positions)}
 local ref={support={},applications={},levels={},rolls={},offers={}}
 for name,definition in pairs(core.registered_items)do
  local tool=name:match('^mcl_tools:pick_(%a+)$');local armor=name:match('^mcl_armor:helmet_(%a+)$')
  if tool then out.materials.tool[tool]=core.get_item_group(name,'enchantability')end
  if armor then out.materials.armor[armor]=core.get_item_group(name,'enchantability')end
 end
 local relevant={}
 for _,key in ipairs(sorted)do
  local d=lib.enchantments[key];local label=labels[key]or key;labels[key]=label;out.order[#out.order+1]=label
  local incompatible={};for _,k in ipairs(keys(d.incompatible))do incompatible[#incompatible+1]=labels[k]or k end
  out.definitions[label]={source_key=key,name=label,max_level=d.max_level,primary=keys(d.primary),secondary=keys(d.secondary),disallow=keys(d.disallow),incompatible=incompatible,treasure=d.treasure==true,tradable=d.tradable==true,curse=d.curse==true,requires_tool=d.requires_tool==true,weight=d.weight,power_range_table=d.power_range_table,anvil_item_factor=d.anvil_item_factor or 1,anvil_book_factor=d.anvil_book_factor or 1}
  for _,field in ipairs({'primary','secondary','disallow'})do for tag in pairs(d[field]or{})do relevant[tag]=true end end
 end
 local function profile(name)
  local d=core.registered_items[name];if not d then return nil end
  local groups={};for tag in pairs(relevant)do local value=core.get_item_group(name,tag);if value~=0 then groups[tag]=value end end
  return {name=name,ability=core.get_item_group(name,'enchantability'),tool=d.type=='tool',book=lib.is_book(name),enchanted=lib.is_enchanted(name),groups=groups}
 end
 local function ench(st)local result={};for k,n in pairs(lib.get_enchantments(st))do result[labels[k]or k]=n end;return result end
 lib.random=function(_,a,b)return random(a,b)end
 math.random=random
 lib.get_enchantment_description=function(key,level)local d=lib.enchantments[key];return labels[key]..(d.max_level>1 and ' '..({'','I','II','III','IV','V'})[level+1]or'')end
 local ids={};for id in pairs(names)do ids[#ids+1]=id end;table.sort(ids,function(a,b)return tonumber(a)<tonumber(b)end)
 for _,id in ipairs(ids)do
  local name=names[id];local base=profile(name)
  if base then
   local altered_name=lib.get_enchanted_itemstring(name);local altered=altered_name and profile(altered_name)or base
   out.profiles[id]={base=base,enchanted=altered}
   for _,variant in ipairs({false,true})do
    local target=variant and altered.name or name;local support={};local levels={}
    for _,key in ipairs(sorted)do
     local ok,primary=lib.item_supports_enchantment(target,key);support[#support+1]=ok and (primary and 2 or 1)or 0
     local d=lib.enchantments[key];local values={};for _,n in ipairs({0,1,d.max_level,d.max_level+1})do values[#values+1]=lib.can_enchant(ItemStack(target),key,n)==true end;levels[#levels+1]=values
    end
    ref.support[#ref.support+1]={id=tonumber(id),variant=variant,values=support}
    if base.ability~=0 then ref.levels[#ref.levels+1]={id=tonumber(id),variant=variant,values=levels}end
   end
   if base.ability~=0 then
    for cur=0,#sorted do
     local st=ItemStack(name);local current={}
     if cur>0 then lib.enchant(st,sorted[cur],1);current[labels[sorted[cur]]]=1 end
     local allowed='';for _,key in ipairs(sorted)do allowed=allowed..(lib.can_enchant(st,key,1)==true and '1'or'0')end
     ref.applications[#ref.applications+1]={id=tonumber(id),current=current,allowed=allowed}
    end
   end
   if base.ability~=0 then
    for _,shelves in ipairs({0,1,5,15})do for _,seed in ipairs({1,7,12345})do
     stream=seed;local slots={false,false,false}
     if lib.can_enchant_freshly(name)and not lib.not_enchantable_on_enchanting_table(name)then slots=lib.generate_random_table_slots(ItemStack(name),shelves)end
     for _,row in ipairs(slots)do if row then local translated={};for k,n in pairs(row.enchantments)do translated[labels[k]or k]=n end;row.enchantments=translated;row.glyphs=nil end end
     ref.offers[#ref.offers+1]={id=tonumber(id),shelves=shelves,seed=seed,value=slots,state=stream}
    end end
   end
   if base.ability>0 then
    for _,mode in ipairs({{false,false},{true,false},{true,true}})do for _,state in ipairs({0,1,2})do for _,power in ipairs({1,7,15,30,50})do for _,seed in ipairs({1,19,1729,91377})do
     local st=ItemStack(name);local current={};local ignore=state==2
     if state>0 then lib.enchant(st,'unbreaking',1);current.Unbreaking=1 end
     stream=seed;local value,description=lib.generate_random_enchantments(st,power,mode[1],mode[2],ignore)
     local translated={};for k,n in pairs(value or{})do translated[labels[k]or k]=n end
     ref.rolls[#ref.rolls+1]={id=tonumber(id),current=current,ignore=ignore,power=power,treasure=mode[1],unrestricted=mode[2],seed=seed,state=stream,value=value and {enchantments=translated,description=description}or false}
    end end end end
   end
  else out.profiles[id]={missing=name}end
 end
 core.safe_file_write(core.get_worldpath()..'/registry.json',core.write_json(out,true))
 core.safe_file_write(core.get_worldpath()..'/reference.json',core.write_json(ref,true))
 core.request_shutdown('Registered enchanting export complete',false,0)
end)end)
'''
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--project',default=str(ROOT));parser.add_argument('--bindings');args=parser.parse_args()
    if args.bindings:
        bindings=json.loads(Path(args.bindings).read_text())
    else:
        output=Path(tempfile.mktemp(prefix='voxey-enchanting-bindings-',suffix='.json'))
        run=subprocess.run(['godot','--headless','--path',args.project,'--script','res://tests/enchanting_registry_bindings.gd','--',str(output)],capture_output=True,text=True,timeout=120)
        if run.returncode or not output.exists() or 'SCRIPT ERROR:' in run.stdout+run.stderr:raise RuntimeError((run.stdout+run.stderr)[-3500:])
        bindings=json.loads(output.read_text())
    prior=json.loads((ROOT/'assets/data/enchanting.json').read_text()); labels={d['source_key']:name for name,d in prior['definitions'].items()}
    world=Path(tempfile.mkdtemp(prefix='voxey-enchant-registry-'));mod=world/'worldmods/enchant_registry';mod.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
    (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31513\nserver_announce = false\nenable_ipv6 = false\n')
    (mod/'mod.conf').write_text('name = enchant_registry\ndepends = mcl_enchanting, mobs_mc\n')
    (mod/'init.lua').write_text(BODY.replace('NATIVE_NAMES',lua(bindings['bindings'])).replace('LABELS',lua(labels)))
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=240)
    if not (world/'registry.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3500:])
    data=json.loads((world/'registry.json').read_text()); reference=json.loads((world/'reference.json').read_text())
    for definition in data['definitions'].values():
        for field in ('primary','secondary','disallow','incompatible'):
            definition[field]=definition.get(field) or []
    for pair in data['profiles'].values():
        for key in ('base','enchanted'):
            if key in pair: pair[key]['groups']=pair[key].get('groups') or {}
    hashes={str(p.relative_to(SOURCE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((SOURCE/'mods').rglob('*.lua')) if 'enchant' in p.read_text(errors='replace') or 'register_set' in p.read_text(errors='replace')}
    data.update(license='GPL-3.0-or-later',source_hashes=hashes,native_extensions=bindings['unmapped'])
    reference.update(source_hashes=hashes,order=data['order'])
    (ROOT/'assets/data/enchanting.json').write_text(json.dumps(data,indent=2)+'\n')
    (ROOT/'assets/data/enchanting_registry_reference.json').write_text(json.dumps(reference,separators=(',',':'))+'\n')
    plain=[]
    for row in reference['rolls']:
        if not row['current'] and not row['ignore']:
            row=dict(row);row['no_reduced_bonus']=row.pop('unrestricted');plain.append(row)
    compatibility={'rolls':plain,'offers':reference['offers'],'source_hashes':hashes}
    (ROOT/'assets/data/enchanting_reference.json').write_text(json.dumps(compatibility,separators=(',',':'))+'\n')
    print('Registered:',len(data['definitions']),'definitions,',len(data['profiles']),'item profiles;', {k:len(v) for k,v in reference.items() if isinstance(v,list)})
if __name__=='__main__':main()
