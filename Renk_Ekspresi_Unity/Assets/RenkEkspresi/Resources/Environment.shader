Shader "RenkEkspresi/Environment" {
 Properties { _Color("Color",Color)=(1,1,1,1) _Glossiness("Smoothness",Range(0,1))=.28 }
 SubShader { Tags { "RenderType"="Opaque" } LOD 200
 CGPROGRAM
 #pragma surface surf Standard fullforwardshadows
 #pragma target 3.0
 struct Input { float3 worldPos; };
 fixed4 _Color; half _Glossiness;
 void surf(Input IN,inout SurfaceOutputStandard o){o.Albedo=_Color.rgb;o.Metallic=0;o.Smoothness=_Glossiness;o.Alpha=1;}
 ENDCG
 }
 FallBack "Diffuse"
}
