"""Generate original rounded enamel train meshes. No external art dependencies."""
import json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / 'Assets/RenkEkspresi/Resources/Models'
PALETTE=['E65D52','348CD3','F2C34D','39A985','9868CD']
NAVY='203944'; METAL='81999F'; BRASS='DBB46B'; GLASS='A8E4E8'
def rgb(h): return [int(h[i:i+2],16)/255 for i in (0,2,4)]
def part(color,metal=.05,rough=.34):
 r,g,b=rgb(color);return dict(vertices=[],normals=[],triangles=[],r=r,g=g,b=b,metallic=metal,roughness=rough)
def vertex(p,v,n):
 p['vertices'].append(dict(zip('xyz',v)));p['normals'].append(dict(zip('xyz',n)));return len(p['vertices'])-1
def tri(p,a,b,c,n):
 i=[vertex(p,v,n) for v in (a,b,c)];p['triangles']+=i
# Bevelled cuboid: rounded-rectangle rings, softly bevelled top/bottom, no box primitives.
def box(parts,pos,size,color,r=.09):
 p=part(color);x,y,z=pos;w,h,d=size;r=min(r,w/4,h/4,d/4)
 rings=[]
 for yy,inset in [(y-h/2,r*.6),(y-h/2+r,0),(y+h/2-r,0),(y+h/2,r*.6)]:
  ring=[]
  for cx,cz,start in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]:
   for k in range(5):
    a=math.radians(start+k*22.5)
    ring.append((x+cx*(w/2-r-inset)+r*math.cos(a),yy,z+cz*(d/2-r-inset)+r*math.sin(a)))
  rings.append(ring)
 for j in range(3):
  for i in range(20):
   a,b,c,d0=rings[j][i],rings[j][(i+1)%20],rings[j+1][(i+1)%20],rings[j+1][i]
   u=[b[k]-a[k] for k in range(3)];v=[d0[k]-a[k] for k in range(3)]
   n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
   norm=math.sqrt(sum(q*q for q in n));n=[q/norm for q in n]
   # Rings run counterclockwise viewed from above; this order faces inward: reverse.
   n=[-q for q in n];tri(p,a,c,b,n);tri(p,a,d0,c,n)
 for ring,sign in [(rings[0],-1),(rings[-1],1)]:
  center=(x,ring[0][1],z)
  for i in range(20):
   a,b=ring[i],ring[(i+1)%20]
   if sign==1:tri(p,center,b,a,(0,1,0))
   else:tri(p,center,a,b,(0,-1,0))
 parts.append(p)
def cylinder(parts,pos,radius,length,color,axis='y',segments=20,r2=None):
 p=part(color,.45 if color in [METAL,BRASS] else .05);r2=radius if r2 is None else r2
 def rotate(v):return (v[1],v[0],v[2]) if axis=='x' else ((v[0],v[2],v[1]) if axis=='z' else v)
 def world(v):return tuple(a+b for a,b in zip(pos,rotate(v)))
 # Build CCW triangles in local coordinates, correct winding by computing normals.
 for i in range(segments):
  a=2*math.pi*i/segments;b=2*math.pi*(i+1)/segments
  vs=[(radius*math.cos(a),-length/2,radius*math.sin(a)),(radius*math.cos(b),-length/2,radius*math.sin(b)),(r2*math.cos(b),length/2,r2*math.sin(b)),(r2*math.cos(a),length/2,r2*math.sin(a))]
  n=rotate((math.cos((a+b)/2),(radius-r2)/length,math.sin((a+b)/2)));nn=math.sqrt(sum(v*v for v in n));n=tuple(v/nn for v in n)
  # Axis swaps reverse handedness.
  order=[(0,2,1),(0,3,2)] if axis=='y' else [(0,1,2),(0,2,3)]
  for ids in order:
   triangle=[]
   for k in ids:
    vv=vs[k];a0=math.atan2(vv[2],vv[0]);normal=rotate((math.cos(a0),(radius-r2)/length,math.sin(a0)));length0=math.sqrt(sum(q*q for q in normal));normal=tuple(q/length0 for q in normal)
    triangle.append(vertex(p,world(vv),normal))
   p['triangles']+=triangle
  for yy,rr,sign in [(-length/2,radius,-1),(length/2,r2,1)]:
   va=(rr*math.cos(a),yy,rr*math.sin(a));vb=(rr*math.cos(b),yy,rr*math.sin(b))
   flip=(sign==1) != (axis!='y')
   tri(p,world((0,yy,0)),world(vb if flip else va),world(va if flip else vb),rotate((0,sign,0)))
 parts.append(p)
