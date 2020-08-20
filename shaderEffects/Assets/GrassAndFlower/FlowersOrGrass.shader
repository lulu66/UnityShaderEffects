Shader "Unlit/FlowersOrGrass"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_MatCap("MatCap (RGBA),A:EmissionMask", 2D) = "white" {}
		_CutOff("CutOff",Range(0,1)) = 0.5
		[Toggle(USE_WIND)]
		_UseWind("Use Wind",float) = 0
		[Header(WindInfo)]
		_WindNoise("Wind Noise", 2D) = "white" {}
		_NoiseScale("Wind Noise Scale", Float) = 1
		_BaseSwingSpeed("Wind Base Swing Speed", Float) = 1
		_BaseSwingAmplitude("Wind Base Swing Amplitude", Float) = 1
		[Header(GlobalWind)]
		_WindControl("WindControl",vector) = (1,1,1,1)		//xyz:在各个轴上自身的摆动速度 w:摆动强度
		_WaveControl("WaveControl",vector) = (1,1,1,1)		//xyz:在各个轴上风浪的速度 w:控制草叶摆动是整齐还是凌乱，越大越整齐
		[HDR]_EmissiveColor("EmissiveColor", Color) = (0,0,0,0)
	}
	SubShader
	{
		Tags { "Queue" = "AlphaTest" "IgnoreProjector" = "True" "LightMode" = "ForwardBase" }

		Pass
		{
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma shader_feature USE_WIND

			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 color : COLOR;			//r:运动幅度权重 a:alpha
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float3 worldViewDir : TEXCOORD3;
				half2 cap : TEXCOORD4;
				half4 vertColor : TEXCOORD5;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _WindNoise;
			uniform sampler2D _MatCap;
			float _BaseSwingSpeed;
			float _BaseSwingAmplitude;
			float _NoiseScale;
			float4x4 _GlobalWorldBoundToLocalMatrix;
			float4 _GlobalInteractiveInfo;
			float4 _WindControl;
			float4 _WaveControl;
			fixed4 _EmissiveColor;
			half _CutOff;
			UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_DEFINE_INSTANCED_PROP(fixed4, _Color)
			UNITY_INSTANCING_BUFFER_END(Props)

			v2f vert (appdata v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				half weight = v.color.r;

				half3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				half3 worldPosInCollector = worldPos;

				//用世界坐标当作uv
				half2 interactiveTexcoord = mul(worldPosInCollector, _GlobalWorldBoundToLocalMatrix).xz;
				interactiveTexcoord = 0.5 * interactiveTexcoord + 0.5;

				//使用noise
#if USE_WIND
				
				//half noiseInfo = tex2Dlod(_WindNoise, float4(_NoiseScale * interactiveTexcoord + _Time.x * _BaseSwingSpeed, 0, 0)).r;
				//worldPos.xz += noiseInfo * _BaseSwingAmplitude * weight;
				//worldPos.xz += sin(_Time.x * _BaseSwingSpeed) * _BaseSwingAmplitude * weight;
				//half2 wind = _WindDir.xy * sin(_Time.x *  UNITY_PI * _WindSpeed * (_WindDir.x * worldPos.x + _WindDir.y * worldPos.z) / 100);
				//worldPos.xz += wind * _WindForce * weight;
				float2 samplePos = worldPos.xz / _WaveControl.w;
				samplePos += _Time.x * -_WaveControl.xz;
				fixed waveSample = tex2Dlod(_WindNoise, float4(samplePos, 0, 0)).r;
				worldPos.x += sin(waveSample * _WindControl.x) * _WaveControl.x * _WindControl.w * weight;
				worldPos.z += sin(waveSample * _WindControl.z) * _WaveControl.z * _WindControl.w * weight;
#endif
				v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, 1));
				o.worldPos = worldPos;
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldViewDir = UnityWorldSpaceViewDir(worldPos);
				o.pos = mul(UNITY_MATRIX_VP, half4(worldPos, 1));
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.cap = o.worldNormal.xy * 0.5 + 0.5;
				o.vertColor = v.color;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				fixed4 mainColor = tex2D(_MainTex, i.uv);
				clip(mainColor.a - _CutOff);
				fixed4 mc = tex2D(_MatCap, i.cap);
				//half3 worldPos = i.worldPos;
				//half3 worldNormal = normalize(i.worldNormal);
				//return fixed4(worldNormal,1);
				//half3 worldViewDir = normalize(i.worldViewDir);
				//half3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				//half nl = saturate(dot(worldNormal, worldLightDir));
				//half3 ambient = ShadeSH9(half4(worldNormal,1));
				//half3 h = normalize(worldViewDir + worldLightDir);
				//half nh = saturate(dot(h, worldNormal));
				//half3 diffColor = nl * mainColor * _LightColor0.rgb * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
				//half3 specColor = pow(nh, 15) * _LightColor0.rgb;
				half3 diffColor = mainColor.rgb * UNITY_ACCESS_INSTANCED_PROP(Props, _Color) * mc.rgb * 2;//mainColor.rgb * _LightColor0.rgb * UNITY_ACCESS_INSTANCED_PROP(Props, _Color) * nl;
				fixed4 col = 0;
				col.rgb = diffColor; //+ specColor + ambient;
				col.rgb += _EmissiveColor.rgb * mainColor.rgb * mc.a;
				col.a = 1;
				return col;
			}
			ENDCG
		}
	}
}
