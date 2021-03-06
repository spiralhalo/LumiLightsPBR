#include frex:shaders/lib/math.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/common/userconfig.glsl

/*******************************************************
 *  lumi:shaders/common/contrast.glsl                  *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo, Contributors   *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

// PROFILE-AGNOSTIC
// ******************************

    // STRENGTHS
    #define _0_BASE_AMBIENT_STR 0.1
    #define _0_SKYLESS_AMBIENT_STR 0.5
    #define _0_SKYLESS_LIGHT_STR 1.0
    #define _0_BLOCK_LIGHT_STR 1.5
    #define _0_EMISSIVE_LIGHT_STR 1.0
    const float NIGHT_VISION_STR = 1.5;

    // ATMOS STRENGTHS
    #define DEF_SUNLIGHT_STR 1.5
    #define DEF_SKY_STR 0.5
    #define DEF_SKY_AMBIENT_STR 0.5
    #define _0_DEF_MOONLIGHT_STR 0.25

    // ATMOS COLORS
    #define _0_DEF_NIGHT_AMBIENT vec3(0.65, 0.65, 0.8)

    // LIGHT COLORS
#if BLOCK_LIGHT_MODE == BLOCK_LIGHT_MODE_NEUTRAL
    const vec3 BLOCK_LIGHT_COLOR = hdr_fromGamma(vec3(0.7555)); // luminance of warm BL color
#else
    const vec3 BLOCK_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 0.7, 0.4));
#endif
    const vec3 NIGHT_VISION_COLOR = hdr_fromGamma(vec3(1.0, 0.95, 1.0));
    const vec3 SKYLESS_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 1.0, 1.0));
    const vec3 NETHER_SKYLESS_LIGHT_COLOR = hdr_fromGamma(vec3(1.0, 0.9, 0.8));

    // SKY COLORS
    #define _0_DEF_NEBULAE_COLOR vec3(0.8, 0.3, 0.6)
    #define _0_LUMI_NIGHT_SKY_COLOR vec3(0.1, 0.1, 0.2)
    #define DEF_VANILLA_DAY_SKY_COLOR hdr_fromGamma(vec3(0.52, 0.69, 1.0))
#if SKY_MODE == SKY_MODE_LUMI

    #if LUMI_SKY_COLOR == LUMI_SKY_COLOR_BRIGHT_CYAN
        #define DEF_DAY_SKY_COLOR hdr_fromGamma(vec3(0.33, 0.7, 1.0))
        #define DEF_DAY_CLOUD_COLOR hdr_fromGamma(vec3(0.40, 0.69, 1.0))
    #else
        #define DEF_DAY_SKY_COLOR hdr_fromGamma(vec3(0.3, 0.5, 1.0))
        #define DEF_DAY_CLOUD_COLOR DEF_VANILLA_DAY_SKY_COLOR
    #endif

#else

    #define DEF_DAY_SKY_COLOR DEF_VANILLA_DAY_SKY_COLOR
    #define DEF_DAY_CLOUD_COLOR DEF_VANILLA_DAY_SKY_COLOR

#endif

// PROFILE-BASED
// ******************************

#ifdef HIGH_CONTRAST_ENABLED

    #define HIGH_CONTRAST_EXPOSURE 5.0
    #define getExposure(eyeBrightness) mix(HIGH_CONTRAST_EXPOSURE, 1.0, eyeBrightness)
    #define MOON_EXPOSURE getExposure(1.0 / DEF_SUNLIGHT_STR) // MAGIC NUMBER, HARD TO COMPUTE (recursive?)

    // STRENGTHS
    const float BASE_AMBIENT_STR = _0_BASE_AMBIENT_STR / HIGH_CONTRAST_EXPOSURE;
    const float SKYLESS_AMBIENT_STR = _0_SKYLESS_AMBIENT_STR / HIGH_CONTRAST_EXPOSURE;
    const float SKYLESS_LIGHT_STR = _0_SKYLESS_LIGHT_STR / HIGH_CONTRAST_EXPOSURE;
    const float BLOCK_LIGHT_STR = _0_BLOCK_LIGHT_STR / HIGH_CONTRAST_EXPOSURE;
    const float EMISSIVE_LIGHT_STR = _0_EMISSIVE_LIGHT_STR / HIGH_CONTRAST_EXPOSURE;

    // ATMOS STRENGTHS
    #define DEF_MOONLIGHT_STR _0_DEF_MOONLIGHT_STR / HIGH_CONTRAST_EXPOSURE

    // ATMOS COLORS
    #define DEF_NIGHT_AMBIENT _0_DEF_NIGHT_AMBIENT / MOON_EXPOSURE

    // SKY_COLORS
    #define DEF_NEBULAE_COLOR _0_DEF_NEBULAE_COLOR / MOON_EXPOSURE
    #define LUMI_NIGHT_SKY_COLOR _0_LUMI_NIGHT_SKY_COLOR / MOON_EXPOSURE

#else

    // STRENGTHS
    const float BASE_AMBIENT_STR = _0_BASE_AMBIENT_STR;
    const float SKYLESS_AMBIENT_STR = _0_SKYLESS_AMBIENT_STR;
    const float SKYLESS_LIGHT_STR = _0_SKYLESS_LIGHT_STR;
    const float BLOCK_LIGHT_STR = _0_BLOCK_LIGHT_STR;
    const float EMISSIVE_LIGHT_STR = _0_EMISSIVE_LIGHT_STR;

    // ATMOS STRENGTHS
    #define DEF_MOONLIGHT_STR _0_DEF_MOONLIGHT_STR

    // ATMOS COLORS
    #define DEF_NIGHT_AMBIENT _0_DEF_NIGHT_AMBIENT

    // SKY_COLORS
    #define DEF_NEBULAE_COLOR _0_DEF_NEBULAE_COLOR
    #define LUMI_NIGHT_SKY_COLOR _0_LUMI_NIGHT_SKY_COLOR

#endif

    // SKY COLORS
#if SKY_MODE == SKY_MODE_LUMI

    #define DEF_NIGHT_SKY_COLOR hdr_fromGamma(LUMI_NIGHT_SKY_COLOR)
    const vec3 NEBULAE_COLOR = hdr_fromGamma(DEF_NEBULAE_COLOR);

#else

    #define DEF_NIGHT_SKY_COLOR hdr_fromGamma(vec3(0.01, 0.01, 0.01))
    const vec3 NEBULAE_COLOR = vec3(0.9, 0.75, 1.0);

#endif