def running(parts,engine):
 box(parts,(0,.37,0),(1.04,.2,1.72),NAVY)
 for z in [-.56,.56]:
  for x in [-.51,.51]:
   cylinder(parts,(x,.27,z),.255,.16,NAVY,'x',16)
   cylinder(parts,(x+math.copysign(.09,x),.27,z),.15,.025,METAL,'x',12)
   cylinder(parts,(x+math.copysign(.11,x),.27,z),.055,.03,BRASS,'x',10)
 for z in [-.96,.96]:
  box(parts,(0,.33,z),(.23,.1,.25),METAL,.03)
 if engine:
  for x in [-.62,.62]:box(parts,(x,.27,0),(.06,.075,1.2),BRASS,.02)
def build(color):
 p=[];running(p,color<0)
 if color<0:
  # Locomotive silhouette: navy enamel boiler, copper chimney, ivory cab, glass.
  cylinder(p,(0,.86,.32),.43,1.03,NAVY,'z',24)
  for z in [0,.64]:cylinder(p,(0,.86,z),.446,.055,BRASS,'z',24)
  cylinder(p,(0,.86,.86),.36,.08,NAVY,'z',24)
  cylinder(p,(0,1.0,.92),.16,.08,BRASS,'z',20)
  cylinder(p,(0,1.0,.97),.115,.03,'FFF2B3','z',16)
  box(p,(0,1.04,-.54),(1.03,1.12,.7),'EAE7D8',.12)
  box(p,(0,1.65,-.54),(1.22,.18,.94),NAVY,.07)
  for x in [-.524,.524]:
   box(p,(x,1.22,-.52),(.04,.41,.43),NAVY,.015)
   box(p,(x+math.copysign(.025,x),1.23,-.52),(.025,.32,.33),GLASS,.01)
  box(p,(0,1.28,-.17),(.73,.35,.04),GLASS,.012)
  cylinder(p,(0,1.39,.48),.14,.48,NAVY,'y',20,r2=.2)
  cylinder(p,(0,1.65,.48),.215,.08,BRASS,'y',20)
  cylinder(p,(0,1.22,-.03),.19,.2,BRASS,'y',16,r2=.14)
  box(p,(0,.48,1.01),(1.03,.2,.25),'D75649',.05)
 else:
  c=PALETTE[color]
  box(p,(0,.78,0),(1.09,.66,1.48),c,.16)
  # A curved coach roof breaks the toy-crate silhouette while leaving a broad arrow surface.
  cylinder(p,(0,1.05,0),.55,1.5,c,'z',28)
  roof=p[-1]
  for v in roof['vertices']:v['y']=1.05+(v['y']-1.05)*.45
  for n in roof['normals']:
   n['y']/=.45;norm=math.sqrt(sum(n[k]*n[k] for k in 'xyz'))
   for k in 'xyz':n[k]/=norm
  for x in [-.55,.55]:
   box(p,(x,.65,0),(.035,.055,1.28),BRASS,.01)
   for z in [-.48,0,.48]:box(p,(x,.88,z),(.04,.33,.04),c,.01)
  for z in [-.75,.75]:box(p,(0,.75,z),(.76,.08,.04),BRASS,.01)
 return {'parts':p}
if __name__=='__main__':
 ROOT.mkdir(parents=True,exist_ok=True)
 for color in range(-1,5):
  data=build(color)
  for part0 in data['parts']:
   oldv,oldn=part0['vertices'],part0['normals'];unique={};vertices=[];normals=[];mapping=[]
   for v,n in zip(oldv,oldn):
    key=tuple(round(v[k],7) for k in 'xyz')+tuple(round(n[k],7) for k in 'xyz')
    if key not in unique:unique[key]=len(vertices);vertices.append(v);normals.append(n)
    mapping.append(unique[key])
   part0['vertices']=vertices;part0['normals']=normals;part0['triangles']=[mapping[i] for i in part0['triangles']]
  name='Locomotive' if color<0 else f'Wagon{color}'
  (ROOT/(name+'.json')).write_text(json.dumps(data,separators=(',',':')))
  print(name,sum(len(p['vertices']) for p in data['parts']),'vertices')
