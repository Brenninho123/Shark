package shark.online;

import haxe.Http;
import haxe.Timer;

class Online
{
	public static var isOnline(default, null):Bool = false;
	public static var onStatusChanged:Bool->Void;

	public static var checkUrls:Array<String> = [
		"https://www.google.com",
		"https://www.cloudflare.com",
		"https://www.apple.com"
	];

	public static var onlineCheckInterval:Float = 20;
	public static var offlineCheckInterval:Float = 5;
	public static var checkTimeoutMs:Int = 8000;

	public static var consecutiveFailures(default, null):Int = 0;
	public static var lastCheckTime(default, null):Float = 0;

	static var timer:Timer;
	static var isChecking:Bool = false;
	static var isRunning:Bool = false;

	public static function start():Void
	{
		isRunning = true;
		checkNow();
		scheduleNext();
	}

	public static function stop():Void
	{
		isRunning = false;

		if (timer != null)
		{
			timer.stop();
			timer = null;
		}
	}

	static function scheduleNext():Void
	{
		if (!isRunning)
			return;

		if (timer != null)
			timer.stop();

		var interval:Float = isOnline ? onlineCheckInterval : offlineCheckInterval;

		timer = new Timer(Std.int(interval * 1000));
		timer.run = function():Void
		{
			checkNow();
			scheduleNext();
		};
	}

	public static function checkNow(?onResult:Bool->Void):Void
	{
		if (isChecking)
			return;

		isChecking = true;
		lastCheckTime = Timer.stamp();

		attemptCheck(0, onResult);
	}

	static function attemptCheck(urlIndex:Int, ?onResult:Bool->Void):Void
	{
		if (urlIndex >= checkUrls.length)
		{
			isChecking = false;
			consecutiveFailures++;
			setStatus(false);

			if (onResult != null)
				onResult(false);

			return;
		}

		var http = new Http(checkUrls[urlIndex]);
		var finished:Bool = false;

		var timeoutTimer = Timer.delay(function():Void
		{
			if (finished)
				return;

			finished = true;
			attemptCheck(urlIndex + 1, onResult);
		}, checkTimeoutMs);

		http.onData = function(data:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();

			isChecking = false;
			consecutiveFailures = 0;
			setStatus(true);

			if (onResult != null)
				onResult(true);
		};

		http.onError = function(msg:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();

			attemptCheck(urlIndex + 1, onResult);
		};

		http.request(false);
	}

	static function setStatus(value:Bool):Void
	{
		var wasOnline:Bool = isOnline;
		isOnline = value;

		if (wasOnline != value)
		{
			if (onStatusChanged != null)
				onStatusChanged(value);

			if (isRunning)
				scheduleNext();
		}
	}
}
