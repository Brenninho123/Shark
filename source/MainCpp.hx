package;

@:headerCode('
#include <chrono>
')
class MainCpp
{
	static var nativeStartTimeMs:Float = -1;

	public static function nativeInit():Void
	{
		#if cpp
		nativeStartTimeMs = untyped __cpp__("
			(double)std::chrono::duration_cast<std::chrono::microseconds>(
				std::chrono::high_resolution_clock::now().time_since_epoch()
			).count() / 1000.0
		");
		#else
		nativeStartTimeMs = Sys.time() * 1000;
		#end
	}

	public static function getTimeSinceNativeStartMs():Float
	{
		if (nativeStartTimeMs < 0)
			return 0;

		#if cpp
		var now:Float = untyped __cpp__("
			(double)std::chrono::duration_cast<std::chrono::microseconds>(
				std::chrono::high_resolution_clock::now().time_since_epoch()
			).count() / 1000.0
		");
		#else
		var now:Float = Sys.time() * 1000;
		#end

		return now - nativeStartTimeMs;
	}
}
