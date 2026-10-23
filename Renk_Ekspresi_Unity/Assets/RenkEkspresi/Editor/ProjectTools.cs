using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
namespace RenkEkspresi.Editor
{
    [InitializeOnLoad]
    public static class ProjectTools
    {
        const string ScenePath = "Assets/RenkEkspresi/Scenes/Main.unity";
        static ProjectTools()
        {
            EditorApplication.delayCall += () => { if (!File.Exists("ProjectSettings/RenkConfigured.txt")) { Configure(); TrainPrefabBaker.Bake(); File.WriteAllText("ProjectSettings/RenkConfigured.txt", "Unity migration v1\n"); Open(); } };
        }
        [MenuItem("Renk Ekspresi/Configure project")]
        public static void Configure()
        {
            PlayerSettings.companyName = "BedoGames";
            PlayerSettings.productName = "Renk Ekspresi";
            PlayerSettings.bundleVersion = "0.40.0";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.iOS, "com.bedogames.renkekspresi");
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.bedogames.renkekspresi");
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
            PlayerSettings.defaultScreenWidth = 720;
            PlayerSettings.defaultScreenHeight = 1280;
            PlayerSettings.resizableWindow = true;
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.iOS, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.iOS.targetOSVersionString = "15.0";
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
            PlayerSettings.WebGL.decompressionFallback = true;
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            AssetDatabase.SaveAssets();
        }
        [MenuItem("Renk Ekspresi/Open game scene")]
        public static void Open()
        {
            EditorSceneManager.OpenScene(ScenePath);
        }
        static string Number()
        {
            string n = Environment.GetEnvironmentVariable("RENK_EKSPRESI_BUILD_NUMBER");
            int parsed;
            if (!int.TryParse(n, out parsed) || parsed < 1)
                throw new BuildFailedException("Set RENK_EKSPRESI_BUILD_NUMBER to a positive integer newer than the last uploaded build.");
            return n;
        }
        static void Build(BuildTarget target, string destination)
        {
            if (!BuildPipeline.IsBuildTargetSupported(BuildPipeline.GetBuildTargetGroup(target), target))
                throw new BuildFailedException("Install the Unity build support module for " + target);
            if (EditorUserBuildSettings.activeBuildTarget != target)
                EditorUserBuildSettings.SwitchActiveBuildTarget(BuildPipeline.GetBuildTargetGroup(target), target);
            Directory.CreateDirectory(Path.GetDirectoryName(destination));
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions { scenes = new[] { ScenePath }, locationPathName = destination, target = target, options = BuildOptions.None });
            if (report.summary.result != BuildResult.Succeeded)
                throw new BuildFailedException(report.summary.result.ToString());
        }
        [MenuItem("Renk Ekspresi/Build/WebGL preview")]
        public static void BuildWeb()
        {
            Configure();
            Build(BuildTarget.WebGL, "Builds/WebGL");
            File.WriteAllText("Builds/WebGL/online.txt", "online");
        }
        [MenuItem("Renk Ekspresi/Build/iOS Xcode project")]
        public static void BuildIOS()
        {
            Configure();
            PlayerSettings.iOS.buildNumber = Number();
            string team = Environment.GetEnvironmentVariable("APPLE_TEAM_ID");
            if (string.IsNullOrWhiteSpace(team))
                throw new BuildFailedException("Set APPLE_TEAM_ID before the signed iOS pipeline.");
            PlayerSettings.iOS.appleDeveloperTeamID = team;
            PlayerSettings.iOS.appleEnableAutomaticSigning = true;
            Build(BuildTarget.iOS, "Builds/iOS");
        }
        [MenuItem("Renk Ekspresi/Build/Android test APK")]
        public static void BuildAPK()
        {
            Configure();
            PlayerSettings.Android.bundleVersionCode = int.Parse(Number());
            EditorUserBuildSettings.buildAppBundle = false;
            PlayerSettings.Android.useCustomKeystore = false;
            Build(BuildTarget.Android, "Builds/Android/RenkEkspresi.apk");
        }
        [MenuItem("Renk Ekspresi/Build/Android signed AAB")]
        public static void BuildAAB()
        {
            Configure();
            PlayerSettings.Android.bundleVersionCode = int.Parse(Number());
            string[] names = { "ANDROID_KEYSTORE_PATH", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD" };
            foreach (var name in names)
                if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable(name)))
                    throw new BuildFailedException("Missing signing environment variable: " + name);
            PlayerSettings.Android.useCustomKeystore = true;
            PlayerSettings.Android.keystoreName = Environment.GetEnvironmentVariable(names[0]);
            PlayerSettings.Android.keystorePass = Environment.GetEnvironmentVariable(names[1]);
            PlayerSettings.Android.keyaliasName = Environment.GetEnvironmentVariable(names[2]);
            PlayerSettings.Android.keyaliasPass = Environment.GetEnvironmentVariable(names[3]);
            EditorUserBuildSettings.buildAppBundle = true;
            try
            {
                Build(BuildTarget.Android, "Builds/Android/RenkEkspresi.aab");
            }
            finally { PlayerSettings.Android.keystorePass = ""; PlayerSettings.Android.keyaliasPass = ""; AssetDatabase.SaveAssets(); }
        }
        [MenuItem("Renk Ekspresi/Level inspector")]
        public static void Inspector()
        {
            EditorWindow.GetWindow<LevelInspector>("Renk · Levels");
        }
    }
    // Unity Build Automation invokes BuildPipeline directly, rather than BuildIOS().
    // Apply the iOS build number for every entry point, before Xcode export/signing.
    public sealed class IosBuildVersionGuard : IPreprocessBuildWithReport
    {
        public int callbackOrder => int.MaxValue;

        public void OnPreprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.iOS)
                return;

            int number;
            string requested = Environment.GetEnvironmentVariable("RENK_EKSPRESI_BUILD_NUMBER");
            string cloudBuild = Environment.GetEnvironmentVariable("UCB_BUILD_NUMBER");
            if (!string.IsNullOrWhiteSpace(requested))
            {
                if (!int.TryParse(requested, out number) || number < 1)
                    throw new BuildFailedException("RENK_EKSPRESI_BUILD_NUMBER must be a positive integer.");
            }
            else if (!string.IsNullOrWhiteSpace(cloudBuild))
            {
                if (!int.TryParse(cloudBuild, out number) || number < 1 || number > int.MaxValue - 40)
                    throw new BuildFailedException("UCB_BUILD_NUMBER must be a valid positive integer.");
                number += 40;
            }
            else if (!int.TryParse(PlayerSettings.iOS.buildNumber, out number) || number < 1)
            {
                number = 41;
            }

            PlayerSettings.iOS.buildNumber = number.ToString(System.Globalization.CultureInfo.InvariantCulture);
            Debug.Log("[Renk Ekspresi] iOS CFBundleVersion = " + PlayerSettings.iOS.buildNumber);
        }
    }
    public sealed class LevelInspector : EditorWindow
    {
        int level = 1;
        void OnGUI()
        {
            EditorGUILayout.HelpBox("Only runs inside the Unity Editor. Does not unlock the player's campaign.", MessageType.Info);
            level = EditorGUILayout.IntSlider("Level", level, 1, 100);
            GUI.enabled = EditorApplication.isPlaying;
            if (GUILayout.Button("Play selected level"))
            {
                var game = UnityEngine.Object.FindFirstObjectByType<GameManager>();
                if (game)
                    game.EditorPreviewLevel(level - 1);
            }
            GUI.enabled = true;
        }
    }
}
