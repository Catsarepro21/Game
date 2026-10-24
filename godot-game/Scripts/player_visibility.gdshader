shader_type canvas_item;
render_mode unshaded;
uniform sampler2D player_visibility : filter_linear, repeat_disable;
void fragment() {
	float light_amount = texture(player_visibility, SCREEN_UV).r;
	float visible_amount = smoothstep(0.005, 0.06, light_amount);
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - visible_amount);
}
