#ifndef FABRIC_LIGHTING_H
#define FABRIC_LIGHTING_H

#include "UnityCG.cginc"
#include "UnityStandardBRDF.cginc"
//inputs
float _FabricScatterScale;
fixed4 _FabricScatterColor;
float _SpecularScale;


half3 _UnpackNormalWithScale(half4 packedNormal, half normalScale)
{
	half3 normal = UnpackNormal(packedNormal);
	half3 unpackedNormal;
	unpackedNormal.xy = (normal.xy * 2 - 1) * normalScale;
	unpackedNormal.z = sqrt(1 - dot(unpackedNormal.xy, unpackedNormal.xy));
	return unpackedNormal;
}

half3 FabricDiffuseTerm(half3 diffColor, float diffuseTerm, float nl)
{
	half3 fd = 0;
	float wrap = saturate((nl + _FabricScatterScale) / (1 + _FabricScatterScale) * (1 + _FabricScatterScale));
	diffuseTerm *= wrap;
	fd = diffColor * _LightColor0.rgb * diffuseTerm * saturate(_FabricScatterColor + nl);
	return fd;
}

//布料的法线分布项，法一
float D_Ashikhmin(float roughness, float nh)
{
	float a2 = roughness * roughness;
	float cos2h = nh * nh;
	float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
	float sin4h = sin2h * sin2h;
	float cot2 = -cos2h / (a2 * sin2h);
	return 1.0 / (UNITY_PI * (4.0 * a2 + 1.0) * sin4h) * (4.0 * exp(cot2) + sin4h);
}

//布料的法线分布项，法二
float D_Charlie(float roughness, float nh)
{
	float invAlpha = 1.0 / roughness;
	float cos2h = nh * nh;
	float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
	return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * UNITY_PI);
}

//布料的G项
float VisibilityCloth(float nl, float nv, float roughness)
{
	return  1 / (4 * (nl + nv - nl*nv) + 1e-5f);
}

half3 LambertLighting(float3 albedo, float3 worldNormal, float3 worldViewDir, float3 worldLightDir)
{
	half nl = saturate(dot(worldNormal, worldLightDir));
	half3 diffColor = nl * _LightColor0.rgb * albedo;
	return diffColor;
}

half3 BRDF(half3 diffColor, half3 specColor, half oneMinusReflectivity, half3 worldNormal, float3 worldViewDir, float3 worldLightDir, float smoothness, half3 blingColor)
{
	float3 halfDir = Unity_SafeNormalize(worldLightDir + worldViewDir);

	half nl = saturate(dot(worldNormal, worldLightDir));
	float nh = saturate(dot(worldNormal, halfDir));
	half nv = saturate(dot(worldNormal, worldViewDir));
	float lh = saturate(dot(worldLightDir, halfDir));

	half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	//specular term
	half a = roughness;
	float a2 = a*a;

	float d = nh * nh * (a2 - 1.f) + 1.00001f;
	#ifdef UNITY_COLORSPACE_GAMMA
	float specularTerm = a / (max(0.32f, lh) * (1.5f + roughness) * d);
	#else
	float specularTerm = a2 / (max(0.1f, lh*lh) * (roughness + 0.5f) * (d * d) * 4);
	#endif

	#if defined (SHADER_API_MOBILE)
	specularTerm = specularTerm - 1e-4f;
	#endif

	#if defined (SHADER_API_MOBILE)
	specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
	#endif

	#ifdef UNITY_COLORSPACE_GAMMA
	half surfaceReduction = 0.28;
	#else
	half surfaceReduction = (0.6 - 0.08*perceptualRoughness);
	#endif
	surfaceReduction = 1.0 - roughness*perceptualRoughness*surfaceReduction;
	half grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
	half3 color = (diffColor + specularTerm * specColor * blingColor) * _LightColor0.rgb * nl
		/*+ gi.diffuse * diffColor*/
		+ surfaceReduction /** gi.specular*/ * FresnelLerpFast(specColor, grazingTerm, nv);
	return color;
}


half3 Cloth_BRDF(half3 diffColor, half3 specColor, half oneMinusReflectivity, half3 worldNormal, float3 worldViewDir, float3 worldLightDir, float smoothness)
{
	float3 halfDir = Unity_SafeNormalize(worldLightDir + worldViewDir);

	half nl = saturate(dot(worldNormal, worldLightDir));
	float nh = saturate(dot(worldNormal, halfDir));
	half nv = saturate(dot(worldNormal, worldViewDir));
	float lh = saturate(dot(worldLightDir, halfDir));

	half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
	half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	roughness = max(roughness, 0.002);
	half disneyDiffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness);
	//diffuseTerm添加此表面散射
	half3 fabricDiffColor = FabricDiffuseTerm(diffColor, disneyDiffuseTerm, nl);

	//接下来是高光项（Cloth没有G项）
	half D = D_Charlie(roughness, nh);
	half V = VisibilityCloth(nl, nv, roughness);
#ifdef USE_LUMINANCE
	half luminance = dot(diffColor, half3(0.299, 0.587, 0.114));
	half F = luminance;
#else
	half3 F = specColor;
#endif
	//可不适用F项，没啥大的差别
	half specTerm = D * V  *_SpecularScale;
	specTerm = max(0, specTerm * nl);
	half3 color;
	color = fabricDiffColor + specTerm * _LightColor0.rgb;
	return color;
}

half3 PBRLighting(float3 albedo, float3 worldNormal, float3 worldViewDir, float3 worldLightDir, float smoothness, float metallic, half3 blingColor)
{
	//漫反射率：金属度越高，漫反射率越小，高光反射率越大
	half oneMinusReflectivity;
	half3 albedoColor;		//漫反射颜色
	half3 specColor;		//高光反射颜色
	//按照金属度对高光反射颜色进行插值，如果金属度=1，则光线全部吸收，反射出来的都是albedo的颜色
	specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
	oneMinusReflectivity = unity_ColorSpaceDielectricSpec.a * (1 - metallic);
	albedoColor = oneMinusReflectivity * albedo;
	half3 color = BRDF(albedoColor, specColor, oneMinusReflectivity, worldNormal, worldViewDir, worldLightDir, smoothness, blingColor);
	return color;
}

half3 PBRFabricLighting(float3 albedo, float3 worldNormal, float3 worldViewDir, float3 worldLightDir, float smoothness, float metallic)
{
	//漫反射率：金属度越高，漫反射率越小，高光反射率越大
	half oneMinusReflectivity;
	half3 albedoColor;		//漫反射颜色
	half3 specColor;		//高光反射颜色
							//按照金属度对高光反射颜色进行插值，如果金属度=1，则光线全部吸收，反射出来的都是albedo的颜色
	specColor = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
	oneMinusReflectivity = unity_ColorSpaceDielectricSpec.a * (1 - metallic);
	albedoColor = oneMinusReflectivity * albedo;
	half3 color = Cloth_BRDF(albedoColor, specColor, oneMinusReflectivity, worldNormal, worldViewDir, worldLightDir, smoothness);
	return color;
}

#endif