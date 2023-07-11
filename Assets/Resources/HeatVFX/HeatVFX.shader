Shader "Entity Recolored" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" { }
        _ExtraValue ("ExtraValue", Range(0.0,1.0)) = 0
        _HighHeat("HighHeat", Color) = (0,0,0,0)
        _LowHeat("LowHeat", Color) = (0,0,0,0)
        _BaseColor("BaseColor", Color) = (0,0,0,0)
        [HideInInspector] _SelectColorHue("_SelectColorHue", Range(0.0,1.0)) = 0.83 // RGB 255,0,255
    }

    SubShader {
        ColorMask RGB

        Blend SrcAlpha OneMinusSrcAlpha

        CGPROGRAM
        #pragma surface surf Lambert
        #include "Utils.cginc"

        sampler2D _MainTex;

        float _ExtraValue;
        float3 _HighHeat;
        float3 _LowHeat;
        float3 _BaseColor;
        float _SelectColorHue;

        struct Input {
            float2 uv_MainTex;
        };

        void surf(Input IN, inout SurfaceOutput o) 
        {
            float4 c = tex2D(_MainTex, IN.uv_MainTex);
            float3 hsv = RGBtoHSV(c);

            if (abs(hsv.x - _SelectColorHue) <= 0.1)
            {
                float saturation = hsv.y * _ExtraValue;
                hsv.y = 0;
                c.rgb = HSVtoRGB(hsv);
                float3 heatColor = lerp(_LowHeat, _HighHeat, pow(saturation, 2));
                c.rgb = lerp(_BaseColor, heatColor, saturation);
            }

            o.Albedo = c.rgb;
            o.Alpha = 1;
        }
        ENDCG
    }
    Fallback "BuildIn/Mobile/VertexLit"
}