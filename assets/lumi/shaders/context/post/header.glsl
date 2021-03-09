#version 130
#extension GL_EXT_gpu_shader4 : enable

#define POST_SHADER

#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/tonemap.glsl
#include lumi:shaders/context/global/lighting.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/view.glsl

#define VERTEX_SHADER

/*******************************************************
 *  lumi:shaders/context/post/header.glsl              *
 *******************************************************/

uniform ivec2 frxu_size;
uniform int frxu_lod;
varying vec2 v_texcoord;
varying vec3 v_skycolor;
varying vec3 v_up;

#ifdef VERTEX_SHADER
// const vec3 day_sky = vec3(0.52, 0.69, 1.0);
// const vec3 day_fog = vec3(0.75, 0.84375, 1.0);

vec3 hdr_skyColor()
{
    vec3 skyColor;
    bool customOverworldColor =
        frx_worldFlag(FRX_WORLD_IS_OVERWORLD)
        && !frx_viewFlag(FRX_CAMERA_IN_FLUID);

    if (customOverworldColor) {
        #ifdef TRUE_DARKNESS_MOONLIGHT
            const vec3 ngtc = vec3(0.0);
        #else
            const vec3 ngtc = NIGHT_SKY_COLOR;
        #endif
        const vec3 dayc = DAY_SKY_COLOR;

        const int len = 4;
        const vec3 colors[len] =  vec3[](dayc, ngtc, ngtc, dayc);
        const float times[len] = float[](0.50, 0.52, 0.98, 1.0);

        if (frx_worldTime() <= times[0]) {
            skyColor = colors[0];
        } else {
            int i = 1;
            while (frx_worldTime() > times[i] && i < len) i++;
            skyColor = mix(colors[i-1], colors[i], l2_clampScale(times[i-1], times[i], frx_worldTime()));
        }

        float thunderFactor = frx_rainGradient() *0.5 + frx_thunderGradient() *0.5;
        skyColor *= (1.0 - thunderFactor * 0.9);
        vec3 grayScale = vec3(frx_luminance(skyColor));
        skyColor = mix(skyColor, grayScale, thunderFactor);
    } else {
        skyColor = hdr_gammaAdjust(frx_vanillaClearColor());
    }

    // vec3 grayScale = vec3(frx_luminance(skyColor));
    // skyColor = mix(skyColor, grayScale, frx_viewFlag(FRX_CAMERA_IN_WATER) ? 0.5 : 0.0);
    
    return skyColor;
}

vec3 ldr_skyColor()
{
    return ldr_tonemap3(hdr_skyColor());
}
#else
vec3 hdr_orangeSkyColor(vec3 original, vec3 viewDir) {
    bool customOverworldOrange =
        frx_worldFlag(FRX_WORLD_IS_OVERWORLD)
        && !frx_viewFlag(FRX_CAMERA_IN_FLUID)
        && !frx_worldFlag(FRX_WORLD_IS_MOONLIT);
    if (customOverworldOrange) {
        float vDotSun = l2_clampScale(0.0, -1.0, dot(viewDir, frx_normalModelMatrix()*frx_skyLightVector()));
        float sunHorizonFactor = l2_clampScale(0.5 /*BRUTE FORCED NUMBER*/, 0.0, frx_skyLightVector().y);
        return mix(original, ORANGE_SKY_COLOR, sunHorizonFactor * vDotSun * frx_skyLightTransitionFactor());
    } else {
        return original;
    }
}
#endif
