Shader "Unlit/Cloth"
{
    Properties
    {
		_MainColor("MainColor", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
		_NormalMap("Normal Map", 2D) = "bump"{}
		_NormalScale("NormalScale", Range(-1,2)) = 1
		_PBRMap("PBRMap(R:Smooth,G:Metallic)",2D) = "white"{}
		_Smoothness("Smoothness",Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.5
		_NoiseTex("NoiseTex", 2D) = "black"{}
		[HDR]_EmissiveColor("EmissiveColor", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "transparent" "IgnoreProjector" = "true" "ForceNoShadowCasting" = "True" }
        LOD 100

		//Pass
		//{
		//	ColorMask 0
		//	ZWrite On
		//	Cull Off
		//}
		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }
			Cull Front
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "FabricLighting.cginc"

			struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
			float3 normal : NORMAL;
			float4 tangent : TANGENT;
		};

		struct v2f
		{
			float4 uv : TEXCOORD0;
			float4 vertex : SV_POSITION;
			float4 TtoW0 : TEXCOORD1;
			float4 TtoW1 : TEXCOORD2;
			float4 TtoW2 : TEXCOORD3;
		};

		sampler2D _MainTex;
		float4 _MainTex_ST;
		sampler2D _NormalMap;
		float _NormalScale;
		sampler2D _PBRMap;
		float _Smoothness;
		float _Metallic;
		fixed4 _MainColor;
		sampler2D _NoiseTex;
		float4 _NoiseTex_ST;
		fixed4 _EmissiveColor;

		v2f vert(appdata v)
		{
			v2f o;
			float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			float3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
			float3 worldTangent = normalize(UnityObjectToWorldDir(v.tangent));
			float3 worldBinormal = normalize(cross(worldNormal, worldTangent) * v.tangent.w);
			o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
			o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
			o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
			o.uv.zw = TRANSFORM_TEX(v.uv, _NoiseTex);
			return o;
		}

		fixed4 frag(v2f i) : SV_Target
		{
			fixed4 albedo = tex2D(_MainTex, i.uv);
		float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
		float3 normal = _UnpackNormalWithScale(tex2D(_NormalMap, i.uv), _NormalScale);
		float3 worldNormal = float3(dot(normal, i.TtoW0.xyz), dot(normal, i.TtoW1.xyz), dot(normal, i.TtoW2.xyz));
		float3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
		float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
		half3 pbr = tex2D(_PBRMap, i.uv).rgb;
		half smoothness = pbr.r * _Smoothness;
		half metallic = pbr.g * _Metallic;
		half4 finalColor = 0;
		//half3 color = LambertLighting(albedo, worldNormal, worldViewDir, worldLightDir);
		half3 emissiveColor1 = tex2D(_NoiseTex, i.uv.zw);
		half3 emissiveColor2 = tex2D(_NoiseTex, i.uv.zw + worldViewDir.xz);
		half3 blingColor = emissiveColor1.r * emissiveColor2.r * _EmissiveColor.rgb;

		half3 color = PBRLighting(albedo.rgb, worldNormal, worldViewDir, worldLightDir, smoothness, metallic, blingColor);
		finalColor.rgb = color;
		finalColor.a = _MainColor.a;
		return finalColor;
		}
			ENDCG
		}
        Pass
        {
			Tags {"LightMode" = "ForwardBase"}
			Cull Back
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "FabricLighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _NormalMap;
			float _NormalScale;
			sampler2D _PBRMap;
			float _Smoothness;
			float _Metallic;
			fixed4 _MainColor;
			sampler2D _NoiseTex;
			float4 _NoiseTex_ST;
			fixed4 _EmissiveColor;

            v2f vert (appdata v)
            {
                v2f o;
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
				float3 worldTangent = normalize(UnityObjectToWorldDir(v.tangent));
				float3 worldBinormal = normalize(cross(worldNormal, worldTangent) * v.tangent.w);
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _NoiseTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 albedo = tex2D(_MainTex, i.uv);
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				float3 normal = _UnpackNormalWithScale(tex2D(_NormalMap, i.uv), _NormalScale);
				float3 worldNormal = float3(dot(normal, i.TtoW0.xyz), dot(normal, i.TtoW1.xyz), dot(normal, i.TtoW2.xyz));
				float3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				half3 pbr = tex2D(_PBRMap, i.uv).rgb;
				half smoothness = pbr.r * _Smoothness;
				half metallic = pbr.g * _Metallic;
				half4 finalColor = 0;
				//half3 color = LambertLighting(albedo, worldNormal, worldViewDir, worldLightDir);
				half3 emissiveColor1 = tex2D(_NoiseTex, i.uv.zw); 
				half3 emissiveColor2 = tex2D(_NoiseTex, i.uv.zw + worldViewDir.xz);
				half3 blingColor = emissiveColor1.r * emissiveColor2.r * _EmissiveColor.rgb;

				half3 color = PBRLighting(albedo.rgb, worldNormal, worldViewDir, worldLightDir, smoothness, metallic, blingColor);
				finalColor.rgb = color;
				finalColor.a = _MainColor.a;
                return finalColor;
            }
            ENDCG
        }
    }
}
