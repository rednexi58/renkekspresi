using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
namespace RenkEkspresi
{
    public sealed class GameUI : MonoBehaviour
    {
        public GameManager Game; public RectTransform Root; public GameObject Modal;
        Canvas canvas; CanvasScaler scaler; Font font, bold; Sprite rounded;
        Text title, region, phase, count; Image progress; GameObject toast;
        readonly Button[] boosters=new Button[3], stationActions=new Button[5];
        readonly Text[] stationLabels=new Text[5], boosterNames=new Text[3], boosterCounts=new Text[3];
        readonly Dictionary<int,CardOverlay> cardViews=new Dictionary<int,CardOverlay>();
        PuzzleEngine shownRules;
        readonly List<GameObject> flights = new List<GameObject>();
        readonly Color Ink=GameWorld.Hex("203944"), Cream=GameWorld.Hex("F6F3E9"), Navy=GameWorld.Hex("203944"), Gold=GameWorld.Hex("EDBF67"), Muted=GameWorld.Hex("6E8587");
        sealed class CardOverlay {public RectTransform Root; public RailGlyph Arrow; public Text Count, Key; public Image Badge; public float FlashUntil;}
        public string L(string tr,string en){return Game.English?en:tr;}
        Sprite Round()
        {
            var tex=new Texture2D(64,64,TextureFormat.RGBA32,false){filterMode=FilterMode.Bilinear};
            for(int y=0;y<64;y++)for(int x=0;x<64;x++)
            {float dx=Mathf.Max(16-x,x-47),dy=Mathf.Max(16-y,y-47);float d=new Vector2(Mathf.Max(dx,0),Mathf.Max(dy,0)).magnitude;tex.SetPixel(x,y,new Color(1,1,1,Mathf.Clamp01(16.5f-d)));}
            tex.Apply();return Sprite.Create(tex,new Rect(0,0,64,64),new Vector2(.5f,.5f),100,0,SpriteMeshType.FullRect,new Vector4(20,20,20,20));
        }
        public void Setup(GameManager game)
        {
            Game=game;font=Resources.Load<Font>("UI/Interface");bold=Resources.Load<Font>("UI/Interface-Bold");rounded=Round();
            canvas=gameObject.AddComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;canvas.sortingOrder=10;
            scaler=gameObject.AddComponent<CanvasScaler>();scaler.uiScaleMode=CanvasScaler.ScaleMode.ConstantPixelSize;
            gameObject.AddComponent<GraphicRaycaster>();
            if(!EventSystem.current){var e=new GameObject("EventSystem");e.AddComponent<EventSystem>();e.AddComponent<StandaloneInputModule>();}
            Root=Rect("Safe area",transform,Vector2.zero,Vector2.one,Vector2.zero,Vector2.zero);
            SafeArea();BuildHud();
        }
        RectTransform Rect(string name,Transform parent,Vector2 min,Vector2 max,Vector2 pos,Vector2 size)
        {
            var g=new GameObject(name,typeof(RectTransform));var r=g.GetComponent<RectTransform>();r.SetParent(parent,false);
            r.anchorMin=min;r.anchorMax=max;r.pivot=new Vector2(.5f,.5f);r.anchoredPosition=pos;r.sizeDelta=size;return r;
        }
        Image Panel(Transform parent,Vector2 anchor,Vector2 pos,Vector2 size,Color color)
        {
            var r=Rect("Surface",parent,anchor,anchor,pos,size);var im=r.gameObject.AddComponent<Image>();im.sprite=rounded;im.type=Image.Type.Sliced;im.color=color;im.raycastTarget=false;return im;
        }
        RailGlyph Icon(Transform parent,RailGlyph.Symbol kind,Vector2 pos,float size,Color color)
        {
            var r=Rect(kind.ToString(),parent,Vector2.one*.5f,Vector2.one*.5f,pos,Vector2.one*size);
            var icon=r.gameObject.AddComponent<RailGlyph>();icon.Kind=kind;icon.color=color;icon.raycastTarget=false;return icon;
        }
        public Text Label(Transform parent,string text,int size,Color color,Vector2 pos,Vector2 dimensions,bool heavy=false)
        {
            var r=Rect("Label",parent,Vector2.one*.5f,Vector2.one*.5f,pos,dimensions);var t=r.gameObject.AddComponent<Text>();
            t.font=heavy?bold:font;t.text=text;t.fontSize=size;t.color=color;t.alignment=TextAnchor.MiddleCenter;t.raycastTarget=false;
            t.horizontalOverflow=HorizontalWrapMode.Wrap;t.verticalOverflow=VerticalWrapMode.Truncate;return t;
        }
        public Button Button(Transform parent,string text,Vector2 anchor,Vector2 pos,Vector2 size,Action action,bool primary=false)
        {
            Panel(parent,anchor,pos+Vector2.down*4,size,new Color(.05f,.14f,.16f,.14f));
            var image=Panel(parent,anchor,pos,size,primary?Gold:Navy);image.raycastTarget=true;
            var button=image.gameObject.AddComponent<Button>();button.targetGraphic=image;
            var c=button.colors;c.highlightedColor=Color.white;c.pressedColor=new Color(.82f,.88f,.9f);c.disabledColor=new Color(.65f,.7f,.71f,.65f);button.colors=c;
            Label(button.transform,text,22,primary?Ink:Cream,Vector2.zero,size-new Vector2(16,8),true);
            button.onClick.AddListener(()=>{Game.Audio.Play("tap");action();});return button;
        }
        void BuildHud()
        {
            var header=Panel(Root,new Vector2(.5f,1),new Vector2(0,-54),new Vector2(696,96),Cream);
            var emblem=Panel(header.transform,Vector2.one*.5f,new Vector2(-298,0),new Vector2(64,64),Navy);
            Icon(emblem.transform,RailGlyph.Symbol.Arrow,Vector2.zero,43,Gold).Direction=Vector2.right;
            title=Label(header.transform,"",27,Ink,new Vector2(-50,15),new Vector2(410,38),true);title.alignment=TextAnchor.MiddleLeft;
            region=Label(header.transform,"",17,Muted,new Vector2(-50,-18),new Vector2(410,28));region.alignment=TextAnchor.MiddleLeft;
            var pause=Button(header.transform,"",Vector2.one*.5f,new Vector2(295,0),new Vector2(64,64),Game.Menu);
            Icon(pause.transform,RailGlyph.Symbol.Pause,Vector2.zero,39,Cream);
            var track=Panel(Root,new Vector2(.5f,1),new Vector2(0,-112),new Vector2(672,7),new Color(.1f,.2f,.22f,.14f));
            progress=Panel(track.transform,new Vector2(0,.5f),Vector2.zero,new Vector2(1,7),Gold);progress.rectTransform.pivot=new Vector2(0,.5f);
            phase=Label(Root,"",18,Ink,Vector2.zero,new Vector2(670,30),true);phase.rectTransform.anchorMin=phase.rectTransform.anchorMax=new Vector2(.5f,1);phase.rectTransform.anchoredPosition=new Vector2(0,-137);
            var dock=Panel(Root,new Vector2(.5f,0),new Vector2(0,67),new Vector2(696,126),Cream);
            count=Label(dock.transform,"",15,Muted,new Vector2(0,47),new Vector2(620,23),true);
            var accents=new[]{GameWorld.Hex("CDE6EF"),GameWorld.Hex("F4D3B8"),GameWorld.Hex("D9DED0")};
            var kinds=new[]{RailGlyph.Symbol.Freeze,RailGlyph.Symbol.Blast,RailGlyph.Symbol.Recall};
            for(int i=0;i<3;i++)
            {
                int kind=i;boosters[i]=Button(dock.transform,"",Vector2.one*.5f,new Vector2((i-1)*224,-13),new Vector2(212,80),()=>Game.Booster(kind));
                var b=boosters[i];var circle=Panel(b.transform,Vector2.one*.5f,new Vector2(-72,0),new Vector2(55,55),accents[i]);
                Icon(circle.transform,kinds[i],Vector2.zero,40,Ink);
                boosterNames[i]=Label(b.transform,"",21,Cream,new Vector2(28,13),new Vector2(135,30),true);
                boosterCounts[i]=Label(b.transform,"",15,Gold,new Vector2(28,-16),new Vector2(135,26));
            }
            for(int i=0;i<5;i++)
            {
                int slot=i;
                // No detached shadow: these labels follow the world-space station berths.
                var image=Panel(Root,Vector2.one*.5f,Vector2.zero,new Vector2(96,42),Navy);image.raycastTarget=true;
                stationActions[i]=image.gameObject.AddComponent<Button>();stationActions[i].targetGraphic=image;
                stationActions[i].onClick.AddListener(()=>Game.StationAction(slot));
                stationLabels[i]=Label(image.transform,"",17,Cream,Vector2.zero,new Vector2(90,38),true);
            }
        }
        public void SafeArea()
        {
            Rect s=Screen.safeArea;
            // Preserve a phone-shaped play surface on desktop without stretching controls.
            float width=Mathf.Min(s.width,s.height*.68f);s.x+=(s.width-width)*.5f;s.width=width;
            float unit=Mathf.Min(s.width/720f,s.height/1280f);scaler.scaleFactor=unit;canvas.scaleFactor=unit;
            Root.anchorMin=new Vector2(s.x/Screen.width,s.y/Screen.height);Root.anchorMax=new Vector2(s.xMax/Screen.width,s.yMax/Screen.height);Root.offsetMin=Root.offsetMax=Vector2.zero;
            int rows=Game.Rules==null?5:Game.Rules.Level.rows;
            float fraction=rows>=5?(s.height<740?.62f:.57f):rows>=4?.54f:.5f;
            float bottom=s.y+142*unit,top=s.yMax-158*unit,split=bottom+(top-bottom)*fraction;
            var routeRect=new Rect(s.x/Screen.width,(split+6*unit)/Screen.height,s.width/Screen.width,(top-split-6*unit)/Screen.height);
            var yardRect=new Rect(s.x/Screen.width,bottom/Screen.height,s.width/Screen.width,(split-bottom)/Screen.height);
            Game.World.SetViewports(routeRect,yardRect);
        }
        Vector2 Local(Vector3 screen){Vector2 local;RectTransformUtility.ScreenPointToLocalPointInRectangle(Root,screen,null,out local);return local;}
        void BindBoard()
        {
            foreach(var flight in flights)if(flight)Destroy(flight);flights.Clear();
            foreach(var v in cardViews.Values)Destroy(v.Root.gameObject);cardViews.Clear();shownRules=Game.Rules;
            foreach(var card in Game.Rules.Cards)
            {
                var root=Rect("Collector direction "+card.Data.id,Root,Vector2.one*.5f,Vector2.one*.5f,Vector2.zero,new Vector2(130,80));
                var v=new CardOverlay{Root=root};v.Arrow=Icon(root,RailGlyph.Symbol.Arrow,new Vector2(-17,0),72,Color.white);
                v.Badge=Panel(root,Vector2.one*.5f,new Vector2(35,-17),new Vector2(40,33),Ink);
                v.Count=Label(v.Badge.transform,"",26,Cream,Vector2.zero,new Vector2(38,31),true);
                v.Key=Label(root,"",23,Ink,new Vector2(0,-44),new Vector2(170,26),true);
                cardViews[card.Data.id]=v;
            }
            if(Modal)Modal.transform.SetAsLastSibling();
        }
        public void Refresh()
        {
            var r=Game.Rules;if(r==null)return;if(!ReferenceEquals(shownRules,r)){SafeArea();BindBoard();}
            title.text=L("Bölüm ","Level ")+r.Level.id;
            region.text=(Game.English?r.Level.region_en:r.Level.region)??r.Level.region;
            if(r.Multi)region.text+="  /  "+r.Heads.Length+L(" tren"," trains");
            progress.rectTransform.sizeDelta=new Vector2(Mathf.Clamp01((float)r.Danger)*672,7);
            progress.color=r.Danger>.87?GameWorld.Hex("E65D52"):Gold;
            phase.text=r.FreezeLeft>0?L("TREN DURDU  ·  ","TRAIN FROZEN  ·  ")+r.FreezeLeft.ToString("0.0")+" s":r.Danger>.87?L("Son viraj! Yaklaşan renkleri karşıla.","Final stretch! Match the approaching colors."):L("Oku izle. Yolu aç. Treni kurtar.","Follow the arrow. Clear the way. Save the train.");
            count.text=L("KURTARILAN VAGONLAR  ","WAGONS RESCUED  ")+(r.Total-r.Wagons.Count)+" / "+r.Total;
            var names=Game.English?new[]{"Freeze","Blast","Recall"}:new[]{"Dondur","Patlat","Geri al"};
            for(int i=0;i<3;i++)
            {
                boosterNames[i].text=names[i];boosterCounts[i].text=r.BoosterStock[i]>0?r.BoosterStock[i]+L(" kullanım"," use(s)"):Game.Commerce.RewardReady?L("Reklam · +1","Watch ad · +1"):L("Reklam yok","Ad unavailable");
                boosters[i].interactable=r.Status=="playing"&&!Game.Paused;
            }
            var locked=new List<string>();if(!r.Vip)locked.Add("VIP +1");if(!r.RewardSlot)locked.Add(L("Reklam +1","Ad +1"));
            for(int i=0;i<5;i++)
            {
                bool open=i<r.Slots.Count;bool occupied=open&&r.Slots[i].Collector>=0;
                stationLabels[i].text=open?(occupied?r.Cards[r.Slots[i].Collector].Remaining.ToString():L("BOŞ","FREE")):locked[i-r.Slots.Count];
                stationActions[i].interactable=!open&&!Game.Paused&&r.Status=="playing";
                stationActions[i].targetGraphic.raycastTarget=!open;
                stationActions[i].targetGraphic.color=!open&&locked[i-r.Slots.Count].StartsWith("VIP")?Gold:Navy;
                stationLabels[i].color=!open&&locked[i-r.Slots.Count].StartsWith("VIP")?Ink:Cream;
                var pos=Game.World.YardCamera.WorldToScreenPoint(Game.World.SlotPositions[i]+new Vector3(0,.15f,-1));
                stationActions[i].GetComponent<RectTransform>().anchoredPosition=Local(pos);
                var adjacent=Local(Game.World.YardCamera.WorldToScreenPoint(Game.World.SlotPositions[i]+new Vector3(2.65f,.15f,-1)));
                float w=Mathf.Clamp(Mathf.Abs(adjacent.x-Local(pos).x)-7,64,112);
                stationActions[i].GetComponent<RectTransform>().sizeDelta=new Vector2(w,40);stationLabels[i].rectTransform.sizeDelta=new Vector2(w-4,38);
            }
            foreach(var c in r.Cards)
            {
                var v=cardViews[c.Data.id];v.Root.gameObject.SetActive(c.State=="parked");if(c.State!="parked")continue;
                var at=Game.World.CardPosition(c.Data.id);v.Root.anchoredPosition=Local(Game.World.YardCamera.WorldToScreenPoint(at));
                float cell=(Local(Game.World.YardCamera.WorldToScreenPoint(at+Vector3.right*4.2f))-v.Root.anchoredPosition).magnitude;
                v.Root.localScale=Vector3.one*Mathf.Clamp(cell/180f,.9f,1.15f);
                v.Arrow.Direction=Game.World.CardDirection(c.Data);v.Arrow.color=Time.unscaledTime<v.FlashUntil?GameWorld.Hex("FFB884"):Color.white;v.Arrow.SetVerticesDirty();
                v.Count.text=c.Remaining.ToString();v.Badge.color=Time.unscaledTime<v.FlashUntil?GameWorld.Hex("AC372F"):Ink;
                v.Key.text=r.Locked(c.Data.id)?"["+r.Cards[c.Data.requires].Data.key+"]":!string.IsNullOrEmpty(c.Data.key)?"+"+c.Data.key:"";
            }
        }
        public void Blocked(int id,IEnumerable<int> blockers)
        {
            if(cardViews.ContainsKey(id))cardViews[id].FlashUntil=Time.unscaledTime+.8f;
            foreach(int other in blockers)if(cardViews.ContainsKey(other))cardViews[other].FlashUntil=Time.unscaledTime+.8f;
        }
        public void Match(MatchEvent match){StartCoroutine(MatchFlight(match));}
        IEnumerator MatchFlight(MatchEvent match)
        {
            var from=Local(Game.World.Camera.WorldToScreenPoint(Game.World.Rail.Point(match.Lane,match.Distance)+Vector3.up));
            var to=Local(Game.World.YardCamera.WorldToScreenPoint(Game.World.SlotPositions[match.Slot]+Vector3.up));
            var dot=Panel(Root,Vector2.one*.5f,from,new Vector2(22,22),GameWorld.Palette[match.Color]);flights.Add(dot.gameObject);
            float t=0;while(dot&&t<.26f){t+=Time.deltaTime;float f=Mathf.Clamp01(t/.26f);dot.rectTransform.anchoredPosition=Vector2.Lerp(from,to,f)+Vector2.right*Mathf.Sin(f*Mathf.PI)*30;dot.rectTransform.localScale=Vector3.one*Mathf.Lerp(1,.35f,f);yield return null;}if(dot){flights.Remove(dot.gameObject);Destroy(dot.gameObject);}
        }
        public Transform Dialog(string heading,string description)
        {
            Close();Modal=Rect("Dialog overlay",Root,Vector2.zero,Vector2.one,Vector2.zero,Vector2.zero).gameObject;
            var dim=Modal.AddComponent<Image>();dim.color=new Color(.05f,.12f,.15f,.78f);
            var panel=Panel(Modal.transform,Vector2.one*.5f,Vector2.zero,new Vector2(648,850),Cream);
            Panel(panel.transform,Vector2.one*.5f,new Vector2(0,410),new Vector2(180,7),Gold);
            Label(panel.transform,"RENK / EKSPRESİ",13,Muted,new Vector2(0,384),new Vector2(500,22),true);
            Label(panel.transform,heading,30,Ink,new Vector2(0,330),new Vector2(576,72),true);
            Label(panel.transform,description,21,Muted,new Vector2(0,183),new Vector2(558,210));
            return panel.transform;
        }
        public Button DialogButton(Transform p,string text,int row,Action action,bool primary=false)
        {return Button(p,text,Vector2.one*.5f,new Vector2(0,15-row*66),new Vector2(550,56),action,primary);}
        public void Slider(Transform parent,string heading,int row,float value,Action<float> changed)
        {
            float y=40-row*105;Label(parent,heading,20,Ink,new Vector2(0,y+29),new Vector2(540,30));
            var track=Panel(parent,Vector2.one*.5f,new Vector2(0,y),new Vector2(490,18),GameWorld.Hex("CAD4CC"));track.raycastTarget=true;
            // A wide transparent hit surface makes dragging possible on a phone.
            var hit=Panel(parent,Vector2.one*.5f,new Vector2(0,y),new Vector2(510,48),Color.clear);hit.raycastTarget=true;
            var handle=Panel(hit.transform,Vector2.one*.5f,Vector2.zero,new Vector2(36,36),Navy);
            var slider=hit.gameObject.AddComponent<Slider>();slider.direction=UnityEngine.UI.Slider.Direction.LeftToRight;slider.handleRect=handle.rectTransform;slider.targetGraphic=handle;slider.minValue=0;slider.maxValue=1;slider.value=value;slider.onValueChanged.AddListener(v=>changed(v));
        }
        public void Close(){if(Modal){Modal.SetActive(false);Destroy(Modal);Modal=null;}}
        public void Toast(string text)
        {
            if(toast){toast.SetActive(false);Destroy(toast);}
            var panel=Panel(Root,new Vector2(.5f,0),new Vector2(0,176),new Vector2(640,64),Navy);toast=panel.gameObject;
            Label(panel.transform,text,20,Cream,Vector2.zero,new Vector2(610,58));Destroy(toast,2);
        }
    }
}
