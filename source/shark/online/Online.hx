package shark.online;

import haxe.Http;
import haxe.Timer;
import haxe.Json;
import shark.ui.debug.CrasherLog;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

#if js
import js.Browser;
#end

typedef ConnectivityEvent = {
	timestamp:Float,
	online:Bool,
	?downtimeSeconds:Float,
	?latencyMs:Float,
	?qualityScore:Int
}

typedef PendingRequest = {
	id:Int,
	description:String,
	action:Void->Void,
	addedAt:Float
}

typedef PersistedStats = {
	totalOnlineSeconds:Float,
	totalTrackedSeconds:Float,
	longestUptimeStreakSeconds:Float,
	longestOfflineStreakSeconds:Float,
	totalSessions:Int
}

enum abstract CheckStrategy(Int)
{
	var AGGRESSIVE = 0;
	var BALANCED = 1;
	var BATTERY_SAVER = 2;
}

enum abstract QualityTier(Int)
{
	var EXCELLENT = 0;
	var GOOD = 1;
	var FAIR = 2;
	var POOR = 3;
	var OFFLINE_TIER = 4;
}

class Online
{
	public static var isOnline(default, null):Bool = false;
	public static var apiOnline(default, null):Bool = true;
	public static var isFlapping(default, null):Bool = false;
	public static var isPaused(default, null):Bool = false;

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

	public static var requiredFailuresForOffline:Int = 2;
	public static var requiredSuccessesForOnline:Int = 1;

	public static var consecutiveFailures(default, null):Int = 0;
	public static var lastCheckTime(default, null):Float = 0;
	public static var averageLatencyMs(default, null):Float = -1;
	public static var jitterMs(default, null):Float = 0;
	public static var bandwidthKbps(default, null):Float = -1;

	public static var customCheck:(Bool->Void)->Void;

	public static var apiCheckUrl(default, null):String;
	public static var apiCheckInterval:Float = 30;
	public static var apiConsecutiveFailures(default, null):Int = 0;
	public static var apiLatencyMs(default, null):Float = -1;
	public static var apiCircuitOpen(default, null):Bool = false;
	public static var apiCircuitFailureThreshold:Int = 5;
	public static var apiCircuitCooldownSeconds:Float = 60;

	public static var flappingWindowSeconds:Float = 120;
	public static var flappingThreshold:Int = 4;

	static var statusListeners:Array<Bool->Void> = [];
	static var qualityListeners:Array<String->Void> = [];
	static var apiStatusListeners:Array<Bool->Void> = [];

	static var onlineSeconds:Float = 0;
	static var totalTrackedSeconds:Float = 0;
	static var lastTrackTime:Float = -1;
	static var lastTransitionTime:Float = -1;

	static var uptimeStreakStart:Float = -1;
	static var offlineStreakStart:Float = -1;
	static var longestUptimeStreakSeconds:Float = 0;
	static var longestOfflineStreakSeconds:Float = 0;
	static var totalSessions:Int = 0;

	static var latencySamples:Array<Float> = [];
	static inline var LATENCY_SAMPLE_WINDOW:Int = 10;

	static var connectivityLog:Array<ConnectivityEvent> = [];
	static inline var MAX_LOG_ENTRIES:Int = 50;

	static var transitionTimestamps:Array<Float> = [];

	static var pendingFailureCount:Int = 0;
	static var pendingSuccessCount:Int = 0;

	static var retryQueue:Array<PendingRequest> = [];
	static var nextRequestId:Int = 0;

	static var currentOfflineInterval:Float;
	static var strategy:CheckStrategy = BALANCED;

	static var timer:Timer;
	static var apiTimer:Timer;
	static var isChecking:Bool = false;
	static var isApiChecking:Bool = false;
	static var isRunning:Bool = false;

	static var apiCircuitOpenedAt:Float = -1;

	static inline var PERSIST_PATH:String = "shark_connectivity.json";

