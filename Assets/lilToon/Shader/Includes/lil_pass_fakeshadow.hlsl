#ifndef LIL_PASS_FAKESHADOW_INCLUDED
#define LIL_PASS_FAKESHADOW_INCLUDED

#include "Includes/lil_pipeline.hlsl"

float4 _FakeShadowVector;

//------------------------------------------------------------------------------------------------------------------------------
// Struct
struct v2f
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    LIL_FOG_COORDS(1)
    #if defined(LIL_HDRP) || defined(LIL_V2F_FORCE_POSITION_WS)
        float3 positionWS : TEXCOORD2;
    #endif
    LIL_VERTEX_INPUT_INSTANCE_ID
    LIL_VERTEX_OUTPUT_STEREO
};

//------------------------------------------------------------------------------------------------------------------------------
// Shader
v2f vert(appdata input)
{
    v2f output;
    LIL_INITIALIZE_STRUCT(v2f, output);

    LIL_BRANCH
    if(_Invisible) return output;

    LIL_SETUP_INSTANCE_ID(input);
    LIL_TRANSFER_INSTANCE_ID(input, output);
    LIL_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    //------------------------------------------------------------------------------------------------------------------------------
    // Encryption
    #if defined(LIL_FEATURE_ENCRYPTION)
        input.positionOS = vertexDecode(input.positionOS, input.normalOS, input.uv6, input.uv7);
    #endif

    LIL_VERTEX_POSITION_INPUTS(input.positionOS, vertexInput);
    #if defined(LIL_HDRP)
        LIL_VERTEX_NORMAL_INPUTS(input.normalOS, vertexNormalInput);
        LIL_GET_HDRPDATA(vertexInput);
        float3 lightColor;
        float3 lightDirection;
        lilGetLightDirectionAndColor(lightDirection, lightColor, posInput, renderingLayers, featureFlags);
        lightDirection = normalize(lightDirection * Luminance(lightColor) + unity_SHAr.xyz * 0.333333 + unity_SHAg.xyz * 0.333333 + unity_SHAb.xyz * 0.333333 + float3(0.0,0.001,0.0));
        output.positionWS = vertexInput.positionWS;
    #else
        float3 lightDirection = normalize(lilGetLightDirection() + _FakeShadowVector.xyz);
    #endif
    float2 lightShift = mul((float3x3)LIL_MATRIX_VP, lightDirection * _FakeShadowVector.w).xy;
    output.positionCS = vertexInput.positionCS;
    output.positionCS.xy -= lightShift.xy;
    output.uv = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    LIL_TRANSFER_FOG(vertexInput, output);

    return output;
}

float4 frag(v2f input) : SV_Target
{
    LIL_SETUP_INSTANCE_ID(input);
    LIL_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    LIL_GET_HDRPDATA(input);
    #if defined(LIL_HDRP)
        float3 viewDirection = normalize(LIL_GET_VIEWDIR_WS(input.positionWS.xyz));
    #endif
    float4 col = LIL_SAMPLE_2D(_MainTex, sampler_MainTex, input.uv);
    col *= _Color;
    float4 fogColor = float4(1,1,1,1);
    LIL_APPLY_FOG_COLOR(col, input.fogCoord, fogColor);
    return col;
}

#endif