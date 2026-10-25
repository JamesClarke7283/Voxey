#!/usr/bin/env python3
"""Map the live barrier registry onto stable native item and state IDs."""
import copy,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 r=json.loads((ROOT/'assets/data/barriers_reference.json').read_text());out={'walls':{},'states':{},'fences':{},'nodes':r['nodes'],'aliases':r['aliases'],'source_hashes':r['source_hashes'],'recipes':[]}
 def canonical(n):
  for _ in range(16):
   if n not in r['aliases']:break
   n=r['aliases'][n]
  return n
 names={}
 for i,n in r['native']['ids'].items():names[canonical(n)]=min(names.get(canonical(n),int(i)),int(i))
 for n,i in json.loads((ROOT/'assets/data/harvest_items.json').read_text())['items'].items():names.setdefault(canonical(n),i)
 native={canonical(w['name']):w for w in r['native']['walls']if w['name']}
 occupied=set(r['native']['occupied']);target=ROOT/'assets/data/barriers.json';prior=json.loads(target.read_text())if target.exists()else{}
 allocated={k:v['first']for k,v in prior.get('walls',{}).items()}
 for i in allocated.values():occupied.update(range(i,i+8))
 def reserve(key):
  if key in allocated:return allocated[key]
  i=next(i for i in range(14800,16376,8)if not any(v in occupied for v in range(i,i+8)))
  allocated[key]=i;occupied.update(range(i,i+8));return i
 def clean(d):
  d=copy.deepcopy(d)
  d['title']=re.sub(r'\x1b\([^)]*\)|\x1b[EF]','',d.get('description','')).split('\n')[0]
  d['hardness']=d.get('hardness',2);d['fuel']=d.get('fuel',0)
  d['cuts']=[names[canonical(n)]for n in d.get('cuts',[])or[]]
  d['recipes']=d.get('recipes',[])or[]
  return d
 walldefs=[]
 for root,v in sorted(r['walls'].items()):
  old=native.get(v['short_pillar']['name']);first=reserve(root);base=old['id']if old else first+5
  material=old['material'] if old else names[canonical(v['short_pillar']['recipes'][0]['items'][0])]
  if root=='mcl_pale_oak:resinbrick':material=11522
  walldefs.append((root,base,material,v,first))
 for old in r['native']['walls']:
  if old['name']:continue
  root='native:'+str(old['id']);v=copy.deepcopy(r['walls']['mcl_walls:cobble'])
  for item in v.values():item['name']='';item['description']='';item['recipes']=[]
  walldefs.append((root,old['id'],old['material'],v,reserve(root)))
 for root,base,material,v,first in walldefs:
  states=[base,first,first+1,first+2,first+3,first+4]
  kinds=['short_pillar','tall_pillar','short_flat','short_flat','tall_flat','tall_flat']
  out['walls'][root]={'id':base,'first':first,'material':material,'states':states,'source':not root.startswith('native:')}
  for j,(i,k)in enumerate(zip(states,kinds)):
   d=clean(v[k]);d.update({'id':i,'item':base,'root':root,'material':material,'state':k,'facing':1 if j in [3,5]else 0,'title':clean(v['short_pillar'])['title']})
   out['states'][str(i)]=d
   if d['name']:names.setdefault(d['name'],i)
 for f in r['native']['fences']:
  name=canonical(f['name']);prefix=name
  for i,n in [(f['id'],name),(f['id']+1,name+'_gate'),(f['id']+5,name+'_gate_open')]:
   if n not in r['fences']:raise RuntimeError('Missing source fence '+n)
   d=clean(r['fences'][n]);d.update({'id':i,'material':f['material']});out['fences'][str(i)]=d;names[n]=i
 for d in list(out['states'].values())+list(out['fences'].values()):
  for recipe in d['recipes']:
   if recipe['method']!='normal':continue
   pattern=[names[canonical(n)] if n else 0 for n in recipe['items']]
   out['recipes'].append({'id':d['id'],'pattern':pattern,'width':recipe['width'],'count':int(recipe['output'].split()[1])if len(recipe['output'].split())>1 else 1,'source_items':{str(names[canonical(n)]):n for n in recipe['items']if n}})
 target.write_text(json.dumps(out,indent=2)+'\n')
 print('Bound',len(out['walls']),'wall families,',len(out['states']),'wall states,',len(out['fences']),'fence/gate profiles,',len(out['recipes']),'recipes')
 print('New items',[(k,v['id'])for k,v in out['walls'].items()if v['id']>=14800])
if __name__=='__main__':main()
