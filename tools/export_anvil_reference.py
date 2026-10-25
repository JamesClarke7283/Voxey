#!/usr/bin/env python3
"""Run Mineclonia's real anvil update/take handlers against portable fixtures."""
import hashlib
import json
import subprocess
from pathlib import Path
from export_enchanting_reference import lua

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
FILES = ['mods/ITEMS/mcl_anvils/init.lua', 'mods/ITEMS/mcl_enchanting/engine.lua']

HARNESS = r'''
local function copy(v)
 if type(v)~='table' then return v end
 local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t
end
local function json(v)
 if type(v)=='string' then return string.format('%q',v)
 elseif type(v)=='boolean' or type(v)=='number' then return tostring(v)
 elseif type(v)=='table' then
  local s={};if #v>0 then for i=1,#v do s[#s+1]=json(v[i])end;return '['..table.concat(s,',')..']'end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do s[#s+1]=json(k)..':'..json(v[k])end;return '{'..table.concat(s,',')..'}'
 end
 return 'null'
end
local items={};local node_defs={};local callbacks={};local current;local level=100000000
local M={};M.__index=M
function M:get_string(k)return self.values[k] or ''end
function M:set_string(k,v)self.values[k]=v end
function M:get_int(k)return tonumber(self.values[k]) or 0 end
function M:set_int(k,v)self.values[k]=v end
function M:get_inventory()return self.inv end
local ST={};ST.__index=ST
function ST:get_name()return self.name end
function ST:set_name(v)self.name=v or ''end
function ST:get_definition()return items[self.name] or {groups={},stack_max=64}end
function ST:get_meta()return setmetatable({values=self.meta},M)end
function ST:get_count()return self.count end
function ST:set_count(v)self.count=math.max(0,v);if self.count==0 then self.name='' end end
function ST:get_wear()return self.wear end
function ST:set_wear(v)self.wear=math.floor(v)end
function ST:get_stack_max()return self:get_definition().stack_max end
function ST:is_empty()return self.name=='' or self.count==0 end
function ST:take_item(v)self:set_count(self.count-(v or 1))end
local function ItemStack(v)
 if type(v)=='table' then return setmetatable(copy(v),ST)end
 return setmetatable({name=v or '',count=v and v~='' and 1 or 0,wear=0,meta={}},ST)
end
local lib={};for k,v in pairs(table)do lib[k]=v end
lib.copy=copy;lib.indexof=function(t,v)for i,x in ipairs(t)do if x==v then return i end end;return -1 end
lib.merge=function(a,b)local t=copy(a);for k,v in pairs(b)do t[k]=v end;return t end
local m={};for k,v in pairs(math)do m[k]=v end;m.pow=function(a,b)return a^b end;m.random=function()return 100 end
local env={math=m,table=lib,string=string,pairs=pairs,ipairs=ipairs,type=type,tostring=tostring,tonumber=tonumber,
 ItemStack=ItemStack,mcl_enchanting={},mcl_formspec={label_color='',get_itemslot_bg_v4=function()return ''end},
 mcl_colors={RED=''},tt={reload_itemstack_description=function()end},doc={add_entry_alias=function()end},
 screwdriver={rotate_simple=function()end},vector={offset=function()return {}end,new=function()return {}end},
 mcl_sounds={node_sound_metal_defaults=function()return {}end},
 mcl_util={resolve_alias=function(v)return v end,truncate_utf8=function(v,_,limit)return v:sub(1,limit)end,
 drop_items_from_meta_container=function()return function()end end},
 mcl_experience={get_level=function()return level end,set_level=function(_,v)level=v end}}
env.core={registered_items=items,get_current_modname=function()return 'mcl_anvils'end,
 get_translator=function()return function(v)return v end end,formspec_escape=function(v)return v end,colorize=function(_,v)return v end,
 register_on_mods_loaded=function(fn)callbacks[#callbacks+1]=fn end,deserialize=function(v)return type(v)=='table' and copy(v) or nil end,serialize=copy,
 get_item_group=function(n,k)return items[n] and items[n].groups[k] or 0 end,
 is_creative_enabled=function()return false end,register_craft=function()end,register_lbm=function()end,
 register_node=function(n,d)node_defs[n]=d end,get_meta=function()return current end}
assert(load(ENGINE,'engine','t',env))();env.mcl_enchanting.enchantments=DEFINITIONS;env.mcl_enchanting.load_enchantments=function()end
for _,p in ipairs(PROFILES)do
 items[p.name]={groups=p.groups,stack_max=p.stack,type=p.tool and 'tool' or 'craftitem',_repair_material=p.repair}
 if p.enchantable then
  items[p.name]._mcl_enchanting_enchanted_tool=p.book and 'mcl_enchanting:book_enchanted' or p.name..'_enchanted'
  local n=items[p.name]._mcl_enchanting_enchanted_tool;items[n]=copy(items[p.name]);items[n].groups.enchanted=1
  if p.book then items[n].stack_max=1 end
 end
end
assert(load(ANVIL,'anvil','t',env))()
local function stack(slot)
 if not slot or not slot.id or slot.id==0 then return ItemStack('')end
 local p=BYID[slot.id];local s=ItemStack(p.name);s.count=slot.count or 1
 s.wear=math.floor((slot.wear or 0)*65535/(p.span or 65535));s.meta={}
 local data=slot.data or {};s.meta.name=data.custom_name or '';s.meta['mcl_enchanting:pwp']=data.pwp or 0
 if data.enchantments then
  s.meta['mcl_enchanting:enchantments']={}
  for n,v in pairs(data.enchantments)do s.meta['mcl_enchanting:enchantments'][KEYS[n] or n]=v end
  if items[p.name]._mcl_enchanting_enchanted_tool then s.name=items[p.name]._mcl_enchanting_enchanted_tool end
 end
 return s
end
local function native(s)
 if s:is_empty() then return false end
 local p=BYNAME[s.name];local data={};local ench=s.meta['mcl_enchanting:enchantments']
 if ench and next(ench)then data.enchantments={};for k,v in pairs(ench)do data.enchantments[NAMES[k] or k]=v end end
 if (s.meta.name or '')~=''then data.custom_name=s.meta.name end
 if (s.meta['mcl_enchanting:pwp'] or 0)>0 then data.pwp=s.meta['mcl_enchanting:pwp']end
 local v={id=s.name=='mcl_enchanting:book_enchanted' and 791 or p.id,count=s.count,wear=math.ceil(s.wear*(p.span or 65535)/65535)}
 if next(data)then v.data=data end;return v
end
local result={}
for _,case in ipairs(CASES)do
 local before={stack(case.a),stack(case.b)};local counts={before[1].count,before[2].count};local inv={input=before,output={ItemStack('')}}
 function inv:get_stack(n,i)return ItemStack(self[n][i])end
 function inv:set_stack(n,i,s)self[n][i]=ItemStack(s)end
 current=setmetatable({values={set_name=case.name or ''},inv=inv},M);level=100000000
 local player={get_player_name=function()return 'test'end}
 node_defs['mcl_anvils:anvil'].on_metadata_inventory_put({},'input',1,before[1],player)
 local out=inv:get_stack('output',1);local cost=current:get_int('mcl_anvil:xp_cost')
 local value=false
 if not out:is_empty() then
  value={output=native(out),cost=cost,normalized=out:get_wear()}
  node_defs['mcl_anvils:anvil'].on_metadata_inventory_take({},'output',1,out,player)
  value.consume={counts[1]-inv.input[1].count,counts[2]-inv.input[2].count}
 end
 result[#result+1]={case=case,value=value}
end
io.write(json(result))
'''

