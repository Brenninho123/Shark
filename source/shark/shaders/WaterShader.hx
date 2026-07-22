package shark.shaders;

import flixel.system.FlxShader;

class WaterShader extends FlxShader
{
	@:glFragmentSource('
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
	')
	public function new()
	{
		super();

		amplitude = 0.01;
		frequency = 20;
		tintStrength = 0.15;
		tint = [0.38, 0.65, 0.75];
	}

	public var time(get, set):Float;

	function get_time():Float
	{
		return data.uTime.value[0];
	}

	function set_time(value:Float):Float
	{
		data.uTime.value = [value];
		return value;
	}

	public var amplitude(get, set):Float;

	function get_amplitude():Float
	{
		return data.uAmplitude.value[0];
	}

	function set_amplitude(value:Float):Float
	{
		data.uAmplitude.value = [value];
		return value;
	}

	public var frequency(get, set):Float;

	function get_frequency():Float
	{
		return data.uFrequency.value[0];
	}

	function set_frequency(value:Float):Float
	{
		data.uFrequency.value = [value];
		return value;
	}

	public var tintStrength(get, set):Float;

	function get_tintStrength():Float
	{
		return data.uTintStrength.value[0];
	}

	function set_tintStrength(value:Float):Float
	{
		data.uTintStrength.value = [value];
		return value;
	}

	public var tint(get, set):Array<Float>;

	function get_tint():Array<Float>
	{
		return data.uTint.value;
	}

	function set_tint(value:Array<Float>):Array<Float>
	{
		data.uTint.value = value;
		return value;
	}

	public function update(elapsed:Float):Void
	{
		time += elapsed;
	}
}
