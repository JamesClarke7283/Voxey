shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec2 tex_uv = (UV2 + (fract(UV + vec2(TIME * 0.013, TIME * 0.008)) * 15.0 + 0.5) / 16.0) / 8.0;
	vec3 tex = texture(atlas, tex_uv).rgb;
	ALBEDO = tex * COLOR.rgb;
	ROUGHNESS = 0.26;
	METALLIC = 0.15;
	ALPHA = 0.66;
}
