shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 0.2, 0.2, 0.8);
uniform float border_size : hint_range(0.0, 0.5) = 0.08;
uniform float softness : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec2 uv = UV;
	
	// Calculate distance from edges (0 at edge, 0.5 at center)
	float dist_x = min(uv.x, 1.0 - uv.x);
	float dist_y = min(uv.y, 1.0 - uv.y);
	float dist = min(dist_x, dist_y);
	
	// Create gradient from edge
	float alpha = 1.0 - smoothstep(0.0, border_size + softness, dist);
	
	// Boost corners (where both x and y are near edges)
	float corner_boost = (1.0 - smoothstep(0.0, border_size * 2.0, dist_x)) * 
						 (1.0 - smoothstep(0.0, border_size * 2.0, dist_y));
	alpha = max(alpha, corner_boost * 0.7);
	
	COLOR = vec4(border_color.rgb, border_color.a * alpha);
}
