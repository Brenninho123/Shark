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

	static inline function get_platform():String
	{
		return LimeManager.getPlatformName();
	}

	public static var isMobile(get, never):Bool;

	static inline function get_isMobile():Bool
	{
		return LimeManager.isMobileTarget;
	}

	public static var isDesktop(get, never):Bool;

	static inline function get_isDesktop():Bool
	{
		return LimeManager.isDesktopTarget;
	}

	public static var isWeb(get, never):Bool;

	static inline function get_isWeb():Bool
	{
		return LimeManager.isWebTarget;
	}

	public static var isDebugBuild(get, never):Bool;

	static inline function get_isDebugBuild():Bool
	{
		return LimeManager.isDebugBuild;
	}

	public static var isLowEndDevice(get, never):Bool;

	static inline function get_isLowEndDevice():Bool
	{
		return SutilLime.isLowEndDevice;
	}

	public static inline function showKeyboard():Void
	{
		LimeInput.showSoftKeyboard();
	}

	public static inline function hideKeyboard():Void
	{
		LimeInput.hideSoftKeyboard();
	}

	public static inline function getPerformanceSummary():String
	{
		return LimeManager.getPerformanceSummary();
	}

	public static inline function getDiagnostics():String
	{
		return SutilLime.getDiagnosticsReport();
	}

	public static inline function getBuildSummary():String
	{
		return LimeManager.getBuildSummary();
	}

	public static inline function getMemoryUsageMB():Float
	{
		#if cpp
		return CPP.getMemoryUsageMB();
		#else
		return 0.0;
		#end
	}

	public static inline function collectGarbage(major:Bool = false):Void
	{
		#if cpp
		CPP.collectGarbage(major);
		#end
	}

	public static inline function getCpuCoreCount():Int
	{
		#if cpp
		return CPP.getCpuCoreCount();
		#else
		return 1;
		#end
	}

	public static inline function generateSecureToken(length:Int = 16):String
	{
		return Guard.generateToken(length);
	}
}
