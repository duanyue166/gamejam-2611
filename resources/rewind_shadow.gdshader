shader_type canvas_item;
render_mode blend_mix, unshaded;

group_uniforms render;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float opacity : hint_range(0.0, 2.0) = 0.35;
uniform vec4 ghost_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float flicker_speed : hint_range(0.0, 5.0) = 1.2;
uniform float phase_frequency : hint_range(0.0, 1.0) = 0.4;

uniform float fresnel_strength : hint_range(0.0, 1.5) = 0.8;
uniform vec3 fresnel_color : source_color = vec3(1.0, 1.0, 1.0);

uniform float wave_amplitude : hint_range(0.0, 0.01) = 0.006;
uniform float wave_frequency : hint_range(0.0, 20.0) = 19.397;
uniform float wave_speed : hint_range(0.0, 10.0) = 3.618;
uniform float chroma_amount : hint_range(0.0, 10.0) = 1.0;

group_uniforms points;

uniform bool points_enabled = true;
uniform float point_field_scale : hint_range(1.0, 50.0) = 4.377;
uniform float point_size : hint_range(0.001, 0.02) = 0.008;
uniform float point_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float point_axis_speed : hint_range(0.0, 0.5) = 0.051;
uniform int point_move_mode : hint_range(0, 3) = 1;
uniform vec3 point_color : source_color = vec3(1.0, 1.0, 1.0);

varying vec4 sprite_modulate;

float random(vec2 st) {
	return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
	sprite_modulate = COLOR;
}

void fragment() {
	vec4 base_texture = texture(TEXTURE, UV);
	if (base_texture.a <= 0.0) {
		discard;
	}

	vec2 wave_offset = sin(SCREEN_UV.yx * wave_frequency + TIME * wave_speed) * wave_amplitude;
	vec2 distorted_uv = SCREEN_UV + wave_offset;
	float r = texture(screen_texture, distorted_uv + wave_offset * chroma_amount).r;
	float g = texture(screen_texture, distorted_uv).g;
	float b = texture(screen_texture, distorted_uv - wave_offset * chroma_amount).b;
	vec3 screen_color = vec3(r, g, b);

	float flicker = sin(TIME * flicker_speed) * 0.5 + 0.5;
	float phase = 1.0 - abs(sin(TIME * phase_frequency * 6.2831)) * 0.5;

	// Use the sprite's alpha edge for the rim light.
	vec2 pixel_x = vec2(TEXTURE_PIXEL_SIZE.x, 0.0);
	vec2 pixel_y = vec2(0.0, TEXTURE_PIXEL_SIZE.y);
	float neighbor_alpha_x = min(texture(TEXTURE, UV - pixel_x).a, texture(TEXTURE, UV + pixel_x).a);
	float neighbor_alpha_y = min(texture(TEXTURE, UV - pixel_y).a, texture(TEXTURE, UV + pixel_y).a);
	float edge = max(base_texture.a - min(neighbor_alpha_x, neighbor_alpha_y), 0.0);
	vec3 rim_light = fresnel_color * edge * edge * fresnel_strength;

	float point_accum = 0.0;
	if (points_enabled) {
		vec2 offset = vec2(0.0);
		if (point_move_mode == 0) {
			offset = vec2(0.0, TIME * point_axis_speed);
		} else if (point_move_mode == 1) {
			offset = vec2(TIME * point_axis_speed, 0.0);
		} else if (point_move_mode == 2) {
			offset = vec2(TIME * point_axis_speed);
		} else if (point_move_mode == 3) {
			offset = vec2(sin(TIME * point_axis_speed * 1.3), cos(TIME * point_axis_speed * 1.7));
		}

		vec2 grid_uv = fract(UV + offset) * point_field_scale;
		vec2 id = floor(grid_uv);
		vec2 f = fract(grid_uv) - 0.5;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell_id = id + vec2(float(i), float(j));
				vec2 point_pos = vec2(random(cell_id), random(cell_id * 1.3)) - 0.5;
				float d = length(f - point_pos);
				point_accum += 1.0 - smoothstep(point_size * 0.5, point_size, d);
			}
		}
		point_accum = clamp(point_accum, 0.0, 1.0);
	}

	vec3 final_rgb = mix(base_texture.rgb * ghost_color.rgb, screen_color, 0.6) + rim_light;
	final_rgb = mix(final_rgb, point_color, point_intensity * point_accum);
	float final_alpha = clamp(ghost_color.a * opacity * flicker * phase, 0.0, 1.0);
	COLOR = vec4(final_rgb * sprite_modulate.rgb, final_alpha * base_texture.a * sprite_modulate.a);
}
