shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec2 motion = COLOR.a < 0.75 ? vec2(0.0, TIME * 0.45) : vec2(TIME * 0.013, TIME * 0.008);
	vec2 tex_uv = (floor(UV2 + vec2(0.5)) * 16.0 + fract(UV + motion) * 15.0 + 0.5) / vec2(textureSize(atlas, 0));
	vec3 tex = texture(atlas, tex_uv).rgb;
	ALBEDO = tex * COLOR.rgb;
	ROUGHNESS = 0.26;
	METALLIC = 0.15;
	ALPHA = 0.66;
}
