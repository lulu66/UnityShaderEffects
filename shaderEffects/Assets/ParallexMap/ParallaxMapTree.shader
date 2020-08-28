Shader "Unlit/ParallaxMapTree"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Tilling("Tilling",float) = 1
		_NormalMap("NormalMap", 2D) = "Bump"{}
		_NormalScale("NormalScale",float) = 1
		_MetallicMap("MetallicMap", 2D) = "white"{}
		_Metallic("Metallic", float) = 1
		_SmoothMap("SmoothMap",2D) = "white"{}
		_Smooth("Smooth", float) = 1
		_OcclusionMap("Occlusion", 2D) = "white"{}
		_HeightMap("HeightMap", 2D) = "white"{}
		_Parallax("Parallax", Range(0,1)) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "UnityPBSLighting.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"
			//struct appdata
			//{
			//	float4 vertex : POSITION;
			//	float4 uv : TEXCOORD0;
			//	float3 normal : NORMAL;
			//	float4 tangent : TANGENT;
			//};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
				//half3 tangentViewDir : TEXCOORD4;
				//half3 tangentLightDir : TEXCOORD5;
				UNITY_SHADOW_COORDS(5)

			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _NormalMap;
			float _NormalScale;
			sampler2D _MetallicMap;
			float _Metallic;
			sampler2D _SmoothMap;
			float _Smooth;
			sampler2D _OcclusionMap;
			sampler2D _HeightMap;
			float4 _HeightMap_ST;
			float _Parallax;
			float _Tilling;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				//o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				//o.uv.zw = TRANSFORM_TEX(v.uv, _HeightMap);
				o.uv = v.texcoord.xy;
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				half3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
				half3 worldTangent = normalize(UnityObjectToWorldDir(v.tangent.xyz));
				half3 worldBinormal = normalize(cross(worldNormal, worldTangent) * v.tangent.w);
				//half3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				half3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.x, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
				//o.tangentViewDir = half3(dot(worldViewDir, worldTangent.xyz), dot(worldViewDir, worldBinormal.xyz), dot(worldViewDir, worldNormal.xyz));
				//o.tangentLightDir = half3(dot(worldLightDir, worldTangent.xyz), dot(worldLightDir, worldBinormal.xyz), dot(worldLightDir, worldNormal.xyz));
				UNITY_TRANSFER_SHADOW(o, v.uv);
				return o;
			}
			
			//普通的视差贴图的方法
			half2 ParallaxMapping(half2 origin_uv, half3 viewDir)
			{
				half2 uv_offset = 0;
				half height = tex2D(_HeightMap, origin_uv).r;
				uv_offset = height * _Parallax * viewDir.xy/viewDir.z;
				return (origin_uv - uv_offset);
			}

			//陡峭视差贴图
			half2 ParallaxMapping2(half2 uv, half3 viewDir)
			{
				//half layerOffset = viewDir.xy / viewDir.z * _Parallax;
				//half2 main_uv = uv * _Tilling.xx;
				half2 heightMap_uv = uv * _HeightMap_ST.xy + _HeightMap_ST.zw;
				half layerNum = 50;//lerp(layerMin, layerMax, 1 - factor);
				half layerHeight = 1 / layerNum;
				half curHeight = 0;
				half heightFromTexture = tex2D(_HeightMap, heightMap_uv).r;
				half2 uv_offset = layerHeight * viewDir.xy / viewDir.z * _Parallax;
				int i = 0;
				while (curHeight < heightFromTexture && i<100)
				{
					curHeight += layerHeight;
					heightMap_uv += uv_offset;
					heightFromTexture = tex2D(_HeightMap, heightMap_uv).r;
					i += 1;
				}

				return heightMap_uv;
			}

			half2 ParallaxMapping3(half2 uv, half3 viewDir)
			{
				half layerOffset = viewDir.xy / viewDir.z * _Parallax;
				half2 main_uv = uv * _Tilling.xx;
				half2 heightMap_uv = uv * _HeightMap_ST.xy + _HeightMap_ST.zw;
				half2 uv_offset1 = (tex2D(_HeightMap, heightMap_uv).r - 1) * layerOffset + main_uv;
				half2 uv_offset2 = (tex2D(_HeightMap, uv_offset1).r - 1) * layerOffset + uv_offset1;
				half2 uv_offset3 = (tex2D(_HeightMap, uv_offset2).r - 1) * layerOffset + uv_offset2;
				half2 uv_offset4 = (tex2D(_HeightMap, uv_offset3).r - 1) * layerOffset + uv_offset3;
				return uv_offset4;
			}

			half2 ParallaxMapping4(half2 uv, half3 viewDir)
			{
				half2 heightMap_uv = uv * _HeightMap_ST.xy + _HeightMap_ST.zw;
				half height = tex2D(_HeightMap, heightMap_uv).r;
				half2 uv_offset = ParallaxOffset(height, _Parallax, viewDir);
				return uv_offset;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float3 worldPos = half3(i.TtoW0.w, i.TtoW1.w,  i.TtoW2.w);
				half3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				half3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				UNITY_LIGHT_ATTENUATION(atten, i, worldPos)
					//half3 tangentLightDir = normalize(i.tangentLightDir);
					//parallax 
			
				half3 tangentViewDir = half3(dot(worldViewDir, float3(i.TtoW0.x, i.TtoW1.x, i.TtoW2.x)), dot(worldViewDir, float3(i.TtoW0.y, i.TtoW1.y, i.TtoW2.y)), dot(worldViewDir, float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z)));//normalize(i.tangentViewDir);
				//tangentViewDir = normalize(tangentViewDir);
				half2 uv_afterOffset = ParallaxMapping2(i.uv, tangentViewDir);
				//half2 uv = i.uv;
				half2 uv = uv_afterOffset;
				fixed4 albedo = tex2D(_MainTex, uv);
				half3 normal = UnpackNormal(tex2D(_NormalMap, uv)).xyz;
				half3 worldNormal = normalize(half3(dot(i.TtoW0.xyz, normal), dot(i.TtoW1.xyz, normal), dot(i.TtoW2.xyz, normal)));
				half metallic = tex2D(_MetallicMap, uv).r + (1 - _Metallic);
				half smooth = tex2D(_SmoothMap, uv).r * _Smooth;
				half occlusion = tex2D(_OcclusionMap, uv).r;
				fixed4 c = 0;
				//half nl = saturate(dot(normal, tangentLightDir));
				//half3 diffcolor = nl * _LightColor0.rgb * albedo.rgb;
				SurfaceOutputStandard o;
				o.Albedo = albedo.rgb;
				o.Emission = 0.0;
				o.Alpha = albedo.a;
				o.Occlusion = occlusion;
				o.Normal = worldNormal;
				o.Metallic = metallic;
				o.Smoothness = smooth;

				UnityGI gi;
				UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
				gi.indirect.diffuse = 0;
				gi.indirect.specular = 0;
				gi.light.color = _LightColor0.rgb;
				gi.light.dir = worldLightDir;

				UnityGIInput giInput;
				UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
				giInput.light = gi.light;
				giInput.worldPos = worldPos;
				giInput.worldViewDir = worldViewDir;
				giInput.atten = atten;
				giInput.lightmapUV = 0.0;
				giInput.ambient.rgb = 0.0;

				#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
				giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
				#endif
				#ifdef UNITY_SPECCUBE_BOX_PROJECTION
				giInput.boxMax[0] = unity_SpecCube0_BoxMax;
				giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
				giInput.boxMax[1] = unity_SpecCube1_BoxMax;
				giInput.boxMin[1] = unity_SpecCube1_BoxMin;
				giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
				#endif

				LightingStandard_GI(o, giInput, gi);
				c = LightingStandard(o, worldViewDir, gi);
				//c.rgb = diffcolor;
				c.a = albedo.a;

				return c;
			}
			ENDCG
		}
	}
	Fallback "Mobile/VertexLit"
}



