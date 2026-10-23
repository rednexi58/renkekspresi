using System;
namespace RenkEkspresi
{
    [Serializable]
    public class Campaign
    {
        public LevelData[] levels;
    }
    [Serializable]
    public class LevelData
    {
        public int id, theme, layout, map_seed, rows, cols, active_count, collector_capacity, par_laps, train_count = 1;
        public string name, name_en, region, region_en, mode, match_scope, lesson;
        public bool guided;
        public double speed, dispatch_seconds, loading_fraction, recoil_per_unit, approach_speed, track_length;
        public int[] train, wagon_streams;
        public CardData[] parking;
        public Design design;
    }
    [Serializable]
    public class Design
    {
        public int[] solution;
    }
    [Serializable]
    public class CardData
    {
        public int id, row, col, dx, dz, color, capacity, requires = -1;
        public string key;
    }
    public class Collector
    {
        public CardData Data; public int Remaining; public string State = "parked";
        public Collector(CardData d)
        {
            Data = d;
            Remaining = d.capacity;
        }
    }
    public class WagonState
    {
        public int Id, Color, Lane; public double Distance;
    }
    public class StationSlot
    {
        public int Collector = -1, Color = -1, Target = -1; public double Ready;
    }
    public class MatchEvent
    {
        public int Wagon, Slot, Collector, Color, Lane; public double Distance;
    }
}
