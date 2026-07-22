package;

@:headerCode('
#include <chrono>
#include <thread>
#include <ctime>
')
class MainCpp
{
	static var nativeStartTimeMs:Float = -1;
	static var checkpoints:Map<String, Float> = new Map();
	static var checkpointOrder:Array<String> = [];

	public static function nativeInit():Void
	{
		nativeStartTimeMs = nowMs();
		checkpoints = new Map();
		checkpointOrder = [];

		recordCheckpoint("native_init");
	}

	static function nowMs():Float
	{
		#if cpp
		return untyped __cpp__("
			(double)std::chrono::duration_cast<std::chrono::microseconds>(
				std::chrono::high_resolution_clock::now().time_since_epoch()
			).count() / 1000.0
		");
		#else
		return Sys.time() * 1000;
		#end
	}

	public static function getTimeSinceNativeStartMs():Float
	{
		if (nativeStartTimeMs < 0)
			return 0;

		return nowMs() - nativeStartTimeMs;
	}

	public static function recordCheckpoint(name:String):Void
	{
		if (!checkpoints.exists(name))
			checkpointOrder.push(name);

		checkpoints.set(name, getTimeSinceNativeStartMs());
	}

	public static function getCheckpoint(name:String):Float
	{
		return checkpoints.exists(name) ? checkpoints.get(name) : -1;
	}

	public static function getCheckpointReport():String
	{
		var lines:Array<String> = [];

		for (name in checkpointOrder)
			lines.push('$name: ${Math.round(checkpoints.get(name))}ms');

		return lines.join(" | ");
	}

	public static function getCheckpointDelta(fromName:String, toName:String):Float
	{
		if (!checkpoints.exists(fromName) || !checkpoints.exists(toName))
			return -1;

		return checkpoints.get(toName) - checkpoints.get(fromName);
	}

	public static function getPhaseReport():String
	{
		var lines:Array<String> = [];

		for (i in 1...checkpointOrder.length)
		{
			var fromName:String = checkpointOrder[i - 1];
			var toName:String = checkpointOrder[i];
			var delta:Float = getCheckpointDelta(fromName, toName);

			lines.push('$fromName -> $toName: ${Math.round(delta)}ms');
		}

		return lines.join(" | ");
	}

	public static function getCpuTimeMs():Float
	{
		#if cpp
		return untyped __cpp__("((double)std::clock() / CLOCKS_PER_SEC) * 1000.0");
		#else
		return Sys.cpuTime() * 1000;
		#end
	}

	public static function getCpuUsageRatio():Float
	{
		var wallTime:Float = getTimeSinceNativeStartMs();

		if (wallTime <= 0)
			return 0;

		var coreCount:Int = 1;

		#if cpp
		coreCount = untyped __cpp__("(int)std::thread::hardware_concurrency()");

		if (coreCount <= 0)
			coreCount = 1;
		#end

		return getCpuTimeMs() / (wallTime * coreCount);
	}

	public static function is64Bit():Bool
	{
		#if cpp
		return untyped __cpp__("(sizeof(void*) == 8)");
		#else
		return true;
		#end
	}

	public static function getNativeThreadHash():Int
	{
		#if cpp
		return untyped __cpp__("(int)std::hash<std::thread::id>{}(std::this_thread::get_id())");
		#else
		return 0;
		#end
	}

	public static function getCpuArchitecture():String
	{
		#if cpp
		return untyped __cpp__("
			#if defined(__aarch64__) || defined(_M_ARM64)
				\"arm64\"
			#elif defined(__arm__) || defined(_M_ARM)
				\"arm\"
			#elif defined(__x86_64__) || defined(_M_X64)
				\"x86_64\"
			#elif defined(__i386__) || defined(_M_IX86)
				\"x86\"
			#else
				\"unknown\"
			#endif
		");
		#else
		return "unknown";
		#end
	}

	public static function getCompilerName():String
	{
		#if cpp
		return untyped __cpp__("
			#if defined(__clang__)
				\"clang\"
			#elif defined(__GNUC__)
				\"gcc\"
			#elif defined(_MSC_VER)
				\"msvc\"
			#else
				\"unknown\"
			#endif
		");
		#else
		return "unknown";
		#end
	}

	public static function clearCheckpoints():Void
	{
		checkpoints = new Map();
		checkpointOrder = [];
	}

	public static function preciseSleepMs(milliseconds:Float):Void
	{
		if (milliseconds <= 0)
			return;

		#if cpp
		untyped __cpp__("
			std::this_thread::sleep_for(std::chrono::microseconds((long long)({0} * 1000.0)))
		", milliseconds);
		#else
		Sys.sleep(milliseconds / 1000);
		#end
	}

	public static function preciseWaitUntil(targetTimeMs:Float, spinThresholdMs:Float = 2):Void
	{
		var remaining:Float = targetTimeMs - nowMs();

		if (remaining <= 0)
			return;

		if (remaining > spinThresholdMs)
			preciseSleepMs(remaining - spinThresholdMs);

		while (nowMs() < targetTimeMs) {}
	}

	public static function getFrameBudgetMs(targetFps:Int):Float
	{
		if (targetFps <= 0)
			return 0;

		return 1000 / targetFps;
	}
}
