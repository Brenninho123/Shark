package lime.manager;

import shark.online.Online;
import shark.mobile.StorageUtil;

class LimeManager
{
	public static var platform(default, null):String;
	public static var isMobileTarget(default, null):Bool;
	public static var isDesktopTarget(default, null):Bool;
	public static var isWebTarget(default, null):Bool;
	public static var isDebugBuild(default, null):Bool;
	public static var supportsFileStorage(default, null):Bool;

	public static var buildVersion:String = "0.1.0";

	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		resolvePlatform();
		resolveCapabilities();
		runPlatformSetup();
	}

	static function resolvePlatform():Void
	{
		#if android
		platform = "android";
		isMobileTarget = true;
		#elseif ios
		platform = "ios";
		isMobileTarget = true;
		#elseif windows
		platform = "windows";
		isDesktopTarget = true;
		#elseif mac
		platform = "mac";
		isDesktopTarget = true;
		#elseif linux
		platform = "linux";
		isDesktopTarget = true;
		#elseif html5
		platform = "html5";
		isWebTarget = true;
		#else
		platform = "unknown";
		#end

		if (isMobileTarget == null)
			isMobileTarget = false;

		if (isDesktopTarget == null)
			isDesktopTarget = false;

		if (isWebTarget == null)
			isWebTarget = false;

		#if debug
		isDebugBuild = true;
		#else
		isDebugBuild = false;
		#end
	}

	static function resolveCapabilities():Void
	{
		#if sys
		supportsFileStorage = true;
		#else
		supportsFileStorage = false;
		#end
	}

	static function runPlatformSetup():Void
	{
		if (supportsFileStorage)
			StorageUtil.ensureContentFolder();

		Online.start();

		if (isMobileTarget)
			setupMobileDefaults();
		else if (isDesktopTarget)
			setupDesktopDefaults();
		else if (isWebTarget)
			setupWebDefaults();
	}

	static function setupMobileDefaults():Void
	{
		Online.checkInterval = 20;
	}

	static function setupDesktopDefaults():Void
	{
		Online.checkInterval = 15;
	}

	static function setupWebDefaults():Void
	{
		Online.checkInterval = 30;
		supportsFileStorage = false;
	}

	public static function getPlatformName():String
	{
		return platform == null ? "unknown" : platform;
	}

	public static function getBuildSummary():String
	{
		var mode:String = isDebugBuild ? "debug" : "release";
		return 'Shark $buildVersion ($platform, $mode)';
	}
}
