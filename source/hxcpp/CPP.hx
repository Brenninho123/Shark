package hxcpp;

#if cpp
import cpp.vm.Gc;
#end

@:headerCode('
#include <thread>
#include <cmath>
#include <chrono>
#include <random>
#ifdef _WIN32
#include <process.h>
#else
#include <unistd.h>
#endif
')
class CPP
{
	static var startTimeMs:Float = -1;

	public static function isSupported():Bool
	{
		#if cpp
		return true;
		#else
		return false;
		#end
	}

	public static function getMemoryUsageMB():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_USAGE) / 1024 / 1024;
		#else
		return 0;
		#end
	}

	public static function getMemoryReservedMB():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_RESERVED) / 1024 / 1024;
		#else
		return 0;
		#end
	}

	public static function collectGarbage(major:Bool = true):Void
	{
		#if cpp
		Gc.run(major);
		#end
	}

	public static function enableGc(enabled:Bool):Void
	{
		#if cpp
		Gc.enable(enabled);
		#end
	}

	public static function getCpuCoreCount():Int
	{
		#if cpp
		return untyped __cpp__("(int)std::thread::hardware_concurrency()");
		#else
		return 1;
		#end
	}

	public static function getProcessId():Int
	{
		#if cpp
		return untyped __cpp__("
			#ifdef _WIN32
				_getpid()
			#else
				(int)getpid()
			#endif
		");
		#else
		return 0;
		#end
	}

	public static function fastDistance(x1:Float, y1:Float, x2:Float, y2:Float):Float
	{
		#if cpp
		return untyped __cpp__("std::sqrt(({0} - {2}) * ({0} - {2}) + ({1} - {3}) * ({1} - {3}))", x1, y1, x2, y2);
		#else
		var dx:Float = x2 - x1;
		var dy:Float = y2 - y1;
		return Math.sqrt(dx * dx + dy * dy);
		#end
	}

	public static function fastDistanceSquared(x1:Float, y1:Float, x2:Float, y2:Float):Float
	{
		#if cpp
		return untyped __cpp__("(({0} - {2}) * ({0} - {2}) + ({1} - {3}) * ({1} - {3}))", x1, y1, x2, y2);
		#else
		var dx:Float = x2 - x1;
		var dy:Float = y2 - y1;
		return dx * dx + dy * dy;
		#end
	}

	public static function fastLerp(a:Float, b:Float, t:Float):Float
	{
		#if cpp
		return untyped __cpp__("{0} + ({1} - {0}) * {2}", a, b, t);
		#else
		return a + (b - a) * t;
		#end
	}

	public static function getHighResTimeMs():Float
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

	public static function getUptimeSeconds():Float
	{
		if (startTimeMs < 0)
			startTimeMs = getHighResTimeMs();

		return (getHighResTimeMs() - startTimeMs) / 1000;
	}

	public static function clampInt(value:Int, min:Int, max:Int):Int
	{
		#if cpp
		return untyped __cpp__("({0} < {1} ? {1} : ({0} > {2} ? {2} : {0}))", value, min, max);
		#else
		if (value < min)
			return min;
		if (value > max)
			return max;
		return value;
		#end
	}

	public static function secureRandomInt(min:Int, max:Int):Int
	{
		#if cpp
		return untyped __cpp__("
			[](int lo, int hi) {
				static std::random_device rd;
				static std::mt19937 gen(rd());
				std::uniform_int_distribution<int> dist(lo, hi);
				return dist(gen);
			}({0}, {1})
		", min, max);
		#else
		return min + Std.random(max - min + 1);
		#end
	}

	public static function fnv1aHash(text:String):Int
	{
		var hash:Int = 0x811C9DC5;

		for (i in 0...text.length)
		{
			hash = hash ^ text.charCodeAt(i);

			#if cpp
			hash = untyped __cpp__("({0} * 16777619)", hash);
			#else
			hash = hash * 16777619;
			#end
		}

		return hash;
	}
}
