// Writes App Store-relevant Info.plist keys into the exported Xcode project.
// Kept separate from IosAppIconSetup so each post-processor has one responsibility.
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
#if UNITY_IOS
using UnityEditor.iOS.Xcode;
#endif

namespace RenkEkspresi.Editor
{
    public sealed class IosInfoPlistSetup : IPostprocessBuildWithReport
    {
        public int callbackOrder => int.MaxValue - 2;

        public void OnPostprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.iOS)
                return;
#if UNITY_IOS
            string plistPath = Path.Combine(report.summary.outputPath, "Info.plist");
            if (!File.Exists(plistPath))
                throw new BuildFailedException("Exported Xcode project has no Info.plist: " + plistPath);

            var plist = new PlistDocument();
            plist.ReadFromFile(plistPath);
            var root = plist.root;

            // The game uses no custom or non-exempt encryption (only HTTPS via the OS, if any).
            // Declaring it here removes the export-compliance prompt on every TestFlight upload.
            root.SetBoolean("ITSAppUsesNonExemptEncryption", false);

            // Portrait-only puzzle: keep iPad multitasking from forcing landscape layouts.
            root.SetBoolean("UIRequiresFullScreen", true);

            plist.WriteToFile(plistPath);
#endif
        }
    }
}
