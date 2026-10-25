#!/usr/bin/env python3
"""Bind the actual filtered stonecutter recipes, including waxed copper."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
r=json.loads((ROOT/'assets/data/stonecutting_reference.json').read_text())
def canonical(n):
 for _ in range(16):
  if n not in r['aliases']:break
  n=r['aliases'][n]
 return n
names={}
for key,name in r['bindings'].items():
 name=canonical(name);names[name]=min(names.get(name,int(key)),int(key))
def mapped(name):return names[canonical(name.removesuffix('_preserved'))]
recipes={}
for input, outputs in r['recipes'].items():
 recipes[input]=[{'name':name,'id':mapped(name),'count':count,'waxed':name.endswith('_preserved')}for name,count in sorted(outputs.items())]
result={'recipes':recipes,'names':names,'bindings':r['bindings'],'aliases':r['aliases'],'source_hashes':r['source_hashes'],'node':r['node'],'orientations':r['orientations'],'license':'GPL-3.0-or-later'}
(ROOT/'assets/data/stonecutting.json').write_text(json.dumps(result,indent=2)+'\n')
print(len(recipes),'inputs;',sum(map(len,recipes.values())),'conversions')
