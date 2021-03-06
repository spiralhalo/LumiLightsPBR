#include lumi:shaders/post/common/header.glsl
#include frex:shaders/lib/math.glsl
#include frex:shaders/lib/color.glsl
#include frex:shaders/api/world.glsl
#include lumi:shaders/func/tile_noise.glsl
#include lumi:shaders/func/tonemap.glsl
#include lumi:shaders/func/volumetrics.glsl
#include lumi:shaders/lib/util.glsl
#include lumi:shaders/lib/fast_gaussian_blur.glsl
#include lumi:shaders/lib/godrays.glsl
#include lumi:shaders/common/userconfig.glsl
#include lumi:shaders/post/common/clouds.glsl

/******************************************************
  lumi:shaders/post/composite.frag
******************************************************/

uniform sampler2D u_combine_solid;
uniform sampler2D u_solid_depth;
uniform sampler2D u_combine_translucent;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_particles;
uniform sampler2D u_particles_depth;
uniform sampler2D u_clouds;
uniform sampler2D u_clouds_depth;
uniform sampler2D u_weather;
uniform sampler2D u_weather_depth;

uniform sampler2D u_emissive_solid;
uniform sampler2D u_emissive_transparent;

uniform sampler2DArrayShadow u_shadow;
uniform sampler2D u_blue_noise;

in vec3 v_godray_color;
in vec2 v_skylightpos;
in float v_godray_intensity;
in float v_aspect_adjuster;
in vec2 v_invSize;

out vec4[3] fragColor;

#define NUM_LAYERS 5

vec4 color_layers[NUM_LAYERS];
float depth_layers[NUM_LAYERS];
int active_layers = 0;

void try_insert(vec4 color, float depth)
{
    if (color.a == 0.0) {
        return;
    }

    color_layers[active_layers] = color;
    depth_layers[active_layers] = depth;

    int target = active_layers++;
    int probe = target - 1;

    while (target > 0 && depth_layers[target] > depth_layers[probe]) {
        float probeDepth = depth_layers[probe];
        depth_layers[probe] = depth_layers[target];
        depth_layers[target] = probeDepth;

        vec4 probeColor = color_layers[probe];
        color_layers[probe] = color_layers[target];
        color_layers[target] = probeColor;

        target = probe--;
    }
}

vec3 blend(vec3 dst, vec4 src)
{
    return (dst * (1.0 - src.a)) + src.rgb * src.a;
}

// arbitrary chosen depth threshold
#define blurDepthThreshold 0.01
void main()
{
    float depth_solid = texture(u_solid_depth, v_texcoord).r;
    vec4 solid = texture(u_combine_solid, v_texcoord);
    bool tonemapTheSky = frx_worldFlag(FRX_WORLD_IS_NETHER);
    #if SKY_MODE == SKY_MODE_LUMI
        tonemapTheSky = tonemapTheSky || frx_worldFlag(FRX_WORLD_IS_OVERWORLD);
    #endif
    if ((depth_solid != 1.0 || tonemapTheSky) && solid.a > 0) {
        solid.rgb = ldr_tonemap3(solid.rgb);
    }

    float depth_translucent = texture(u_translucent_depth, v_texcoord).r;
    vec4 translucent = texture(u_combine_translucent, v_texcoord);
    translucent.rgb = ldr_tonemap3(translucent.rgb);

    float depth_particles = texture(u_particles_depth, v_texcoord).r;
    vec4 particles = texture(u_particles, v_texcoord);

    float depth_clouds = texture(u_clouds_depth, v_texcoord).r;
    vec4 clouds = texture(u_clouds, v_texcoord);

    float depth_weather = texture(u_weather_depth, v_texcoord).r;
    vec4 weather = texture(u_weather, v_texcoord);
    weather.rgb = ldr_tonemap3(hdr_fromGamma(weather.rgb));

    color_layers[0] = vec4(solid. rgb, 1.0);
    depth_layers[0] = depth_solid;
    active_layers = 1;

    try_insert(translucent, depth_translucent);
    try_insert(particles, depth_particles);
    try_insert(clouds, depth_clouds);
    try_insert(weather, depth_weather);

    vec3 c = color_layers[0].rgb;

    for (int i = 1; i < active_layers; ++i) {
        c = blend(c, color_layers[i]);
    }

    float min_depth = min(depth_translucent, depth_particles);

    if (v_godray_intensity > 0.0) {
        vec4 worldPos = frx_inverseViewProjectionMatrix() * vec4(v_texcoord * 2.0 - 1.0, min_depth * 2.0 - 1.0, 1.0);

        worldPos.xyz /= worldPos.w;

        float tileJitter = getRandomFloat(u_blue_noise, v_texcoord, frxu_size);

        vec4 godBeam = celestialLightRays(u_shadow, worldPos.xyz, tileJitter, depth_translucent, min_depth);

        godBeam = ldr_tonemap(godBeam) * v_godray_intensity;

        c = c + godBeam.rgb * godBeam.a;

        // TODO: screenspace godrays when there is no shadow map

        // vec2 diff = abs(v_texcoord - v_skylightpos);
        // diff.x *= v_aspect_adjuster;
        // float rainFactor = 1.0 - frx_rainGradient();
        // float godlightfactor = frx_smootherstep(frx_worldFlag(FRX_WORLD_IS_MOONLIT) ? 0.3 : 0.6, 0.0, length(diff)) * v_godray_intensity * rainFactor;
        // float godhack = depth_solid == 1.0 ? 0.5 : 1.0;
        // if (godlightfactor > 0.0) {
        //     vec3 godlight = v_godray_color * godrays(4, u_solid_depth, u_clouds, u_blue_noise, v_skylightpos, v_texcoord, frxu_size);
        //     c += godlightfactor * godlight * godhack;
        // }
    }
    
    fragColor[0] = vec4(c, 1.0); //frx_luminance(c.rgb)); // FXAA 3 would need this
    fragColor[1] = vec4(min_depth, 0., 0., 1.);
    
    #ifdef TOON_OUTLINE
        float d1 = ldepth(min_depth);
        float maxDiff = 0.;
        float maxD = 0;
        const vec2[4] check = vec2[](vec2( 1.,  1.), vec2( 1., -1.), vec2(-1.,  1.), vec2(-1., -1.));
        for (int i = 0; i < 4; i++) {
            vec2 coord = v_texcoord + v_invSize * check[i];
            float minD = ldepth(min(texture(u_translucent_depth, coord).x, texture(u_particles_depth, coord).x));
            float diff = d1 - minD;
            if (diff > maxDiff) {
                maxDiff = diff;
                maxD = minD;
            }
        }
        float threshold = mix(.0, .3, d1);
        float lineness = l2_clampScale(threshold, threshold * .5, maxDiff);
        lineness += (1.0 - lineness) * min(1.0, maxD * 2.0);
        lineness += (1.0 - lineness) * (maxD > ldepth(depth_layers[active_layers-1]) ? color_layers[active_layers-1].a : 0.0);
        fragColor[0] *= lineness;
    #endif

    // no need to check for solid depth because translucent behind solid are culled in GL depth test
    float bloom = max(texture(u_emissive_solid, v_texcoord).r, texture(u_emissive_transparent, v_texcoord).r);
    float min_occluder = min(depth_clouds, depth_weather);
    float occluder_alpha = min_occluder == depth_clouds ? clouds.a : weather.a;

    bloom *= max(0.0, 1.0 - occluder_alpha);

    fragColor[2].r = bloom;
}
