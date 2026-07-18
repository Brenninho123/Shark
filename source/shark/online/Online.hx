package shark.online;

import haxe.Http;
import haxe.Timer;
import shark.ui.debug.CrasherLog;

typedef ConnectivityEvent = {
	timestamp:Float,
	online:Bool,
	?downtimeSeconds:Float
}

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
	public static var jitterMs(default, null):Float = 0;

	public static var customCheck:(Bool->Void)->Void;

	static var onlineSeconds:Float = 0;
	static var totalTrackedSeconds:Float = 0;
	static var lastTrackTime:Float = -1;
	static var lastTransitionTime:Float = -1;

	static var latencySamples:Array<Float> = [];
	static inline var LATENCY_SAMPLE_WINDOW:Int = 10;

	static var connectivityLog:Array<ConnectivityEvent> = [];
	static inline var MAX_LOG_ENTRIES:Int = 50;

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

		if (customCheck != null)
		{
			customCheck(function(success:Bool):Void
			{
				isChecking = false;
				handleCheckResult(success, onResult);
			});
			return;
		}

		attemptCheck(0, onResult);
	}

	static function attemptCheck(urlIndex:Int, ?onResult:Bool->Void):Void
	{
		if (urlIndex >= checkUrls.length)
		{
			isChecking = false;
			handleCheckResult(false, onResult);
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

			recordLatency((Timer.stamp() - startTime) * 1000);
			handleCheckResult(true, onResult);
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

	static function handleCheckResult(success:Bool, ?onResult:Bool->Void):Void
	{
		if (success)
		{
			consecutiveFailures = 0;
			currentOfflineInterval = offlineCheckIntervalBase;
		}
		else
		{
			consecutiveFailures++;
			growOfflineInterval();
		}

		setStatus(success);

		if (onResult != null)
			onResult(success);
	}

	static function recordLatency(sampleMs:Float):Void
	{
		if (averageLatencyMs < 0)
			averageLatencyMs = sampleMs;
		else
			averageLatencyMs = averageLatencyMs * 0.7 + sampleMs * 0.3;

		latencySamples.push(sampleMs);

		if (latencySamples.length > LATENCY_SAMPLE_WINDOW)
			latencySamples.shift();

		jitterMs = computeJitter();
	}

	static function computeJitter():Float
	{
		if (latencySamples.length < 2)
			return 0;

		var mean:Float = 0;

		for (sample in latencySamples)
			mean += sample;

		mean /= latencySamples.length;

		var variance:Float = 0;

		for (sample in latencySamples)
			variance += (sample - mean) * (sample - mean);

		variance /= latencySamples.length;

		return Math.sqrt(variance);
	}

	public static function getStabilityLabel():String
	{
		if (!isOnline)
			return "offline";

		if (jitterMs < 30)
			return "stable";

		if (jitterMs < 100)
			return "variable";

		return "unstable";
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
			recordTransition(value);

			if (onStatusChanged != null)
				onStatusChanged(value);

			if (isRunning)
				scheduleNext();
		}
	}

	static function recordTransition(nowOnline:Bool):Void
	{
		var now:Float = Timer.stamp();
		var downtime:Null<Float> = null;

		if (nowOnline && lastTransitionTime >= 0)
		{
			downtime = now - lastTransitionTime;
			CrasherLog.logWarning('Back online after ${Math.round(downtime)}s offline');
		}
		else if (!nowOnline)
		{
			CrasherLog.logWarning("Connection lost");
		}

		lastTransitionTime = now;

		connectivityLog.push({
			timestamp: now,
			online: nowOnline,
			downtimeSeconds: downtime
		});

		if (connectivityLog.length > MAX_LOG_ENTRIES)
			connectivityLog.shift();
	}

	public static function getConnectivityLog():Array<ConnectivityEvent>
	{
		return connectivityLog.copy();
	}

	public static function getLastDowntimeSeconds():Float
	{
		var i:Int = connectivityLog.length - 1;

		while (i >= 0)
		{
			if (connectivityLog[i].downtimeSeconds != null)
				return connectivityLog[i].downtimeSeconds;

			i--;
		}

		return 0;
	}
}
