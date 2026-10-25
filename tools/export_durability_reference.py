#!/usr/bin/env python3
"""Run the installed Mineclonia game and real Luanti ItemStacks as a durability oracle."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
from export_enchanting_reference import lua

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
PATHS=['mods/ITEMS/mcl_enchanting/enchantments.lua','mods/ITEMS/mcl_armor/damage.lua','mods/CORE/mcl_util/item.lua','mods/ITEMS/mcl_enchanting/groupcaps.lua']

def callback(path,start,end):
    text=(SOURCE/path).read_text();a=text.index(start)+len(start);b=text.index(end,a)
    return text[a:b]+'\nend'

BODY=r'''
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local stream=1
local function random(a,b)
 stream=(stream*1664525+1013904223)%4294967296
 if not a then return stream/4294967295 end
 if not b then b=a;a=1 end
 return a+stream%(b-a+1)
end
local names={};local profiles={};local ids={}
local function collect_profiles()
for _,p in ipairs(PROFILES)do
 if core.registered_items[p.name] then
  names[p.id]=p.name;ids[p.name]=p.id
  local st=ItemStack(p.name);local groups=st:get_definition().groups
  local uses={};for n=0,3 do local s=ItemStack(st);if n>0 then mcl_enchanting.enchant(s,'unbreaking',n)end;uses[#uses+1]=mcl_util.calculate_durability(s)end
  profiles[#profiles+1]={id=p.id,name=p.name,span=p.span,uses=uses,armor=(groups.mcl_armor_uses or 0)>0,elytra=(groups.elytra or 0)>0,
   points=groups.mcl_armor_points or 0,toughness=groups.mcl_armor_toughness or 0}
 else error('Missing source item '..p.name)end
end
end
local function stack(p)
 if not p or not p.id then return ItemStack('')end
 local s=ItemStack(names[p.id]);s:set_wear(p.normalized or 0)
 for n,v in pairs(p.enchantments or {})do mcl_enchanting.enchant(s,n,v)end
 local d=s:get_definition();d._on_break=nil
 return s
end
local function inv_for(slots)
 local lists={main={stack(slots[1])},armor={ItemStack(''),stack(slots[2]),stack(slots[3]),stack(slots[4]),stack(slots[5])},offhand={stack(slots[6])}}
 return {lists=lists,get_stack=function(self,l,i)return ItemStack(self.lists[l][i] or '')end,
  set_stack=function(self,l,i,s)self.lists[l][i]=ItemStack(s)end}
end
local function wear(s)return s:is_empty() and -1 or s:get_wear()end
local function snapshot(inv)return {wear(inv.lists.main[1]),wear(inv.lists.armor[2]),wear(inv.lists.armor[3]),wear(inv.lists.armor[4]),wear(inv.lists.armor[5]),wear(inv.lists.offhand[1])}end
local function player(inv)return {is_player=function()return true end,get_inventory=function()return inv end,get_wield_index=function()return 1 end,get_luaentity=function()return nil end}end
core.register_on_mods_loaded(function()
 core.after(0,function()
  collect_profiles()
  local old_random=math.random;math.random=random
  local result={profiles=profiles,mending={},wear={},armor={}}
  for _,p in ipairs(profiles)do
   for level=0,3 do
    for _,initial in ipairs({0,12000,32767,65000})do
     for _,use in ipairs({1,2,7})do
      local st=stack({id=p.id,normalized=initial,enchantments=level>0 and {unbreaking=level} or {}})
      local row={id=p.id,level=level,initial=initial,use=use,steps={}}
      for i=1,8 do mcl_util.use_item_durability(st,use);row.steps[#row.steps+1]=wear(st);if st:is_empty()then break end end
      result.wear[#result.wear+1]=row
     end
    end
   end
  end
  for _,case in ipairs(MENDING)do
   local inv=inv_for(case.slots);stream=case.seed
   local remaining=mend(player(inv),case.xp)
   result.mending[#result.mending+1]={case=case,remaining=remaining,wear=snapshot(inv),state=stream}
  end
  local original_update=mcl_armor.update;local original_deal=mcl_util.deal_damage
  mcl_armor.update=function()end
  local order={};for _,element in pairs(mcl_armor.elements)do order[#order+1]=element.index-1 end;result.order=order
  for _,case in ipairs(ARMOR)do
   local inv=inv_for(case.slots);local reflected=0;local gone=false
   mcl_util.deal_damage=function(_,damage)reflected=reflected+damage;gone=case.remove_source or false end
   stream=case.seed
   local source=case.source and {get_pos=function()if not gone then return {x=0,y=0,z=0}end end} or nil
   local damage=armor_damage(player(inv),case.damage,{type=case.reason,flags=case.flags,source=source})
   result.armor[#result.armor+1]={case=case,damage=damage or case.damage,reflected=reflected,wear=snapshot(inv),state=stream}
  end
  mcl_armor.update=original_update;mcl_util.deal_damage=original_deal;math.random=old_random
  core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(result,true))
  core.request_shutdown('Durability oracle complete',false,0)
 end)
end)
'''

def export():
    profiles=[]
    def add(id_,name,span):profiles.append(dict(id=id_,name=name,span=span))
    spans=[60,132,251,1562,2031]
    for i,mat in enumerate(['wood','stone','iron','diamond','netherite']):
        for j,tool in enumerate(['pick','axe','shovel','sword','hoe']):
            id_=80+i*5+j if i<4 else 1090+j
            add(id_,('mcl_farming:hoe_' if tool=='hoe' else 'mcl_tools:'+tool+'_')+mat,spans[i])
    for j,tool in enumerate(['pick','axe','shovel','sword','hoe']):add(1110+j,('mcl_farming:hoe_' if tool=='hoe' else 'mcl_tools:'+tool+'_')+'gold',33)
    for j,tool in enumerate(['pick','axe','shovel','sword','hoe']):add(11592+j,('mcl_farming:hoe_' if tool=='hoe' else 'mcl_tools:'+tool+'_')+'copper',191)
    factors=[.6857,1,.9375,.8125]
    for i,mat in enumerate(['leather','iron','gold','diamond','netherite','chain']):
        base=[80,240,112,528,556,240][i]
        for j,part in enumerate(['helmet','chestplate','leggings','boots']):
            id_=100+i*4+j if i<4 else 1095+j if i==4 else 817+j
            add(id_,'mcl_armor:'+part+'_'+mat,[381,556,521,451][j] if i==4 else int(base*factors[j])+1)
    for id_,name,span in [(277,'mcl_armor:elytra',433),(134,'mcl_bows:bow',385),(789,'mcl_fishing:fishing_rod',65),(790,'mcl_bows:crossbow',465),(123,'mcl_tools:shears',239),(813,'mcl_shields:shield',337),(947,'mcl_tools:mace',500),(138,'mcl_fire:flint_and_steel',65),(11580,'mcl_mobitems:carrot_on_a_stick',26),(11581,'mcl_mobitems:warped_fungus_on_a_stick',26),(279,'screwdriver:screwdriver',200)]:add(id_,name,span)
    for j,part in enumerate(['helmet','chestplate','leggings','boots']):
        add(11568+j,'mcl_armor:'+part+'_copper',int(176*factors[j])+1)
    def item(id_,wear=12000,**enchantments):return dict(id=id_,normalized=wear,enchantments=enchantments)
    mending=[]
    for p in profiles:
        for level in [0,1,3]:
            for xp in [1,3,20]:
                mending.append(dict(slots=[item(p['id'],3200,mending=1,unbreaking=level),{},{},{},{},{}],xp=xp,seed=73))
    six=[item(95,mending=1),item(112,mending=1),item(113,mending=1,unbreaking=3),item(114,mending=1),item(115,mending=1),item(813,mending=1)]
    for seed in range(1,19):mending.append(dict(slots=six,xp=4,seed=seed))
    mending.append(dict(slots=[{},{},{},{},{},{}],xp=7,seed=1))
    armor=[]
    for seed in [1,7,73,991]:
        for damage in [0,1,8,25]:
            for reason,flags in [('mob',{}),('fall',{'bypasses_armor':True}),('on_fire',{'bypasses_armor':True,'is_fire':True}),('arrow',{'is_projectile':True}),('starve',{'bypasses_armor':True,'bypasses_magic':True}),('thorns',{'is_magic':True})]:
                slots=[{},item(112,unbreaking=3,thorns=3,protection=2),item(113,unbreaking=2,thorns=2,blast_protection=2),item(114,thorns=1,projectile_protection=3),item(115,unbreaking=1,thorns=3,feather_falling=4),{}]
                armor.append(dict(slots=slots,damage=damage,reason=reason,flags=flags,source=True,seed=seed))
    armor += [dict(case,remove_source=True) for case in armor if case['reason']=='mob' and case['damage']==25]
    text=(SOURCE/PATHS[1]).read_text();wear=text[:text.index('mcl_armor.use_durability =')]
    mending_cb=callback(PATHS[0],'mcl_experience.register_on_add_xp(', '\nend, 0)')
    armor_cb=callback(PATHS[1],'mcl_damage.register_modifier(', '\nend, 0)')
    prefix='local PROFILES='+lua(profiles)+'\nlocal MENDING='+lua(mending)+'\nlocal ARMOR='+lua(armor)+'\n'+wear+'\nlocal mend='+mending_cb+'\nlocal armor_damage='+armor_cb+'\n'
    world=Path(tempfile.mkdtemp(prefix='voxey-durability-oracle-'))
    fixture=world/'worldmods'/'voxey_durability_fixture';fixture.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_durability_fixture = true\n')
    (world/'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31491\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture/'mod.conf').write_text('name = voxey_durability_fixture\ndepends = mcl_enchanting, mcl_armor, mcl_tools, mcl_farming, mcl_fishing, mcl_shields, screwdriver\n')
    (fixture/'init.lua').write_text(prefix+BODY)
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'oracle.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists():raise RuntimeError('Oracle failed at '+str(world)+'\n'+run.stdout[-1000:]+'\n'+run.stderr[-3000:])
    output=json.loads((world/'oracle.json').read_text())
    output['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in PATHS}
    output['license']='GPL-3.0-or-later'
    (ROOT/'assets/data/durability_reference.json').write_text(json.dumps(output,separators=(',',':'))+'\n')
    (ROOT/'assets/data/durability.json').write_text(json.dumps({'profiles':{str(p['id']):p for p in output['profiles']},'license':output['license'],'source_hashes':output['source_hashes']},indent=2)+'\n')
    print('Exported real-engine oracle:',len(output['profiles']),'profiles,',len(output['wear']),'wear cases,',len(output['mending']),'Mending cases,',len(output['armor']),'armor cases. Workdir:',world)

if __name__=='__main__':export()
