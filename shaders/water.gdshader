shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 honey_tile = vec2(-1.0);
uniform vec2 tinted_glass_tile = vec2(-1.0);
void fragment() {
	vec2 cell = floor(UV2 + vec2(0.5));
	bool solid_glass = cell == honey_tile || cell == tinted_glass_tile;
	vec2 motion = solid_glass ? vec2(0.0) : (COLOR.a < 0.75 ? vec2(0.0, TIME * 0.45) : vec2(TIME * 0.013, TIME * 0.008));
	vec2 tex_uv = (cell * 16.0 + fract(UV + motion) * 15.0 + 0.5) / vec2(textureSize(atlas, 0));
	vec4 tex = texture(atlas, tex_uv);
	ALBEDO = tex.rgb * COLOR.rgb;
	ROUGHNESS = solid_glass ? 0.55 : 0.26;
	METALLIC = solid_glass ? 0.0 : 0.15;
	ALPHA = solid_glass ? tex.a : 0.66;
}
