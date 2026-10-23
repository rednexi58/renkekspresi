using System;
namespace RenkEkspresi
{
    [Serializable]
    public sealed class PlayerSave
    {
        public int schema = 1, unlocked = 1, lastLevel, winsSinceAd;
        public string language = "tr";
        public bool tutorial, haptics = true, lowQuality;
        public float music = .35f, train = .55f, effects = .7f;
        public double[] standard = new double[100], assisted = new double[100];
    }
}
