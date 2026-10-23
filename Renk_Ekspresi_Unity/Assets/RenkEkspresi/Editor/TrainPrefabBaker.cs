using System.IO;
using UnityEngine;
using UnityEditor;
namespace RenkEkspresi.Editor
{
    public static class TrainPrefabBaker
    {
        [MenuItem("Renk Ekspresi/Art/Create missing editable train prefabs")]
        public static void Bake()
        {
            const string folder = "Assets/RenkEkspresi/Resources/Prefabs";
            Directory.CreateDirectory(folder);
            AssetDatabase.Refresh();
            string materialPath = folder + "/TrainPaint.mat";
            var paint = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (!paint)
            {
                paint = new Material(Resources.Load<Shader>("PaintedTrain")) { enableInstancing = true };
                AssetDatabase.CreateAsset(paint, materialPath);
            }
            for (int color = -1; color < 5; color++)
            {
                string name = color < 0 ? "Locomotive" : "Wagon" + color;
                string path = folder + "/" + name + ".prefab";
                if (AssetDatabase.LoadAssetAtPath<GameObject>(path))
                    continue;
                string meshPath = folder + "/" + name + ".asset";
                var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(meshPath);
                if (!mesh)
                {
                    mesh = Object.Instantiate(TrainModels.GetMesh(color));
                    AssetDatabase.CreateAsset(mesh, meshPath);
                }
                var go = new GameObject(name);
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                go.AddComponent<MeshRenderer>().sharedMaterial = paint;
                PrefabUtility.SaveAsPrefabAsset(go, path);
                Object.DestroyImmediate(go);
            }
            AssetDatabase.SaveAssets();
        }
    }
}
