#!/usr/bin/env python3
"""Run the installed villager trade catalog, creation, restock and XP callbacks."""
import hashlib, json, re, subprocess, tempfile
from pathlib import Path
from export_enchanting_reference import lua
ROOT=Path(__file__).resolve().parents[1]; SOURCE=Path('/home/impulse/.minetest/games/mineclonia')
FILES=['mods/ENTITIES/mobs_mc/villager.lua','mods/ITEMS/mcl_enchanting/engine.lua','mods/ITEMS/mcl_enchanting/enchantments.lua','mods/ITEMS/mcl_armor/register.lua']
BODY=r'''
local labels=LABELS; local stream=1
local function random(a,b)
 stream=(stream*1664525+1013904223)%4294967296
 if not a then return stream/4294967295 end
 if not b then b=a;a=1 end
 return a+stream%(b-a+1)
end
core.register_on_mods_loaded(function()core.after(0,function()
 mcl_potions.give_effect_by_level=function()end
 local v=core.registered_entities['mobs_mc:villager'];local out={catalog={},generated={},restock={},progress={},activation={},enchanting={},price_refresh={}}
 local function item(value)
  local st=ItemStack(type(value)=='function' and value() or value)
  local ench={}; for key,n in pairs(mcl_enchanting.get_enchantments(st))do ench[labels[key]or key]=n end
  return {name=st:get_name(),count=st:get_count(),enchantments=ench,metadata=st:get_meta():to_table().fields}
 end
 out.book_candidates={}; local keys={}; for key in pairs(mcl_enchanting.enchantments)do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do local ok,_,_,primary=mcl_enchanting.can_enchant(ItemStack('mcl_enchanting:book_enchanted'),key,1);local d=mcl_enchanting.enchantments[key];if ok and (primary or (d.treasure and d.tradable)) and key~='soul_speed' then out.book_candidates[#out.book_candidates+1]=labels[key]or key end end
 local old_random=mcl_enchanting.random;mcl_enchanting.random=function(_,a,b)return random(a,b)end
 local pr={next=function(_,a,b)return random(a,b)end}
 local function offer(tr)
  return {costs={item(tr.wanted1),item(tr.wanted2)},give=item(tr.offered),uses=tr.uses,stock=tr.max_uses,xp=tr.xp,multiplier=tr.price_multiplier,reward=tr.reward_xp}
 end
 local function actor(tier,xp)
  local a=setmetatable({_tier=tier,_xp=xp or 0,_trades={},_gossips={},_reputation={},_levelup_in=0,_profession='farmer',base_texture={},object={get_pos=function()return vector.zero()end}},{__index=v})
  a.update_trades=function(self,trades)self._trades=trades end;a.get_overlaid_texture=function()return 'badge'end;a.set_textures=function()end
  return a
 end
 for profession,tiers in pairs(mobs_mc.villager_trades)do
  local rows={};local index=0
  for tier,trades in ipairs(tiers)do for _,tr in ipairs(trades)do
   index=index+1
   local costs={{item=item(tr[1][1]),low=tr[1][2],high=tr[1][3]}}
   if tr[1][4]then costs[2]={item=item(tr[1][4]),low=tr[1][5],high=tr[1][6]}end
   rows[#rows+1]={tier=tier,costs=costs,give={item=item(tr[2][1]),low=tr[2][2],high=tr[2][3]},stock=tr[3]or 12,xp=tr[4]or 1,multiplier=tr[5]or 0}
   local itemname=item(tr[2][1]).name
   local enchanted=core.get_item_group(itemname,'enchanted')>0
   if enchanted and not out.enchanting[itemname]then
    local profile={ability=core.get_item_group(itemname,'enchantability'),primary={},secondary={}}
    local keys={};for key in pairs(mcl_enchanting.enchantments)do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys)do local ok,_,_,primary=mcl_enchanting.can_enchant(ItemStack(itemname),key,1);if ok then table.insert(primary and profile.primary or profile.secondary,labels[key]or key)end end
    out.enchanting[itemname]=profile
   end
   for seed=1,(enchanted and 24 or 3)do
    stream=seed;local made=mobs_mc.trade_from_table(pr,tr,true)
    out.generated[#out.generated+1]={profession=profession,index=index-1,seed=seed,after=offer(made),state=stream}
   end
  end end
  out.catalog[profession]=rows
  for tier=1,5 do
   local a=actor(tier);a._profession=profession;a:reload_trades();local before=#a._trades
   if tier<5 then a:level_up()end
   out.activation[#out.activation+1]={profession=profession,tier=tier,before=before,after=#a._trades}
  end
 end
 local saved_random=mcl_enchanting.random;mcl_enchanting.random=old_random
 for _,last_day in ipairs({-1,0,4})do for _,last_time in ipairs({-1,0,100})do for _,remaining in ipairs({0,1,2})do for _,clock in ipairs({0,100,120,121,220,221,599,600,700,1400})do for _,day in ipairs({0,4,5})do for _,used in ipairs({0,1,16})do
  core.get_gametime=function()return clock end;core.get_day_count=function()return day end
  local a=actor(1);a._last_restock_gmt=last_time;a._last_restock_day=last_day;a._restocks_remaining=remaining
  a._trades={mobs_mc.make_villager_trade({uses=used,demand=2,max_uses=16}),mobs_mc.make_villager_trade({uses=0,demand=-1,max_uses=4})}
  a:check_restock(clock,day)
  out.restock[#out.restock+1]={last_day=last_day,last_time=last_time,remaining=remaining,clock=clock,day=day,used=used,after={day=a._last_restock_day,time=a._last_restock_gmt,remaining=a._restocks_remaining,uses={a._trades[1].uses,a._trades[2].uses},demands={a._trades[1].demand,a._trades[2].demand}}}
 end end end end end end
 local source=SOURCE_TEXT;local block=source:match('(if self%._levelup_in > 0%.0 then.-)\n\tif self%._hero_cooldown then')
 local timer=assert(loadstring('return function(self,dtime) '..block..' end'))()
 local refresh_body=source:match('function villager:show_trade_formspec %(player, tradenum%)\n(.-)\nend')
 refresh_body=refresh_body:gsub('return villager_base%.show_trade_formspec %(self, player, tradenum%)','return true')
 local refresh=assert(loadstring('return function(self,player,tradenum) '..refresh_body..' end'))()
 local player={};local count=0;local a={_trading_with={[player]=1},apply_player_prices=function()count=count+1 end}
 out.price_refresh={result=refresh(a,player,1)==true,count=count,numeric_length=table.getn(a._trading_with)}
 for tier=1,5 do for _,xp in ipairs({0,9,10,69,70,149,150,249,250,999})do for _,gain in ipairs({1,2,12,30,400})do for _,dt in ipairs({0.1,1.99,2,2.1})do
  local a=actor(tier,xp);local bonus=0;local regenerations=0
  mcl_experience.throw_xp=function(_,amount)bonus=bonus+amount end;mcl_potions.give_effect_by_level=function(name,_,level,duration)assert(name=='regeneration'and level==1 and duration==10);regenerations=regenerations+1 end
  a.activate_trades=function()end
  a:on_transaction({xp=gain},{get_player_name=function()return 'player'end})
  local pending=a._levelup_in;timer(a,dt)
  out.progress[#out.progress+1]={tier=tier,xp=xp,gain=gain,dt=dt,after={tier=a._tier,xp=a._xp,timer=a._levelup_in,pending=pending,bonus=bonus,regenerations=regenerations,trading=a._gossips.player.trading}}
 end end end end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Trading fixture complete',false,0)
end)end)
'''
def main():
    labels={v['source_key']:k for k,v in json.loads((ROOT/'assets/data/enchanting.json').read_text())['definitions'].items()}
    world=Path(tempfile.mkdtemp(prefix='voxey-trading-'));mod=world/'worldmods/trading_fixture';mod.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
    (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31512\nserver_announce = false\nenable_ipv6 = false\n')
    (mod/'mod.conf').write_text('name = trading_fixture\ndepends = mobs_mc\n'); (mod/'init.lua').write_text(BODY.replace('LABELS',lua(labels)).replace('SOURCE_TEXT',lua((SOURCE/FILES[0]).read_text())))
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists():raise RuntimeError(str(world)+'\n'+run.stderr[-3000:])
    data=json.loads((world/'oracle.json').read_text());data['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in FILES}
    native_text=(ROOT/'scripts/village_trades.gd').read_text(); native=json.loads(re.sub(r',\s*([}\]])',r'\1',native_text[native_text.index('{'):]))
    profiles={}
    for profession, rows in data['catalog'].items():
        assert len(rows)==len(native[profession]),profession
        for index,row in enumerate(rows):
            name=row['give']['item']['name']
            if name in data['enchanting']: profiles[str(native[profession][index]['give'][0])]=data['enchanting'][name]
    runtime={'profiles':profiles,'book_candidates':data['book_candidates'],'source_hashes':data['source_hashes']}
    (ROOT/'assets/data/villager_trade_enchanting.json').write_text(json.dumps(runtime,indent=2)+'\n')
    (ROOT/'assets/data/villager_trading_reference.json').write_text(json.dumps(data,separators=(',',':'))+'\n');print({k:len(v) for k,v in data.items()})
if __name__=='__main__':main()
