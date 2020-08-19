Shader "Unlit/FlowersOrGrass"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_MatCap("MatCap (RGB)", 2D) = "white" {}
		[Header(WindInfo)]
		_WindNoise("Wind Noise", 2D) = "white" {}
		_NoiseScale("Wind Noise Scale", Float) = 1
		_BaseSwingSpeed("Wind Base Swing Speed", Float) = 1
		_BaseSwingAmplitude("Wind Base Swing Amplitude", Float) = 1
	}
	SubShader
	{
		Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "LightMode" = "ForwardBase" }

		Pass
		{
			Cull Off
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 color : COLOR;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float3 worldView : TEXCOORD3;
				half2 cap : TEXCOORD4;
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

			UNITY_INSTANCING_BUFFER_START(Props)
				UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
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
				half noiseInfo = tex2Dlod(_WindNoise, float4(_NoiseScale * interactiveTexcoord + _Time.x * _BaseSwingSpeed, 0, 0)).r;
				//worldPos.xz += noiseInfo * _BaseSwingAmplitude * weight;

				v.vertex = mul(unity_WorldToObject, float4(worldPos.xyz, 1));
				float3 worldNorm = normalize(unity_WorldToObject[0].xyz * v.normal.x + unity_WorldToObject[1].xyz * v.normal.y + unity_WorldToObject[2].xyz * v.normal.z);
				o.worldNormal = worldNorm;
				o.pos = mul(UNITY_MATRIX_VP, half4(worldPos, 1));
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.cap.xy = worldNorm.xy * 0.5 + 0.5;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				fixed4 mc = tex2D(_MatCap, i.cap);
				fixed4 col = tex2D(_MainTex, i.uv) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color) * mc * 2;
				return col;
			}
			ENDCG
		}
	}
}
