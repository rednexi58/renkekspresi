using UnityEngine;
using System.Runtime.InteropServices;
namespace RenkEkspresi
{
    public static class Haptics
    {
#if UNITY_IOS && !UNITY_EDITOR
 [DllImport("__Internal")] static extern void RenkSoftHaptic();
#endif
        public static void Pulse()
        {
#if UNITY_IOS && !UNITY_EDITOR
  RenkSoftHaptic();
#elif UNITY_ANDROID && !UNITY_EDITOR
  try{using(var player=new AndroidJavaClass("com.unity3d.player.UnityPlayer"))using(var activity=player.GetStatic<AndroidJavaObject>("currentActivity"))using(var vibrator=activity.Call<AndroidJavaObject>("getSystemService","vibrator"))using(var effect=new AndroidJavaClass("android.os.VibrationEffect"))using(var pulse=effect.CallStatic<AndroidJavaObject>("createOneShot",35L,45)){vibrator.Call("vibrate",pulse);}}catch(System.Exception e){Debug.LogWarning("Haptics unavailable: "+e.Message);}
#endif
        }
    }
}
