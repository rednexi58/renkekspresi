using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
namespace RenkEkspresi.Editor
{
    // Cloud Build may skip Configure(). Keep the presentation settings deterministic.
    public sealed class PresentationBuild : IPreprocessBuildWithReport
    {
        public int callbackOrder => 1000;
        public void OnPreprocessBuild(BuildReport report)
        {
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.defaultScreenWidth = 720;
            PlayerSettings.defaultScreenHeight = 1280;
            Debug.Log("[Renk Ekspresi] Presentation v2: linear lighting, fixed portrait, vector direction markers.");
        }
    }
}
