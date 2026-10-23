#if UNITY_ANDROID
using System.IO;
using System.Xml;
using UnityEditor.Android;
namespace RenkEkspresi.Editor {
public sealed class AndroidPermissions:IPostGenerateGradleAndroidProject {
 public int callbackOrder{get{return 0;}}
 public void OnPostGenerateGradleAndroidProject(string path){
  string file=Path.Combine(path,"src/main/AndroidManifest.xml");var doc=new XmlDocument();doc.Load(file);const string ns="http://schemas.android.com/apk/res/android";
  foreach(string name in new[]{"android.permission.VIBRATE","android.permission.INTERNET","android.permission.ACCESS_NETWORK_STATE"}){
   bool found=false;foreach(XmlNode item in doc.DocumentElement.ChildNodes)if(item.Name=="uses-permission"&&item.Attributes["name",ns]?.Value==name)found=true;
   if(!found){var permission=doc.CreateElement("uses-permission");permission.SetAttribute("name",ns,name);doc.DocumentElement.AppendChild(permission);}
  }doc.Save(file);
 }
}
}
#endif
