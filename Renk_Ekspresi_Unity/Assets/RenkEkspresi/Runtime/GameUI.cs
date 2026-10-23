using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
namespace RenkEkspresi
{
    public sealed class GameUI : MonoBehaviour
    {
        public GameManager Game; public RectTransform Root; public GameObject Modal;
        Canvas canvas; Font font, bold; Sprite rounded; Text title, phase, count; Image progress;
        Button[] boosters = new Button[3], stationActions = new Button[5]; Text[] stationLabels = new Text[5];
        Color Ink = GameWorld.Hex("203D48"), Cream = GameWorld.Hex("F4F1E6"), Navy = GameWorld.Hex("173844"), Gold = GameWorld.Hex("E7BD72");
        public string L(string tr, string en)
        {
            return Game.English ? en : tr;
        }
        Sprite Round()
        {
            var tex = new Texture2D(64, 64, TextureFormat.RGBA32, false);
            for (int y = 0; y < 64; y++)
                for (int x = 0; x < 64; x++)
                {
                    float dx = Mathf.Max(16 - x, x - 47), dy = Mathf.Max(16 - y, y - 47);
                    float d = new Vector2(Mathf.Max(dx, 0), Mathf.Max(dy, 0)).magnitude;
                    tex.SetPixel(x, y, new Color(1, 1, 1, Mathf.Clamp01(16.5f - d)));
                }
            tex.Apply();
            return Sprite.Create(tex, new Rect(0, 0, 64, 64), new Vector2(.5f, .5f), 100, 0, SpriteMeshType.FullRect, new Vector4(20, 20, 20, 20));
        }
        public void Setup(GameManager game)
        {
            Game = game;
            font = Resources.Load<Font>("UI/Interface");
            bold = Resources.Load<Font>("UI/Interface-Bold");
            rounded = Round();
            canvas = gameObject.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 10;
            var scale = gameObject.AddComponent<CanvasScaler>();
            scale.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scale.referenceResolution = new Vector2(720, 1280);
            scale.matchWidthOrHeight = .5f;
            gameObject.AddComponent<GraphicRaycaster>();
            if (!EventSystem.current)
            {
                var e = new GameObject("EventSystem");
                e.AddComponent<EventSystem>();
                e.AddComponent<StandaloneInputModule>();
            }
            Root = Rect("Safe area", transform, new Vector2(0, 0), new Vector2(1, 1), Vector2.zero, Vector2.zero);
            SafeArea();
            BuildHud();
        }
        RectTransform Rect(string name, Transform parent, Vector2 min, Vector2 max, Vector2 pos, Vector2 size)
        {
            var g = new GameObject(name, typeof(RectTransform));
            var r = g.GetComponent<RectTransform>();
            r.SetParent(parent, false);
            r.anchorMin = min;
            r.anchorMax = max;
            r.pivot = new Vector2(.5f, .5f);
            r.anchoredPosition = pos;
            r.sizeDelta = size;
            return r;
        }
        Image Panel(Transform parent, Vector2 anchor, Vector2 pos, Vector2 size, Color color)
        {
            var r = Rect("Panel", parent, anchor, anchor, pos, size);
            var im = r.gameObject.AddComponent<Image>();
            im.sprite = rounded;
            im.type = Image.Type.Sliced;
            im.color = color;
            return im;
        }
        public Text Label(Transform parent, string text, int size, Color color, Vector2 pos, Vector2 dimensions, bool heavy = false)
        {
            var r = Rect("Text", parent, new Vector2(.5f, .5f), new Vector2(.5f, .5f), pos, dimensions);
            var t = r.gameObject.AddComponent<Text>();
            t.font = heavy ? bold : font;
            t.text = text;
            t.fontSize = size;
            t.color = color;
            t.alignment = TextAnchor.MiddleCenter;
            t.raycastTarget = false;
            t.horizontalOverflow = HorizontalWrapMode.Wrap;
            t.verticalOverflow = VerticalWrapMode.Truncate;
            return t;
        }
        public Button Button(Transform parent, string text, Vector2 anchor, Vector2 pos, Vector2 size, Action action, bool primary = false)
        {
            var image = Panel(parent, anchor, pos, size, primary ? Gold : Navy);
            var button = image.gameObject.AddComponent<Button>();
            button.targetGraphic = image;
            var colors = button.colors;
            colors.highlightedColor = new Color(1.08f, 1.08f, 1.08f);
            colors.pressedColor = new Color(.8f, .8f, .8f);
            colors.disabledColor = new Color(.5f, .5f, .5f, .7f);
            button.colors = colors;
            Label(button.transform, text, 20, primary ? Ink : Cream, Vector2.zero, size - new Vector2(12, 8), true);
            button.onClick.AddListener(() => { Game.Audio.Play("tap"); action(); });
            return button;
        }
        void BuildHud()
        {
            var header = Panel(Root, new Vector2(.5f, 1), new Vector2(0, -72), new Vector2(676, 104), Navy);
            Label(header.transform, "RENK EKSPRESİ", 13, Gold, new Vector2(-180, 30), new Vector2(240, 24), true);
            title = Label(header.transform, "", 24, Cream, new Vector2(-80, 0), new Vector2(430, 50), true);
            Button(header.transform, "Ⅱ", new Vector2(1, .5f), new Vector2(-43, 0), new Vector2(60, 60), Game.Menu);
            var bar = Panel(header.transform, new Vector2(.5f, 0), new Vector2(0, 10), new Vector2(630, 6), GameWorld.Hex("41606A"));
            progress = Panel(bar.transform, new Vector2(0, .5f), Vector2.zero, new Vector2(630, 6), Gold);
            progress.rectTransform.pivot = new Vector2(0, .5f);
            phase = Label(Root, "", 18, Ink, new Vector2(0, 0), new Vector2(630, 44), true);
            phase.rectTransform.anchorMin = phase.rectTransform.anchorMax = new Vector2(.5f, 1);
            phase.rectTransform.anchoredPosition = new Vector2(0, -148);
            var dock = Panel(Root, new Vector2(.5f, 0), new Vector2(0, 89), new Vector2(676, 142), Navy);
            count = Label(dock.transform, "", 15, Gold, new Vector2(0, 48), new Vector2(620, 24), true);
            for (int i = 0; i < 3; i++)
            {
                int kind = i;
                boosters[i] = Button(dock.transform, "", new Vector2(.5f, .5f), new Vector2((i - 1) * 211, -12), new Vector2(201, 84), () => Game.Booster(kind));
                var tex = Resources.Load<Texture2D>("UI/" + new[] { "freeze", "blast", "recall" }[i]);
                var icon = Rect("Icon", boosters[i].transform, new Vector2(0, .5f), new Vector2(0, .5f), new Vector2(37, 0), new Vector2(54, 54)).gameObject.AddComponent<RawImage>();
                icon.texture = tex;
                icon.raycastTarget = false;
                var txt = boosters[i].GetComponentInChildren<Text>();
                txt.rectTransform.anchoredPosition = new Vector2(29, 0);
                txt.rectTransform.sizeDelta = new Vector2(125, 76);
                txt.fontSize = 18;
            }
            for (int i = 0; i < 5; i++)
            {
                int index = i;
                stationActions[i] = Button(Root, "", new Vector2(.5f, .5f), Vector2.zero, new Vector2(94, 42), () => Game.StationAction(index));
                stationLabels[i] = stationActions[i].GetComponentInChildren<Text>();
                stationLabels[i].fontSize = 13;
            }
        }
        public void SafeArea()
        {
            Rect s = Screen.safeArea;
            Root.anchorMin = new Vector2(s.x / Screen.width, s.y / Screen.height);
            Root.anchorMax = new Vector2(s.xMax / Screen.width, s.yMax / Screen.height);
            Root.offsetMin = Root.offsetMax = Vector2.zero;
        }
        public void Refresh()
        {
            var r = Game.Rules;
            if (r == null)
                return;
            title.text = L("Bölüm ", "Level ") + r.Level.id + " · " + (Game.English ? r.Level.region_en : r.Level.region);
            progress.rectTransform.sizeDelta = new Vector2((float)r.Danger * 630, 6);
            progress.color = r.Danger > .9 ? GameWorld.Hex("E66F5F") : Gold;
            phase.text = r.FreezeLeft > 0 ? L("Donduruldu · ", "Frozen · ") + r.FreezeLeft.ToString("0.0") + " s" : Array.Exists(r.Opened, x => x) ? L("Yaklaşan renklere yer bırak", "Leave room for the approaching colors") : L("Okun önü açıksa vagona dokun", "Tap a collector with a clear arrow path");
            count.text = L("TOPLANAN  ", "CLEARED  ") + (r.Total - r.Wagons.Count) + " / " + r.Total;
            var names = Game.English ? new[] { "Freeze", "Blast", "Recall" } : new[] { "Dondur", "Patlat", "Geri al" };
            for (int i = 0; i < 3; i++)
            {
                boosters[i].GetComponentInChildren<Text>().text = names[i] + "\n" + (r.BoosterStock[i] > 0 ? r.BoosterStock[i] + L(" hak", " left") : L("Reklam +1", "Ad +1"));
                boosters[i].interactable = r.Status == "playing" && !Game.Paused;
            }
            var locked = new List<string>();
            if (!r.Vip)
                locked.Add("VIP +1");
            if (!r.RewardSlot)
                locked.Add(L("▶ Yuva +1", "▶ Slot +1"));
            for (int i = 0; i < 5; i++)
            {
                bool open = i < r.Slots.Count;
                stationLabels[i].text = open ? (r.Slots[i].Collector < 0 ? L("BOŞ", "EMPTY") : r.Cards[r.Slots[i].Collector].Remaining.ToString()) : locked[i - r.Slots.Count];
                stationActions[i].interactable = !open && !Game.Paused && r.Status == "playing";
                stationActions[i].targetGraphic.color = open ? new Color(.09f, .22f, .26f, .85f) : (locked[i - r.Slots.Count].StartsWith("VIP") ? Gold : Navy);
                stationLabels[i].color = !open && locked[i - r.Slots.Count].StartsWith("VIP") ? Ink : Cream;
                Vector2 local;
                var screen = Game.World.Camera.WorldToScreenPoint(Game.World.SlotPositions[i] + new Vector3(0, .25f, -.9f));
                RectTransformUtility.ScreenPointToLocalPointInRectangle(Root, screen, null, out local);
                var rect = stationActions[i].GetComponent<RectTransform>();
                rect.anchoredPosition = local;
                Vector2 adjacent;
                RectTransformUtility.ScreenPointToLocalPointInRectangle(Root, Game.World.Camera.WorldToScreenPoint(Game.World.SlotPositions[i] + new Vector3(2.65f, .25f, -.9f)), null, out adjacent);
                float labelWidth = Mathf.Clamp(Mathf.Abs(adjacent.x - local.x) - 8, 64, 106);
                rect.sizeDelta = new Vector2(labelWidth, 42);
                stationLabels[i].rectTransform.sizeDelta = new Vector2(labelWidth - 8, 36);
            }
        }
        public Transform Dialog(string title, string description)
        {
            Close();
            Modal = Rect("Dialog overlay", Root, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero).gameObject;
            var dim = Modal.AddComponent<Image>();
            dim.color = new Color(.03f, .1f, .13f, .78f);
            var panel = Panel(Modal.transform, new Vector2(.5f, .5f), Vector2.zero, new Vector2(630, 840), Cream);
            Label(panel.transform, title, 29, Ink, new Vector2(0, 350), new Vector2(570, 84), true);
            Label(panel.transform, description, 21, Ink, new Vector2(0, 180), new Vector2(558, 240));
            return panel.transform;
        }
        public Button DialogButton(Transform p, string text, int row, Action action, bool primary = false)
        {
            return Button(p, text, new Vector2(.5f, .5f), new Vector2(0, 15 - row * 66), new Vector2(550, 56), action, primary);
        }
        public void Slider(Transform parent, string title, int row, float value, Action<float> changed)
        {
            float y = 40 - row * 105;
            Label(parent, title, 19, Ink, new Vector2(0, y + 28), new Vector2(540, 30));
            var track = Panel(parent, new Vector2(.5f, .5f), new Vector2(0, y), new Vector2(490, 16), GameWorld.Hex("AEBFBA"));
            var handle = Panel(track.transform, new Vector2(.5f, .5f), Vector2.zero, new Vector2(34, 34), Navy);
            var slider = track.gameObject.AddComponent<Slider>();
            slider.direction = UnityEngine.UI.Slider.Direction.LeftToRight;
            slider.handleRect = handle.rectTransform;
            slider.targetGraphic = handle;
            slider.minValue = 0;
            slider.maxValue = 1;
            slider.value = value;
            slider.onValueChanged.AddListener(v => changed(v));
        }
        public void Close()
        {
            if (Modal)
            {
                Destroy(Modal);
                Modal = null;
            }
        }
        public void Toast(string text)
        {
            var panel = Panel(Root, new Vector2(.5f, .5f), new Vector2(0, -70), new Vector2(580, 62), Navy);
            Label(panel.transform, text, 19, Cream, Vector2.zero, new Vector2(550, 54));
            Destroy(panel.gameObject, 2);
        }
    }
}
