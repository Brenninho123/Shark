package lime.manager;

import flixel.FlxG;
import haxe.Timer;
import shark.backend.ClientPrefs;
import shark.online.Online;
import shark.mobile.StorageUtil;
import shark.ui.debug.CrasherLog;

import Main;

#if cpp
import hxcpp.CPP;
#end

typedef QualityChangeEntry = {
	timestamp:Float,
	tier:Int,
	reason:String
}

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
	public static var maxFramerate:Int = 60;

	public static var onQualityChanged:Int->Void;
	public static var onLowMemoryModeChanged:Bool->Void;

	static inline var QUALITY_HIGH:Int = 2;
	static inline var QUALITY_MEDIUM:Int = 1;
	static inline var QUALITY_LOW:Int = 0;

	static inline var GC_CHECK_INTERVAL:Float = 10;
	static inline var GC_MEMORY_THRESHOLD_MB:Float = 180;
	static inline var CRITICAL_MEMORY_THRESHOLD_MB:Float = 280;
	static inline var GC_ACTION_COOLDOWN_SECONDS:Float = 30;
	static inline var QUALITY_CHANGE_COOLDOWN_SECONDS:Float = 5;
	static inline var MAX_QUALITY_HISTORY:Int = 20;

	static var initialized:Bool = false;
	static var frameTimeSamples:Array<Float> = [];
	static var gcCheckTimer:Float = 0;
	static var lastGcActionTime:Float = -1000;
	static var lastQualityChangeTime:Float = -1000;
	static var qualityHistory:Array<QualityChangeEntry> = [];

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
				setQualityTier(QUALITY_LOW, "manual");
				isManualQuality = true;
			case "medium":
				setQualityTier(QUALITY_MEDIUM, "manual");
				isManualQuality = true;
			case "high":
				setQualityTier(QUALITY_HIGH, "manual");
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

		CrasherLog.addBreadcrumb("Runtime performance optimization enabled", "performance");
	}

	public static function disableRuntimeOptimization():Void
	{
		if (!runtimeOptimizationEnabled)
			return;

		runtimeOptimizationEnabled = false;
		FlxG.signals.postUpdate.remove(onPostUpdate);

		CrasherLog.addBreadcrumb("Runtime performance optimization disabled", "performance");
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

		if (Timer.stamp() - lastQualityChangeTime < QUALITY_CHANGE_COOLDOWN_SECONDS)
			return;

		var targetFrameMs:Float = 1000 / FlxG.updateFramerate;

		if (averageFrameTimeMs > targetFrameMs * 1.4 && currentQualityTier > QUALITY_LOW)
			setQualityTier(currentQualityTier - 1, "auto");
		else if (averageFrameTimeMs < targetFrameMs * 0.9 && currentQualityTier < QUALITY_HIGH)
			setQualityTier(currentQualityTier + 1, "auto");
	}

	public static function forceQualityReevaluation():Void
	{
		frameTimeSamples = [];
	}

	static function setQualityTier(tier:Int, reason:String = "auto"):Void
	{
		if (currentQualityTier == tier)
			return;

		currentQualityTier = tier;
		lastQualityChangeTime = Timer.stamp();
		frameTimeSamples = [];

		qualityHistory.push({timestamp: lastQualityChangeTime, tier: tier, reason: reason});

		if (qualityHistory.length > MAX_QUALITY_HISTORY)
			qualityHistory.shift();

		switch (tier)
		{
			case QUALITY_LOW:
				FlxG.drawFramerate = Std.int(Math.min(FlxG.drawFramerate, maxFramerate * 0.5));
			case QUALITY_MEDIUM:
				FlxG.drawFramerate = Std.int(Math.min(FlxG.drawFramerate, maxFramerate * 0.75));
			case QUALITY_HIGH:
				FlxG.drawFramerate = maxFramerate;
		}

		CrasherLog.addBreadcrumb('Quality tier changed to $tier ($reason)', "performance");

		if (onQualityChanged != null)
			onQualityChanged(tier);
	}

	public static function getQualityHistory():Array<QualityChangeEntry>
	{
		return qualityHistory.copy();
	}

	public static function getQualityMultiplier():Float
	{
		if (isLowMemoryMode)
			return 0.4;

		return switch (currentQualityTier)
		{
			case QUALITY_LOW: 0.6;
			case QUALITY_MEDIUM: 0.8;
			default: 1;
		}
	}

	public static function shouldRenderHighQualityEffects():Bool
	{
		return !isLowMemoryMode && currentQualityTier >= QUALITY_HIGH;
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
			var now:Float = Timer.stamp();

			if (now - lastGcActionTime >= GC_ACTION_COOLDOWN_SECONDS)
			{
				lastGcActionTime = now;
				shark.backend.Paths.clearVolatileCache();
				CPP.collectGarbage(false);
				CrasherLog.addBreadcrumb('Forced cache clear + GC at ${Math.round(memoryUsageMB)}MB', "performance");
			}
		}
		#end
	}

	static function setLowMemoryMode(value:Bool):Void
	{
		if (isLowMemoryMode == value)
			return;

		isLowMemoryMode = value;

		if (value)
			CrasherLog.logWarning('Entered low-memory mode at ${Math.round(memoryUsageMB)}MB', "performance");
		else
			CrasherLog.addBreadcrumb('Exited low-memory mode at ${Math.round(memoryUsageMB)}MB', "performance");

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

	public static function getStatusSummary():String
	{
		var lines:Array<String> = [];

		lines.push(getBuildSummary());
		lines.push(getPerformanceSummary());
		lines.push('Runtime optimization: ${runtimeOptimizationEnabled ? "on" : "off"}, quality changes tracked: ${qualityHistory.length}');

		return lines.join("\n");
	}
}