	public static function start():Void
	{
		if (isRunning)
			return;

		isRunning = true;
		isPaused = false;
		currentOfflineInterval = offlineCheckIntervalBase;
		lastTrackTime = Timer.stamp();
		totalSessions++;

		loadStatsFromDisk();
		attachBrowserListeners();

		checkNow();
		scheduleNext();

		if (apiCheckUrl != null)
			scheduleNextApiCheck();
	}

	public static function stop():Void
	{
		isRunning = false;

		if (timer != null)
		{
			timer.stop();
			timer = null;
		}

		if (apiTimer != null)
		{
			apiTimer.stop();
			apiTimer = null;
		}

		saveStatsToDisk();
	}

	public static function pause():Void
	{
		if (!isRunning || isPaused)
			return;

		isPaused = true;
		trackUptime();

		if (timer != null)
			timer.stop();

		if (apiTimer != null)
			apiTimer.stop();
	}

	public static function resume():Void
	{
		if (!isRunning || !isPaused)
			return;

		isPaused = false;
		lastTrackTime = Timer.stamp();

		checkNow();
		scheduleNext();

		if (apiCheckUrl != null)
			scheduleNextApiCheck();
	}

	public static function configureApi(url:String):Void
	{
		apiCheckUrl = url;

		if (isRunning && !isPaused && apiTimer == null)
			scheduleNextApiCheck();
	}

	public static function setStrategy(value:CheckStrategy):Void
	{
		strategy = value;

		switch (value)
		{
			case AGGRESSIVE:
				onlineCheckInterval = 10;
				offlineCheckIntervalBase = 2;
				offlineCheckIntervalMax = 20;
			case BALANCED:
				onlineCheckInterval = 20;
				offlineCheckIntervalBase = 5;
				offlineCheckIntervalMax = 60;
			case BATTERY_SAVER:
				onlineCheckInterval = 60;
				offlineCheckIntervalBase = 15;
				offlineCheckIntervalMax = 180;
		}

		currentOfflineInterval = offlineCheckIntervalBase;
	}

	public static function addStatusListener(listener:Bool->Void):Void
	{
		if (statusListeners.indexOf(listener) == -1)
			statusListeners.push(listener);
	}

	public static function removeStatusListener(listener:Bool->Void):Void
	{
		statusListeners.remove(listener);
	}

	public static function addQualityListener(listener:String->Void):Void
	{
		if (qualityListeners.indexOf(listener) == -1)
			qualityListeners.push(listener);
	}

	public static function removeQualityListener(listener:String->Void):Void
	{
		qualityListeners.remove(listener);
	}

	public static function addApiStatusListener(listener:Bool->Void):Void
	{
		if (apiStatusListeners.indexOf(listener) == -1)
			apiStatusListeners.push(listener);
	}

	public static function removeApiStatusListener(listener:Bool->Void):Void
	{
		apiStatusListeners.remove(listener);
	}

	public static function enqueueRetry(description:String, action:Void->Void):Int
	{
		var id:Int = nextRequestId++;

		retryQueue.push({
			id: id,
			description: description,
			action: action,
			addedAt: Timer.stamp()
		});

		if (isOnline)
			flushRetryQueue();

		return id;
	}

	public static function cancelRetry(id:Int):Void
	{
		retryQueue = retryQueue.filter(function(request:PendingRequest):Bool
		{
			return request.id != id;
		});
	}

	public static function getPendingRetryCount():Int
	{
		return retryQueue.length;
	}

	static function flushRetryQueue():Void
	{
		if (retryQueue.length == 0)
			return;

		var pending:Array<PendingRequest> = retryQueue;
		retryQueue = [];

		for (request in pending)
		{
			try
			{
				request.action();
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Retry queue action "${request.description}" threw an error - dropped.');
			}
		}
	}

	static function scheduleNext():Void
	{
		if (!isRunning || isPaused)
			return;

		if (timer != null)
			timer.stop();

		var interval:Float = isOnline ? onlineCheckInterval : currentOfflineInterval;

		if (isFlapping)
			interval = Math.max(interval, currentOfflineInterval * 2);

		timer = new Timer(Std.int(interval * 1000));
		timer.run = function():Void
		{
			trackUptime();
			checkNow();
			scheduleNext();
		};
	}

