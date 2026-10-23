using UnityEngine;
namespace RenkEkspresi
{
    public sealed class AudioManager : MonoBehaviour
    {
        AudioSource music, train, fx; public PlayerSave Settings; float lastMatch;
        AudioSource Source(string file, bool loop)
        {
            var s = gameObject.AddComponent<AudioSource>();
            s.clip = Resources.Load<AudioClip>("Audio/" + file);
            s.loop = loop;
            s.playOnAwake = false;
            return s;
        }
        public void Setup(PlayerSave settings)
        {
            Settings = settings;
            music = Source("calm_journey", true);
            train = Source("steam_chuffs", true);
            fx = Source("tap", false);
        }
        public void StartSound()
        {
            if (!music.isPlaying)
                music.Play();
            if (!train.isPlaying)
                train.Play();
        }
        public void Motion(bool moving, float danger, bool muted)
        {
            music.volume = muted ? 0 : Settings.music * .18f * (moving ? 1 : .65f);
            float target = muted || !moving ? 0 : Settings.train * .25f * Mathf.Lerp(.25f, 1, Mathf.SmoothStep(0, 1, (danger - .2f) / .8f));
            train.volume = Mathf.MoveTowards(train.volume, target, Time.unscaledDeltaTime * .16f);
        }
        public void Play(string name)
        {
            if (name == "match" && Time.unscaledTime - lastMatch < .55f)
                return;
            if (name == "match")
                lastMatch = Time.unscaledTime;
            fx.PlayOneShot(Resources.Load<AudioClip>("Audio/" + name), Settings.effects * (name == "match" ? .12f : .3f));
        }
        void OnApplicationPause(bool p)
        {
            if (music)
            {
                music.Pause();
                train.Pause();
                if (!p)
                {
                    music.UnPause();
                    train.UnPause();
                }
            }
        }
    }
}
