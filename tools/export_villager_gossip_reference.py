#!/usr/bin/env python3
"""Execute Mineclonia's gossip and special-price callbacks as a test oracle."""
import hashlib, json, subprocess, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')
FILES = ['mods/ENTITIES/mobs_mc/villager.lua', 'mods/ENTITIES/mobs_mc/villager_zombie.lua', 'mods/ENTITIES/mobs_mc/iron_golem.lua']
BODY = r'''
core.register_on_mods_loaded(function() core.after(0,function()
 local v=core.registered_entities['mobs_mc:villager']
 local out={record={},copy={},decay={},clock={},conversation={},prices={}}
 local types={'major_negative','minor_negative','minor_positive','major_positive','trading'}
 local function actor(gossips)
  local a=setmetatable({_gossips=table.copy(gossips or {}),_reputation={},_last_gossip_decay_gmt=0,_last_gossip_gmt=0},{__index=v})
  for p in pairs(a._gossips) do a:evaluate_player_reputation(p) end
  return a
 end
 local function snapshot(a) return {gossips=table.copy(a._gossips),reputations=table.copy(a._reputation)} end
 for _,kind in ipairs(types) do for _,initial in ipairs({0,1,2,5,10,19,20,24,25,99,100}) do for _,amount in ipairs({-125,-25,-2,0,1,2,25,100}) do
  local a=actor({player={[kind]=initial}}); a:record_gossip('player',kind,amount)
  out.record[#out.record+1]={kind=kind,initial=initial,amount=amount,after=snapshot(a)}
 end end end
 for _,kind in ipairs(types) do for _,sent in ipairs({0,1,5,10,19,20,21,25,99,100}) do for _,received in ipairs({0,1,10,20,25,99}) do
  local a=actor({player={[kind]=sent}});local b=actor({player={[kind]=received},other={trading=3}});b:copy_gossips(a)
  out.copy[#out.copy+1]={kind=kind,sent=sent,received=received,after=snapshot(b)}
 end end end
 for _,kind in ipairs(types) do for _,initial in ipairs({0,1,2,3,5,10,11,12,19,20,21,22,24,25,99,100}) do
  local a=actor({player={[kind]=initial}});a:decay_gossips_1()
  out.decay[#out.decay+1]={kind=kind,initial=initial,after=snapshot(a)}
 end end
 for _,last in ipairs({0,1,100,1200}) do for _,now in ipairs({0,1,59,60,100,1199,1200,1201,1300,2400,10000}) do
  local a=actor({player={major_negative=100,minor_positive=25,trading=20}});a._last_gossip_decay_gmt=last;core.get_gametime=function()return now end;a:decay_gossips()
  out.clock[#out.clock+1]={last=last,now=now,after=snapshot(a),stamp=a._last_gossip_decay_gmt}
 end end
 for _,last in ipairs({0,1,60,100}) do for _,now in ipairs({0,1,59,60,61,100,119,120,160,10000}) do
  local a=actor({player={major_negative=25,minor_positive=25,major_positive=20,trading=20}});local b=actor({player={minor_negative=20}})
  b._last_gossip_gmt=last;core.get_gametime=function()return now end;local summons=0
  a.maybe_summon_golem=function(_,_,count)assert(count==5);summons=summons+1 end;a:gossip_with(vector.zero(),b)
  out.conversation[#out.conversation+1]={last=last,now=now,after=snapshot(b),stamp=b._last_gossip_gmt,summons=summons}
 end end
 for _,count in ipairs({1,2,7,20,32,64}) do for _,second in ipairs({0,1,10,64}) do for _,demand in ipairs({-5,0,2,5}) do for _,mult in ipairs({0,0.05,0.2}) do for _,rep in ipairs({-600,-125,-100,-1,0,1,20,45,65}) do for _,hero in ipairs({false,true}) do
  local tr=mobs_mc.make_villager_trade({wanted1='mcl_core:emerald '..count,wanted2=second==0 and '' or 'mcl_core:gravel '..second,price_multiplier=mult,demand=demand})
  local a=actor();a._trades={tr};a._reputation.player=rep
  mcl_potions.has_effect=function()return hero end;a:apply_player_prices({get_player_name=function()return 'player' end})
  out.prices[#out.prices+1]={costs=second==0 and {count} or {count,second},limits=second==0 and {64} or {64,64},demand=demand,multiplier=mult,standing=rep,hero=hero,after=second==0 and {tr:get_wanted1():get_count()} or {tr:get_wanted1():get_count(),tr:get_wanted2():get_count()}}
 end end end end end end
 for _,rep in ipairs({-600,-125,-1,0,1,20,45,65}) do for _,hero in ipairs({false,true}) do
  local tr=mobs_mc.make_villager_trade({wanted1='mcl_tools:pick_iron',wanted2='mcl_core:emerald 32',price_multiplier=0.2,demand=4})
  local a=actor();a._trades={tr};a._reputation.player=rep;mcl_potions.has_effect=function()return hero end;a:apply_player_prices({get_player_name=function()return 'player' end})
  out.prices[#out.prices+1]={costs={1,32},limits={1,64},demand=4,multiplier=0.2,standing=rep,hero=hero,after={tr:get_wanted1():get_count(),tr:get_wanted2():get_count()}}
 end end
 core.safe_file_write(core.get_worldpath()..'/oracle.json',core.write_json(out,true));core.request_shutdown('Gossip fixture complete',false,0)
end) end)
'''
def main():
    world=Path(tempfile.mkdtemp(prefix='voxey-gossip-')); mod=world/'worldmods/gossip_fixture'; mod.mkdir(parents=True)
    (world/'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
    (world/'source.conf').write_text('bind_address = 127.0.0.1\nport = 31511\nserver_announce = false\nenable_ipv6 = false\n')
    (mod/'mod.conf').write_text('name = gossip_fixture\ndepends = mobs_mc\n'); (mod/'init.lua').write_text(BODY)
    run=subprocess.run(['luanti','--server','--world',str(world),'--config',str(world/'source.conf'),'--logfile',str(world/'debug.txt')],capture_output=True,text=True,timeout=120)
    if not (world/'oracle.json').exists(): raise RuntimeError(str(world)+'\n'+run.stderr[-3000:])
    data=json.loads((world/'oracle.json').read_text()); data['source_hashes']={p:hashlib.sha256((SOURCE/p).read_bytes()).hexdigest() for p in FILES}
    (ROOT/'assets/data/villager_gossip_reference.json').write_text(json.dumps(data,separators=(',',':'))+'\n'); print({k:len(v) for k,v in data.items()})
if __name__=='__main__': main()
