// specular shader
Shader "Custom/SpecularPhong"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Gloss ("Gloss", float) = 1
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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _LightColor0; //Color of directional light source
            float _Gloss;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);;

                // we need this to be rotatable and not stuck to the rotation & position
                o.normal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //world space direction of directional light | from the source of light
                float3 lightDirection = _WorldSpaceLightPos0.xyz;
                float3 normals = normalize(i.normal); // we need to normalize normals, because they are interpolated between vertexes and it can result in some strange shading
                float4 diffuseLight = saturate(dot(lightDirection, normals) * _LightColor0); // saturate == max(0,x)

                //specular lighting part
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.worldPos); //from the surface to the camera
                float3 reflectedVector = reflect(-lightDirection, normals);
                float reflectionLight = saturate(dot(viewDirection, reflectedVector));
                reflectionLight = saturate(pow(reflectionLight, _Gloss));

                return tex2D(_MainTex, i.uv) * diffuseLight + reflectionLight;
            }
            ENDCG
        }
    }
}
