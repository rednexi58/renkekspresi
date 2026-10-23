using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using RenkEkspresi;
class Program {
 static int assertions,snapshots;
 static void Check(bool ok,string message){assertions++;if(!ok)throw new Exception(message);}
 static void Near(double actual,double expected,string context){Check(Math.Abs(actual-expected)<.00025,context+": "+actual+" != "+expected);}
 static void Main(){
 var campaign=JsonSerializer.Deserialize<Campaign>(File.ReadAllText("../Assets/RenkEkspresi/Resources/Data/campaign.json"),new JsonSerializerOptions{IncludeFields=true});
 using var reference=JsonDocument.Parse(File.ReadAllText("godot_reference.json"));
 using var edges=JsonDocument.Parse(File.ReadAllText("godot_edge_reference.json"));
 foreach(var test in reference.RootElement.GetProperty("cases").EnumerateArray().Concat(edges.RootElement.GetProperty("cases").EnumerateArray())){
  int level=test.GetProperty("level").GetInt32();var rules=new PuzzleEngine(campaign.levels[level-1]);rules.Status="playing";
  var actions=test.GetProperty("actions").EnumerateArray().ToArray();var frames=test.GetProperty("snapshots").EnumerateArray().ToArray();int act=0,frame=0;
  for(int step=0;frame<frames.Length;step++){
   while(act<actions.Length&&actions[act].GetProperty("step").GetInt32()==step){
    var action=actions[act++];string kind=action.TryGetProperty("kind",out var k)?k.GetString():"choose";string expected=action.TryGetProperty("error",out var error)?error.GetString():"";bool ok;
    switch(kind){
     case "choose":Check(rules.Choose(action.GetProperty("id").GetInt32())==expected,"Choice level "+level+" step "+step);break;
     case "vip":ok=rules.GrantVip();Check(ok==action.GetProperty("ok").GetBoolean(),"VIP parity");break;
     case "slot":ok=rules.GrantRewardSlot();Check(ok==action.GetProperty("ok").GetBoolean(),"Slot parity");break;
     case "refill":ok=rules.GrantBooster(action.GetProperty("id").GetInt32());Check(ok==action.GetProperty("ok").GetBoolean(),"Refill parity");break;
     case "boost":Check(rules.UseBooster(action.GetProperty("id").GetInt32(),out var matches)==expected,"Booster parity L"+level+" step "+step);break;
    }
   }
   rules.Tick(.05);
   if(step+1!=frames[frame].GetProperty("step").GetInt32())continue;
   var f=frames[frame++];snapshots++;string ctx="L"+level+" t"+(step+1);
   Check(rules.Status==f.GetProperty("status").GetString(),ctx+" status");Near(rules.Elapsed,f.GetProperty("elapsed").GetDouble(),ctx+" elapsed");Near(rules.Head,f.GetProperty("head").GetDouble(),ctx+" head");
   Check(rules.Wagons.Select(w=>w.Id).SequenceEqual(f.GetProperty("ids").EnumerateArray().Select(x=>x.GetInt32())),ctx+" wagon ids");
   Check(rules.Slots.Select(s=>s.Collector).SequenceEqual(f.GetProperty("slots").EnumerateArray().Select(x=>x.GetInt32())),ctx+" slots");
   Check(rules.Cards.Select(c=>c.Remaining).SequenceEqual(f.GetProperty("remaining").EnumerateArray().Select(x=>x.GetInt32())),ctx+" capacities");
   var heads=f.GetProperty("heads").EnumerateArray().ToArray();for(int i=0;i<heads.Length;i++)Near(rules.Heads[i],heads[i].GetDouble(),ctx+" lane "+i);
   if(f.TryGetProperty("stock",out var stock)){
    Check(rules.BoosterStock.SequenceEqual(stock.EnumerateArray().Select(x=>x.GetInt32())),ctx+" stock");Near(rules.FreezeLeft,f.GetProperty("freeze").GetDouble(),ctx+" freeze");
    Check(rules.Slots.Select(s=>s.Target).SequenceEqual(f.GetProperty("targets").EnumerateArray().Select(x=>x.GetInt32())),ctx+" targets");
    var ready=f.GetProperty("ready").EnumerateArray().ToArray();for(int i=0;i<ready.Length;i++)Near(rules.Slots[i].Ready,ready[i].GetDouble(),ctx+" ready "+i);
   }
   var distances=f.GetProperty("distances").EnumerateArray().ToArray();for(int i=0;i<distances.Length;i++)Near(rules.Wagons[i].Distance,distances[i].GetDouble(),ctx+" wagon "+i);
  }
  Console.WriteLine("Parity level "+level+": "+rules.Status+" "+rules.Elapsed.ToString("0.00")+"s");
 }
 // Losing, direction blocking, physical exposure, finite capacity, reward ownership.
 foreach(var level in campaign.levels){var r=new PuzzleEngine(level);r.Status="playing";for(int t=0;t<24000&&r.Status=="playing";t++)r.Tick(.05);Check(r.Status=="lost","Idle must lose L"+level.id);}
 var game=new PuzzleEngine(campaign.levels[20]);game.Status="playing";
 var blocked=game.Cards.FirstOrDefault(c=>!game.Available(c.Data.id));Check(blocked!=null,"Blocked puzzle candidate");int taps=game.Taps;Check(game.Choose(blocked.Data.id)!="","Blocked choice rejected");Check(game.Taps==taps,"No accepted tap for blocked");
 foreach(var w in game.Wagons)Check(!game.CanCollect(w),"Fresh wagon not eligible");
 Check(game.GrantVip()&&!game.GrantVip()&&game.Slots.Count==4,"VIP exactly one");Check(game.GrantRewardSlot()&&!game.GrantRewardSlot()&&game.Slots.Count==5,"Reward slot exactly one");
 var fresh=new PuzzleEngine(game.Level,true);Check(fresh.Slots.Count==4&&!fresh.RewardSlot,"Per-level ad slot resets");Check(fresh.BoosterStock.SequenceEqual(new[]{0,0,1}),"Initial stock");
 var guard=new RewardGuard();int token=guard.Begin();Check(guard.Accept(token,true)&&!guard.Accept(token,true),"One reward per callback");token=guard.Begin();guard.Cancel();Check(!guard.Accept(token,true),"Stale callback rejected");
 var shop=new UnavailableCommerce();bool bought=true,reward=true;shop.Buy(ok=>bought=ok);shop.Reward(ok=>reward=ok);Check(!bought&&!reward&&!shop.Vip,"No fake transactions");
 var migrated=LegacyMigration.Read("{\"schema\":1,\"unlocked\":42,\"last_level\":35,\"language\":\"en\",\"onboarding_v033\":true,\"test_vip\":true,\"records_v027\":{\"standard\":{\"3\":19.4},\"assisted\":{\"4\":25.2}}}");
 Check(migrated.unlocked==42&&migrated.lastLevel==35&&migrated.language=="en"&&migrated.tutorial,"Legacy progress migrated");Near(migrated.standard[3],19.4,"Legacy standard record");Near(migrated.assisted[4],25.2,"Legacy assisted record");
 Console.WriteLine("PASS: 100 campaign + 16 edge traces, "+snapshots+" snapshots, 100 idle-loss runs; "+assertions+" assertions.");
 }
}
