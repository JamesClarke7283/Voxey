#!/usr/bin/env python3
"""Check every mapped node/state against the real, unfiltered Luanti registry."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from export_enchanting_reference import lua

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/impulse/.minetest/games/mineclonia')

BODY = r'''
core.register_on_mods_loaded(function()
 core.after(0,function()
  local result={nodes={},cases={}}
  local hand=ItemStack(PROFILES['0']):get_tool_capabilities()
  for _,p in ipairs(INPUTS)do
   local stack=ItemStack(PROFILES[tostring(p.id)])
   local def=stack:get_definition()
   if def._mcl_enchanting_enchanted_tool then
    if p.efficiency>0 then mcl_enchanting.enchant(stack,'efficiency',p.efficiency)end
    if p.unbreaking>0 then mcl_enchanting.enchant(stack,'unbreaking',p.unbreaking)end
   end
   local caps=def.tool_capabilities and stack:get_tool_capabilities() or table.copy(hand)
   caps=mcl_potions.apply_haste_fatigue(caps,p.speed.haste,p.speed.fatigue)
   local fallback=mcl_potions.apply_haste_fatigue(table.copy(hand),p.speed.haste,p.speed.fatigue)
   local values={}
   for _,node in ipairs(NODES)do
    local nd=assert(core.registered_nodes[node.name],node.name)
    local value={diggable=false,time=0,wear=0}
    if nd.diggable~=false then
     value=core.get_dig_params(nd.groups,caps,p.initial)
     if not value.diggable then value=core.get_dig_params(nd.groups,fallback,0)end
    end
    values[#values+1]={diggable=value.diggable,time=value.time,wear=value.wear}
   end
   result.cases[#result.cases+1]={input=p,results=values}
  end
  result.nodes=NODES
  core.safe_file_write(core.get_worldpath()..'/result.json',core.write_json(result,true))
  core.request_shutdown('Node mapping oracle complete',false,0)
 end)
end)
'''


def export():
    world = Path(tempfile.mkdtemp(prefix='voxey-mining-oracle-'))
    audit = world / 'audit.json'
    run = subprocess.run(['godot', '--headless', '--path', str(ROOT), '--script',
                          'tools/audit_digging.gd', '--', str(audit), '--all-states'],
                         capture_output=True, text=True, timeout=120)
    if run.returncode or 'SCRIPT ERROR' in run.stdout + run.stderr:
        raise RuntimeError(run.stdout + run.stderr)
    grouped = {}
    for row in json.loads(audit.read_text()):
        if row['source']:
            grouped.setdefault(row['source'], []).append(row['id'])
    nodes = [{'name': name, 'ids': ids} for name, ids in sorted(grouped.items())]
    profiles = {key: value['name'] for key, value in json.loads((ROOT / 'assets/data/digging.json').read_text())['tools'].items()}
    inputs = []
    for item in [0, 80, 81, 82, 83, 84, 95, 123]:
        for enhanced in [False, True]:
            inputs.append({'id': item, 'efficiency': 3 if enhanced else 0,
                           'unbreaking': 3 if enhanced else 0,
                           'initial': 65000 if enhanced else 0,
                           'speed': {'haste': .68 if enhanced else 0, 'fatigue': 1}})
    fixture = world / 'worldmods/voxey_mining_fixture'
    fixture.mkdir(parents=True)
    (world / 'world.mt').write_text('gameid = mineclonia\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_voxey_mining_fixture = true\n')
    (world / 'oracle.conf').write_text('bind_address = 127.0.0.1\nport = 31493\nserver_announce = false\nenable_ipv6 = false\n')
    (fixture / 'mod.conf').write_text('name = voxey_mining_fixture\ndepends = mcl_potions, mcl_enchanting, mcl_tools, mcl_meshhand\n')
    (fixture / 'init.lua').write_text('local NODES=' + lua(nodes) + '\nlocal INPUTS=' + lua(inputs) + '\nlocal PROFILES=' + lua(profiles) + '\n' + BODY)
    run = subprocess.run(['luanti', '--server', '--world', str(world), '--config', str(world / 'oracle.conf'), '--logfile', str(world / 'debug.txt')], capture_output=True, text=True, timeout=120)
    if not (world / 'result.json').exists():
        raise RuntimeError(str(world) + '\n' + run.stderr[-4000:])
    data = json.loads((world / 'result.json').read_text())
    data['license'] = 'GPL-3.0-or-later'
    data['source'] = str(SOURCE)
    data['source_hashes'] = {str(p.relative_to(SOURCE)): hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.glob('mods/**/init.lua') if p.parent.name in ['_mcl_autogroup', 'mcl_stairs', 'mcl_tools', 'mcl_meshhand']}
    (ROOT / 'assets/data/mining_reference.json').write_text(json.dumps(data, separators=(',', ':')) + '\n')
    print(f'Exported {len(nodes)} registered nodes, {sum(len(n["ids"]) for n in nodes)} native IDs and {len(nodes) * len(inputs)} real-engine cases: {world}')


if __name__ == '__main__':
    export()
