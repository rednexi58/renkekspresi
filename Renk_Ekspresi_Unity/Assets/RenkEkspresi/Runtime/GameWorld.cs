using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
namespace RenkEkspresi
{
    public sealed class CardTag : MonoBehaviour
    {
        public int Id;
    }
    public sealed class GameWorld : MonoBehaviour
    {
        public Camera Camera, YardCamera; public RailSpline Rail; public Vector3[] SlotPositions = new Vector3[5];
        public static readonly Color[] Palette = { Hex("E65D52"), Hex("348CD3"), Hex("F2C34D"), Hex("39A985"), Hex("9868CD") };
        static readonly string[] Grounds = { "A8C5B3", "E6D8B9", "B7C2A1", "C1CCCF", "D4AE92", "DBE4E7" };
        readonly Dictionary<int, GameObject> wagons = new Dictionary<int, GameObject>();
        readonly Dictionary<int, Transform> cards = new Dictionary<int, Transform>();
        const int YardLayer = 30;
        readonly List<LineRenderer> loadingTracks = new List<LineRenderer>();
        readonly List<GameObject> engines = new List<GameObject>();
        readonly List<GameObject> stationTokens = new List<GameObject>();
        readonly List<int> stationColors = new List<int>();
        readonly Dictionary<string, Material> materials = new Dictionary<string, Material>();
        Transform content, scenery, yard; Vector3[] cardOrigins; LevelData level;
        public static Color Hex(string value)
        {
            Color c;
            ColorUtility.TryParseHtmlString("#" + value, out c);
            return c;
        }
        Material Mat(Color c)
        {
            string key = ColorUtility.ToHtmlStringRGBA(c);
            if (materials.ContainsKey(key))
                return materials[key];
            var m = new Material(Resources.Load<Shader>("Environment"));
            m.color = c;
            m.SetFloat("_Glossiness", .28f);
            materials[key] = m;
            return m;
        }
        GameObject Shape(string name, PrimitiveType type, Vector3 at, Vector3 scale, Color c, Transform parent = null)
        {
            var go = GameObject.CreatePrimitive(type);
            go.name = name;
            go.transform.SetParent(parent ? parent : scenery, false);
            go.transform.localPosition = at;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = Mat(c);
            Destroy(go.GetComponent<Collider>());
            return go;
        }
        public void Setup()
        {

            var go = new GameObject("Fixed portrait camera");
            Camera = go.AddComponent<Camera>();
            Camera.orthographic = true;
            Camera.clearFlags = CameraClearFlags.SolidColor;
            Camera.backgroundColor = Hex("CBD9D7");
            Camera.nearClipPlane = .1f;
            Camera.farClipPlane = 200;
            go.AddComponent<AudioListener>();
            Camera.cullingMask = ~(1 << YardLayer);
            YardCamera = new GameObject("Fixed close-up puzzle camera").AddComponent<Camera>();
            YardCamera.orthographic = true;
            YardCamera.clearFlags = CameraClearFlags.SolidColor;
            YardCamera.backgroundColor = Hex("EDECE3");
            YardCamera.cullingMask = 1 << YardLayer;
            YardCamera.nearClipPlane = .1f;
            YardCamera.farClipPlane = 160;
            YardCamera.depth = Camera.depth + 1;
            var sun = new GameObject("Soft morning sun").AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.intensity = 1.05f;
            sun.color = Hex("FFF0D9");
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = .32f;
            sun.transform.rotation = Quaternion.Euler(52, -32, 0);
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = Hex("D8E4EF");
            RenderSettings.ambientEquatorColor = Hex("A3B7B0");
            RenderSettings.ambientGroundColor = Hex("697A73");
        }
        public void Load(LevelData data)
        {
            StopAllCoroutines();
            level = data;
            Rail = new RailSpline(data.id);
            if (content)
                Destroy(content.gameObject);
            content = new GameObject("Level " + data.id).transform;
            content.SetParent(transform, false);
            scenery = new GameObject("Environment").transform;
            scenery.SetParent(content, false);
            wagons.Clear();
            cards.Clear();
            yard = new GameObject("Dispatch yard").transform;
            yard.SetParent(content, false);
            engines.Clear();
            loadingTracks.Clear();
            stationTokens.Clear();
            stationColors.Clear();
            Shape("Terrain", PrimitiveType.Cube, new Vector3(0, -.4f, 5), new Vector3(90, .7f, 90), Hex(Grounds[data.theme]));
            for (int lane = 0; lane < Rail.Routes.Length; lane++)
            {
                for (float d = 0; d < Rail.Routes[lane].length; d += .45f)
                {
                    var tie = Shape("Sleeper", PrimitiveType.Cube, Rail.Point(lane, d) + Vector3.up * .08f, new Vector3(1.18f, .12f, .21f), Hex("685949"));
                    tie.transform.rotation = Quaternion.LookRotation(Rail.Direction(lane, d));
                }
                var bed = new GameObject("Continuous stone track bed").AddComponent<LineRenderer>();
                bed.transform.SetParent(scenery, false);
                bed.useWorldSpace=false; bed.positionCount=Rail.Routes[lane].points.Length;
                bed.startWidth=bed.endWidth=1.55f; bed.alignment=LineAlignment.TransformZ;
                bed.transform.rotation=Quaternion.Euler(-90,0,0);
                bed.sharedMaterial=Mat(Hex("8E9C98"));
                for(int i=0;i<bed.positionCount;i++) bed.SetPosition(i,bed.transform.InverseTransformPoint(Rail.Routes[lane].points[i]+Vector3.up*.015f));
                var active = new GameObject("Physical matching track").AddComponent<LineRenderer>();
                active.transform.SetParent(content,false);active.positionCount=32;active.useWorldSpace=true;
                active.startWidth=active.endWidth=1.27f;active.alignment=LineAlignment.TransformZ;
                active.transform.rotation=Quaternion.Euler(-90,0,0);
                active.sharedMaterial=Mat(Hex("69B9AE"));
                float end=data.track_length-.9f,start=.8f+(end-.8f)*(float)data.loading_fraction;
                for(int i=0;i<32;i++)active.SetPosition(i,Rail.Point(lane,Mathf.Lerp(start,end-.2f,i/31f))+Vector3.up*.035f);
                active.gameObject.SetActive(false);loadingTracks.Add(active);
                foreach (float side in new[] { -.37f, .37f })
                {
                    var line = new GameObject("Steel rail").AddComponent<LineRenderer>();
                    line.transform.SetParent(scenery, false);
                    line.useWorldSpace = false;
                    line.positionCount = Rail.Routes[lane].points.Length;
                    line.startWidth = line.endWidth = .085f;
                    line.numCornerVertices = 2;
                    line.sharedMaterial = Mat(Hex("B9C7CB"));
                    for (int i = 0; i < line.positionCount; i++)
                    {
                        float d = Rail.Routes[lane].length * i / (line.positionCount - 1);
                        line.SetPosition(i, Rail.Point(lane, d) + Vector3.Cross(Vector3.up, Rail.Direction(lane, d)) * side + Vector3.up * .18f);
                    }
                }
                var engine = TrainModels.Create(-1, content);
                engines.Add(engine);
                var depot = new GameObject("Depot").transform;
                depot.SetParent(scenery, false);
                depot.position = Rail.Point(lane, 0);
                depot.rotation = Quaternion.LookRotation(Rail.Direction(lane, 0));
                for (int side = -1; side <= 1; side += 2)
                    Shape("Depot pier", PrimitiveType.Cube, Vector3.right * side * .9f + Vector3.up * .8f, new Vector3(.5f, 1.6f, 1.6f), Hex("737F7B"), depot);
                Shape("Depot roof", PrimitiveType.Cube, Vector3.up * 1.7f, new Vector3(2.4f, .35f, 1.8f), Hex("445D63"), depot);
            }
            Shape("Station platform", PrimitiveType.Cube, new Vector3(0, .05f, 0), new Vector3(15.8f, .28f, 2.4f), Hex("D3D8CD"), yard);
            for (int i = 0; i < 5; i++)
            {
                SlotPositions[i] = new Vector3((i - 2) * 2.65f, .3f, 0);
                Shape("Brass station berth", PrimitiveType.Cube, SlotPositions[i], new Vector3(2.3f, .12f, 1.65f), Hex("7B9693"), yard);
                stationTokens.Add(null);
                stationColors.Add(-1);
            }
            cardOrigins = new Vector3[data.parking.Length];
            Shape("Puzzle yard", PrimitiveType.Cube, new Vector3(0, -.02f, -4.2f - (data.rows - 1) * 1.175f), new Vector3(16.4f, .18f, data.rows * 2.35f + 1.6f), Hex("DBDFD6"), yard);
            foreach (var c in data.parking)
            {
                var root = new GameObject("Collector " + c.id);
                root.transform.SetParent(yard, false);
                root.transform.localPosition = new Vector3((c.col - (data.cols - 1) * .5f) * 4.2f, .12f, -4.2f - c.row * 2.35f);
                cardOrigins[c.id] = root.transform.localPosition;
                var model = TrainModels.Create(c.color, root.transform);
                model.transform.localScale = Vector3.one * 1.27f;
                model.transform.localRotation = Quaternion.LookRotation(new Vector3(c.dx * 4.2f, 0, -c.dz * 2.35f));
                var hit = root.AddComponent<BoxCollider>();
                hit.center = Vector3.up * .7f;
                hit.size = new Vector3(3.6f, 1.7f, 2);
                root.AddComponent<CardTag>().Id = c.id;
                cards[c.id] = root.transform;
            }
            for (int i = 0; i < data.train.Length; i++)
                wagons[i] = TrainModels.Create(data.train[i], content);
            // Visible rails under each collector establish a consistent, readable grid.
            for (int row = 0; row < data.rows; row++)
                for (int col = 0; col < data.cols; col++)
                    Shape("Yard paving", PrimitiveType.Cube,
                        new Vector3((col - (data.cols - 1) * .5f) * 4.2f, .10f, -4.2f - row * 2.35f),
                        new Vector3(3.85f, .04f, 2.12f), Hex("EDEEE6"), yard);
            SetLayer(yard.gameObject, YardLayer);
            Decorate();
            BuildFriend(Rail.Point(0, Rail.Routes[0].length) + new Vector3(1.8f, 0, 0));
            Fit();
            StaticBatchingUtility.Combine(scenery.gameObject);
        }
        public static void SetLayer(GameObject go, int layer)
        {
            go.layer = layer;
            foreach (Transform child in go.transform) SetLayer(child.gameObject, layer);
        }
        public Vector3 CardPosition(int id) { return cards[id].position + Vector3.up * 1.9f; }
        public Vector2 CardDirection(CardData c)
        {
            var origin = CardPosition(c.id);
            return (Vector2)(YardCamera.WorldToScreenPoint(origin + new Vector3(c.dx * 4.2f, 0, -c.dz * 2.35f)) - YardCamera.WorldToScreenPoint(origin));
        }
        public void Sync(PuzzleEngine rules)
        {
            for (int lane = 0; lane < engines.Count; lane++)
            {
                engines[lane].SetActive(rules.HasLane(lane));
                loadingTracks[lane].gameObject.SetActive(rules.Opened[lane] && rules.HasLane(lane));
                engines[lane].transform.position = Rail.Point(lane, rules.Heads[lane]);
                engines[lane].transform.rotation = Quaternion.LookRotation(Rail.Direction(lane, rules.Heads[lane]));
            }
            var live = new HashSet<int>(rules.Wagons.Select(w => w.Id));
            foreach (var pair in wagons)
                if (!live.Contains(pair.Key))
                    pair.Value.SetActive(false);
            foreach (var w in rules.Wagons)
            {
                var go = wagons[w.Id];
                go.SetActive(w.Distance >= 0);
                if (w.Distance >= 0)
                {
                    go.transform.position = Rail.Point(w.Lane, w.Distance);
                    go.transform.rotation = Quaternion.LookRotation(Rail.Direction(w.Lane, w.Distance));
                }
            }
            foreach (var c in rules.Cards)
            {
                cards[c.Data.id].gameObject.SetActive(c.State == "parked");
            }
            for (int i = 0; i < 5; i++)
            {
                int color = i < rules.Slots.Count ? rules.Slots[i].Color : -1;
                if (stationColors[i] != color)
                {
                    if (stationTokens[i])
                        Destroy(stationTokens[i]);
                    stationTokens[i] = color < 0 ? null : TrainModels.Create(color, yard);
                    stationColors[i] = color;
                    if (stationTokens[i])
                    {
                        SetLayer(stationTokens[i], YardLayer);
                        stationTokens[i].transform.position = SlotPositions[i] + Vector3.up * .15f;
                        stationTokens[i].transform.rotation = Quaternion.Euler(0, 90, 0);
                        stationTokens[i].transform.localScale = Vector3.one * .8f;
                    }
                }
            }
        }
        // Short animations give feedback without changing rule time or match eligibility.
        public void Launch(int id, PuzzleEngine rules)
        {
            int slot = rules.Slots.FindIndex(s => s.Collector == id);
            if (slot < 0)
                return;
            var ghost = TrainModels.Create(rules.Cards[id].Data.color, yard);
            SetLayer(ghost, YardLayer);
            ghost.transform.localScale = Vector3.one * 1.1f;
            StartCoroutine(Fly(ghost, cardOrigins[id] + Vector3.up * .4f, SlotPositions[slot] + Vector3.up * .5f, .26f, false));
        }
        public void Match(MatchEvent match)
        {
            StartCoroutine(Sparkle(SlotPositions[match.Slot] + Vector3.up * 1.2f));
        }
        IEnumerator Fly(GameObject go, Vector3 from, Vector3 to, float duration, bool shrink)
        {
            float elapsed = 0;
            while (go && elapsed < duration)
            {
                elapsed += Time.deltaTime;
                float t = Mathf.Clamp01(elapsed / duration), ease = t * t * (3 - 2 * t);
                go.transform.position = Vector3.Lerp(from, to, ease) + Vector3.up * Mathf.Sin(t * Mathf.PI) * 1.8f;
                go.transform.rotation = Quaternion.Euler(0, Mathf.Lerp(0, 90, ease), 0);
                if (shrink)
                    go.transform.localScale = Vector3.one * Mathf.Lerp(.85f, .15f, ease);
                yield return null;
            }
            if (go)
                Destroy(go);
            if (shrink)
                StartCoroutine(Sparkle(to));
        }
        IEnumerator Sparkle(Vector3 at)
        {
            var bits = new GameObject[5];
            for (int i = 0; i < bits.Length; i++)
                bits[i] = Shape("Brass sparkle", PrimitiveType.Sphere, at, Vector3.one * .1f, Hex("F0D392"), yard);
            foreach (var bit in bits) SetLayer(bit, YardLayer);
            float t = 0;
            while (t < .32f)
            {
                t += Time.deltaTime;
                for (int i = 0; i < bits.Length; i++)
                    if (bits[i])
                    {
                        float a = i * Mathf.PI * 2 / bits.Length;
                        bits[i].transform.position = at + new Vector3(Mathf.Cos(a), .7f, Mathf.Sin(a)) * t * 2.5f;
                        bits[i].transform.localScale = Vector3.one * .1f * (1 - t / .32f);
                    }
                yield return null;
            }
            foreach (var bit in bits)
                if (bit)
                    Destroy(bit);
        }
        public void Nudge(int id)
        {
            if (cards.ContainsKey(id))
                StartCoroutine(NudgeRoutine(id));
        }
        IEnumerator NudgeRoutine(int id)
        {
            float elapsed = 0;
            while (elapsed < .2f && cards.ContainsKey(id))
            {
                elapsed += Time.deltaTime;
                cards[id].localPosition = cardOrigins[id] + Vector3.right * Mathf.Sin(elapsed * 70) * .12f;
                yield return null;
            }
            if (cards.ContainsKey(id))
                cards[id].localPosition = cardOrigins[id];
        }
        public int Pick(Vector2 screen)
        {
            if (!YardCamera.pixelRect.Contains(screen)) return -1;
            // Pick on one common plane, so tall colliders cannot steal a tap from the row behind.
            var ray = YardCamera.ScreenPointToRay(screen);
            var plane = new Plane(Vector3.up, Vector3.up * 2.02f);
            float distance;
            if (!plane.Raycast(ray, out distance)) return -1;
            var point = ray.GetPoint(distance);
            foreach (var entry in cards)
            {
                if (!entry.Value.gameObject.activeSelf) continue;
                var delta = point - entry.Value.position;
                if (Mathf.Abs(delta.x) <= 2.02f && Mathf.Abs(delta.z) <= 1.16f) return entry.Key;
            }
            return -1;
        }
        public void SetViewports(Rect routeRect, Rect yardRect)
        {
            Camera.rect = routeRect; YardCamera.rect = yardRect; Fit();
        }
        public void Fit()
        {
            if (level == null) return;
            var routePoints = Rail.Routes.SelectMany(r => r.points).ToList();
            routePoints.AddRange(routePoints.Select(p => p + Vector3.up * 2.2f).ToArray());
            Frame(Camera, routePoints.ToArray(), 58, 1.12f);
            var board = new[] {new Vector3(-7.7f,0,1.7f), new Vector3(7.7f,2.5f,1.7f),
                new Vector3(-7.7f,0,-5.5f-(level.rows-1)*2.35f),new Vector3(7.7f,2.2f,-5.5f-(level.rows-1)*2.35f)};
            Frame(YardCamera, board, 67, 1.05f);
            Camera.backgroundColor = Hex(Grounds[Mathf.Clamp(level.theme,0,Grounds.Length-1)]);
        }
        static void Frame(Camera camera, Vector3[] points, float angle, float padding)
        {
            camera.transform.rotation = Quaternion.Euler(angle,0,0);
            var rotation = Quaternion.Inverse(camera.transform.rotation);
            Vector3 min = Vector3.one * float.MaxValue, max = Vector3.one * float.MinValue;
            foreach (var point in points) {var p = rotation * point; min=Vector3.Min(min,p);max=Vector3.Max(max,p);}
            var center = camera.transform.rotation * ((min+max)*.5f);
            camera.transform.position = center - camera.transform.forward * 65;
            camera.orthographicSize = Mathf.Max((max.y-min.y)*.5f,(max.x-min.x)*.5f / Mathf.Max(.1f,camera.aspect))*padding;
        }
        void Tree(Vector3 p, bool snow)
        {
            Shape("Cedar trunk", PrimitiveType.Cylinder, p+Vector3.up*.6f,new Vector3(.14f,.6f,.14f),Hex("82694C"));
            for(int i=0;i<3;i++)
            {
                var crown=Shape("Layered cedar",PrimitiveType.Capsule,p+Vector3.up*(1.25f+i*.36f),new Vector3(1.22f-i*.24f,.48f,1.22f-i*.24f),Hex(snow?"CADCD2":i==0?"3D7868":i==1?"4E9278":"72A88A"));
            }
            if(snow)Shape("Snow cap",PrimitiveType.Sphere,p+Vector3.up*2.1f,new Vector3(.65f,.3f,.65f),Hex("F8FAEF"));
        }
        void House(Vector3 p, bool coast)
        {
            Shape("Station cottage",PrimitiveType.Cube,p+Vector3.up*.58f,new Vector3(1.15f,1.16f,.95f),Hex(coast?"FAEDCF":"E5DBC8"));
            for(int side=-1;side<=1;side+=2)
            {
                var roof=Shape("Pitched roof",PrimitiveType.Cube,p+new Vector3(side*.31f,1.26f,0),new Vector3(.78f,.12f,1.2f),Hex(coast?"C16C4D":"4C707B"));
                roof.transform.localRotation=Quaternion.Euler(0,0,side*-28);
                Shape("Glazed window",PrimitiveType.Cube,p+new Vector3(side*.31f,.73f,-.49f),new Vector3(.22f,.32f,.03f),Hex("8ECBD2"));
            }
            Shape("Door",PrimitiveType.Cube,p+new Vector3(0,.32f,-.49f),new Vector3(.23f,.61f,.035f),Hex("426A70"));
        }
        void Decorate()
        {
            var rng=new System.Random(level.map_seed);
            var path=Rail.Routes.SelectMany(r=>r.points).ToArray();
            float low=path.Min(p=>p.z),high=path.Max(p=>p.z);
            if(level.theme==1)
            {
                Shape("Turquoise inlet",PrimitiveType.Sphere,new Vector3(-12,-.3f,(low+high)*.5f),new Vector3(9,.45f,high-low+10),Hex("70BABF"));
                Shape("Shallow water",PrimitiveType.Sphere,new Vector3(-9.7f,-.18f,(low+high)*.5f),new Vector3(3,.16f,high-low+6),Hex("A1D8CE"));
                for(int i=0;i<8;i++)Shape("Wave glint",PrimitiveType.Capsule,new Vector3(-9.7f-(float)rng.NextDouble(),-.08f,low+i*2),new Vector3(.06f,.04f,1.2f),Hex("DFF0E4"));
            }
            if(level.theme==3)
                for(int i=0;i<3;i++)House(new Vector3(9.1f,0,low+2+i*4),false);
            for(int i=0;i<40;i++)
            {
                var p=new Vector3((float)rng.NextDouble()*21-10.5f,0,low-1+(float)rng.NextDouble()*(high-low+2));
                // Decorations never stand on rails or hide a train.
                if(path.Any(q=>(q-p).sqrMagnitude<3.2f))continue;
                if(level.theme==1)
                {
                    if(p.x<-8)continue;
                    if(i%4==0)House(p,true);
                    else if(i%3==0)Shape("Coastal boulder",PrimitiveType.Sphere,p+Vector3.up*.23f,new Vector3(.75f,.48f,.58f),Hex("D6C8AE"));
                    else Tree(p,false);
                }
                else if(level.theme==4)
                {
                    for(int j=0;j<3;j++)Shape("Weathered sandstone",PrimitiveType.Capsule,p+Vector3.up*(.35f+j*.36f),new Vector3(1.35f-j*.28f,.31f,1.1f-j*.2f),Hex(j==1?"BC8766":"D6A583"));
                    if(i%3==0)Shape("Desert scrub",PrimitiveType.Sphere,p+new Vector3(.7f,.2f,0),new Vector3(.46f,.4f,.43f),Hex("8D9D78"));
                }
                else if(level.theme==2)
                {
                    if(i%3==0)House(p,false);
                    else {Shape("Meadow",PrimitiveType.Sphere,p+Vector3.down*.09f,new Vector3(2.3f,.3f,1.5f),Hex("9CAC86"));Tree(p,false);}
                }
                else if(level.theme==3){if(i%2==0)House(p,false);else Tree(p,false);}
                else Tree(p,level.theme==5);
            }
            for(int side=-1;side<=1;side+=2)
            {
                for(int i=0;i<5;i++)
                {
                    var p=new Vector3(side*9.5f,0,low+i*(high-low)/4);
                    Shape("Boundary post",PrimitiveType.Cylinder,p+Vector3.up*.33f,new Vector3(.1f,.33f,.1f),Hex("F1E6CB"));
                }
                Shape("Timber boundary",PrimitiveType.Cube,new Vector3(side*9.5f,.46f,(low+high)*.5f),new Vector3(.07f,.09f,high-low),Hex("D8C69E"));
            }
        }
        void BuildFriend(Vector3 p)
        {
            Shape("Cotton body", PrimitiveType.Sphere, p + Vector3.up * .45f, new Vector3(.75f, .8f, .65f), Hex("F1E9D9"));
            Shape("Cotton head", PrimitiveType.Sphere, p + new Vector3(0, .96f, -.1f), new Vector3(.62f, .62f, .55f), Hex("F7F0E4"));
            for (int s = -1; s <= 1; s += 2)
            {
                Shape("Ear", PrimitiveType.Sphere, p + new Vector3(s * .18f, 1.4f, -.05f), new Vector3(.18f, .65f, .16f), Hex("F7F0E4"));
                Shape("Eye", PrimitiveType.Sphere, p + new Vector3(s * .14f, 1, -.36f), Vector3.one * .075f, Hex("233D45"));
            }
        }
    }
}
