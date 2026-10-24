using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Networking;
namespace RenkEkspresi
{
    /// <summary>Owns transitions. Rules own matches; views cannot grant rewards or remove wagons.</summary>
    public sealed class GameManager : MonoBehaviour
    {
        public PuzzleEngine Rules
        {
            get; private set;
        }
        public GameWorld World
        {
            get; private set;
        }
        public GameUI UI
        {
            get; private set;
        }
        public AudioManager Audio
        {
            get; private set;
        }
        public bool Paused { get; private set; } = true;
        public bool English
        {
            get
            {
                return save.Data.language == "en";
            }
        }
        public ICommerce Commerce
        {
            get; private set;
        }
        SaveData save; Campaign campaign; RewardGuard rewardGuard = new RewardGuard();
        int levelIndex, generation, width, height; bool finishing, busy, background; float refreshAt;
        public string L(string tr, string en)
        {
            return English ? en : tr;
        }
        void Awake()
        {
            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            save = new SaveData();
            save.Load();
            Commerce = new UnavailableCommerce();
            campaign = JsonUtility.FromJson<Campaign>(Resources.Load<TextAsset>("Data/campaign").text);
            World = new GameObject("Game world").AddComponent<GameWorld>();
            World.Setup();
            Audio = new GameObject("Audio manager").AddComponent<AudioManager>();
            Audio.Setup(save.Data);
            UI = new GameObject("Interface").AddComponent<GameUI>();
            UI.Setup(this);
            ApplyQuality();
            Load(save.Data.lastLevel);
            Home();
        }
        // A native SDK bridge can attach after it has restored and verified entitlements.
        public void SetCommerce(ICommerce provider)
        {
            Commerce = provider ?? new UnavailableCommerce();
            if (Rules != null && Commerce.Vip)
                Rules.GrantVip();
            UI.Refresh();
        }
        void Load(int index)
        {
            generation++;
            rewardGuard.Cancel();
            busy = false;
            finishing = false;
            Paused = true;
            levelIndex = Mathf.Clamp(index, 0, campaign.levels.Length - 1);
            Rules = new PuzzleEngine(campaign.levels[levelIndex], Commerce.Vip);
            World.Load(Rules.Level);
            World.Sync(Rules);
            UI.Refresh();
        }
        void Update()
        {
            if (Screen.width != width || Screen.height != height)
            {
                width = Screen.width;
                height = Screen.height;
                World.Fit();
                UI.SafeArea();
                UI.Refresh();
            }
            if (!Paused && !background && Rules.Status == "playing")
            {
                if (Input.GetKeyDown(KeyCode.Escape))
                {
                    Menu();
                    return;
                }
                ReadTouch();
                ShowMatches(Rules.Tick(Time.deltaTime));
                World.Sync(Rules);
                if (Rules.Status != "playing")
                    Finish();
            }
            Audio.Motion(!Paused && !background && Rules.Status == "playing" && Rules.FreezeLeft <= 0, (float)Rules.Danger, background || busy);
            if (Time.unscaledTime >= refreshAt)
            {
                refreshAt = Time.unscaledTime + .05f;
                UI.Refresh();
            }
        }
        void ReadTouch()
        {
            if (Input.touchCount > 0)
            {
                var t = Input.GetTouch(0);
                if (t.phase != TouchPhase.Began || EventSystem.current.IsPointerOverGameObject(t.fingerId))
                    return;
                Choose(World.Pick(t.position));
            }
            else if (Input.GetMouseButtonDown(0) && !EventSystem.current.IsPointerOverGameObject())
                Choose(World.Pick(Input.mousePosition));
        }
        void Choose(int id)
        {
            if (id < 0)
                return;
            string error = Rules.Choose(id);
            if (error.Length == 0)
            {
                World.Launch(id, Rules);
                Audio.Play("tap");
            }
            else
            {
                World.Nudge(id);
                UI.Blocked(id, Rules.Blockers(id));
                UI.Toast(error == "full" ? L("Yuvalar dolu. Bir toplayıcının bitmesini bekle.", "Slots are full. Let a collector finish.") : error == "locked" ? L("Önce anahtar vagonunu çıkar.", "Release the key collector first.") : L("Okun önünde başka bir vagon var.", "Another collector blocks this arrow."));
            }
        }
        void ShowMatches(List<MatchEvent> matches)
        {
            foreach (var e in matches)
            {
                World.Match(e);
                UI.Match(e);
                Audio.Play("match");
            }
        }
        void Finish()
        {
            if (finishing)
                return;
            finishing = true;
            Paused = true;
            bool won = Rules.Status == "won";
            if (won)
                save.Win(levelIndex, Rules.Elapsed, Rules.Assisted || Rules.Vip || Rules.RewardSlot);
            Audio.Play(won ? "win" : "lose");
            if (save.Data.haptics)
                Haptics.Pulse();
            var p = UI.Dialog(won ? L("Bir yolculuk daha kurtarıldı", "Another journey saved") : L("Bir hamle daha düşün", "Plan your next move"), won ?
             L("Güzel iş! Tüm renkler yerini buldu.\n", "Well done! Every color found its place.\n") + TimeLabel(Rules.Elapsed) + "  ·  " + Rules.Taps + L(" hamle", " moves") :
             L("Tren sona ulaştı. Okların açtığı yolu ve yaklaşan renkleri birlikte düşün.", "The train reached the end. Watch both the arrow paths and the approaching colors."));
            if (won && levelIndex < 99)
                UI.DialogButton(p, L("Sonraki bölüm →", "Next level →"), 0, () => Begin(levelIndex + 1), true);
            else if (won)
                UI.DialogButton(p, L("100 bölüm tamamlandı · Bölümler", "100 levels complete · Levels"), 0, () => Levels(8), true);
            else
                UI.DialogButton(p, L("Tekrar dene", "Try again"), 0, () => Begin(levelIndex), true);
            UI.DialogButton(p, L("Bölümler", "Levels"), 1, () => Levels(levelIndex / 12));
            UI.DialogButton(p, L("Ana menü", "Home"), 2, Home);
        }
        static string TimeLabel(double seconds)
        {
            return ((int)seconds / 60).ToString("00") + ":" + ((int)seconds % 60).ToString("00");
        }
        public void Home()
        {
            if (busy)
                return;
            Paused = true;
            var p = UI.Dialog("RENK EKSPRESİ", L("Renkleri bul. Yolu aç. Yolculuğu kurtar.\n\nBir sonraki durak seni bekliyor.", "Find the colors. Clear the way. Save the journey.\n\nYour next stop is waiting."));
            UI.DialogButton(p, L("Devam et · Bölüm ", "Continue · Level ") + (save.Data.lastLevel + 1), 0, () => Begin(save.Data.lastLevel), true);
            UI.DialogButton(p, L("Bölümleri keşfet", "Explore levels"), 1, () => Levels(save.Data.lastLevel / 12));
            UI.DialogButton(p, "VIP", 2, Vip);
            UI.DialogButton(p, L("Sıralama", "Leaderboard"), 3, Leaderboard);
            UI.DialogButton(p, L("Ayarlar", "Settings"), 4, Settings);
        }
        public void Menu()
        {
            if (busy)
                return;
            Paused = true;
            var p = UI.Dialog(L("Kısa bir mola", "A little break"), L("Tren seni bekliyor. Hazır olduğunda kaldığın yerden devam et.", "The train is waiting. Carry on whenever you are ready."));
            UI.DialogButton(p, L("Devam et", "Resume"), 0, Resume, true);
            UI.DialogButton(p, L("Yeniden başlat", "Restart"), 1, () => Begin(levelIndex));
            UI.DialogButton(p, L("Ayarlar", "Settings"), 2, Settings);
            UI.DialogButton(p, L("Nasıl oynanır?", "How to play"), 3, () => Tutorial(0, Resume));
            UI.DialogButton(p, L("Ana menü", "Home"), 4, Home);
        }
        void Resume()
        {
            if (Rules.Status != "playing")
            {
                Home();
                return;
            }
            UI.Close();
            Paused = false;
            Audio.StartSound();
        }
        void Begin(int index)
        {
            if (busy)
                return;
            Paused = true;
            StartCoroutine(CheckConnection(() =>
            {
                int stamp = generation;
                busy = true;
                Action start = () =>
                {
                    if (stamp != generation)
                        return;
                    busy = false;
                    Load(index);
                    save.Data.lastLevel = levelIndex;
                    save.Commit();
                    Action play = () => { Rules.Status = "playing"; Paused = false; UI.Close(); Audio.StartSound(); };
                    if (!save.Data.tutorial)
                        Tutorial(0, () => { save.Data.tutorial = true; save.Commit(); play(); });
                    else
                        play();
                };
                if (!Commerce.Vip && save.Data.winsSinceAd >= 2)
                {
                    save.Data.winsSinceAd = 0;
                    save.Commit();
                    Commerce.Interstitial(start);
                }
                else
                    start();
            }));
        }
        IEnumerator CheckConnection(Action online)
        {
            busy = true;
            UI.Dialog(L("Yola hazırlanıyoruz", "Preparing your journey"), L("Bağlantı kontrol ediliyor…", "Checking your connection…"));
            int stamp = generation;
            string endpoint = "https://www.gstatic.com/generate_204";
#if UNITY_WEBGL && !UNITY_EDITOR
  // Build Automation does not invoke ProjectTools.BuildWeb(), so online.txt is absent
  // from its WebGL artifact. The HTML entry point is present in either build path.
  endpoint=new Uri(new Uri(Application.absoluteURL),"index.html?t="+DateTime.UtcNow.Ticks).ToString();
#endif
            using (var request = UnityWebRequest.Get(endpoint))
            {
                request.timeout = 8;
                yield return request.SendWebRequest();
                if (stamp != generation)
                    yield break;
                busy = false;
                if (request.result == UnityWebRequest.Result.Success)
                {
                    online();
                    yield break;
                }
            }
            var p = UI.Dialog(L("Bağlantı bekleniyor", "Waiting for connection"), L("Oynamak için internet bağlantısı gerekiyor. Bağlantını kontrol edip tekrar dene.", "An internet connection is required to play. Check your connection and try again."));
            UI.DialogButton(p, L("Tekrar dene", "Try again"), 0, () => StartCoroutine(CheckConnection(online)), true);
            UI.DialogButton(p, L("Ana menü", "Home"), 1, Home);
        }
        void Tutorial(int step, Action done)
        {
            string[] titles = English ? new[] { "Follow the arrows", "Prepare your collectors", "Rescue the train" } : new[] { "Okları takip et", "Toplayıcıları hazırla", "Treni kurtar" };
            string[] texts = English ? new[] { "Tap a collector whose arrow path is clear. It moves to the first free slot with one tap.", "Each collector takes its own color. The number shows how many wagons it can collect. Keep space for the colors coming next.", "Only wagons that reach the highlighted track can be collected. [A] is locked until you release the +A key collector. Recall starts with one use." } : new[] { "Okunun önü açık olan toplayıcıya dokun. Tek dokunuşla ilk boş yuvaya gider.", "Her toplayıcı kendi rengini alır. Üzerindeki sayı kalan kapasitesidir. Sıradaki renklere yer bırak.", "Sadece işaretli raya ulaşan vagonlar alınır. [A] kilidini açmak için önce +A anahtar vagonunu çıkar. Geri al için başlangıçta bir hakkın var." };
            var p = UI.Dialog(titles[step] + " · " + (step + 1) + "/3", texts[step]);
            UI.DialogButton(p, step == 2 ? L("Hazırım", "Let's go") : L("Devam →", "Next →"), 0, () => { if (step < 2) Tutorial(step + 1, done); else done(); }, true);
        }
        public void Levels(int page)
        {
            Paused = true;
            page = Mathf.Clamp(page, 0, 8);
            var p = UI.Dialog(L("Yeni bir yolculuk seç", "Choose your journey"), L("Her yolun kendi ritmi, her bölümün yeni bir bulmacası var.", "Every route has its own rhythm. Every level, a new puzzle."));
            for (int i = 0; i < 12; i++)
            {
                int n = page * 12 + i;
                if (n >= 100)
                    break;
                bool unlocked = n < save.Data.unlocked;
                var b = UI.Button(p, unlocked ? (n + 1).ToString() : "—", new Vector2(.5f, .5f), new Vector2((i % 3 - 1) * 180, 40 - (i / 3) * 74), new Vector2(162, 62), () => Begin(n), n == save.Data.lastLevel);
                b.interactable = unlocked;
            }
            UI.Button(p, "‹", new Vector2(.5f, .5f), new Vector2(-220, -290), new Vector2(100, 52), () => Levels(page - 1)).interactable = page > 0;
            UI.Button(p, L("Ana menü", "Home"), new Vector2(.5f, .5f), new Vector2(0, -290), new Vector2(300, 52), Home);
            UI.Button(p, "›", new Vector2(.5f, .5f), new Vector2(220, -290), new Vector2(100, 52), () => Levels(page + 1)).interactable = page < 8;
        }
        public void Booster(int kind)
        {
            if (Paused || busy || Rules.Status != "playing")
                return;
            if (Rules.BoosterStock[kind] <= 0)
            {
                Reward(L("Bir yardımcı kazan", "Earn a booster"), () => Rules.GrantBooster(kind));
                return;
            }
            List<MatchEvent> matches;
            string error = Rules.UseBooster(kind, out matches);
            ShowMatches(matches);
            if (error.Length > 0)
                UI.Toast(error == "no_target" ? L("Şu an toplanabilecek eşleşme yok.", "No eligible matching wagons right now.") : error == "empty" ? L("Geri alınacak toplayıcı yok.", "There is no collector to recall.") : L("Bu yardımcı zaten aktif.", "This booster is already active."));
            else
                Audio.Play("fill");
            World.Sync(Rules);
            UI.Refresh();
            if (Rules.Status != "playing")
                Finish();
        }
        public void StationAction(int index)
        {
            if (Paused || busy || index < Rules.Slots.Count)
                return;
            int lockedIndex = index - Rules.Slots.Count;
            if (!Rules.Vip && lockedIndex == 0)
                Vip();
            else
                Reward(L("Bu bölüm için ek yuva", "Extra slot for this level"), () => Rules.GrantRewardSlot());
        }
        void Reward(string title, Func<bool> grant)
        {
            Paused = true;
            var p = UI.Dialog(title, L("Reklamı tamamladığında ödülün açılır. İptal edilen reklam hak kazandırmaz.", "Complete the ad to earn your reward. A cancelled ad does not grant a reward.") +
             (Commerce.RewardReady ? "" : "\n\n" + L("Şu an uygun reklam yok.", "No ad is available right now.")));
            UI.DialogButton(p, L("Reklam izle · +1", "Watch ad · +1"), 0, () =>
            {
                int stamp = generation, token = rewardGuard.Begin();
                busy = true;
                Commerce.Reward(earned =>
                {
                    if (stamp != generation)
                        return;
                    busy = false;
                    if (rewardGuard.Accept(token, earned) && grant())
                        UI.Toast(L("Ödül açıldı", "Reward unlocked"));
                    else
                        UI.Toast(L("Reklam tamamlanmadı. Hak değişmedi.", "Ad not completed. No reward granted."));
                    Resume();
                });
            }, true).interactable = Commerce.RewardReady;
            UI.DialogButton(p, L("Oyuna dön", "Back to game"), 1, Resume);
        }
        public void Vip()
        {
            if (busy)
                return;
            Paused = true;
            var p = UI.Dialog("VIP · " + L("Bir ömür seninle", "Yours for a lifetime"), L("Kalıcı +1 toplayıcı yuvası\nBölüm sonu zorunlu reklamlar kalkar\nTek seferlik satın alma\n\nİsteğe bağlı ödüllü reklamlar devam eder.", "One permanent extra collector slot\nNo forced level-end ads\nOne-time purchase\n\nOptional rewarded ads remain available."));
            string price = Commerce.Price;
            string buy = Commerce.Vip ? L("VIP aktif", "VIP active") : Commerce.CanBuy && !string.IsNullOrEmpty(price) ? price : L("Mağaza bağlantısı bekleniyor", "Store connection pending");
            UI.DialogButton(p, buy, 0, () => { busy = true; int stamp = generation; Commerce.Buy(ok => { if (stamp != generation) return; busy = false; if (ok && Commerce.Vip) Rules.GrantVip(); Vip(); }); }, true).interactable = Commerce.CanBuy && !Commerce.Vip;
            UI.DialogButton(p, L("Satın alımları geri yükle", "Restore purchases"), 1, () => { busy = true; Commerce.Restore(ok => { busy = false; if (ok && Commerce.Vip) Rules.GrantVip(); Vip(); }); }).interactable = Commerce.CanBuy;
            UI.DialogButton(p, L("Geri", "Back"), 2, () => { if (Rules.Status == "playing") Resume(); else Home(); });
        }
        public void Settings()
        {
            Paused = true;
            var p = UI.Dialog(L("Tam senin ritminde", "Find your rhythm"), L("Sakin müzik, hafif bir çuf çuf.\nSesleri ayrı ayrı ayarla.", "Calm music, a gentle chuff.\nAdjust each sound separately."));
            UI.Slider(p, L("Müzik", "Music"), 0, save.Data.music, v => { save.Data.music = v; });
            UI.Slider(p, L("Tren", "Train"), 1, save.Data.train, v => { save.Data.train = v; });
            UI.Slider(p, L("Efektler", "Effects"), 2, save.Data.effects, v => { save.Data.effects = v; });
            UI.Button(p, English ? "Türkçe" : "English", new Vector2(.5f, .5f), new Vector2(-190, -250), new Vector2(170, 48), () => { save.Data.language = English ? "tr" : "en"; save.Commit(); Settings(); UI.Refresh(); });
            UI.Button(p, save.Data.lowQuality ? L("Grafik: Ekonomik", "Graphics: Low") : L("Grafik: Yüksek", "Graphics: High"), new Vector2(.5f, .5f), new Vector2(190, -250), new Vector2(170, 48), () => { save.Data.lowQuality = !save.Data.lowQuality; ApplyQuality(); save.Commit(); Settings(); });
            UI.Button(p, save.Data.haptics ? L("Titreşim: Açık", "Haptics: On") : L("Titreşim: Kapalı", "Haptics: Off"), new Vector2(.5f, .5f), new Vector2(0, -250), new Vector2(170, 48), () => { save.Data.haptics = !save.Data.haptics; save.Commit(); Settings(); });
            UI.Button(p, L("Kaydet ve geri dön", "Save and return"), new Vector2(.5f, .5f), new Vector2(0, -325), new Vector2(550, 56), () => { save.Commit(); if (Rules.Status == "playing") Menu(); else Home(); }, true);
        }
        void ApplyQuality()
        {
            QualitySettings.antiAliasing = save.Data.lowQuality ? 0 : 4;
            QualitySettings.shadows = save.Data.lowQuality ? ShadowQuality.Disable : ShadowQuality.All;
            QualitySettings.shadowDistance = 70;
            QualitySettings.shadowResolution = ShadowResolution.Medium;
            QualitySettings.vSyncCount = 0;
        }
        void Leaderboard()
        {
            var p = UI.Dialog(L("Yolculuğun izleri", "Journeys worth remembering"), L("Örnek sıralama · İsimler ve puanlar kurgusaldır.\nGerçek çevrimiçi yarış henüz bağlı değil.", "Sample leaderboard · Names and scores are fictional.\nLive online rankings are not connected yet."));
            string[] names = { "LunaRail", "MaviRota", "CopperFox", "Sen / You" };
            int[] scores = { 87, 82, 79, save.Data.unlocked };
            for (int i = 0; i < 4; i++)
                UI.Label(p, (i < 3 ? (i + 1) + ".  " : "→  ") + names[i] + "     " + L("Bölüm ", "Level ") + scores[i], 22, GameWorld.Hex(i == 3 ? "29675B" : "203D48"), new Vector2(0, 45 - i * 65), new Vector2(550, 52), i == 3);
            int completed = save.Data.standard.Count(x => x > 0);
            UI.Label(p, L("Bu cihazdaki yardımsız rekorların: ", "Your unassisted records on this device: ") + completed, 17, GameWorld.Hex("526A70"), new Vector2(0, -235), new Vector2(550, 54));
            UI.DialogButton(p, L("Ana menü", "Home"), 5, Home);
        }
        void OnApplicationPause(bool paused)
        {
            background = paused;
            if (paused)
            {
                save?.Commit();
                if (Rules != null && Rules.Status == "playing")
                    Paused = true;
            }
            else if (Rules != null && Rules.Status == "playing" && !busy)
                StartCoroutine(CheckConnection(Menu));
        }
        void OnApplicationFocus(bool focus)
        {
            if (!focus && Rules != null && Rules.Status == "playing" && !busy)
            {
                Paused = true;
                Menu();
            }
        }
        void OnApplicationQuit()
        {
            save?.Commit();
        }
        // Editor only: useful for checking all levels without changing player progression.
#if UNITY_EDITOR
 public void EditorPreviewLevel(int index){Load(index);Rules.Status="playing";Paused=false;UI.Close();Audio.StartSound();}
#endif
    }
}
