#include lumi:shaders/post/common/header.glsl
#include lumi:shaders/post/common/reflection.glsl

/*******************************************************
 *  lumi:shaders/post/kaleidoskop.frag        *
 *******************************************************
 *  Copyright (c) 2020-2021 spiralhalo                 *
 *  Released WITHOUT WARRANTY under the terms of the   *
 *  GNU Lesser General Public License version 3 as     *
 *  published by the Free Software Foundation, Inc.    *
 *******************************************************/

uniform sampler2D u_solid_color;
uniform sampler2D u_solid_albedo;
uniform sampler2D u_solid_depth;
uniform sampler2D u_light_solid;
uniform sampler2D u_normal_solid;
uniform sampler2D u_material_solid;

uniform sampler2D u_translucent_color;
uniform sampler2D u_translucent_albedo;
uniform sampler2D u_translucent_depth;
uniform sampler2D u_light_translucent;
uniform sampler2D u_normal_translucent;
uniform sampler2D u_material_translucent;

#ifndef USE_LEGACY_FREX_COMPAT
out vec4[2] fragColor;
#endif

const float JITTER_STRENGTH = 0.2;

vec4 work_on_pair(
    in vec4 base_color,
    in vec3 albedo,
    in sampler2D reflector_depth,
    in sampler2D reflector_light,
    in sampler2D reflector_normal,
    in sampler2D reflector_material,

    in sampler2D reflected_color,
    in sampler2D reflected_depth,
    in sampler2D reflected_normal,
    float fallback
)
{
    vec4 noreturn = vec4(0.0);
    vec4 material = texture(reflector_material, v_texcoord);
    vec3 worldNormal = sample_worldNormal(v_texcoord, reflector_normal);
    float roughness = material.x == 0.0 ? 1.0 : material.x; //prevent gloss on unmanaged draw
    if (roughness <= REFLECTION_MAXIMUM_ROUGHNESS) {
        vec3 ray_view  = uv2view(v_texcoord, frx_inverseProjectionMatrix(), reflector_depth);
        vec3 ray_world = view2world(ray_view, frx_inverseViewMatrix());
        vec3 jitter    = 2.0 * vec3(frx_noise2d(ray_world.yz), frx_noise2d(ray_world.zx), frx_noise2d(ray_world.xy)) - 1.0;
        vec3 normal    = frx_normalModelMatrix() * normalize(worldNormal);
        float roughness2 = roughness * roughness;
        // if (ray_view.y < normal.y) return noreturn;
        vec3 unit_view  = normalize(-ray_view);
        vec3 unit_march = normalize(reflect(-unit_view, normal) + mix(vec3(0.0, 0.0, 0.0), jitter * JITTER_STRENGTH, roughness2));
        vec2 light      = texture(reflector_light, v_texcoord).y;
        vec3 reg_f0     = vec3(material.z);
        vec3 f0         = mix(reg_f0, albedo, material.y);
        rt_Result result = rt_reflection(ray_view, unit_view, normal, unit_march, frx_normalModelMatrix(), frx_projectionMatrix(), frx_inverseProjectionMatrix(), reflector_depth, reflector_normal, reflected_depth, reflected_normal);
        vec4 reflected;
        float reflected_depth_value = sample_depth(result.reflected_uv, reflected_depth);
        if (reflected_depth_value == 1.0 || !result.hit || result.reflected_uv.x < 0.0 || result.reflected_uv.y < 0.0 || result.reflected_uv.x > 1.0 || result.reflected_uv.y > 1.0) {
            reflected.rgb = calcFallbackColor(unit_view, unit_march, light);
            reflected.rgb *= result.hits > 1 ? 0.1 : 1.0;
            reflected.rgb *= fallback;
            reflected.a = fallback;
        } else {
            reflected = texture(reflected_color, result.reflected_uv);
        }
        return vec4(pbr_lightCalc(roughness, f0, reflected.rgb * base_color.a, unit_march * frx_normalModelMatrix(), unit_view * frx_normalModelMatrix()), reflected.a);
    } else return noreturn;
}

void main()
{
    vec4 solid_base = texture(u_solid_color, v_texcoord);
    vec3 solid_albedo = texture(u_solid_albedo, v_texcoord).rgb;
    vec4 translucent_base = texture(u_translucent_color, v_texcoord);
    vec3 translucent_albedo = texture(u_translucent_albedo, v_texcoord).rgb;
    vec4 solid_solid       = work_on_pair(solid_base, solid_albedo, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_solid_color, u_solid_depth, u_normal_solid, 1.0);
    vec4 solid_translucent = work_on_pair(solid_base, solid_albedo, u_solid_depth, u_light_solid, u_normal_solid, u_material_solid, u_translucent_color, u_translucent_depth, u_normal_translucent, 0.0);
    vec4 translucent_solid       = work_on_pair(translucent_base, translucent_albedo, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_solid_color, u_solid_depth, u_normal_solid, 1.0);
    vec4 translucent_translucent = work_on_pair(translucent_base, translucent_albedo, u_translucent_depth, u_light_translucent, u_normal_translucent, u_material_translucent, u_translucent_color, u_translucent_depth, u_normal_translucent, 0.0);
    float roughness1 = texture(u_material_solid, v_texcoord).x;
    float roughness2 = texture(u_material_translucent, v_texcoord).x;
    fragColor[0] = vec4(solid_solid.rgb * (1.0 - solid_translucent.a) + solid_translucent.rgb, roughness1);
    fragColor[1] = vec4(translucent_solid.rgb * (1.0 - translucent_translucent.a) + translucent_translucent.rgb, roughness2);
}
