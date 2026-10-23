using System;
using System.IO;
using System.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
class SyntaxCheck {
 static int Main(){int count=0,errors=0;foreach(var defines in new[]{new[]{"UNITY_EDITOR","UNITY_STANDALONE"},new[]{"UNITY_IOS"},new[]{"UNITY_ANDROID"},new[]{"UNITY_WEBGL"}})foreach(var file in Directory.GetFiles("../Assets","*.cs",SearchOption.AllDirectories)){
  var syntax=CSharpSyntaxTree.ParseText(File.ReadAllText(file),new CSharpParseOptions(LanguageVersion.CSharp9,preprocessorSymbols:defines),file);foreach(var error in syntax.GetDiagnostics().Where(x=>x.Severity==DiagnosticSeverity.Error)){Console.WriteLine(error);errors++;}count++;
 }Console.WriteLine("Syntax checks: "+count+", errors: "+errors+". This checks C# parsing only, NOT Unity API binding, shaders, scene import, or a player build.");return errors==0?0:1;}
}
