// Add this file AND AppIcon1024.png to Assets/RenkEkspresi/Editor/.
// Runs for Unity Build Automation as well as local iOS builds.
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
#if UNITY_IOS
using UnityEditor.iOS;
#endif

namespace RenkEkspresi.Editor
{
    public sealed class IosAppIconSetup : IPreprocessBuildWithReport, IPostprocessBuildWithReport
    {
        private const string IconPath = "Assets/RenkEkspresi/Editor/AppIcon1024.png";
        public int callbackOrder => int.MaxValue - 1;

        public void OnPreprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.iOS) return;
#if UNITY_IOS
            if (!File.Exists(IconPath))
                throw new BuildFailedException("Missing app icon: upload AppIcon1024.png beside IosAppIconSetup.cs.");

            AssetDatabase.ImportAsset(IconPath, ImportAssetOptions.ForceSynchronousImport);
            var importer = AssetImporter.GetAtPath(IconPath) as TextureImporter;
            if (importer == null)
                throw new BuildFailedException("Cannot import " + IconPath);
            importer.textureType = TextureImporterType.Default;
            importer.maxTextureSize = 1024;
            importer.npotScale = TextureImporterNPOTScale.None;
            importer.mipmapEnabled = false;
            importer.alphaSource = TextureImporterAlphaSource.None;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.ClearPlatformTextureSettings("iPhone");
            importer.SaveAndReimport();

            var texture = AssetDatabase.LoadAssetAtPath<Texture2D>(IconPath);
            if (texture == null || texture.width != 1024 || texture.height != 1024)
                throw new BuildFailedException("AppIcon1024.png must import at exactly 1024 x 1024 pixels.");

            var kinds = new[] {
                iOSPlatformIconKind.Application, iOSPlatformIconKind.Spotlight,
                iOSPlatformIconKind.Settings, iOSPlatformIconKind.Notification,
                iOSPlatformIconKind.Marketing
            };
            foreach (var kind in kinds)
            {
                var icons = PlayerSettings.GetPlatformIcons(NamedBuildTarget.iOS, kind);
                if (kind == iOSPlatformIconKind.Marketing && icons.Length == 0)
                    throw new BuildFailedException("Unity did not expose the iOS marketing icon slot.");
                foreach (var icon in icons) icon.SetTexture(texture);
                PlayerSettings.SetPlatformIcons(NamedBuildTarget.iOS, kind, icons);
            }
            PlayerSettings.productName = "Renk Ekspresi";
            PlayerSettings.iOS.targetOSVersionString = "15.0";
            AssetDatabase.SaveAssets();
            Debug.Log("[Renk Ekspresi] iOS icons assigned, including 1024px marketing icon; minimum iOS = 15.0.");
#else
            throw new BuildFailedException("Switch the active Unity build target to iOS before building.");
#endif
        }

        // Catch a missing exported marketing icon before Xcode signing/upload.
        public void OnPostprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.iOS) return;
            string root = report.summary.outputPath;
            if (!Directory.Exists(root))
                throw new BuildFailedException("Cannot inspect exported Xcode project: " + root);
            foreach (string catalog in Directory.GetFiles(root, "Contents.json", SearchOption.AllDirectories))
            {
                string directory = Path.GetDirectoryName(catalog);
                if (!directory.EndsWith(".appiconset", StringComparison.OrdinalIgnoreCase)) continue;
                var contents = JsonUtility.FromJson<IconCatalog>(File.ReadAllText(catalog));
                if (contents == null || contents.images == null) continue;
                foreach (var entry in contents.images)
                {
                    if (entry.size != "1024x1024" || string.IsNullOrEmpty(entry.filename)) continue;
                    bool iosIcon = entry.idiom == "ios-marketing" ||
                        (entry.idiom == "universal" && entry.platform == "ios");
                    if (!iosIcon || (entry.appearances != null && entry.appearances.Length > 0)) continue;
                    string png = Path.Combine(directory, entry.filename);
                    if (!File.Exists(png)) continue;
                    byte[] bytes = File.ReadAllBytes(png);
                    // PNG signature and IHDR dimensions, 1024 = 0x00000400.
                    if (bytes.Length < 33 || bytes[0] != 137 || bytes[1] != 80 ||
                        bytes[2] != 78 || bytes[3] != 71 ||
                        bytes[16] != 0 || bytes[17] != 0 || bytes[18] != 4 || bytes[19] != 0 ||
                        bytes[20] != 0 || bytes[21] != 0 || bytes[22] != 4 || bytes[23] != 0) continue;
                    Debug.Log("[Renk Ekspresi] Verified exported 1024px Any Appearance icon: " + png);
                    return;
                }
            }
            throw new BuildFailedException("Exported Xcode project has no 1024px Any Appearance iOS icon. Do not upload this build.");
        }

        [Serializable] private sealed class IconCatalog { public IconEntry[] images; }
        [Serializable] private sealed class IconEntry
        {
            public string idiom, platform, size, filename;
            public IconAppearance[] appearances;
        }
        [Serializable] private sealed class IconAppearance { public string appearance, value; }
    }
}
