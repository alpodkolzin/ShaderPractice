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
        [HideInInspector] _F0("F0", Range(0,1)) = 0
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
            float4 _MainTex_ST;
            float4 _LightColor0; //Color of directional light source
            float _Gloss;
            float minZeroValue = 0.0001;
            sampler2D _Metallic;
            float _F0;
            sampler2D _Roughness;
            sampler2D _Normals;

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
            float D (float alpha, float3 normal, float3 halfVector)
            {
                float numerator = pow(alpha, 2);
                float NdotH = max(dot(normal, halfVector), 0);
                float denominator = UNITY_PI * pow(pow(NdotH, 2) * (pow(alpha, 2) - 1 ) + 1, 2);
                denominator - max(denominator, minZeroValue);

                return numerator/denominator;
            }

            // Schlick-Beckmann Geometry Shadowing Function
            float G1(float alpha, float3 normal, float3 X)
            {
                float numerator = max(dot(normal, X), 0);
                float k = alpha / 2;
                float denominator = max(dot(normal,X),0) * (1-k) + k;
                denominator = max(denominator, minZeroValue);

                return numerator/denominator;
            }

            //Smith Model
            float G(float alpha, float3 normal, float3 view, float3 light)
            {
                return G1(alpha, normal,view) * G1(alpha, normal,light);
            }

            //Fresnel-Schlick Function
            float3 F(float3 F0, float3 view, float3 halfVector)
            {
                return F0 + (1 - F0) * pow(1 - max(dot(view,halfVector), 0), 5);
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
                float3 normals = mul( mtxTangToWorld, tangentSpaceNormals);

                // V
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.worldPos); //from the surface to the camera

                // L
                //world space direction of directional light | from the source of light
                float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);

                // H
                float3 halfVector = normalize(lightDirection + viewDirection );

                float3 albedo = tex2D(_MainTex, i.uv);

                float roughness = tex2D(_Roughness, i.uv);
                float alpha = pow(roughness, 2);
                float3 emission = 0;

                // implement lazy "F0"
                _F0 = albedo;

                //Calculation

                float3 Ks = F(_F0, viewDirection, halfVector);
                float3 Kd = (float3(1,1,1) - Ks) * (1 - tex2D(_Metallic, i.uv));

                float3 lambert = albedo/ UNITY_PI;

                float3 cookTorranceNumerator = D(alpha, normals, halfVector) * G(alpha, normals, viewDirection, lightDirection) * F(_F0, viewDirection, halfVector);
                float cookTorranceDenominator = 4 * max(dot(viewDirection,normals), 0) * max(dot(lightDirection, normals), 0);

                cookTorranceDenominator = max(cookTorranceDenominator, minZeroValue);
                float3 cookTorrance = cookTorranceNumerator/cookTorranceDenominator;

                float3 BRDF = Kd * lambert + cookTorrance;
                float3 outgoingLight = emission + BRDF * _LightColor0 * max(dot(lightDirection, normals), 0);

                return float4(outgoingLight,1);

            }

            ENDCG
        }
    }
}
