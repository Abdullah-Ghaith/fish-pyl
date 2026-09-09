shader_type canvas_item;
// Animated dashes for a SkillTreeView's link layer.
//
// Use it by setting, on the tree's SkillTreeStyle:
//   link_shader_strip = true
//   link_material     = a ShaderMaterial using this shader
//
// Each link then arrives as ONE quad: UV.x counts dash periods along the link
// (0 at the prerequisite), UV.y crosses the line 0..1. The link's state colour
// arrives as COLOR, so satisfied / gated / locked links keep their meaning.
//
// Widen style.link_width a little when you switch this on - the shader tapers
// and softens inside the quad, so the quad is the outer bound, not the line.

// Fraction of each period that is dash rather than gap.
uniform float duty : hint_range(0.05, 1.0) = 0.6;
// Periods per second travelled toward the target. Negative flows backwards.
uniform float speed = 0.9;
// Softness of the dash ends and the long edges, in UV units.
uniform float feather : hint_range(0.0, 0.5) = 0.08;
// Each dash starts thin and grows toward its head, which reads as direction.
uniform float taper : hint_range(0.0, 1.0) = 0.5;
// Additive glow on the dash bodies.
uniform vec4 glow : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	// Where we are inside the current dash period.
	float d = fract(UV.x - TIME * speed);

	// 1 inside the dash, 0 in the gap, feathered at the trailing end.
	float body = 1.0 - smoothstep(duty - feather, duty + feather, d);

	// 1 at the dash's head, 0 at its tail.
	float head = clamp(1.0 - d / max(duty, 0.001), 0.0, 1.0);

	// Taper across the line, then soften the long edges.
	float half_w = mix(1.0 - taper, 1.0, head) * 0.5;
	float edge = 1.0 - smoothstep(max(half_w - 0.12, 0.0), half_w,
			abs(UV.y - 0.5));

	float mask = body * edge;

	vec4 c = COLOR;
	c.rgb += glow.rgb * glow_strength * mask;
	c.a *= mask;
	COLOR = c;
}