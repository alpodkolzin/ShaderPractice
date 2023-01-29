Shader "Custom/Diffuse"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _LightColor0; //Color of directional light source

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // we need this to be rotatable and not stuck to the rotation & position
                o.normal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //world space direction of directional light | from the source of light
                float3 lightDirection = _WorldSpaceLightPos0.xyz;
                float3 diffuseLight = saturate(dot(lightDirection, i.normal)) * _LightColor0; // saturate == max(0,x) 

                return tex2D(_MainTex, i.uv) * float4(diffuseLight, 1);
            }
            ENDCG
        }
    }
}
