#!/usr/bin/env python3
"""Bind registered shape families to stable native IDs without moving old saves."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
NEW_BASES={'mcl_core:lapisblock':13700,'mcl_core:sandstonesmooth':13701,'mcl_core:redsand':13702,'mcl_core:redsandstone':13703,'mcl_core:redsandstonesmooth':13704,'mcl_core:redsandstonecarved':13705,'mcl_core:redsandstonesmooth2':13706}
def main():
 raw=json.loads((ROOT/'assets/data/shapes_reference.json').read_text());target=ROOT/'assets/data/shapes.json'
 old=json.loads(target.read_text())if target.exists()else{}
 aliases=raw['aliases']
 def canonical(name):
  for _ in range(16):
   if name not in aliases:break
   name=aliases[name]
  return name
 mats={}
 for id,name in raw['native']['materials'].items():mats.setdefault(canonical(name),[]).append(int(id))
 for name,id in NEW_BASES.items():mats[name]=[id]
 mats['mcl_wool:white']=[75,571]
 existing={r['key']:r for r in raw['native']['families']if r['key']in raw['families']}
 assigned={k:int(v['first'])for k,v in existing.items()}
 for key,first in old.get('by_key',{}).items():
  if key not in assigned:assigned[key]=first
 used=set(raw['native']['occupied'])
 for first in assigned.values():used.update(range(first,first+16))
 for key in sorted(raw['families']):
  if key in assigned:continue
  first=next(i for i in range(14000,16000,16)if not any(j in used for j in range(i,i+16)))
  assigned[key]=first;used.update(range(first,first+16))
 def plain(value):return re.sub(r'\x1b\([^)]*\)|\x1b[EF]','',value).split('\n')[0]
 result={'families':{},'by_key':assigned,'by_material':{},'new_families':[],'missing_inputs':[],'source_hashes':raw['source_hashes'],'license':'GPL-3.0-or-later'}
 for key,row in sorted(raw['families'].items()):
  recipe=next(r for r in row['slab']['recipes']if r['method']=='normal'and r['width']==3 and len(r['items'])==3 and len(set(r['items']))==1)
  name=next(s for s in recipe['items']if s);group=name.startswith('group:')
  base=existing[key]['base']if group else min(mats.get(canonical(name),[0]))
  if not base:raise RuntimeError('Missing base '+key+' '+name)
  first=assigned[key];info={'key':key,'base':base,'recipe_item':name}
  for kind in ['slab','top','double','stair']:
   src=row[kind];cuts=[]
   for item in src.get('cuts')or[]:
    if canonical(item)in mats:cuts.append(min(mats[canonical(item)]))
    else:result['missing_inputs'].append([key,kind,item])
   info[kind]={'name':src['name'],'title':plain(src['description']),'hardness':src.get('hardness',0),'resistance':src.get('resistance',src.get('hardness',0)),'cuts':cuts,'groups':src['groups'],'fuel':src['fuel'],'tiles':src['tiles']}
  result['families'][str(first)]=info
  for id in mats.get(canonical(name),[base]):result['by_material'][str(id)]=first
  result['by_material'][str(base)]=first
  if key in existing:result['by_material'][str(existing[key]['base'])]=first
  else:result['new_families'].append(first)
 result['new_families'].sort()
 names={canonical(name):min(ids)for name,ids in mats.items()}
 names.update({canonical(k):v for k,v in json.loads((ROOT/'assets/data/harvest_items.json').read_text())['items'].items()})
 names.update(NEW_BASES)
 for key,first in assigned.items():
  names['mcl_stairs:slab_'+key]=first;names['mcl_stairs:stair_'+key]=first+3
 representatives={'quartz_block':541,'purpur_block':236,'wool_slab':assigned['wool_white'],'wool_stair':assigned['wool_white']+3,'wool_stairs':assigned['wool_white']+3}
 result['recipes']=[]
 for key,row in raw['families'].items():
  for kind,offset in [('slab',0),('stair',3)]:
   for recipe in row[kind]['recipes']or[]:
    cells=[];source_items={};valid=True
    for name in recipe['items']:
     if not name:cells.append(0);continue
     id=representatives.get(name[6:],0)if name.startswith('group:')else names.get(canonical(name),0)
     if not id:result['missing_inputs'].append([key,kind,name]);valid=False
     cells.append(id);source_items[str(id)]=name
    if valid:result['recipes'].append({'id':assigned[key]+offset,'count':int(recipe['output'].split(' ')[1])if ' 'in recipe['output']else 1,'pattern':cells,'width':recipe['width'],'source_items':source_items})
 target.write_text(json.dumps(result,indent=2)+'\n')
 print('Bound',len(result['families']),'families;',len(result['new_families']),'new; unresolved cuts:',result['missing_inputs'])
if __name__=='__main__':main()
