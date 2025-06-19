shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_toon,specular_toon;

// =============================================================================
// CORE UNIFORMS - Essential functionality
// =============================================================================
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest_mipmap;

// Material properties
uniform vec4 albedo : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Reflection
uniform sampler2D reflection_screen_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.5;
uniform bool is_orthogonal_camera = false;
uniform float ortho_uv_scale : hint_range(0.1, 3.0) = 1.0;

// Surface normals and distortion
uniform sampler2D texture_normal : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal2 : source_color, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float normal_uv_mult : hint_range(0.1, 10.0) = 1.0;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.1;

// UV controls
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);

// =============================================================================
// OPTIONAL FEATURES - Can be disabled for performance
// =============================================================================
uniform float proximity_fade_distance = 0.0; // Set to 0 to disable
uniform float refraction : hint_range(-1.0, 1.0) = 0.0; // Set to 0 to disable
uniform sampler2D texture_refraction : filter_linear_mipmap, repeat_enable;
uniform vec4 refraction_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);

// =============================================================================
// CUSTOMIZATION POINT 1: Add your custom uniforms here
// Example: Foam, caustics, wave displacement, etc.
// =============================================================================
// uniform float wave_amplitude = 0.0;
// uniform float wave_frequency = 1.0;
// uniform sampler2D foam_texture;
// uniform float foam_threshold = 0.5;

varying vec3 world_position;

void vertex() {
    // Basic UV setup
    UV = UV * uv1_scale.xy + uv1_offset.xy;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // =============================================================================
    // CUSTOMIZATION POINT 2: Vertex displacement (waves, etc.)
    // Add wave displacement, vertex animation, etc. here
    // =============================================================================
    // Example wave displacement:
    // VERTEX.y += sin(world_position.x * wave_frequency + TIME) * wave_amplitude;
}

void fragment() {
    vec2 base_uv = UV;
    
    // =============================================================================
    // CUSTOMIZATION POINT 3: Custom UV modifications
    // Add time-based UV animations, complex distortions, etc.
    // =============================================================================
    
    // Sample base textures
    vec4 albedo_tex = texture(texture_albedo, base_uv);
    
    // Optimized normal sampling with time offset
    float time_scale = TIME * 0.001; // Single time calculation
    vec2 normal_uv1 = (base_uv - vec2(time_scale * 2.0)) * normal_uv_mult;
    vec2 normal_uv2 = (base_uv + vec2(time_scale * 0.25, time_scale * 0.5)) * normal_uv_mult;
    
    vec3 normal1 = texture(texture_normal, normal_uv1).rgb;
    vec3 normal2 = texture(texture_normal2, normal_uv2).rgb;
    vec3 combined_normal = mix(normal1, normal2, 0.5);
    
    // Calculate distortion once
    vec2 distortion = distortion_strength * (normal1.rg - vec2(0.5));
    vec2 warped_uv = SCREEN_UV + distortion;
    
    // Handle orthogonal camera mode
    if (is_orthogonal_camera) {
        vec2 center = vec2(0.5);
        warped_uv = center + (warped_uv - center) * ortho_uv_scale;
    }
    warped_uv = clamp(warped_uv, 0.0, 1.0);
    
    // =============================================================================
    // CUSTOMIZATION POINT 4: Advanced reflection modifications
    // Add SSR, custom reflection filtering, multi-layer reflections, etc.
    // =============================================================================
    
    // Sample reflection
    vec4 reflection_tex = texture(reflection_screen_texture, warped_uv);
    
    // =============================================================================
    // CUSTOMIZATION POINT 5: Surface effects calculations
    // Add foam, caustics, ripples, etc. Calculate factors here
    // =============================================================================
    // Example foam calculation:
    // float surface_turbulence = length(distortion);
    // float foam_factor = smoothstep(foam_threshold - 0.1, foam_threshold + 0.1, surface_turbulence);
    
    // Core material setup
    NORMAL_MAP = combined_normal;
    NORMAL_MAP_DEPTH = normal_scale;
    
    // Base color mixing
    vec3 base_material_color = albedo_tex.rgb * albedo.rgb;
    vec3 base_albedo = mix(reflection_tex.rgb, base_material_color, reflection_strength);
    
    // =============================================================================
    // CUSTOMIZATION POINT 6: Final color modifications
    // Apply foam, caustics, or other surface effects to base_albedo here
    // =============================================================================
    // Example foam application:
    // if (foam_factor > 0.0) {
    //     base_albedo = mix(base_albedo, vec3(1.0), foam_factor * 0.8);
    // }
    
    ALBEDO = base_albedo;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = specular;
    
    // =============================================================================
    // OPTIONAL FEATURES - Only calculated if enabled
    // =============================================================================
   
    // Refraction (only if enabled)
    if (abs(refraction) > 0.001) {
        vec3 unpacked_normal = combined_normal * 2.0 - 1.0;
        unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));
        
        vec3 ref_normal = normalize(mix(NORMAL, 
            TANGENT * unpacked_normal.x + BINORMAL * unpacked_normal.y + NORMAL * unpacked_normal.z, 
            normal_scale));
        
        vec4 refraction_tex = texture(texture_refraction, base_uv);
        vec2 ref_ofs = SCREEN_UV - ref_normal.xy * dot(refraction_tex, refraction_texture_channel) * refraction;
        
        float ref_amount = 1.0 - mix(reflection_tex.a, albedo.a * albedo_tex.a, reflection_strength);
        EMISSION += textureLod(screen_texture, ref_ofs, roughness * 8.0).rgb * ref_amount * EXPOSURE;
        ALBEDO *= 1.0 - ref_amount;
    }
    
    ALPHA = 1.0;
    
    // Proximity fade (only if enabled)
    if (proximity_fade_distance > 0.0) {
        float depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
        vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
        world_pos.xyz /= world_pos.w;
        float fade_factor = clamp(1.0 - smoothstep(world_pos.z + proximity_fade_distance, world_pos.z, VERTEX.z), 0.0, 1.0);
        ALPHA *= fade_factor;
    }
}