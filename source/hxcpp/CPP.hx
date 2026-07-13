package hxcpp;

#if cpp
import cpp.vm.Gc;
#end

@:headerCode('
#include <thread>
#include <cmath>
#include <chrono>
')
class CPP
{
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
}
