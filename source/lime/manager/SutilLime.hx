package lime.manager;

import shark.online.Online;

#if cpp
import hxcpp.CPP;
#end

class SutilLime
{
	public static var devicePerformanceScore(default, null):Float = 0.5;
	public static var isLowEndDevice(default, null):Bool = false;

	static var frameTimeSamples:Array<Float> = [];

	public static function estimateDeviceCapability():Void
	{
		var coreScore:Float = estimateCoreScore();
		var memoryScore:Float = estimateMemoryScore();
		var platformScore:Float = estimatePlatformScore();

		devicePerformanceScore = (coreScore * 0.4) + (memoryScore * 0.3) + (platformScore * 0.3);
		isLowEndDevice = devicePerformanceScore < 0.4;
	}

	static function estimateCoreScore():Float
	{
		#if cpp
		var cores:Int = CPP.getCpuCoreCount();
		return clamp01(cores / 8);
		#else
		return 0.5;
		#end
	}

	static function estimateMemoryScore():Float
	{
		#if cpp
		var reservedMB:Float = CPP.getMemoryReservedMB();

		if (reservedMB <= 0)
			return 0.5;

		return clamp01(reservedMB / 512);
		#else
		return 0.5;
		#end
	}

	static function estimatePlatformScore():Float
	{
		if (LimeManager.isMobileTarget)
			return 0.4;

		if (LimeManager.isWebTarget)
			return 0.5;

		return 1;
	}

	static function clamp01(value:Float):Float
	{
		if (value < 0)
			return 0;

		if (value > 1)
			return 1;

		return value;
	}

	public static function suggestInitialQualityTier():Int
	{
		if (devicePerformanceScore >= 0.7)
			return 2;

		if (devicePerformanceScore >= 0.4)
			return 1;

		return 0;
	}

	public static function suggestBaseFramerate():Int
	{
		if (isLowEndDevice)
			return 30;

		return 60;
	}

	public static function pushFrameSample(frameMs:Float):Void
	{
		frameTimeSamples.push(frameMs);

		if (frameTimeSamples.length > 30)
			frameTimeSamples.shift();
	}

	public static function getMedianFrameTime():Float
	{
		if (frameTimeSamples.length == 0)
			return 0;

		var sorted:Array<Float> = frameTimeSamples.copy();
		sorted.sort(function(a:Float, b:Float):Int
		{
			return a < b ? -1 : (a > b ? 1 : 0);
		});

		var mid:Int = Std.int(sorted.length / 2);

		if (sorted.length % 2 == 0)
			return (sorted[mid - 1] + sorted[mid]) / 2;

		return sorted[mid];
	}

	public static function detectFrameSpikes(thresholdMs:Float = 50):Int
	{
		var spikeCount:Int = 0;

		for (sample in frameTimeSamples)
			if (sample > thresholdMs)
				spikeCount++;

		return spikeCount;
	}

	public static function getDiagnosticsReport():String
	{
		var lines:Array<String> = [];

		lines.push('Platform: ${LimeManager.getPlatformName()}');
		lines.push('Build: ${LimeManager.getBuildSummary()}');
		lines.push('Device score: ${Math.round(devicePerformanceScore * 100)}%${isLowEndDevice ? " (low-end)" : ""}');
		lines.push('Median frame time: ${Math.round(getMedianFrameTime() * 100) / 100}ms');
		lines.push('Frame spikes: ${detectFrameSpikes()}');
		lines.push('Online: ${Online.isOnline} (uptime ${Math.round(Online.getUptimePercentage())}%)');

		#if cpp
		lines.push('Memory: ${Math.round(CPP.getMemoryUsageMB())}MB / ${Math.round(CPP.getMemoryReservedMB())}MB');
		lines.push('CPU cores: ${CPP.getCpuCoreCount()}');
		#end

		return lines.join("\n");
	}
}