def export():
    data = json.loads((ROOT/'assets/data/enchanting.json').read_text())
    definitions = {}
    keys = {n:d['source_key'] for n,d in data['definitions'].items()}
    for name, d in data['definitions'].items():
        d = dict(d)
        for f in ['primary','secondary','disallow']:
            d[f] = dict.fromkeys(d[f], True)
        d['incompatible'] = {keys[n]:True for n in d['incompatible']}
        definitions[keys[name]] = d
    profiles=[]
    def profile(id_, name, tags=(), ability=0, span=65535, repair=None, book=False, max_stack=64):
        groups=dict.fromkeys(tags,1);groups['enchantability']=ability
        profiles.append(dict(id=id_,name=name,groups=groups,tool=span!=65535,span=span,repair=repair,stack=max_stack,enchantable=ability!=0,book=book))
    profile(90,'mcl_tools:pick_iron',['pickaxe'],14,251,'mcl_core:iron_ingot',max_stack=1)
    profile(95,'mcl_tools:pick_diamond',['pickaxe'],10,1562,'mcl_core:diamond',max_stack=1)
    profile(80,'mcl_tools:pick_wood',['pickaxe'],15,60,'group:wood',max_stack=1)
    profile(1110,'mcl_tools:pick_gold',['pickaxe'],22,33,'mcl_core:gold_ingot',max_stack=1)
    profile(105,'mcl_armor:chestplate_iron',['armor_torso','combat_armor','combat_armor_chestplate'],9,241,'mcl_core:iron_ingot',max_stack=1)
    profile(813,'mcl_shields:shield',['tool'],-1,337,'group:wood',max_stack=1)
    profile(947,'mcl_tools:mace',['mace','tool'],10,500,'mcl_mobitems:breeze_rod',max_stack=1)
    profile(123,'mcl_tools:shears',['shears','tool'],-1,239,max_stack=1)
    profile(138,'mcl_fire:flint_and_steel',['tool'],-1,65,max_stack=1)
    profile(11580,'mcl_mobitems:carrot_on_a_stick',['tool'],-1,26,max_stack=1)
    profile(11581,'mcl_mobitems:warped_fungus_on_a_stick',['tool'],-1,26,max_stack=1)
    profile(279,'screwdriver:screwdriver',['tool'],-1,200,max_stack=1)
    profile(134,'mcl_bows:bow',['bow','tool'],1,385,max_stack=1)
    profile(126,'mcl_books:book',ability=1,book=True)
    profile(944,'mcl_mobitems:breeze_rod');profile(66,'mcl_core:iron_ingot');profile(67,'mcl_core:diamond');profile(76,'mcl_core:gold_ingot')
    profile(8,'mcl_trees:wood_oak',['wood']);profile(13203,'mcl_trees:wood_bamboo',['wood'])
    profile(264,'mcl_books:written_book',['no_rename'],max_stack=16)
    byid={p['id']:p for p in profiles};byid[791]=byid[126]
    byname={p['name']:p for p in profiles}
    for p in profiles:
        if p['enchantable']:byname['mcl_enchanting:book_enchanted' if p['book'] else p['name']+'_enchanted']=p
    cases=[]
    def item(id_, wear=0, ench=None, pwp=0, count=1, name=''):
        d={}
        if ench is not None:d['enchantments']=ench
        if pwp:d['pwp']=pwp
        if name:d['custom_name']=name
        return dict(id=id_,wear=wear,count=count,data=d)
    def add(a,b=None,name=''):
        cases.append(dict(a=a,b=b or {},name=name))
    add(item(66,count=64),name='Iron stock');add({},item(66,count=12),name='Second slot')
    add(item(66,name='same'),name='same');add(item(66,name='remove'),name='');add(item(66,pwp=10),name='No penalty rename')
    add(item(264),name='Forbidden');add({}, {}, name='Empty')
    for id_,mat,span in [(90,66,251),(95,67,1562),(80,8,60),(1110,76,33),(105,66,241),(813,8,337),(947,944,500)]:
        for wear in [0,1,span//4,span//2,span-1]:
            for count in [1,2,4,12]:
                for reverse in [False,True]:
                    a,b=item(id_,wear,pwp=2),item(mat,count=count,pwp=1)
                    add(b if reverse else a,a if reverse else b)
        add(item(id_,span-1),item(mat,count=4),name='Restored')
    add(item(80,59),item(13203,count=4));add(item(90,200),item(67,count=4))
    for a,b in [({},{}),({'Efficiency':1},{'Efficiency':1}),({'Efficiency':2},{'Efficiency':1}),({'Efficiency':5},{'Efficiency':5}),
                ({'Fortune':1},{'Silk Touch':1}),({'Fortune':1},{'Silk Touch':1,'Unbreaking':2}),({'Sharpness':1},{'Sharpness':1})]:
        for book in [False,True]:
            for wa,wb in [(0,0),(200,100),(200,0)]:
                add(item(90,wa,a,pwp=2),item(791 if book else 90,0 if book else wb,b,pwp=3))
    for a,b in [({'Sharpness':4},{'Sharpness':4}),({'Sharpness':5},{'Sharpness':5}),({'Fortune':1},{'Silk Touch':1}),
                ({'Fortune':1},{'Silk Touch':1,'Unbreaking':3}),({}, {'Mending':1})]:
        add(item(791,ench=a),item(791,ench=b));add(item(126,count=12),item(791,ench=b))
    add(item(134,200,{'Power':1}),item(134,100,{'Power':2}))
    add(item(791,ench={'Sharpness':1},pwp=6),item(791,ench={'Sharpness':1},pwp=6))
    add(item(123,100),item(791,ench={'Efficiency':4}))
    for id_ in [138,11580,11581,279]:add(item(id_),item(791,ench={'Unbreaking':2}))
    add(item(947,300,{'Smite':1}),item(791,ench={'Density':2,'Unbreaking':1}))
    add(item(105,100,{'Protection':2}),item(791,ench={'Fire Protection':2,'Unbreaking':2}))
    add(item(791,ench={'Aqua Affinity':1}),item(791,ench={'Aqua Affinity':1}))
    values=dict(ENGINE=(SOURCE/FILES[1]).read_text(),ANVIL=(SOURCE/FILES[0]).read_text(),DEFINITIONS=definitions,
                PROFILES=profiles,BYID=byid,BYNAME=byname,KEYS=keys,NAMES={v:k for k,v in keys.items()},CASES=cases)
    program='\n'.join('local '+k+'='+lua(v) for k,v in values.items())+'\n'+HARNESS
    run=subprocess.run(['lua','-'],input=program,text=True,capture_output=True)
    if run.returncode:raise RuntimeError(run.stderr)
    result=dict(cases=json.loads(run.stdout),license='GPL-3.0-or-later',source_hashes={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in FILES})
    (ROOT/'assets/data/anvil_reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    print('Exported',len(cases),'actual source anvil update/take cases')

if __name__=='__main__':export()
