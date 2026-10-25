shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 stonecutter_blade_cell = vec2(-99.0);
void fragment() {
	// Interpolated atlas coordinates can differ by an epsilon. Round before
	// classifying emissive tiles so lava cannot flicker between lit and unlit.
	vec2 cell = floor(UV2 + vec2(0.5));
	vec2 tile_uv = (cell * 16.0 + fract(UV) * 15.0 + 0.5) / vec2(textureSize(atlas, 0));
	if (cell == vec2(7.0, 9.0) && COLOR.a < 0.75) {
		tile_uv = (cell * 16.0 + fract(UV + vec2(0.0, TIME * 0.12)) * 15.0 + 0.5) / vec2(textureSize(atlas, 0));
	}
	bool portal = (cell.x == 7.0 && cell.y == 10.0) || (cell.x == 0.0 && (cell.y == 16.0 || cell.y == 17.0));
	if (portal) { tile_uv = (cell * 16.0 + fract(UV + vec2(sin(TIME * 0.4) * 0.12, TIME * 0.06)) * 15.0 + 0.5) / vec2(textureSize(atlas, 0)); }
	vec4 tex = texture(atlas, tile_uv);
	if (cell == stonecutter_blade_cell) {
		vec2 radial = vec2((fract(UV.x)-0.5)*2.0, fract(UV.y)-1.0);
		float a = atan(radial.y, radial.x) + TIME*6.2831853;
		float edge = mod(floor((a+3.14159265)*12.0/3.14159265),2.0) == 0.0 ? 0.92 : 1.0;
		float r = length(radial);
		tex = vec4(vec3(r < 0.15 ? 0.35 : r > 0.8 ? 0.61 : 0.78),r <= edge ? 1.0 : 0.0);
	}
	ALBEDO = tex.rgb * COLOR.rgb;
	if ((cell.x == 7.0 && cell.y == 9.0) || (cell.x == 7.0 && cell.y == 10.0) || (cell.x == 4.0 && cell.y == 11.0)) { EMISSION = tex.rgb * 0.8; }
	if (portal || (cell.x == 4.0 && cell.y == 16.0)) { EMISSION = tex.rgb * 0.7; }
	if (cell == vec2(7.0, 9.0)) { ALBEDO *= 0.35; EMISSION = tex.rgb * 0.8; }
	ROUGHNESS = 1.0;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (cell.x == 2.0 && cell.y == 2.0) { EMISSION = tex.rgb * 0.6; }
	if (cell.x == 3.0 && cell.y == 6.0) { EMISSION = tex.rgb * 0.45; }
}
