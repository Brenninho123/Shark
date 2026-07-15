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
	public static var offlineCheckIntervalBase:Float = 5;
	public static var offlineCheckIntervalMax:Float = 60;
	public static var checkTimeoutMs:Int = 8000;

	public static var consecutiveFailures(default, null):Int = 0;
	public static var lastCheckTime(default, null):Float = 0;
	public static var averageLatencyMs(default, null):Float = -1;

	static var onlineSeconds:Float = 0;
	static var totalTrackedSeconds:Float = 0;
	static var lastTrackTime:Float = -1;

	static var currentOfflineInterval:Float;

	static var timer:Timer;
	static var isChecking:Bool = false;
	static var isRunning:Bool = false;

	public static function start():Void
	{
		isRunning = true;
		currentOfflineInterval = offlineCheckIntervalBase;
		lastTrackTime = Timer.stamp();

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

		var interval:Float = isOnline ? onlineCheckInterval : currentOfflineInterval;

		timer = new Timer(Std.int(interval * 1000));
		timer.run = function():Void
		{
			trackUptime();
			checkNow();
			scheduleNext();
		};
	}

	static function trackUptime():Void
	{
		if (lastTrackTime < 0)
		{
			lastTrackTime = Timer.stamp();
			return;
		}

		var now:Float = Timer.stamp();
		var elapsed:Float = now - lastTrackTime;
		lastTrackTime = now;

		totalTrackedSeconds += elapsed;

		if (isOnline)
			onlineSeconds += elapsed;
	}

	public static function getUptimePercentage():Float
	{
		if (totalTrackedSeconds <= 0)
			return 100;

		return (onlineSeconds / totalTrackedSeconds) * 100;
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
			growOfflineInterval();
			setStatus(false);

			if (onResult != null)
				onResult(false);

			return;
		}

		var startTime:Float = Timer.stamp();
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
			currentOfflineInterval = offlineCheckIntervalBase;

			recordLatency((Timer.stamp() - startTime) * 1000);
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

	static function recordLatency(sampleMs:Float):Void
	{
		if (averageLatencyMs < 0)
		{
			averageLatencyMs = sampleMs;
			return;
		}

		averageLatencyMs = averageLatencyMs * 0.7 + sampleMs * 0.3;
	}

	static function growOfflineInterval():Void
	{
		currentOfflineInterval = Math.min(currentOfflineInterval * 1.5, offlineCheckIntervalMax);
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
