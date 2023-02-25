// PBR shader
// commont traits
// energy conservation
// microfacet model
// fresnel effect

Shader "Custom/PBR"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _Normals ("Normals", 2D) = "bump" {}
        _Roughness("Roughness", 2D) = "black" {}
        _Metallic("Metallic", 2D) = "black" {}
         // parameter that differs from material to material https://google.github.io/filament/Filament.html#table_fnormalmetals
        _FresnelReflectance("FresnelReflectance", Color) = (0,0,0)
        _AmbientOcclusion("AmbientOcclusion", 2D) = "gray" {}
        _IBLTexture("IBLTexture", 2D) = "black" {}
        _IBLStrength("IBLStrength", Range(0,1)) = 0.5
        _IBLBRDFLUT("IBLBRDFLUT", 2D) = "black" {}
        _MaxReflectionLOD("MaxReflectionLOD", Range(0,10)) = 7
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        // First pass will be ALWAYS Directional light
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            #define TAU 6.28318530718

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT; //xyz - tangent direction, w = tangent sign
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;

                float3 tangent : TEXCOORD3;
                float3 biTangent : TEXCOORD4;
            };

            sampler2D _MainTex;
            sampler2D _Metallic;
            sampler2D _Roughness;
            sampler2D _Normals;
            sampler2D _AmbientOcclusion;
            sampler2D _IBLTexture;
            sampler2D _IBLBRDFLUT;

            float4 _MainTex_ST;
            float4 _LightColor0; //Color of directional light source
            float3 _FresnelReflectance;
            float _IBLStrength;
            float _MaxReflectionLOD;

            float minZeroValue = 0.0001;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                // we need this to be rotatable and not stuck to the rotation & position
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.biTangent = cross(o.normal, o.tangent);
                o.biTangent *= v.tangent.w * unity_WorldTransformParams.w; // handle flipping and scaling

                return o;
            }

            //rules
            // NO negative dot products -> max(dot(X,Y), 0);
            // maybe can be replaced with saturate
            // NO division by zero -> X / max(Y,0.000001);

            // GGX/Trowbridge-Teitz Normal Distribution Function
            float NDF (float alpha, float NdotH)
            {
                float numerator = pow(alpha, 2);
                float denominator = UNITY_PI * pow(pow(NdotH, 2) * (pow(alpha, 2) - 1 ) + 1, 2);
                denominator = max(denominator, minZeroValue);

                return numerator/denominator;
            }

            // Schlick-Beckmann Geometry Shadowing Function
            float G1(float alpha, float cosTheta)
            {
                float numerator = cosTheta;
                float k = alpha / 2;
                float denominator = cosTheta * (1-k) + k;
                denominator = max(denominator, minZeroValue);

                return numerator/denominator;
            }

            //Smith Model
            float G(float alpha, float NdotV, float NdotL)
            {
                return G1(alpha, NdotV) * G1(alpha, NdotL);
            }

            //Fresnel-Schlick Function
            float3 F(float3 F0, float3 normals, float3 halfVector)
            {
                return F0 + (1 - F0) * pow(1 - max(dot(normals ,halfVector), 0), 5);
            }

            //Fresnel-Schlick Function From Roughness
            float3 FRoughness(float cosTheta, float F0, float roughness)
            {
                return F0 + (max(1.0 - roughness, F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
            }

            //Calcualte from normal direction to Equirectangular
            float2 DirToEquirectangular(float3 dir)
            {
                float x = atan2(dir.z, dir.x) / TAU + 0.5;
                float y = dir.y * 0.5 + 0.5;
                return float2(x,y);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //variables

                // N
                // we need to normalize normals, because they are interpolated between vertexes and it can result in some strange shading
                float3 tangentSpaceNormals = UnpackNormal(tex2D(_Normals, i.uv));
                float3x3 mtxTangToWorld = {
                    i.tangent.x, i.biTangent.x, i.normal.x,
                    i.tangent.y, i.biTangent.y, i.normal.y,
                    i.tangent.z, i.biTangent.z, i.normal.z
                };

                float3 normals = normalize(mul( mtxTangToWorld, tangentSpaceNormals));

                // V
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.worldPos); //from the surface to the camera

                // L
                //world space direction of directional light | from the source of light
                float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);

                // H
                float3 halfVector = normalize(lightDirection + viewDirection);

                float3 albedo = tex2D(_MainTex, i.uv);
                float roughness = tex2D(_Roughness, i.uv);
                float alpha = pow(roughness, 2);
                float3 emission = 0;
                float metallic = tex2D(_Metallic, i.uv);

                // option: lazy F0
                // float3 _F0 = albedo;
                // implement F0 calculation from https://google.github.io/filament/Filament.html#listing_fnormal
                float3 F0 = 0.16 * pow(_FresnelReflectance, 2) * (1.0 - metallic) + albedo * metallic;

                //-----------
                // Common variables 
                //-----------

                float NdotH = max(dot(normals, halfVector), 0);
                float NdotV = max(dot(normals, viewDirection), 0);
                float NdotL = max(dot(normals, lightDirection), 0);

                //-----------
                // IBL Calculation
                //-----------

                float3 KsIBL = FRoughness(NdotV, F0, roughness); 
                float3 KdIBL = 1.0 - KsIBL;
                float3 diffuseIBL = tex2Dlod(_IBLTexture, float4(DirToEquirectangular(normals), _MaxReflectionLOD.xx));

                float3 viewReflection = reflect(-viewDirection,normals);

                float mipLevel = roughness * _MaxReflectionLOD;
                float3 specularIBL = tex2Dlod(_IBLTexture, float4(DirToEquirectangular(viewReflection), mipLevel, mipLevel));
;
                float2 envBRDF  = tex2D(_IBLBRDFLUT, float2(NdotV, roughness)).rg;
                float3 specular = specularIBL * (KsIBL * envBRDF.x + envBRDF.y);
                float3 ambient = (KdIBL * diffuseIBL * albedo + specular) * tex2D(_AmbientOcclusion, i.uv) * _IBLStrength;

                //-----------
                // Base Calculation
                //-----------

                float3 Ks = F(F0, normals, halfVector);
                float3 Kd = (1 - Ks) * (1 - metallic);

                // note: Energy conservation "Fix"
                // More to read;
                // https://docs.google.com/document/d/1ZLT1-fIek2JkErN9ZPByeac02nWipMbO89oCW2jxzXo/edit -- why 1.0-kS fucks up microfacet models
                // https://ubm-twvideo01.s3.amazonaws.com/o1/vault/gdc2017/Presentations/Hammon_Earl_PBR_Diffuse_Lighting.pdf -- normalization factor, good ggx approx for diffuse
                //
                // lambert *= 1.0 - F(_F0, normals, lightDirection); //Incoming light
                // lambert *= 1.0 - F(_F0, normals, viewDirection); //Outgoing light
                // lambert *= 1.05 * (1.0 - _F0);

                float3 cookTorranceNumerator = NDF(alpha, NdotH) * G(alpha, NdotV, NdotL) * Ks;
                float cookTorranceDenominator = 4 * NdotV * NdotL;
                cookTorranceDenominator = max(cookTorranceDenominator, minZeroValue);
                float3 cookTorrance = max(cookTorranceNumerator/cookTorranceDenominator, minZeroValue); // HACK: without max created black "non additive shadow"

                float3 BRDF = Kd * albedo / UNITY_PI + cookTorrance;
                float3 outgoingLight = emission + BRDF * _LightColor0 * NdotL;
                outgoingLight += ambient;

                return float4(outgoingLight,1);

            }

            ENDCG
        }
    }
}
