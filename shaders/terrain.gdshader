shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec2 tile_uv = (UV2 * 16.0 + fract(UV) * 15.0 + 0.5) / vec2(textureSize(atlas, 0));
	bool portal = (UV2.x == 7.0 && UV2.y == 10.0) || (UV2.x == 0.0 && (UV2.y == 16.0 || UV2.y == 17.0));
	if (portal) { tile_uv = (UV2 * 16.0 + fract(UV + vec2(sin(TIME * 0.4) * 0.12, TIME * 0.06)) * 15.0 + 0.5) / vec2(textureSize(atlas, 0)); }
	vec4 tex = texture(atlas, tile_uv);
	ALBEDO = tex.rgb * COLOR.rgb;
	if ((UV2.x == 7.0 && UV2.y == 9.0) || (UV2.x == 7.0 && UV2.y == 10.0) || (UV2.x == 4.0 && UV2.y == 11.0)) { EMISSION = tex.rgb * 0.8; }
	if (portal || (UV2.x == 4.0 && UV2.y == 16.0)) { EMISSION = tex.rgb * 0.7; }
	ROUGHNESS = 1.0;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (UV2.x == 2.0 && UV2.y == 2.0) { EMISSION = tex.rgb * 0.6; }
	if (UV2.x == 3.0 && UV2.y == 6.0) { EMISSION = tex.rgb * 0.45; }
}
