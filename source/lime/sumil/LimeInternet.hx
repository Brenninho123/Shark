package lime.sumil;

import flixel.FlxG;

#if sys
import sys.net.Socket;
import sys.net.Host;
import sys.thread.Thread;
import haxe.Timer;
#end

class LimeInternet
{
	public static var isReachable(default, null):Bool = false;
	public static var lastCheckLatencyMs(default, null):Float = -1;
	public static var isSupported(default, null):Bool;

	public static var checkHost:String = "8.8.8.8";
	public static var checkPort:Int = 53;
	public static var checkTimeoutSeconds:Float = 3;

	static var initialized:Bool = false;
	static var isChecking:Bool = false;

	static var resultReady:Bool = false;
	static var pendingResult:Bool = false;
	static var pendingLatency:Float = -1;
	static var pendingCallback:Bool->Void;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		#if sys
		isSupported = true;
		#else
		isSupported = false;
		#end

		if (isSupported)
			FlxG.signals.postUpdate.add(poll);
	}

	public static function checkReachability(?onResult:Bool->Void):Void
	{
		#if sys
		if (!isSupported)
		{
			if (onResult != null)
				onResult(false);

			return;
		}

		if (isChecking)
			return;

		isChecking = true;
		pendingCallback = onResult;

		var host:String = checkHost;
		var port:Int = checkPort;
		var timeout:Float = checkTimeoutSeconds;

		Thread.create(function():Void
		{
			var reachable:Bool = false;
			var start:Float = Timer.stamp();

			try
			{
				var socket = new Socket();
				socket.setTimeout(timeout);
				socket.connect(new Host(host), port);
				socket.close();
				reachable = true;
			}
			catch (e:Dynamic)
			{
				reachable = false;
			}

			var latency:Float = (Timer.stamp() - start) * 1000;

			pendingResult = reachable;
			pendingLatency = reachable ? latency : -1;
			resultReady = true;
		});
		#else
		if (onResult != null)
			onResult(false);
		#end
	}

	static function poll():Void
	{
		if (!resultReady)
			return;

		resultReady = false;
		isChecking = false;
		isReachable = pendingResult;
		lastCheckLatencyMs = pendingLatency;

		if (pendingCallback != null)
		{
			var callback:Bool->Void = pendingCallback;
			pendingCallback = null;
			callback(pendingResult);
		}
	}
}
