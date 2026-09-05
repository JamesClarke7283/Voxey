shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec2 tile_uv = (UV2 + (fract(UV) * 15.0 + 0.5) / 16.0) / 8.0;
	vec4 tex = texture(atlas, tile_uv);
	ALBEDO = tex.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (UV2.x == 2.0 && UV2.y == 2.0) { EMISSION = tex.rgb * 0.6; }
}
