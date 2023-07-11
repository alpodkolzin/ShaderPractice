const float Epsilon = 1e-10;

inline float3 HSVtoRGB(in float3 c)
{
    float4 k = float4(1.0, 0.66, 0.33, 3.0);
    float3 r = c.xxx + k.xyz;
    r = r - floor(r);
    float3 p = abs(r * 6.0 - k.www);
    return c.z * lerp(k.xxx, saturate(p - k.xxx), c.y);
}

inline float3 RGBtoHSV(in float3 c)
{
    float4 k = float4(0.0, -0.33, 0.66, -1.0);
    float4 p = c.g < c.b ? float4(c.bg, k.wz) : float4(c.gb, k.xy);
    float4 q = c.r < p.x ? float4(p.xyw, c.r) : float4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + Epsilon)), d / (q.x + Epsilon), q.x);
}