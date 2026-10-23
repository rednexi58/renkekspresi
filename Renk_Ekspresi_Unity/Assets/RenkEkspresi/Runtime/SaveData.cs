using System;
using System.IO;
using UnityEngine;
namespace RenkEkspresi
{
    public sealed class SaveData
    {
        public PlayerSave Data = new PlayerSave(); string PathName
        {
            get
            {
                return Path.Combine(Application.persistentDataPath, "renk_ekspresi_unity_v1.json");
            }
        }
        public void Load()
        {
            foreach (string file in new[] { PathName, PathName + ".bak" })
                try
                {
                    if (!File.Exists(file))
                        continue;
                    var s = JsonUtility.FromJson<PlayerSave>(File.ReadAllText(file));
                    if (s == null || s.schema != 1)
                        continue;
                    Data = s;
                    Data.unlocked = Mathf.Clamp(Data.unlocked, 1, 100);
                    Data.lastLevel = Mathf.Clamp(Data.lastLevel, 0, Data.unlocked - 1);
                    if (Data.standard == null || Data.standard.Length != 100)
                        Data.standard = new double[100];
                    if (Data.assisted == null || Data.assisted.Length != 100)
                        Data.assisted = new double[100];
                    return;
                }
                catch (Exception e) { Debug.LogWarning(e.Message); }
            TryLegacy();
        }
        void TryLegacy()
        {
            var paths = new System.Collections.Generic.List<string> { Application.persistentDataPath };
#if UNITY_ANDROID && !UNITY_EDITOR
  try{using(var player=new AndroidJavaClass("com.unity3d.player.UnityPlayer"))using(var activity=player.GetStatic<AndroidJavaObject>("currentActivity"))using(var files=activity.Call<AndroidJavaObject>("getFilesDir"))paths.Add(files.Call<string>("getAbsolutePath"));}catch(Exception e){Debug.LogWarning("Legacy path: "+e.Message);}
#endif
#if UNITY_STANDALONE || UNITY_EDITOR
  string appData=Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
  paths.Add(Path.Combine(appData,"Godot","app_userdata","Renk Ekspresi"));
  paths.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal),"Library","Application Support","Godot","app_userdata","Renk Ekspresi"));
  paths.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal),".local","share","godot","app_userdata","Renk Ekspresi"));
#endif
            foreach (var folder in paths)
                foreach (var filename in new[] { "renk_ekspresi_player_v1.json", "renk_ekspresi_player_v1.bak" })
                    try
                    {
                        string path = Path.Combine(folder, filename);
                        if (!File.Exists(path))
                            continue;
                        Data = LegacyMigration.Read(File.ReadAllText(path));
                        Commit();
                        return;
                    }
                    catch (Exception e) { Debug.LogWarning("Legacy save: " + e.Message); }
        }
#if UNITY_WEBGL && !UNITY_EDITOR
 [System.Runtime.InteropServices.DllImport("__Internal")] static extern void RenkSyncSave();
#endif
        public void Commit()
        {
            try
            {
                Directory.CreateDirectory(Application.persistentDataPath);
                File.WriteAllText(PathName + ".tmp", JsonUtility.ToJson(Data));
                if (File.Exists(PathName))
                    File.Copy(PathName, PathName + ".bak", true);
                File.Copy(PathName + ".tmp", PathName, true);
                File.Delete(PathName + ".tmp");
#if UNITY_WEBGL && !UNITY_EDITOR
 RenkSyncSave();
#endif
            }
            catch (Exception e) { Debug.LogWarning("Save: " + e.Message); }
        }
        public void Win(int index, double seconds, bool assisted)
        {
            Data.unlocked = Math.Max(Data.unlocked, Math.Min(100, index + 2));
            Data.lastLevel = Math.Min(99, index + 1);
            var records = assisted ? Data.assisted : Data.standard;
            if (records[index] <= 0 || seconds < records[index])
                records[index] = seconds;
            Data.winsSinceAd = Math.Min(2, Data.winsSinceAd + 1);
            Commit();
        }
    }
}
