package hxcpp;

#if cpp
import cpp.vm.Gc;
import sys.thread.Mutex;
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

	public static function fastMin(a:Float, b:Float):Float
	{
		#if cpp
		return untyped __cpp__("({0} < {1} ? {0} : {1})", a, b);
		#else
		return a < b ? a : b;
		#end
	}

	public static function fastMax(a:Float, b:Float):Float
	{
		#if cpp
		return untyped __cpp__("({0} > {1} ? {0} : {1})", a, b);
		#else
		return a > b ? a : b;
		#end
	}

	public static function fastAbs(value:Float):Float
	{
		#if cpp
		return untyped __cpp__("std::fabs({0})", value);
		#else
		return value < 0 ? -value : value;
		#end
	}

	public static function fastSign(value:Float):Int
	{
		#if cpp
		return untyped __cpp__("({0} > 0.0 ? 1 : ({0} < 0.0 ? -1 : 0))", value);
		#else
		if (value > 0)
			return 1;
		if (value < 0)
			return -1;
		return 0;
		#end
	}

	public static function fastFloor(value:Float):Int
	{
		#if cpp
		return untyped __cpp__("(int)std::floor({0})", value);
		#else
		return Std.int(Math.floor(value));
		#end
	}

	public static function fastCeil(value:Float):Int
	{
		#if cpp
		return untyped __cpp__("(int)std::ceil({0})", value);
		#else
		return Std.int(Math.ceil(value));
		#end
	}

	public static function isFiniteNumber(value:Float):Bool
	{
		#if cpp
		return untyped __cpp__("std::isfinite({0})", value);
		#else
		return Math.isFinite(value);
		#end
	}

	static var countersMutex:Mutex;
	static var counters:Map<String, Int> = new Map();

	static function ensureCountersMutex():Void
	{
		#if cpp
		if (countersMutex == null)
			countersMutex = new Mutex();
		#end
	}

	public static function incrementCounter(name:String, amount:Int = 1):Int
	{
		#if cpp
		ensureCountersMutex();
		countersMutex.acquire();

		var value:Int = (counters.exists(name) ? counters.get(name) : 0) + amount;
		counters.set(name, value);

		countersMutex.release();

		return value;
		#else
		var value:Int = (counters.exists(name) ? counters.get(name) : 0) + amount;
		counters.set(name, value);
		return value;
		#end
	}

	public static function getCounter(name:String):Int
	{
		return counters.exists(name) ? counters.get(name) : 0;
	}

	public static function resetCounter(name:String):Void
	{
		#if cpp
		ensureCountersMutex();
		countersMutex.acquire();
		counters.set(name, 0);
		countersMutex.release();
		#else
		counters.set(name, 0);
		#end
	}
}
