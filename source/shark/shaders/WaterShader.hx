package shark.shaders;

import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;
import lime.manager.LimeManager;

interface IUpdatableShader
{
	function update(elapsed:Float):Void;
}

enum abstract WaterShaderTier(Int)
{
	var FULL = 0;
	var LITE = 1;
	var DISABLED = 2;
}

class WaterShader extends FlxShader implements IUpdatableShader
{
	@:glFragmentSource('
		#pragma header

		#ifdef GL_ES
		precision mediump float;
		#endif

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

			vec4 color = flixel_texture2D(bitmap, uv);
			color.rgb = mix(color.rgb, uTint, uTintStrength * color.a);

			gl_FragColor = color * openfl_Alpha;
		}
	')
	public function new()
	{
		super();

		baseAmplitude = 0.01 * WaterShader.visualScale();
		frequency = 20;
		tintStrength = 0.15;
		tint = [0.38, 0.65, 0.75];
		amplitude = baseAmplitude;
	}

	var baseAmplitude:Float;
	var qualityCheckTimer:Float = 0;

	static inline var QUALITY_CHECK_INTERVAL:Float = 1;

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

		qualityCheckTimer += elapsed;

		if (qualityCheckTimer >= QUALITY_CHECK_INTERVAL)
		{
			qualityCheckTimer = 0;
			amplitude = baseAmplitude * LimeManager.getQualityMultiplier();
		}
	}

	static function visualScale():Float
	{
		return FlxG.onMobile ? 0.6 : 1;
	}

	public static function getRecommendedTier():WaterShaderTier
	{
		if (LimeManager.isLowMemoryMode)
			return DISABLED;

		if (FlxG.onMobile && LimeManager.currentQualityTier == 0)
			return DISABLED;

		if (FlxG.onMobile && LimeManager.currentQualityTier == 1)
			return LITE;

		return FULL;
	}

	public static function isRecommendedForCurrentDevice():Bool
	{
		return getRecommendedTier() != DISABLED;
	}

	public static function createForCurrentDevice():IUpdatableShader
	{
		return switch (getRecommendedTier())
		{
			case FULL: new WaterShader();
			case LITE: new WaterShaderLite();
			case DISABLED: null;
		}
	}
}

class WaterShaderLite extends FlxShader implements IUpdatableShader
{
	@:glFragmentSource('
		#pragma header

		#ifdef GL_ES
		precision mediump float;
		#endif

		uniform float uTime;
		uniform float uAmplitude;
		uniform vec3 uTint;
		uniform float uTintStrength;

		void main(void)
		{
			vec2 uv = openfl_TextureCoordv;

			uv.x += sin(uv.y * 12.0 + uTime) * uAmplitude;

			vec4 color = flixel_texture2D(bitmap, uv);
			color.rgb = mix(color.rgb, uTint, uTintStrength * color.a);

			gl_FragColor = color * openfl_Alpha;
		}
	')
	public function new()
	{
		super();

		amplitude = 0.008;
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
