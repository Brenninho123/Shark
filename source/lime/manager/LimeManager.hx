package lime.manager;

import flixel.FlxG;
import shark.backend.ClientPrefs;
import shark.online.Online;
import shark.mobile.StorageUtil;
import shark.ui.debug.CrasherLog;

import Main;

#if cpp
import hxcpp.CPP;
#end

class LimeManager
{
	public static var platform(default, null):String;
	public static var isMobileTarget(default, null):Bool = false;
	public static var isDesktopTarget(default, null):Bool = false;
	public static var isWebTarget(default, null):Bool = false;
	public static var isDebugBuild(default, null):Bool = false;
	public static var supportsFileStorage(default, null):Bool = false;

	public static var buildVersion:String = "0.1.0";

	public static var runtimeOptimizationEnabled(default, null):Bool = false;
	public static var currentQualityTier(default, null):Int = 2;
	public static var averageFrameTimeMs(default, null):Float = 0;
	public static var memoryUsageMB(default, null):Float = 0;
	public static var isLowMemoryMode(default, null):Bool = false;
	public static var isManualQuality(default, null):Bool = false;

	public static var onQualityChanged:Int->Void;
	public static var onLowMemoryModeChanged:Bool->Void;

	static inline var QUALITY_HIGH:Int = 2;
	static inline var QUALITY_MEDIUM:Int = 1;
	static inline var QUALITY_LOW:Int = 0;

	static inline var GC_CHECK_INTERVAL:Float = 10;
	static inline var GC_MEMORY_THRESHOLD_MB:Float = 180;
	static inline var CRITICAL_MEMORY_THRESHOLD_MB:Float = 280;

	static var initialized:Bool = false;
	static var frameTimeSamples:Array<Float> = [];
	static var gcCheckTimer:Float = 0;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		resolvePlatform();
		resolveCapabilities();
		runPlatformSetup();
		applyStoredPerformancePreference();
		enableRuntimeOptimization();
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

		refineQualityWithDeviceCapability();
	}

	static function refineQualityWithDeviceCapability():Void
	{
		SutilLime.estimateDeviceCapability();

		var suggestedTier:Int = SutilLime.suggestInitialQualityTier();

		if (suggestedTier < currentQualityTier)
			currentQualityTier = suggestedTier;
	}

	static function applyStoredPerformancePreference():Void
	{
		var mode:String = ClientPrefs.getString("performanceMode", "auto");

		switch (mode)
		{
			case "low":
				setQualityTier(QUALITY_LOW);
				isManualQuality = true;
			case "medium":
				setQualityTier(QUALITY_MEDIUM);
				isManualQuality = true;
			case "high":
				setQualityTier(QUALITY_HIGH);
				isManualQuality = true;
			default:
				isManualQuality = false;
		}
	}

	public static function setPerformanceMode(mode:String):Void
	{
		ClientPrefs.setString("performanceMode", mode);
		applyStoredPerformancePreference();
	}

	static function setupMobileDefaults():Void
	{
		Online.onlineCheckInterval = 25;
		Online.offlineCheckIntervalBase = 8;
		currentQualityTier = QUALITY_MEDIUM;
	}

	static function setupDesktopDefaults():Void
	{
		Online.onlineCheckInterval = 15;
		Online.offlineCheckIntervalBase = 5;
		currentQualityTier = QUALITY_HIGH;
	}

	static function setupWebDefaults():Void
	{
		Online.onlineCheckInterval = 30;
		Online.offlineCheckIntervalBase = 10;
		supportsFileStorage = false;
		currentQualityTier = QUALITY_MEDIUM;
	}

	public static function enableRuntimeOptimization():Void
	{
		if (runtimeOptimizationEnabled)
			return;

		runtimeOptimizationEnabled = true;

		FlxG.signals.postUpdate.add(onPostUpdate);
	}

	public static function disableRuntimeOptimization():Void
	{
		runtimeOptimizationEnabled = false;
		FlxG.signals.postUpdate.remove(onPostUpdate);
	}

	static function onPostUpdate():Void
	{
		if (!Main.isActive)
			return;

		trackFrameTime();
		trackMemoryUsage(FlxG.elapsed);
	}

	static function trackFrameTime():Void
	{
		var frameMs:Float = FlxG.elapsed * 1000;

		frameTimeSamples.push(frameMs);
		SutilLime.pushFrameSample(frameMs);

		if (frameTimeSamples.length > 60)
			frameTimeSamples.shift();

		var total:Float = 0;

		for (sample in frameTimeSamples)
			total += sample;

		averageFrameTimeMs = total / frameTimeSamples.length;

		if (!isManualQuality)
			evaluateQuality();
	}

	static function evaluateQuality():Void
	{
		if (frameTimeSamples.length < 60)
			return;

		var targetFrameMs:Float = 1000 / FlxG.updateFramerate;

		if (averageFrameTimeMs > targetFrameMs * 1.4 && currentQualityTier > QUALITY_LOW)
			setQualityTier(currentQualityTier - 1);
		else if (averageFrameTimeMs < targetFrameMs * 0.9 && currentQualityTier < QUALITY_HIGH)
			setQualityTier(currentQualityTier + 1);
	}

	static function setQualityTier(tier:Int):Void
	{
		if (currentQualityTier == tier)
			return;

		currentQualityTier = tier;

		switch (tier)
		{
			case QUALITY_LOW:
				FlxG.drawFramerate = Std.int(Math.min(FlxG.drawFramerate, 30));
			case QUALITY_MEDIUM:
				FlxG.drawFramerate = Std.int(Math.min(FlxG.drawFramerate, 45));
			case QUALITY_HIGH:
				FlxG.drawFramerate = 60;
		}

		if (onQualityChanged != null)
			onQualityChanged(tier);
	}

	static function trackMemoryUsage(elapsed:Float):Void
	{
		#if cpp
		gcCheckTimer += elapsed;

		if (gcCheckTimer < GC_CHECK_INTERVAL)
			return;

		gcCheckTimer = 0;
		memoryUsageMB = CPP.getMemoryUsageMB();

		setLowMemoryMode(memoryUsageMB > CRITICAL_MEMORY_THRESHOLD_MB);

		if (memoryUsageMB > GC_MEMORY_THRESHOLD_MB)
		{
			shark.backend.Paths.clearVolatileCache();
			CPP.collectGarbage(false);
		}
		#end
	}

	static function setLowMemoryMode(value:Bool):Void
	{
		if (isLowMemoryMode == value)
			return;

		isLowMemoryMode = value;

		if (value)
			CrasherLog.logWarning('Entered low-memory mode at ${Math.round(memoryUsageMB)}MB');

		if (onLowMemoryModeChanged != null)
			onLowMemoryModeChanged(value);
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

	public static function getPerformanceSummary():String
	{
		var qualityName:String = switch (currentQualityTier)
		{
			case QUALITY_HIGH: "high";
			case QUALITY_MEDIUM: "medium";
			default: "low";
		}

		var lowMemTag:String = isLowMemoryMode ? " | LOW MEM" : "";

		return 'FPS avg: ${Std.int(1000 / Math.max(averageFrameTimeMs, 1))} | Quality: $qualityName${isManualQuality ? " (manual)" : ""} | Mem: ${Std.int(memoryUsageMB)}MB$lowMemTag';
	}
}
