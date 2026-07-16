package lime;

import lime.input.LimeInput;
import lime.manager.LimeManager;
import lime.manager.SutilLime;
import shark.ui.security.Guard;

#if cpp
import hxcpp.CPP;
#end

class LimeShark
{
	public static var isInitialized(default, null):Bool = false;

	public static function initialize():Void
	{
		if (isInitialized)
			return;

		isInitialized = true;

		LimeManager.initialize();
		LimeInput.initialize();
	}

	public static var platform(get, never):String;

	static function get_platform():String
	{
		return LimeManager.getPlatformName();
	}

	public static var isMobile(get, never):Bool;

	static function get_isMobile():Bool
	{
		return LimeManager.isMobileTarget;
	}

	public static var isDesktop(get, never):Bool;

	static function get_isDesktop():Bool
	{
		return LimeManager.isDesktopTarget;
	}

	public static var isWeb(get, never):Bool;

	static function get_isWeb():Bool
	{
		return LimeManager.isWebTarget;
	}

	public static var isDebugBuild(get, never):Bool;

	static function get_isDebugBuild():Bool
	{
		return LimeManager.isDebugBuild;
	}

	public static var isLowEndDevice(get, never):Bool;

	static function get_isLowEndDevice():Bool
	{
		return SutilLime.isLowEndDevice;
	}

	public static function showKeyboard():Void
	{
		LimeInput.showSoftKeyboard();
	}

	public static function hideKeyboard():Void
	{
		LimeInput.hideSoftKeyboard();
	}

	public static function getPerformanceSummary():String
	{
		return LimeManager.getPerformanceSummary();
	}

	public static function getDiagnostics():String
	{
		return SutilLime.getDiagnosticsReport();
	}

	public static function getBuildSummary():String
	{
		return LimeManager.getBuildSummary();
	}

	public static function getMemoryUsageMB():Float
	{
		#if cpp
		return CPP.getMemoryUsageMB();
		#else
		return 0;
		#end
	}

	public static function collectGarbage(major:Bool = false):Void
	{
		#if cpp
		CPP.collectGarbage(major);
		#end
	}

	public static function getCpuCoreCount():Int
	{
		#if cpp
		return CPP.getCpuCoreCount();
		#else
		return 1;
		#end
	}

	public static function generateSecureToken(length:Int = 16):String
	{
		return Guard.generateToken(length);
	}
}
