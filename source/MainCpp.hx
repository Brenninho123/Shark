package;

@:headerCode('
#include <chrono>
#include <thread>
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
}
