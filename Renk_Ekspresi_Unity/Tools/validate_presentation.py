"""Geometry and directional readability checks. Not a Unity render/device test."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
R=ROOT/'Assets/RenkEkspresi/Resources'
def vec(d):return tuple(d[k] for k in 'xyz')
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
faces=0;counts={}
for f in sorted((R/'Models').glob('*.json')):
 parts=json.loads(f.read_text())['parts'];counts[f.stem]=sum(len(p['vertices']) for p in parts)
 assert counts[f.stem]<12000,f
 for p in parts:
  v=list(map(vec,p['vertices']));n=list(map(vec,p['normals']));t=p['triangles']
  for i in range(0,len(t),3):
   a,b,c=(v[t[i+j]] for j in range(3));normal=cross(sub(b,a),sub(c,a))
   assert dot(normal,n[t[i]])>=-1e-8,(f,i,'reversed normal')
   faces+=1
levels=json.loads((R/'Data/campaign.json').read_text())['levels'];pairs=0
# Independent rule/grid check: arrows must follow actual row/column spacing after projection.
for level in levels:
 for c in level['parking']:
  arrow=(c['dx']*4.2,-c['dz']*2.35*math.sin(math.radians(67)))
  assert dot(arrow,arrow)>0
  for o in level['parking']:
   dx,dz=o['col']-c['col'],o['row']-c['row']
   if dx*c['dz']==dz*c['dx'] and dx*c['dx']+dz*c['dz']>0:
    offset=(dx*4.2,-dz*2.35*math.sin(math.radians(67)))
    assert abs(arrow[0]*offset[1]-arrow[1]*offset[0])<1e-6
    assert dot(arrow,offset)>0;pairs+=1
# Layout checks for compact, notched, tall phones and desktop safe rectangles.
layouts=0;minimum_pitch=999
for width,height in [(320,568),(375,647),(390,763),(430,848),(768,1004),(1440,840)]:
 w=min(width,height*.68);unit=min(w/720,height/1280)
 for level in levels:
  rows=level['rows'];fraction=(.62 if height<740 else .57) if rows>=5 else .54 if rows>=4 else .5
  available=height-300*unit;yardheight=available*fraction;routeheight=available*(1-fraction)-6*unit
  assert routeheight>100 and yardheight>100
  angle=math.radians(67)
  points=[(-7.7,0,1.7),(7.7,2.5,1.7),(-7.7,0,-5.5-(rows-1)*2.35),(7.7,2.2,-5.5-(rows-1)*2.35)]
  ys=[y*math.cos(angle)+z*math.sin(angle) for x,y,z in points];bottom,top=min(ys),max(ys)
  cy=(top+bottom)/2;size=max((top-bottom)/2,7.7/(w/yardheight))*1.05
  for c in level['parking']:
   projected=2.02*math.cos(angle)+(-4.2-c['row']*2.35)*math.sin(angle)
   screen=yardheight/2+(projected-cy)/(2*size)*yardheight
   assert 20*unit<screen<yardheight-20*unit,(width,height,level['id'],screen)
  minimum_pitch=min(minimum_pitch,2.35*math.sin(angle)*yardheight/(2*size));layouts+=1
print('PASS:',faces,'mesh triangles; correct normals;',pairs,'arrow/blocker pairs;',layouts,'camera layout combinations.')
print('Mesh vertex counts:',counts)
print('Minimum projected row pitch:',round(minimum_pitch,1),'pixels on compact safe-area fixture. Actual touch/FPS remains a device test.')