	static function scheduleNextApiCheck():Void
	{
		if (!isRunning || isPaused || apiCheckUrl == null)
			return;

		if (apiTimer != null)
			apiTimer.stop();

		apiTimer = new Timer(Std.int(apiCheckInterval * 1000));
		apiTimer.run = function():Void
		{
			checkApiHealth();
			scheduleNextApiCheck();
		};
	}

	static function trackUptime():Void
	{
		var now:Float = Timer.stamp();

		if (lastTrackTime < 0)
		{
			lastTrackTime = now;
			return;
		}

		var elapsed:Float = now - lastTrackTime;
		lastTrackTime = now;

		totalTrackedSeconds += elapsed;

		if (isOnline)
			onlineSeconds += elapsed;

		updateStreaks(now);
	}

	static function updateStreaks(now:Float):Void
	{
		if (isOnline)
		{
			if (uptimeStreakStart < 0)
				uptimeStreakStart = now;

			var streak:Float = now - uptimeStreakStart;

			if (streak > longestUptimeStreakSeconds)
				longestUptimeStreakSeconds = streak;

			offlineStreakStart = -1;
		}
		else
		{
			if (offlineStreakStart < 0)
				offlineStreakStart = now;

			var streak:Float = now - offlineStreakStart;

			if (streak > longestOfflineStreakSeconds)
				longestOfflineStreakSeconds = streak;

			uptimeStreakStart = -1;
		}
	}

	public static function getUptimePercentage():Float
	{
		if (totalTrackedSeconds <= 0)
			return 100;

		return (onlineSeconds / totalTrackedSeconds) * 100;
	}

	public static function getLongestUptimeStreakSeconds():Float
	{
		return longestUptimeStreakSeconds;
	}

	public static function getLongestOfflineStreakSeconds():Float
	{
		return longestOfflineStreakSeconds;
	}

	public static function checkNow(?onResult:Bool->Void):Void
	{
		if (isChecking || isPaused)
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

		attemptCheckRace(checkUrls.copy(), onResult);
	}

	static function attemptCheckRace(urls:Array<String>, ?onResult:Bool->Void):Void
	{
		if (urls.length == 0)
		{
			isChecking = false;
			handleCheckResult(false, onResult);
			return;
		}

		var finished:Bool = false;
		var pendingCount:Int = urls.length;
		var startTime:Float = Timer.stamp();

		for (url in urls)
		{
			var http = new Http(url);

			var timeoutTimer = Timer.delay(function():Void
			{
				pendingCount--;

				if (!finished && pendingCount <= 0)
				{
					finished = true;
					isChecking = false;
					handleCheckResult(false, onResult);
				}
			}, checkTimeoutMs);

			http.onData = function(data:String):Void
			{
				pendingCount--;

				if (finished)
					return;

				finished = true;
				timeoutTimer.stop();
				isChecking = false;

				var elapsedMs:Float = (Timer.stamp() - startTime) * 1000;
				recordSample(elapsedMs, data.length);
				handleCheckResult(true, onResult);
			};

			http.onError = function(msg:String):Void
			{
				pendingCount--;

				if (!finished && pendingCount <= 0)
				{
					finished = true;
					isChecking = false;
					handleCheckResult(false, onResult);
				}
			};

			http.request(false);
		}
	}

	static function handleCheckResult(success:Bool, ?onResult:Bool->Void):Void
	{
		if (success)
		{
			pendingSuccessCount++;
			pendingFailureCount = 0;
			consecutiveFailures = 0;
			currentOfflineInterval = offlineCheckIntervalBase;

			if (pendingSuccessCount >= requiredSuccessesForOnline)
				setStatus(true);
		}
		else
		{
			pendingFailureCount++;
			pendingSuccessCount = 0;
			consecutiveFailures++;
			growOfflineInterval();

			if (pendingFailureCount >= requiredFailuresForOffline)
				setStatus(false);
		}

		if (onResult != null)
			onResult(success);
	}

