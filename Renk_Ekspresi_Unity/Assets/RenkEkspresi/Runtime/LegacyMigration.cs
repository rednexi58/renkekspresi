using System;
using Newtonsoft.Json.Linq;
namespace RenkEkspresi
{
    // Reads the v0.34 save without ever trusting test VIP/paid flags as purchases.
    public static class LegacyMigration
    {
        public static PlayerSave Read(string json)
        {
            var old = JObject.Parse(json);
            if ((int?)old["schema"] != 1)
                throw new FormatException("Unknown save schema");
            var save = new PlayerSave();
            save.unlocked = (int)PuzzleEngine.Clamp((int?)old["unlocked"] ?? 1, 1, 100);
            save.lastLevel = (int)PuzzleEngine.Clamp((int?)old["last_level"] ?? 0, 0, save.unlocked - 1);
            save.language = (string)old["language"] == "en" ? "en" : "tr";
            save.tutorial = (bool?)old["onboarding_v033"] ?? false;
            save.haptics = (bool?)old["haptics"] ?? true;
            save.lowQuality = (string)old["quality"] == "low";
            save.music = (float)PuzzleEngine.Clamp((double?)old["music_volume"] ?? .35, 0, 1);
            save.train = (float)PuzzleEngine.Clamp((double?)old["train_volume"] ?? .55, 0, 1);
            save.effects = (float)PuzzleEngine.Clamp((double?)old["effects_volume"] ?? .7, 0, 1);
            if ((bool?)old["sound"] == false)
                save.music = save.train = save.effects = 0;
            save.winsSinceAd = (int)PuzzleEngine.Clamp((int?)old["interstitial_wins"] ?? 0, 0, 2);
            Copy(old["records_v027"]?["standard"] as JObject, save.standard);
            Copy(old["records_v027"]?["assisted"] as JObject, save.assisted);
            return save;
        }
        static void Copy(JObject bucket, double[] target)
        {
            if (bucket == null)
                return;
            foreach (var pair in bucket.Properties())
            {
                int index;
                double seconds;
                if (int.TryParse(pair.Name, out index) && index >= 0 && index < target.Length && double.TryParse(pair.Value.ToString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out seconds) && seconds > 0 && !double.IsInfinity(seconds) && !double.IsNaN(seconds))
                    target[index] = seconds;
            }
        }
    }
}
