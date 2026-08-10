package shark;

import lime.LimeShark;
import shark.SharkSys;

import MainCpp;

#if cpp
import hxcpp.CPP;
#end

class Native
{
	public static var isInitialized(default, null):Bool = false;

	public static function initialize():Void
	{
		if (isInitialized)
			return;

		isInitialized = true;

		SharkSys.initialize();
	}

	public static var version(get, never):String;

	static function get_version():String
	{
		return MainCpp.BUILD_VERSION;
	}

	public static var commit(get, never):String;

	static function get_commit():String
	{
		return MainCpp.BUILD_COMMIT;
	}

	public static var platform(get, never):String;

	static function get_platform():String
	{
		return LimeShark.platform;
	}

	public static var isDevMode(get, never):Bool;

	static function get_isDevMode():Bool
	{
		return MainCpp.IS_DEV_MODE;
	}

	public static var isCiBuild(get, never):Bool;

	static function get_isCiBuild():Bool
	{
		return MainCpp.IS_CI_BUILD;
	}

	public static var is64Bit(get, never):Bool;

	static function get_is64Bit():Bool
	{
		return MainCpp.is64Bit();
	}

	public static function getUptimeMs():Float
	{
		return MainCpp.getTimeSinceNativeStartMs();
	}

	public static function getMemoryUsageMB():Float
	{
		return LimeShark.getMemoryUsageMB();
	}

	public static function collectGarbage(major:Bool = false):Void
	{
		#if cpp
		CPP.collectGarbage(major);
		#end
	}

	public static function getCpuCoreCount():Int
	{
		return LimeShark.getCpuCoreCount();
	}

	public static function startTimer(name:String):Void
	{
		#if cpp
		CPP.startTimer(name);
		#end
	}

	public static function stopTimer(name:String):Float
	{
		#if cpp
		return CPP.stopTimer(name);
		#else
		return -1;
		#end
	}

	public static function getEnv(name:String, fallback:String = ""):String
	{
		return SharkSys.getEnv(name, fallback);
	}

	public static function isSysSupported():Bool
	{
		return SharkSys.isSupported;
	}

	public static function getFullReport():String
	{
		var lines:Array<String> = [
			MainCpp.getNativeBuildInfo(),
			'Uptime: ${Math.round(getUptimeMs())}ms',
			'Memory: ${Math.round(getMemoryUsageMB())}MB',
			'CPU cores: ${getCpuCoreCount()}'
		];

		return lines.join(" | ");
	}
}
