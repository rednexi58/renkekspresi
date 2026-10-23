using System;
using System.Collections.Generic;
using System.Linq;
namespace RenkEkspresi
{
    // Direct port of v0.34 GameRules + MultiTrainRules. Rendering never decides matches.
    public sealed class PuzzleEngine
    {
        public const double Gap = 1.8, FirstGap = 2.2, PostTempo = 2.75;
        public LevelData Level;
        public readonly List<WagonState> Wagons = new List<WagonState>();
        public readonly List<Collector> Cards = new List<Collector>();
        public readonly List<StationSlot> Slots = new List<StationSlot>();
        public readonly List<int> Order = new List<int>();
        public double[] Heads, Recoils; public bool[] Opened;
        public double Elapsed, FreezeLeft, Start = .8, End, Loading, LoadingEnd, BrakeDistance, Dispatch;
        public string Status = "ready"; public int Taps, Blocked, Peak;
        public bool Vip, RewardSlot, Assisted;
        public int[] BoosterStock = { 0, 0, 1 }; // freeze, blast, recall
        public int Total;
        public bool Multi
        {
            get
            {
                return Heads.Length > 1;
            }
        }
        public double HeadDistance = .8;
        public double Head
        {
            get
            {
                return HeadDistance;
            }
        }
        double ActiveHead
        {
            get
            {
                return Multi ? Enumerable.Range(0, Heads.Length).Where(HasLane).Select(l => Heads[l]).DefaultIfEmpty(Start).Max() : Heads[0];
            }
        }
        public double Danger
        {
            get
            {
                return Clamp((ActiveHead - Start) / Math.Max(1, End - Start), 0, 1);
            }
        }
        public bool HasLane(int lane)
        {
            return Wagons.Any(w => w.Lane == lane);
        }
        public static double Clamp(double x, double a, double b)
        {
            return Math.Max(a, Math.Min(b, x));
        }
        static double Move(double a, double b, double d)
        {
            return a < b ? Math.Min(a + d, b) : Math.Max(a - d, b);
        }
        public PuzzleEngine(LevelData level, bool vip = false)
        {
            Level = level;
            int lanes = Math.Max(1, level.train_count);
            Heads = new double[lanes];
            Recoils = new double[lanes];
            Opened = new bool[lanes];
            for (int i = 0; i < lanes; i++)
                Heads[i] = Start;
            End = level.track_length - .9;
            Loading = Start + (End - Start) * level.loading_fraction;
            LoadingEnd = End - .2;
            BrakeDistance = level.recoil_per_unit * .8;
            Dispatch = level.dispatch_seconds / 1.75;
            foreach (var c in level.parking)
                Cards.Add(new Collector(c));
            var ranks = new int[lanes];
            for (int i = 0; i < level.train.Length; i++)
            {
                int lane = lanes > 1 ? level.wagon_streams[i] : 0;
                Wagons.Add(new WagonState { Id = i, Color = level.train[i], Lane = lane, Distance = Start - FirstGap - ranks[lane]++ * Gap });
            }
            Total = Wagons.Count;
            for (int i = 0; i < 3; i++)
                Slots.Add(new StationSlot());
            if (vip)
                GrantVip();
        }
        public bool Locked(int id)
        {
            return id >= 0 && id < Cards.Count && Cards[id].Data.requires >= 0 && Cards[Cards[id].Data.requires].State == "parked";
        }
        public List<int> Blockers(int id)
        {
            var result = new List<int>();
            if (id < 0 || id >= Cards.Count)
                return result;
            var c = Cards[id].Data;
            if (Locked(id))
                result.Add(c.requires);
            foreach (var other in Cards)
            {
                var o = other.Data;
                if (other.State != "parked" || o.id == id || result.Contains(o.id))
                    continue;
                int x = o.col - c.col, z = o.row - c.row;
                if ((c.dx != 0 || c.dz != 0) && x * c.dz == z * c.dx && x * c.dx + z * c.dz > 0)
                    result.Add(o.id);
            }
            return result;
        }
        public bool Available(int id)
        {
            return id >= 0 && id < Cards.Count && Cards[id].State == "parked" && Blockers(id).Count == 0;
        }
        public string Choose(int id)
        {
            if (Status != "playing")
                return "not_playing";
            if (Locked(id))
            {
                Blocked++;
                return "locked";
            }
            if (!Available(id))
            {
                Blocked++;
                return "blocked";
            }
            int s = Slots.FindIndex(x => x.Collector < 0);
            if (s < 0)
                return "full";
            var card = Cards[id];
            card.State = "queued";
            Slots[s].Collector = id;
            Slots[s].Color = card.Data.color;
            Slots[s].Ready = Elapsed + .26;
            Slots[s].Target = -1;
            Order.Add(id);
            Taps++;
            Peak = Math.Max(Peak, Slots.Count(x => x.Collector >= 0));
            return "";
        }
        public bool CanCollect(WagonState w)
        {
            return Opened[w.Lane] && w.Distance >= Loading - .00001 && w.Distance <= LoadingEnd;
        }
        public List<WagonState> Candidates()
        {
            if (!Multi)
                return new List<WagonState>(Wagons);
            var lanes = Enumerable.Range(0, Heads.Length).ToList();
            lanes.Sort((a, b) => Math.Abs(Heads[a] - Heads[b]) < .00001 * Math.Max(1, Math.Abs(Heads[a])) ? a.CompareTo(b) : Heads[b].CompareTo(Heads[a]));
            return lanes.SelectMany(l => Wagons.Where(w => w.Lane == l)).ToList();
        }
        void Assign()
        {
            if (!Opened.Any(x => x))
                return;
            for (int s = 0; s < Slots.Count; s++)
            {
                var slot = Slots[s];
                if (slot.Collector < 0 || slot.Target >= 0 || Elapsed + .000001 < slot.Ready)
                    continue;
                if (Slots.Any(x => x != slot && x.Color == slot.Color && x.Collector >= 0 && Order.IndexOf(x.Collector) < Order.IndexOf(slot.Collector)))
                    continue;
                foreach (var w in Candidates())
                    if (CanCollect(w) && w.Color == slot.Color && !Slots.Any(x => x.Target == w.Id))
                    {
                        slot.Target = w.Id;
                        slot.Ready = Elapsed + Dispatch;
                        break;
                    }
            }
        }
        void Remove(WagonState w, int s, List<MatchEvent> events, bool blast)
        {
            var slot = Slots[s];
            int id = slot.Collector;
            Cards[id].Remaining--;
            if (!blast)
                slot.Target = -1;
            if (blast)
                foreach (var other in Slots)
                    if (other.Target == w.Id)
                        other.Target = -1;
            if (Cards[id].Remaining <= 0)
            {
                Cards[id].State = "done";
                Order.Remove(id);
                slot.Color = -1;
                slot.Collector = -1;
                slot.Target = -1;
            }
            else
                slot.Ready = Elapsed + .045;
            events.Add(new MatchEvent { Wagon = w.Id, Color = w.Color, Lane = w.Lane, Collector = id, Slot = s, Distance = w.Distance });
            Wagons.Remove(w);
            Recoils[w.Lane] += BrakeDistance;
        }
        public List<MatchEvent> Tick(double delta)
        {
            var events = new List<MatchEvent>();
            if (Status != "playing")
                return events;
            double remaining = Math.Max(0, delta);
            while (remaining > .000001 && Status == "playing")
            {
                double step = Math.Min(.025, remaining);
                remaining -= step;
                Elapsed += step;
                var before = (double[])Heads.Clone();
                bool frozen = FreezeLeft > 0;
                FreezeLeft = Math.Max(0, FreezeLeft - step);
                for (int lane = 0; lane < Heads.Length; lane++)
                {
                    if (frozen || (Multi && !HasLane(lane)))
                        continue;
                    double progress = (Heads[lane] - Start) / Math.Max(1, End - Start);
                    double speed = Opened[lane] ? Level.approach_speed * .8 * PostTempo : (End - Start) * (progress < .5 ? .5 / (3.0 / 1.15) : .25 / (4.0 / 1.15));
                    if (Opened[lane] && progress < .75)
                        speed *= 1.15;
                    if (Multi)
                        speed *= .88;
                    Heads[lane] += speed * step;
                    if (Recoils[lane] > 0)
                    {
                        double recoil = Math.Min(Recoils[lane], 14 * step);
                        Heads[lane] = Math.Max(Start, Heads[lane] - recoil);
                        Recoils[lane] -= recoil;
                    }
                    if (Multi)
                        Heads[lane] = Math.Max(Start, Heads[lane]);
                    if ((Heads[lane] - Start) / (End - Start) >= .75)
                        Opened[lane] = true;
                }
                var ranks = new int[Heads.Length];
                foreach (var w in Wagons)
                {
                    int rank = ranks[w.Lane]++;
                    if (!frozen)
                        w.Distance = Move(w.Distance + Heads[w.Lane] - before[w.Lane], Heads[w.Lane] - FirstGap - rank * Gap, step * 5.45);
                }
                HeadDistance = ActiveHead;
                Assign();
                for (int s = 0; s < Slots.Count; s++)
                {
                    var slot = Slots[s];
                    if (slot.Collector < 0 || Elapsed + .000001 < slot.Ready)
                        continue;
                    var w = Wagons.Find(x => x.Id == slot.Target);
                    if (w == null)
                        continue;
                    if (!CanCollect(w))
                    {
                        slot.Target = -1;
                        slot.Ready = Elapsed + .045;
                        continue;
                    }
                    Remove(w, s, events, false);
                }
                if (Wagons.Count == 0)
                    Status = "won";
                else if (Danger >= 1)
                    Status = "lost";
            }
            return events;
        }
        public bool GrantVip()
        {
            if (Vip)
                return false;
            Vip = true;
            if (Slots.Count < 5)
                Slots.Add(new StationSlot());
            return true;
        }
        public bool GrantRewardSlot()
        {
            if (Status != "playing" || RewardSlot || Slots.Count >= 5)
                return false;
            RewardSlot = true;
            Slots.Add(new StationSlot());
            return true;
        }
        public bool GrantBooster(int kind)
        {
            if (Status != "playing" || kind < 0 || kind > 2 || BoosterStock[kind] > 0)
                return false;
            BoosterStock[kind]++;
            return true;
        }
        List<Tuple<WagonState, int>> BlastTargets()
        {
            var result = new List<Tuple<WagonState, int>>();
            var capacities = Slots.Select(s => s.Collector < 0 ? 0 : Cards[s.Collector].Remaining).ToArray();
            foreach (var w in Candidates())
            {
                if (!CanCollect(w))
                    continue;
                for (int s = 0; s < Slots.Count; s++)
                {
                    var slot = Slots[s];
                    if (slot.Color != w.Color || capacities[s] <= 0 || (Elapsed < slot.Ready && slot.Target < 0))
                        continue;
                    result.Add(Tuple.Create(w, s));
                    capacities[s]--;
                    break;
                }
                if (result.Count >= 5)
                    break;
            }
            return result;
        }
        public string UseBooster(int kind, out List<MatchEvent> events)
        {
            events = new List<MatchEvent>();
            if (Status != "playing" || kind < 0 || kind > 2)
                return "not_playing";
            if (kind == 0 && FreezeLeft > 0)
                return "active";
            if (kind == 2 && Order.Count == 0)
                return "empty";
            var targets = kind == 1 ? BlastTargets() : null;
            if (kind == 1 && targets.Count == 0)
                return "no_target";
            if (BoosterStock[kind] <= 0)
                return "no_stock";
            if (kind == 0)
                FreezeLeft = 5;
            if (kind == 2)
            {
                int id = Order[Order.Count - 1];
                Order.RemoveAt(Order.Count - 1);
                var slot = Slots.Find(x => x.Collector == id);
                Cards[id].State = "parked";
                slot.Collector = -1;
                slot.Color = -1;
                slot.Target = -1;
                slot.Ready = 0;
            }
            if (kind == 1)
                foreach (var target in targets)
                    if (Wagons.Contains(target.Item1) && CanCollect(target.Item1))
                        Remove(target.Item1, target.Item2, events, true);
            if (Wagons.Count == 0)
                Status = "won";
            BoosterStock[kind]--;
            Assisted = true;
            return "";
        }
    }
}
