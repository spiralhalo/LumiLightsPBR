#include frex:shaders/lib/math.glsl
#include lumi:shaders/func/tile_noise.glsl

/*******************************************************
 *  lumi:shaders/lib/ssao.glsl                         *
 *******************************************************
 *  based on:                                          *
 * https://gist.github.com/transitive-bullshit/6770346 *
 *******************************************************/

// 5 for each is smoother but this setup has double the performance
#define NUM_SAMPLE_DIRECTIONS 3
#define NUM_SAMPLE_STEPS      3

vec3 coords_view(vec2 uv, mat4 inv_projection, in sampler2D target)
{
    float depth = texture(target, uv).r;
    vec3 clip = vec3(2.0 * uv - 1.0, 2.0 * depth - 1.0);
    vec4 view = inv_projection * vec4(clip, 1.0);
    return view.xyz / view.w;
}

vec3 coords_normal(vec2 uv, mat3 normal_mat, in sampler2D target)
{
    return normal_mat * (2.0 * texture(target, uv).xyz - 1.0);
}

const float TWO_PI = 2.0 * PI;
const float theta = TWO_PI / float(NUM_SAMPLE_DIRECTIONS);
const float cosTheta = cos(theta);
const float sinTheta = sin(theta);
const mat2 deltaRotationMatrix = mat2(
    cosTheta, -sinTheta,
    sinTheta, cosTheta
);

float calc_ssao(
    in sampler2D snormal, in sampler2D sdepth, in sampler2D sbluenoise, mat3 normal_mat, mat4 inv_projection, vec2 tex_size,
    vec2 uv, float radius_screen, float attenuation_radius, float angle_bias, float intensity)
{
    vec3 origin_view = coords_view(uv, inv_projection, sdepth);
    vec3 normal_view = coords_normal(uv, normal_mat, snormal);
    float radius_view = radius_screen / abs(origin_view.z - 1);
    float attenuation_rad2 = attenuation_radius * attenuation_radius;

    vec2 deltaUV = vec2(1.0, 0.0) * (radius_view / (float(NUM_SAMPLE_DIRECTIONS * NUM_SAMPLE_STEPS) + 1.0));

    // PERF: Use noise texture?
    vec3 sampleNoise = normalize(2.0 * getRandomVec(sbluenoise, uv, tex_size) - 1.0);
    mat2 rotationMatrix = mat2(
        sampleNoise.x, -sampleNoise.y,
        sampleNoise.y,  sampleNoise.x
    );
    deltaUV = rotationMatrix * deltaUV;

    float jitter = sampleNoise.z;
    float occlusion = 0.0;

    for (int i = 0; i < NUM_SAMPLE_DIRECTIONS; ++i) {
        deltaUV = deltaRotationMatrix * deltaUV;
        vec2 sampleDirUV = deltaUV;
        float oldAngle   = angle_bias;

        for (int j = 0; j < NUM_SAMPLE_STEPS; ++j) {
            vec2 sample_uv      = uv + (jitter + float(j)) * sampleDirUV;
            vec3 sample_view    = coords_view(sample_uv, inv_projection, sdepth);
            vec3 sampleDir_view = (sample_view - origin_view);

            float gamma = (PI / 2.0) - acos(dot(normal_view, normalize(sampleDir_view)));
            if (gamma > oldAngle) {
                float value = sin(gamma) - sin(oldAngle);
                float attenuation = clamp(1.0 - dot(sampleDir_view, sampleDir_view) / attenuation_rad2, 0.0, 1.0);
                occlusion += attenuation * value;
                oldAngle = gamma;
            }
        }
    }
    occlusion = 1.0 - occlusion / float(NUM_SAMPLE_DIRECTIONS);
    return clamp(pow(occlusion, 1.0 + intensity), 0.0, 1.0);
}