	static function recordSample(latencyMs:Float, bytes:Int):Void
	{
		if (averageLatencyMs < 0)
			averageLatencyMs = latencyMs;
		else
			averageLatencyMs = averageLatencyMs * 0.7 + latencyMs * 0.3;

		latencySamples.push(latencyMs);

		if (latencySamples.length > LATENCY_SAMPLE_WINDOW)
			latencySamples.shift();

		jitterMs = computeJitter();

		if (latencyMs > 0 && bytes > 0)
		{
			var seconds:Float = latencyMs / 1000;
			var sampleKbps:Float = (bytes * 8 / 1024) / Math.max(seconds, 0.001);

			bandwidthKbps = bandwidthKbps < 0 ? sampleKbps : bandwidthKbps * 0.7 + sampleKbps * 0.3;
		}

		notifyQualityListeners();
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

	public static function getQualityScore():Int
	{
		if (!isOnline)
			return 0;

		var score:Float = 100;

		score -= Math.min(jitterMs / 2, 40);
		score -= Math.min(consecutiveFailures * 15, 45);
		score -= Math.min((100 - getUptimePercentage()) * 0.5, 20);

		if (isFlapping)
			score -= 15;

		return Std.int(Math.max(0, Math.min(100, score)));
	}

	public static function getQualityTier():QualityTier
	{
		if (!isOnline)
			return OFFLINE_TIER;

		var score:Int = getQualityScore();

		if (score >= 85)
			return EXCELLENT;

		if (score >= 65)
			return GOOD;

		if (score >= 40)
			return FAIR;

		return POOR;
	}

	public static function getStabilityLabel():String
	{
		if (!isOnline)
			return "offline";

		if (isFlapping)
			return "flapping";

		return switch (getQualityTier())
		{
			case EXCELLENT: "stable";
			case GOOD: "good";
			case FAIR: "variable";
			case POOR: "unstable";
			case OFFLINE_TIER: "offline";
		}
	}

	static function notifyQualityListeners():Void
	{
		var label:String = getStabilityLabel();

		for (listener in qualityListeners)
			listener(label);
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
			pendingFailureCount = 0;
			pendingSuccessCount = 0;

			recordTransition(value);

			if (onStatusChanged != null)
				onStatusChanged(value);

			for (listener in statusListeners)
				listener(value);

			notifyQualityListeners();

			if (value)
				flushRetryQueue();

			if (isRunning && !isPaused)
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

		transitionTimestamps.push(now);
		transitionTimestamps = transitionTimestamps.filter(function(t:Float):Bool
		{
			return now - t <= flappingWindowSeconds;
		});

		isFlapping = transitionTimestamps.length >= flappingThreshold;

		connectivityLog.push({
			timestamp: now,
			online: nowOnline,
			downtimeSeconds: downtime,
			latencyMs: averageLatencyMs,
			qualityScore: getQualityScore()
		});

		if (connectivityLog.length > MAX_LOG_ENTRIES)
			connectivityLog.shift();
	}

	static function checkApiHealth():Void
	{
		if (isApiChecking || apiCheckUrl == null || isPaused)
			return;

		if (apiCircuitOpen)
		{
			if (Timer.stamp() - apiCircuitOpenedAt < apiCircuitCooldownSeconds)
				return;
		}

		isApiChecking = true;

		var startTime:Float = Timer.stamp();
		var http = new Http(apiCheckUrl);
		var finished:Bool = false;

		var timeoutTimer = Timer.delay(function():Void
		{
			if (finished)
				return;

			finished = true;
			isApiChecking = false;
			handleApiResult(false);
		}, checkTimeoutMs);

		http.onData = function(data:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			isApiChecking = false;

			apiLatencyMs = (Timer.stamp() - startTime) * 1000;
			handleApiResult(true);
		};

		http.onError = function(msg:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			isApiChecking = false;
			handleApiResult(false);
		};

		http.request(false);
	}

	static function handleApiResult(success:Bool):Void
	{
		var wasOnline:Bool = apiOnline;

		if (success)
		{
			apiConsecutiveFailures = 0;
			apiCircuitOpen = false;
			apiOnline = true;
		}
		else
		{
			apiConsecutiveFailures++;
			apiOnline = false;

			if (apiConsecutiveFailures >= apiCircuitFailureThreshold && !apiCircuitOpen)
			{
				apiCircuitOpen = true;
				apiCircuitOpenedAt = Timer.stamp();
				CrasherLog.logWarning('API circuit opened for $apiCheckUrl after $apiConsecutiveFailures consecutive failures');
			}
		}

		if (wasOnline != apiOnline)
			for (listener in apiStatusListeners)
				listener(apiOnline);
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

	public static function resetStatistics():Void
	{
		onlineSeconds = 0;
		totalTrackedSeconds = 0;
		longestUptimeStreakSeconds = 0;
		longestOfflineStreakSeconds = 0;
		uptimeStreakStart = -1;
		offlineStreakStart = -1;
		latencySamples = [];
		averageLatencyMs = -1;
		jitterMs = 0;
		bandwidthKbps = -1;
		connectivityLog = [];
		transitionTimestamps = [];
		isFlapping = false;
		consecutiveFailures = 0;
		apiConsecutiveFailures = 0;
		apiCircuitOpen = false;
	}

	public static function getSummary():String
	{
		var lines:Array<String> = [];

		lines.push('status: ${isOnline ? "online" : "offline"} (${getStabilityLabel()}, score ${getQualityScore()})');
		lines.push('uptime: ${getUptimePercentage().toStringPrecision(1)}% over ${Std.int(totalTrackedSeconds)}s tracked');
		lines.push('latency: ${averageLatencyMs < 0 ? "n/a" : Std.int(averageLatencyMs) + "ms"}, jitter ${Std.int(jitterMs)}ms');
		lines.push('bandwidth: ${bandwidthKbps < 0 ? "n/a" : Std.int(bandwidthKbps) + " kbps"}');
		lines.push('failures: $consecutiveFailures consecutive');
		lines.push('longest streaks: ${Std.int(longestUptimeStreakSeconds)}s up / ${Std.int(longestOfflineStreakSeconds)}s down');
		lines.push('retry queue: ${retryQueue.length} pending');

		if (apiCheckUrl != null)
			lines.push('api: ${apiOnline ? "online" : "offline"}${apiCircuitOpen ? " (circuit open)" : ""}, latency ${apiLatencyMs < 0 ? "n/a" : Std.int(apiLatencyMs) + "ms"}');

		return lines.join("\n");
	}

	static function attachBrowserListeners():Void
	{
		#if js
		if (Browser.window == null)
			return;

		Browser.window.addEventListener("online", function(e:Dynamic):Void
		{
			checkNow();
		});

		Browser.window.addEventListener("offline", function(e:Dynamic):Void
		{
			pendingFailureCount = requiredFailuresForOffline;
			handleCheckResult(false);
		});
		#end
	}

	static function saveStatsToDisk():Void
	{
		#if sys
		try
		{
			var stats:PersistedStats = {
				totalOnlineSeconds: onlineSeconds,
				totalTrackedSeconds: totalTrackedSeconds,
				longestUptimeStreakSeconds: longestUptimeStreakSeconds,
				longestOfflineStreakSeconds: longestOfflineStreakSeconds,
				totalSessions: totalSessions
			};

			File.saveContent(PERSIST_PATH, Json.stringify(stats));
		}
		catch (e:Dynamic) {}
		#end
	}

	static function loadStatsFromDisk():Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists(PERSIST_PATH))
				return;

			var stats:PersistedStats = Json.parse(File.getContent(PERSIST_PATH));

			onlineSeconds = stats.totalOnlineSeconds;
			totalTrackedSeconds = stats.totalTrackedSeconds;
			longestUptimeStreakSeconds = stats.longestUptimeStreakSeconds;
			longestOfflineStreakSeconds = stats.longestOfflineStreakSeconds;
			totalSessions = stats.totalSessions;
		}
		catch (e:Dynamic) {}
		#end
	}
}
