#pragma header

uniform float uTime;
uniform float uAmplitude;
uniform float uFrequency;
uniform vec3 uTint;
uniform float uTintStrength;

void main(void)
{
	vec2 uv = openfl_TextureCoordv;

	uv.x += sin(uv.y * uFrequency + uTime) * uAmplitude;
	uv.y += cos(uv.x * uFrequency + uTime * 0.8) * uAmplitude;

	vec4 color = texture2D(bitmap, uv);
	color.rgb = mix(color.rgb, uTint, uTintStrength * color.a);

	gl_FragColor = color * openfl_Alpha;
}
