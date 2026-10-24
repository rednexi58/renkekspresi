using UnityEngine;
using UnityEngine.UI;
namespace RenkEkspresi
{
    // Vector icons stay crisp at phone resolution and never depend on font glyphs.
    public sealed class RailGlyph : MaskableGraphic
    {
        public enum Symbol { Arrow, Freeze, Blast, Recall, Pause, Lock, Play, Crown }
        public Symbol Kind;
        public Vector2 Direction = Vector2.up;
        protected override void OnPopulateMesh(VertexHelper vh)
        {
            vh.Clear();
            float scale = Mathf.Min(rectTransform.rect.width, rectTransform.rect.height) / 100f;
            var center = rectTransform.rect.center;
            if (Kind == Symbol.Arrow)
            {
                var dir = Direction.sqrMagnitude > .01f ? Direction.normalized : Vector2.up;
                var right = new Vector2(dir.y, -dir.x);
                Vector2[] outline = { new Vector2(-12,-36),new Vector2(12,-36),new Vector2(12,3),new Vector2(33,3),new Vector2(0,37),new Vector2(-33,3),new Vector2(-12,3) };
                int[] indices = {0,1,2,0,2,6,6,2,4,2,3,4,4,5,6};
                for(int pass=0;pass<2;pass++)
                {
                    int start=vh.currentVertCount;
                    foreach(var p in outline) vh.AddVert(center+(right*p.x+dir*p.y)*scale*(pass==0?1.13f:1f)+(pass==0?Vector2.down*2*scale:Vector2.zero),pass==0?new Color(.07f,.16f,.2f,.85f):color,Vector2.zero);
                    for(int i=0;i<indices.Length;i+=3) vh.AddTriangle(start+indices[i],start+indices[i+1],start+indices[i+2]);
                }
                return;
            }
            if(Kind==Symbol.Freeze)
            {
                for(int i=0;i<6;i++)
                {
                    float a=i*Mathf.PI/3; var d=new Vector2(Mathf.Cos(a),Mathf.Sin(a));var n=new Vector2(-d.y,d.x);
                    Line(vh,center,center+d*34*scale,6*scale);
                    Line(vh,center+d*20*scale,center+(d*13+n*10)*scale,5*scale);
                    Line(vh,center+d*20*scale,center+(d*13-n*10)*scale,5*scale);
                }
            }
            else if(Kind==Symbol.Pause){Line(vh,center+new Vector2(-13,-26)*scale,center+new Vector2(-13,26)*scale,10*scale);Line(vh,center+new Vector2(13,-26)*scale,center+new Vector2(13,26)*scale,10*scale);}
            else if(Kind==Symbol.Play) Triangle(vh,center+new Vector2(-20,-29)*scale,center+new Vector2(29,0)*scale,center+new Vector2(-20,29)*scale);
            else if(Kind==Symbol.Blast)
            {
                for(int i=0;i<8;i++) {float a=i*Mathf.PI/4;Triangle(vh,center,center+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*35*scale,center+new Vector2(Mathf.Cos(a+.39f),Mathf.Sin(a+.39f))*16*scale);Triangle(vh,center,center+new Vector2(Mathf.Cos(a+.39f),Mathf.Sin(a+.39f))*16*scale,center+new Vector2(Mathf.Cos(a+.78f),Mathf.Sin(a+.78f))*35*scale);}
            }
            else if(Kind==Symbol.Recall)
            {
                for(int i=0;i<18;i++){float a=(-45+i*15)*Mathf.Deg2Rad,b=a+15*Mathf.Deg2Rad;Line(vh,center+new Vector2(Mathf.Cos(a),Mathf.Sin(a))*26*scale,center+new Vector2(Mathf.Cos(b),Mathf.Sin(b))*26*scale,7*scale);}
                Triangle(vh,center+new Vector2(-35,25)*scale,center+new Vector2(-4,25)*scale,center+new Vector2(-23,0)*scale);
            }
            else if(Kind==Symbol.Lock)
            {
                Line(vh,center+new Vector2(-22,-11)*scale,center+new Vector2(22,-11)*scale,32*scale);
                for(int i=0;i<12;i++){float a=i*Mathf.PI/12,b=(i+1)*Mathf.PI/12;Line(vh,center+new Vector2(Mathf.Cos(a)*16,8+Mathf.Sin(a)*19)*scale,center+new Vector2(Mathf.Cos(b)*16,8+Mathf.Sin(b)*19)*scale,7*scale);}
            }
            else { // crown
                Triangle(vh,center+new Vector2(-32,22)*scale,center+new Vector2(-23,-24)*scale,center+new Vector2(0,-24)*scale);
                Triangle(vh,center+new Vector2(-23,-24)*scale,center+new Vector2(0,32)*scale,center+new Vector2(23,-24)*scale);
                Triangle(vh,center+new Vector2(0,-24)*scale,center+new Vector2(23,-24)*scale,center+new Vector2(32,22)*scale);
            }
        }
        void Triangle(VertexHelper vh,Vector2 a,Vector2 b,Vector2 c){int i=vh.currentVertCount;vh.AddVert(a,color,Vector2.zero);vh.AddVert(b,color,Vector2.zero);vh.AddVert(c,color,Vector2.zero);vh.AddTriangle(i,i+1,i+2);}
        void Line(VertexHelper vh,Vector2 a,Vector2 b,float width){var n=new Vector2(-(b-a).y,(b-a).x).normalized*width*.5f;int i=vh.currentVertCount;foreach(var p in new[]{a-n,a+n,b+n,b-n})vh.AddVert(p,color,Vector2.zero);vh.AddTriangle(i,i+1,i+2);vh.AddTriangle(i,i+2,i+3);}
    }
}
