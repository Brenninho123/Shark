package git.performance;

import flixel.FlxG;
import lime.manager.LimeManager;

class Boost
{
	public static var isBoostActive(default, null):Bool = false;
	public static var targetFPS(default, null):Int = 60;
	public static var maxSupportedFPS:Int = 144;
	public static var minSupportedFPS:Int = 10;

	static var originalDrawFramerate:Int = 60;
	static var originalUpdateFramerate:Int = 60;
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;
		targetFPS = FlxG.drawFramerate;
	}

	public static function setTargetFPS(fps:Int):Void
	{
		var clamped:Int = clampFPS(fps);

		targetFPS = clamped;
		FlxG.drawFramerate = clamped;
		FlxG.updateFramerate = clamped;
	}

	static function clampFPS(fps:Int):Int
	{
		if (fps < minSupportedFPS)
			return minSupportedFPS;

		if (fps > maxSupportedFPS)
			return maxSupportedFPS;

		return fps;
	}

	public static function enableBoost():Void
	{
		if (isBoostActive)
			return;

		isBoostActive = true;

		originalDrawFramerate = FlxG.drawFramerate;
		originalUpdateFramerate = FlxG.updateFramerate;

		LimeManager.maxFramerate = maxSupportedFPS;
		LimeManager.setPerformanceMode("high");
		setTargetFPS(maxSupportedFPS);
	}

	public static function disableBoost():Void
	{
		if (!isBoostActive)
			return;

		isBoostActive = false;

		LimeManager.maxFramerate = originalDrawFramerate;
		LimeManager.setPerformanceMode("auto");

		FlxG.drawFramerate = originalDrawFramerate;
		FlxG.updateFramerate = originalUpdateFramerate;
		targetFPS = originalDrawFramerate;
	}

	public static function toggleBoost():Bool
	{
		if (isBoostActive)
			disableBoost();
		else
			enableBoost();

		return isBoostActive;
	}

	public static function getCurrentFPS():Float
	{
		return 1000 / Math.max(LimeManager.averageFrameTimeMs, 1);
	}

	public static function getFrameTimeMs():Float
	{
		return LimeManager.averageFrameTimeMs;
	}

	public static function isRunningSmooth():Bool
	{
		return getCurrentFPS() >= targetFPS * 0.9;
	}

	public static function getSpeedMultiplier():Float
	{
		return getCurrentFPS() / 60;
	}

	public static function getBoostSummary():String
	{
		var status:String = isBoostActive ? "ON" : "off";
		return 'Boost: $status | Target: ${targetFPS}fps | Actual: ${Std.int(getCurrentFPS())}fps';
	}
}
