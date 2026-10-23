using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace RenkEkspresi
{
    [Serializable]
    public class ModelPart
    {
        public Vector3[] vertices, normals; public int[] triangles; public float r, g, b, metallic, roughness;
    }
    [Serializable]
    public class ModelData
    {
        public ModelPart[] parts;
    }
    public static class TrainModels
    {
        static Dictionary<int, Mesh> meshes = new Dictionary<int, Mesh>(); static Material paint;
        public static Mesh GetMesh(int color)
        {
            if (meshes.ContainsKey(color))
                return meshes[color];
            var source = Resources.Load<TextAsset>("Models/" + (color < 0 ? "Locomotive" : "Wagon" + color));
            var data = JsonUtility.FromJson<ModelData>(source.text);
            Resources.UnloadAsset(source);
            var v = new List<Vector3>();
            var n = new List<Vector3>();
            var t = new List<int>();
            var colors = new List<Color>();
            var surface = new List<Vector2>();
            foreach (var p in data.parts)
            {
                int offset = v.Count;
                v.AddRange(p.vertices);
                n.AddRange(p.normals);
                foreach (int i in p.triangles)
                    t.Add(i + offset);
                for (int i = 0; i < p.vertices.Length; i++)
                {
                    colors.Add(QualitySettings.activeColorSpace == ColorSpace.Linear ? new Color(p.r, p.g, p.b).linear : new Color(p.r, p.g, p.b));
                    surface.Add(new Vector2(p.metallic, 1 - p.roughness));
                }
            }
            var mesh = new Mesh { name = color < 0 ? "ExpressLocomotive" : "PaintedWagon" + color, indexFormat = IndexFormat.UInt32 };
            mesh.SetVertices(v);
            mesh.SetNormals(n);
            mesh.SetColors(colors);
            mesh.SetUVs(1, surface);
            mesh.SetTriangles(t, 0);
            mesh.RecalculateBounds();
            meshes[color] = mesh;
            return mesh;
        }
        public static GameObject Create(int color, Transform parent)
        {
            var prefab = Resources.Load<GameObject>("Prefabs/" + (color < 0 ? "Locomotive" : "Wagon" + color));
            if (prefab)
                return UnityEngine.Object.Instantiate(prefab, parent, false);
            if (!paint)
                paint = new Material(Resources.Load<Shader>("PaintedTrain")) { name = "Enamel paint", enableInstancing = true };
            var go = new GameObject(color < 0 ? "Locomotive" : "Wagon");
            go.transform.SetParent(parent, false);
            go.AddComponent<MeshFilter>().sharedMesh = GetMesh(color);
            go.AddComponent<MeshRenderer>().sharedMaterial = paint;
            return go;
        }
    }
}
