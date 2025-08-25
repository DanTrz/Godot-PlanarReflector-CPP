#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/* ---- Param buffer ---- */
layout(set = 0, binding = 0, std430) readonly buffer Params {
    vec2  raster_size;        
    float intersect_height;   
    float reflect_gap_fill;   
    mat4  inv_proj_mat;       
    mat4  inv_view_mat;       
    float fill_enable;        
    float fill_radius_px;     
    float fill_aggressiveness;
} P;

layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;

/* ---------- Optimized helpers ---------- */

// Faster depth check using single sample
bool is_sky_fast(vec2 uv) {
    return textureLod(depth_tex, uv, 0.0).r >= 0.99999;
}

// Cache world position calculation components
vec3 world_from_uv_fast(vec2 uv, float depth) {
    vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
    vec4 view = P.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    return (P.inv_view_mat * vec4(view.xyz, 1.0)).xyz;
}

bool is_above_water_with_gap(float world_y) {
    return world_y >= (P.intersect_height + P.reflect_gap_fill);
}

// Simplified hash for rotation
float quick_hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

/* Optimized donor search with early exits and fewer directions */
bool find_donor_optimized(vec2 uv, vec2 dir_uv, int max_steps, out vec3 rgb, out float a) {
    vec2 cur = uv;
    
    for (int s = 1; s <= max_steps; ++s) {
        cur += dir_uv;
        
        // Early boundary check
        if (any(lessThanEqual(cur, vec2(0.0))) || any(greaterThanEqual(cur, vec2(1.0))))
            return false;

        // Sample depth once and reuse
        float depth = textureLod(depth_tex, cur, 0.0).r;
        if (depth >= 0.99999) continue; // is sky

        // Quick world Y check without full world position
        vec3 ndc = vec3(cur * 2.0 - 1.0, depth);
        vec4 view = P.inv_proj_mat * vec4(ndc, 1.0);
        view.xyz /= view.w;
        float world_y = (P.inv_view_mat * vec4(view.xyz, 1.0)).y;
        
        if (!is_above_water_with_gap(world_y)) continue;

        // Sample color
        ivec2 ip = ivec2(cur * P.raster_size);
        vec4 src = imageLoad(color_image, ip);
        if (src.a <= 0.001) continue;

        // Found valid donor
        a = src.a;
        rgb = src.rgb / max(a, 1e-6);
        return true;
    }
    return false;
}

/* Reduced direction set - 8 directions instead of 12 */
const int DIRS = 8;
vec2 base_dirs[DIRS] = vec2[](
    vec2( 1, 0), vec2( 0, 1), vec2(-1, 0), vec2( 0,-1),
    vec2( 1, 1), vec2(-1, 1), vec2(-1,-1), vec2( 1,-1)
);

void main() {
    ivec2 ip = ivec2(gl_GlobalInvocationID.xy);
    if (ip.x >= int(P.raster_size.x) || ip.y >= int(P.raster_size.y)) return;

    vec2 uv = (vec2(ip) + vec2(0.5)) / P.raster_size;

    // Pre-sample depth once
    float depth = textureLod(depth_tex, uv, 0.0).r;

    // Keep sky as-is
    if (depth >= 0.99999) {
        vec4 keep = imageLoad(color_image, ip);
        keep.rgb *= keep.a;
        imageStore(color_image, ip, keep);
        return;
    }

    // Calculate world Y only once
    vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
    vec4 view = P.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float world_y = (P.inv_view_mat * vec4(view.xyz, 1.0)).y;
    
    bool above = is_above_water_with_gap(world_y);

    vec4 cur = imageLoad(color_image, ip);

    if (above) {
        // Above water - premultiply and store
        cur.rgb *= cur.a;
        imageStore(color_image, ip, cur);
        return;
    }

    // Underwater processing
    if (P.fill_enable < 0.5) {
        imageStore(color_image, ip, vec4(0.0));
        return;
    }

    int max_steps = max(1, int(P.fill_radius_px));
    float agg = clamp(P.fill_aggressiveness, 0.0, 1.0);

    // Lighter rotation
    float theta = quick_hash(uv * P.raster_size) * 6.2831853;
    float cos_t = cos(theta);
    float sin_t = sin(theta);

    vec3 acc_rgb = vec3(0.0);
    float acc_a = 0.0;
    int hits = 0;
    
    vec2 texel = 1.0 / P.raster_size;

    // Process fewer directions with early exit
    for (int i = 0; i < DIRS && hits < 4; ++i) {
        // Manual 2D rotation (faster than mat2)
        vec2 base = base_dirs[i];
        vec2 rotated = vec2(
            base.x * cos_t - base.y * sin_t,
            base.x * sin_t + base.y * cos_t
        );
        
        vec2 dir_uv = normalize(rotated) * texel;
        
        vec3 rgb; 
        float a;
        if (find_donor_optimized(uv, dir_uv, max_steps, rgb, a)) {
            acc_rgb += rgb;
            acc_a += a;
            hits++;
        }
    }

    if (hits == 0) {
        imageStore(color_image, ip, vec4(0.0));
        return;
    }

    // Compute result
    float inv_hits = 1.0 / float(hits);
    vec3 avg_rgb = acc_rgb * inv_hits;
    float avg_a = clamp(acc_a * inv_hits, 0.0, 1.0);

    vec3 out_rgb = mix(vec3(0.0), avg_rgb, agg);
    float out_a = mix(0.0, avg_a, agg);

    imageStore(color_image, ip, vec4(out_rgb * out_a, out_a));
}












