Shader "RenkEkspresi/PaintedTrain" {
 Properties { _Glossiness("Smoothness",Range(0,1))=.38 _Metallic("Metal",Range(0,1))=.16 }
 SubShader { Tags { "RenderType"="Opaque" } LOD 200
 CGPROGRAM
 #pragma surface surf Standard fullforwardshadows vertex:vert
 #pragma target 3.0
 struct Input { float4 tint; float2 finish; };
 half _Glossiness; half _Metallic;
 void vert(inout appdata_full v,out Input o){UNITY_INITIALIZE_OUTPUT(Input,o);o.tint=v.color;o.finish=v.texcoord1.xy;}
 void surf(Input IN,inout SurfaceOutputStandard o){o.Albedo=IN.tint.rgb;o.Metallic=IN.finish.x;o.Smoothness=IN.finish.y;o.Alpha=1;}
 ENDCG
 }
 FallBack "Diffuse"
}
