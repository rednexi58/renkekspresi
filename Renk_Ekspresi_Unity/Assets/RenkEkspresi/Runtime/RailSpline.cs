using System;
using UnityEngine;
namespace RenkEkspresi
{
    [Serializable]
    public class Route
    {
        public float length; public Vector3[] points;
    }
    [Serializable]
    public class RouteData
    {
        public Route[] routes;
    }
    public sealed class RailSpline
    {
        public Route[] Routes;
        public RailSpline(int level)
        {
            Routes = JsonUtility.FromJson<RouteData>(Resources.Load<TextAsset>("Data/route_" + level.ToString("000")).text).routes;
        }
        public Vector3 Point(int lane, double distance)
        {
            var route = Routes[lane];
            float f = Mathf.Clamp01((float)distance / route.length) * (route.points.Length - 1);
            int i = Mathf.Min(route.points.Length - 2, Mathf.FloorToInt(f));
            return Vector3.Lerp(route.points[i], route.points[i + 1], f - i);
        }
        public Vector3 Direction(int lane, double distance)
        {
            var d = Point(lane, distance + .05) - Point(lane, distance - .05);
            return d.sqrMagnitude < .0001f ? Vector3.forward : d.normalized;
        }
    }
}
