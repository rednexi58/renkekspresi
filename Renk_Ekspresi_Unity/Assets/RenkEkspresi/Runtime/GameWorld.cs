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
        public Camera Camera; public RailSpline Rail; public Vector3[] SlotPositions = new Vector3[5];
        public static readonly Color[] Palette = { Hex("E85852"), Hex("448DDF"), Hex("F0C347"), Hex("53B689"), Hex("A87DDD") };
        static readonly string[] Grounds = { "9EBCA3", "D7CAAF", "B9B98D", "B2BDC1", "C9A083", "D2DFDF" };
        readonly Dictionary<int, GameObject> wagons = new Dictionary<int, GameObject>();
        readonly Dictionary<int, Transform> cards = new Dictionary<int, Transform>();
        readonly Dictionary<int, TextMesh> captions = new Dictionary<int, TextMesh>();
        readonly List<GameObject> engines = new List<GameObject>();
        readonly List<GameObject> stationTokens = new List<GameObject>();
        readonly List<int> stationColors = new List<int>();
        readonly Dictionary<string, Material> materials = new Dictionary<string, Material>();
        Transform content, scenery; Font font; Vector3[] cardOrigins; LevelData level;
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
            font = Resources.Load<Font>("UI/Interface-Bold");
            var go = new GameObject("Fixed portrait camera");
            Camera = go.AddComponent<Camera>();
            Camera.orthographic = true;
            Camera.clearFlags = CameraClearFlags.SolidColor;
            Camera.backgroundColor = Hex("CBD9D7");
            Camera.nearClipPlane = .1f;
            Camera.farClipPlane = 200;
            go.AddComponent<AudioListener>();
            var sun = new GameObject("Soft morning sun").AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.intensity = 1.15f;
            sun.color = Hex("FFF0D9");
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = .55f;
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
            captions.Clear();
            engines.Clear();
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
            Shape("Station platform", PrimitiveType.Cube, new Vector3(0, .05f, 0), new Vector3(14.2f, .25f, 2), Hex("788C8B"));
            for (int i = 0; i < 5; i++)
            {
                SlotPositions[i] = new Vector3((i - 2) * 2.65f, .3f, 0);
                Shape("Brass station berth", PrimitiveType.Cube, SlotPositions[i], new Vector3(2.15f, .16f, 1.5f), Hex("C8B98F"));
                stationTokens.Add(null);
                stationColors.Add(-1);
            }
            cardOrigins = new Vector3[data.parking.Length];
            Shape("Puzzle yard", PrimitiveType.Cube, new Vector3(0, -.02f, -4.2f - (data.rows - 1) * 1.175f), new Vector3(14.2f, .14f, data.rows * 2.35f + .8f), Hex("718789"));
            foreach (var c in data.parking)
            {
                var root = new GameObject("Collector " + c.id);
                root.transform.SetParent(content, false);
                root.transform.localPosition = new Vector3((c.col - (data.cols - 1) * .5f) * 4.2f, .12f, -4.2f - c.row * 2.35f);
                cardOrigins[c.id] = root.transform.localPosition;
                var model = TrainModels.Create(c.color, root.transform);
                model.transform.localScale = Vector3.one * 1.25f;
                model.transform.localRotation = Quaternion.LookRotation(new Vector3(c.dx, 0, -c.dz));
                var hit = root.AddComponent<BoxCollider>();
                hit.center = Vector3.up * .7f;
                hit.size = new Vector3(3.6f, 1.7f, 2);
                root.AddComponent<CardTag>().Id = c.id;
                var caption = new GameObject("Arrow and capacity").AddComponent<TextMesh>();
                caption.transform.SetParent(root.transform, false);
                caption.transform.localPosition = new Vector3(0, 2.1f, 0);
                caption.font = font;
                caption.GetComponent<Renderer>().sharedMaterial = font.material;
                caption.fontSize = 54;
                caption.characterSize = .045f;
                caption.anchor = TextAnchor.MiddleCenter;
                caption.color = Color.white;
                caption.transform.rotation = Quaternion.Euler(65, 0, 0);
                captions[c.id] = caption;
                cards[c.id] = root.transform;
            }
            for (int i = 0; i < data.train.Length; i++)
                wagons[i] = TrainModels.Create(data.train[i], content);
            Decorate();
            BuildFriend(Rail.Point(0, Rail.Routes[0].length) + new Vector3(1.8f, 0, 0));
            Fit();
            StaticBatchingUtility.Combine(scenery.gameObject);
        }
        string Arrow(CardData c)
        {
            if (c.dx == 0)
                return c.dz < 0 ? "↑" : "↓";
            if (c.dz == 0)
                return c.dx < 0 ? "←" : "→";
            return c.dx < 0 ? (c.dz < 0 ? "↖" : "↙") : (c.dz < 0 ? "↗" : "↘");
        }
        public void Sync(PuzzleEngine rules)
        {
            for (int lane = 0; lane < engines.Count; lane++)
            {
                engines[lane].SetActive(rules.HasLane(lane));
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
                captions[c.Data.id].text = (rules.Locked(c.Data.id) ? rules.Cards[c.Data.requires].Data.key + " ◇ " : !string.IsNullOrEmpty(c.Data.key) ? c.Data.key + " ◆ " : "") + Arrow(c.Data) + "  " + c.Remaining;
                captions[c.Data.id].color = rules.Available(c.Data.id) ? Color.white : Hex("C4D2D2");
            }
            for (int i = 0; i < 5; i++)
            {
                int color = i < rules.Slots.Count ? rules.Slots[i].Color : -1;
                if (stationColors[i] != color)
                {
                    if (stationTokens[i])
                        Destroy(stationTokens[i]);
                    stationTokens[i] = color < 0 ? null : TrainModels.Create(color, content);
                    stationColors[i] = color;
                    if (stationTokens[i])
                    {
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
            var ghost = TrainModels.Create(rules.Cards[id].Data.color, content);
            ghost.transform.localScale = Vector3.one * 1.1f;
            StartCoroutine(Fly(ghost, cardOrigins[id] + Vector3.up * .4f, SlotPositions[slot] + Vector3.up * .5f, .26f, false));
        }
        public void Match(MatchEvent match)
        {
            var ghost = TrainModels.Create(match.Color, content);
            ghost.transform.localScale = Vector3.one * .85f;
            StartCoroutine(Fly(ghost, Rail.Point(match.Lane, match.Distance) + Vector3.up * .2f, SlotPositions[match.Slot] + Vector3.up * .5f, .24f, true));
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
                bits[i] = Shape("Brass sparkle", PrimitiveType.Sphere, at, Vector3.one * .1f, Hex("F0D392"), content);
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
            RaycastHit hit;
            if (Physics.Raycast(Camera.ScreenPointToRay(screen), out hit, 200))
            {
                var tag = hit.collider.GetComponent<CardTag>();
                if (tag)
                    return tag.Id;
            }
            return -1;
        }
        public void Fit()
        {
            if (level == null)
                return;
            var points = Rail.Routes.SelectMany(r => r.points).Concat(new[] { new Vector3(-8, 0, -5 - level.rows * 2.35f), new Vector3(8, 0, -5 - level.rows * 2.35f) }).ToArray();
            Camera.transform.rotation = Quaternion.Euler(52, 0, 0);
            Vector3 center = new Vector3(0, 0, (points.Max(p => p.z) + points.Min(p => p.z)) * .5f);
            Camera.transform.position = center - Camera.transform.forward * 65;
            float width = 0, height = 0;
            foreach (var p in points)
            {
                var local = Camera.transform.InverseTransformPoint(p);
                width = Mathf.Max(width, Mathf.Abs(local.x));
                height = Mathf.Max(height, Mathf.Abs(local.y));
            }
            Camera.orthographicSize = Mathf.Max(height / .69f, width / Mathf.Max(.25f, Camera.aspect) / .94f);
            Camera.backgroundColor = Hex(Grounds[level.theme]);
        }
        void Tree(Vector3 p, bool snow)
        {
            Shape("Trunk", PrimitiveType.Cylinder, p + Vector3.up * .7f, new Vector3(.18f, .7f, .18f), Hex("806E56"));
            for (int i = 0; i < 3; i++)
                Shape("Foliage", PrimitiveType.Sphere, p + Vector3.up * (1.4f + i * .45f), new Vector3(1.5f - i * .26f, 1.2f, 1.5f - i * .26f), snow ? Hex("9DB7AF") : Hex("548D74"));
        }
        void Decorate()
        {
            var rng = new System.Random(level.map_seed);
            for (int side = -1; side <= 1; side += 2)
                for (int i = 0; i < 9; i++)
                {
                    var p = new Vector3(side * (9.8f + (float)rng.NextDouble() * 2), 0, 23 - i * 3.7f);
                    if (level.theme == 4)
                    {
                        for (int k = 0; k < 3; k++)
                            Shape("Sandstone strata", PrimitiveType.Cylinder, p + Vector3.up * k * .55f, new Vector3(2 - k * .35f, .36f, 1.7f - k * .2f), Hex(k == 1 ? "B58161" : "C89774"));
                    }
                    else if (level.theme == 2)
                    {
                        for (int j = 0; j < 4; j++)
                            Shape("Harvest bales", PrimitiveType.Cylinder, p + new Vector3((j % 2) * .7f, .4f, (j / 2) * .8f), new Vector3(.65f, .35f, .65f), Hex("D5B86B"));
                    }
                    else if (level.theme == 3)
                    {
                        Shape("Townhouse", PrimitiveType.Cube, p + Vector3.up * .8f, new Vector3(1.8f, 1.6f, 1.6f), Hex("D5C9B5"));
                        Shape("Slate roof", PrimitiveType.Cube, p + Vector3.up * 1.7f, new Vector3(2, .3f, 1.8f), Hex("59747C"));
                    }
                    else
                        Tree(p, level.theme == 5);
                }
            if (level.theme == 1)
            {
                Shape("Sea", PrimitiveType.Cube, new Vector3(-28, -.18f, 7), new Vector3(32, .08f, 70), Hex("74B8C1"));
                for (int i = 0; i < 5; i++)
                    Shape("Foam line", PrimitiveType.Cube, new Vector3(-12.3f - i * .6f, -.10f, 7), new Vector3(.08f, .02f, 60), Hex("BFE2DF"));
            }
            if (level.theme == 5)
                for (int i = 0; i < 6; i++)
                    Shape("Snowdrift", PrimitiveType.Sphere, new Vector3(i % 2 == 0 ? -11 : 11, .1f, 18 - i * 4), new Vector3(3, .6f, 3), Hex("F1F4EF"));
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
