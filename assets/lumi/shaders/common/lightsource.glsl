#include frex:shaders/lib/math.glsl
#include frex:shaders/api/world.glsl
#include frex:shaders/api/player.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/lighting.glsl

/*******************************************************
 *  lumi:shaders/common/lightsource.glsl               *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo, Contributors   *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

/*  DIRECTIONS
 *******************************************************/

#define l2_skylessDarkenedDir() vec3(0, -0.977358, 0.211593)
#define l2_skylessDir() vec3(0, 0.977358, 0.211593)

/*  MULTIPLIERS
 *******************************************************/

float l2_lightmapRemap(float lightMapCoords)
{
    return hdr_fromGammaf(l2_clampScale(0.03125, 0.96875, lightMapCoords));
}

/*  RADIANCE
 *******************************************************/

vec3 l2_blockRadiance(float blockLight)
{
    float bl = smoothstep(0.03125, 0.96875, blockLight);
    float brightness = frx_viewBrightness();

    bl *= pow(bl, 3.0 + brightness * 2.0) * (2.0 - brightness * 0.5); // lyfe hax

    return BLOCK_LIGHT_COLOR * BLOCK_LIGHT_STR * bl;
}

#if HANDHELD_LIGHT_RADIUS != 0
vec3 l2_handHeldRadiance(vec3 viewPos)
{
    vec4 heldLight = frx_heldLight();
    float distSq = dot(viewPos, viewPos);
    float hlRadSq = heldLight.w * HANDHELD_LIGHT_RADIUS * heldLight.w * HANDHELD_LIGHT_RADIUS;
    float hl = l2_clampScale(hlRadSq, 0.0, distSq);
    float brightness = frx_viewBrightness();

    hl *= pow(hl, 3.0 + brightness * 2.0) * (2.0 - brightness * 0.5); // lyfe hax

    return hdr_fromGamma(heldLight.rgb) * BLOCK_LIGHT_STR * hl;
}
#endif

vec3 l2_emissiveRadiance(vec3 hdrFragColor, float emissivity)
{
    return hdrFragColor * hdr_fromGammaf(emissivity) * EMISSIVE_LIGHT_STR;
}

vec3 l2_baseAmbientRadiance()
{
    if (frx_playerHasNightVision()) return hdr_fromGamma(NIGHT_VISION_COLOR) * NIGHT_VISION_STR;
    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) {
        #ifdef TRUE_DARKNESS_DEFAULT
            return vec3(0.0);
        #else
            return vec3(BASE_AMBIENT_STR);
        #endif
    } else {
        #ifdef TRUE_DARKNESS_NETHER
            if(frx_isSkyDarkened()){
                return vec3(0.0);
            }
        #endif
        #ifdef TRUE_DARKNESS_END
            if(!frx_isSkyDarkened()){
                return vec3(0.0);
            }
        #endif
        vec3 dimensionColor = hdr_fromGamma(vec3(0.8, 0.7, 1.0));
        // THE NETHER
        if (frx_isWorldTheNether()) {
            float min_col = l2_min3(frx_vanillaClearColor());
            float max_col = l2_max3(frx_vanillaClearColor());
            float sat = 0.0;
            if (max_col != 0.0) sat = (max_col-min_col)/max_col;
            dimensionColor = hdr_fromGamma(clamp((frx_vanillaClearColor()*(1/max_col))+pow(sat,2)/2, 0.0, 1.0));
        }
        return dimensionColor * SKYLESS_AMBIENT_STR;
    }
}

// vec3 l2_sunRadiance(float skyLight, in float time, float rainGradient, float thunderGradient)
// {
//         // direct sun light doesn't reach into dark spot as much as sky ambient // TODO: WAT
//         sl = l2_clampScale(0.7, 0.97, sl);
// }

vec3 l2_skylessRadiance()
{
    #ifdef TRUE_DARKNESS_NETHER
        if (frx_isSkyDarkened()) return vec3(0.0);
    #endif
    #ifdef TRUE_DARKNESS_END
        if (!frx_isSkyDarkened()) return vec3(0.0);
    #endif
    if (frx_worldFlag(FRX_WORLD_HAS_SKYLIGHT)) return vec3(0);
    else {
        vec3 color = frx_worldFlag(FRX_WORLD_IS_NETHER) ? NETHER_SKYLESS_LIGHT_COLOR : SKYLESS_LIGHT_COLOR;
        float darkenedFactor = frx_isSkyDarkened() ? 0.6 : 1.0;
        return darkenedFactor * SKYLESS_LIGHT_STR * hdr_fromGamma(color);
    }
}
