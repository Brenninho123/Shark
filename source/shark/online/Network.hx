package shark.online;

import haxe.Http;
import haxe.Json;
import haxe.Timer;
import shark.online.manager.Internet;
import shark.online.NetworkResponse;
import shark.ui.debug.CrasherLog;
import lime.manager.LimeManager;

class Network
{
	public static var defaultTimeoutMs:Int = 15000;
	public static var defaultRetries:Int = 2;
	public static var slowLatencyThresholdMs:Float = 500;
	public static var attachUserAgent:Bool = true;

	public static var circuitBreakerThreshold:Int = 5;
	public static var circuitBreakerCooldownSeconds:Float = 30;

	public static var totalRequests(default, null):Int = 0;
	public static var totalFailures(default, null):Int = 0;
	public static var totalBytesReceived(default, null):Int = 0;

	static var activeRequests:Map<Int, Bool> = new Map();
	static var nextRequestId:Int = 0;

	static var hostFailures:Map<String, Int> = new Map();
	static var hostCooldownUntil:Map<String, Float> = new Map();

	public static function get(url:String, ?headers:Map<String, String>, ?onComplete:NetworkResponse->Void, ?timeoutMs:Int):Int
	{
		return request(url, "GET", headers, null, onComplete, timeoutMs, 0);
	}

	public static function postJson(url:String, payload:Dynamic, ?headers:Map<String, String>, ?onComplete:NetworkResponse->Void, ?timeoutMs:Int,
			?retries:Int):Int
	{
		var mergedHeaders:Map<String, String> = headers != null ? headers : new Map();
		mergedHeaders.set("Content-Type", "application/json");

		var body:String = Json.stringify(payload);

		return request(url, "POST", mergedHeaders, body, onComplete, timeoutMs, retries);
	}

	public static function request(url:String, method:String, ?headers:Map<String, String>, ?body:String, ?onComplete:NetworkResponse->Void,
			?timeoutMs:Int, ?retries:Int):Int
	{
		var requestId:Int = nextRequestId;
		nextRequestId = nextRequestId + 1;

		var host:String = extractHost(url);

		if (isHostInCooldown(host))
		{
			totalFailures++;

			if (onComplete != null)
				onComplete({success: false, status: 0, data: "", error: "Host temporarily unavailable (circuit open)"});

			return requestId;
		}

		activeRequests.set(requestId, true);
		totalRequests++;

		var resolvedTimeout:Int = timeoutMs != null ? timeoutMs : resolveAdaptiveTimeout();
		var resolvedRetries:Int = retries != null ? retries : defaultRetries;
		var mergedHeaders:Map<String, String> = mergeUserAgent(headers);

		runAttempt(requestId, url, host, method, mergedHeaders, body, onComplete, resolvedTimeout, resolvedRetries, 0);

		return requestId;
	}

	static function mergeUserAgent(headers:Map<String, String>):Map<String, String>
	{
		if (!attachUserAgent)
			return headers;

		var result:Map<String, String> = headers != null ? headers : new Map();

		if (!result.exists("User-Agent"))
			result.set("User-Agent", 'Shark/${LimeManager.buildVersion} (${LimeManager.getPlatformName()})');

		return result;
	}

	static function extractHost(url:String):String
	{
		var schemeEnd:Int = url.indexOf("://");

		if (schemeEnd == -1)
			return url;

		var rest:String = url.substr(schemeEnd + 3);
		var endIndex:Int = rest.length;

		for (marker in ["/", "?", "#", ":"])
		{
			var idx:Int = rest.indexOf(marker);

			if (idx != -1 && idx < endIndex)
				endIndex = idx;
		}

		return rest.substr(0, endIndex).toLowerCase();
	}

	static function isHostInCooldown(host:String):Bool
	{
		if (!hostCooldownUntil.exists(host))
			return false;

		var until:Float = hostCooldownUntil.get(host);

		if (Timer.stamp() >= until)
		{
			hostCooldownUntil.remove(host);
			hostFailures.set(host, 0);
			return false;
		}

		return true;
	}

	static function registerHostFailure(host:String):Void
	{
		var count:Int = (hostFailures.exists(host) ? hostFailures.get(host) : 0) + 1;
		hostFailures.set(host, count);

		if (count >= circuitBreakerThreshold)
		{
			hostCooldownUntil.set(host, Timer.stamp() + circuitBreakerCooldownSeconds);
			CrasherLog.logWarning('Circuit breaker opened for $host after $count consecutive failures');
		}
	}

	static function registerHostSuccess(host:String):Void
	{
		hostFailures.set(host, 0);
	}

	public static function cancel(requestId:Int):Void
	{
		activeRequests.remove(requestId);
	}

	public static function cancelAll():Void
	{
		activeRequests = new Map();
	}

	static function resolveAdaptiveTimeout():Int
	{
		var latency:Float = Internet.latencyMs;

		if (latency > slowLatencyThresholdMs)
			return defaultTimeoutMs * 2;

		return defaultTimeoutMs;
	}

	static function isStillActive(requestId:Int):Bool
	{
		return activeRequests.exists(requestId);
	}

	static function runAttempt(requestId:Int, url:String, host:String, method:String, headers:Map<String, String>, body:String,
			onComplete:NetworkResponse->Void, timeoutMs:Int, retries:Int, attemptNumber:Int):Void
	{
		if (!isStillActive(requestId))
			return;

		var httpRequest:Http = new Http(url);
		attachHeaders(httpRequest, headers);

		var state = {
			statusCode: 0,
			finished: false
		};

		httpRequest.onStatus = function(status:Int):Void
		{
			state.statusCode = status;
		};

		var timeoutHandle:Timer = Timer.delay(function():Void
		{
			finishAttempt(state, requestId, url, host, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, "Request timed out");
		}, timeoutMs);

		httpRequest.onData = function(responseData:String):Void
		{
			if (state.finished)
				return;

			state.finished = true;
			timeoutHandle.stop();
			activeRequests.remove(requestId);

			totalBytesReceived += responseData.length;
			registerHostSuccess(host);

			if (onComplete != null)
				onComplete({success: true, status: state.statusCode, data: responseData});
		};

		httpRequest.onError = function(errorMessage:String):Void
		{
			finishAttempt(state, requestId, url, host, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, errorMessage, timeoutHandle);
		};

		sendRequest(httpRequest, method, body);
	}

	static function finishAttempt(state:{statusCode:Int, finished:Bool}, requestId:Int, url:String, host:String, method:String,
			headers:Map<String, String>, body:String, onComplete:NetworkResponse->Void, timeoutMs:Int, retries:Int, attemptNumber:Int, errorMessage:String,
			?timeoutHandle:Timer):Void
	{
		if (state.finished)
			return;

		state.finished = true;

		if (timeoutHandle != null)
			timeoutHandle.stop();

		if (!isStillActive(requestId))
			return;

		var isRetryable:Bool = state.statusCode != 400 && state.statusCode != 401 && state.statusCode != 403;

		if (isRetryable && attemptNumber < retries)
		{
			var backoffMs:Int = Std.int(Math.pow(2, attemptNumber + 1) * 500);

			Timer.delay(function():Void
			{
				runAttempt(requestId, url, host, method, headers, body, onComplete, timeoutMs, retries, attemptNumber + 1);
			}, backoffMs);

			return;
		}

		activeRequests.remove(requestId);
		totalFailures++;
		registerHostFailure(host);

		CrasherLog.logWarning('Request to $host failed after ${attemptNumber + 1} attempt(s): $errorMessage');

		if (onComplete != null)
			onComplete({success: false, status: state.statusCode, data: "", error: errorMessage});
	}

	static function attachHeaders(httpRequest:Http, headers:Map<String, String>):Void
	{
		if (headers == null)
			return;

		for (headerName in headers.keys())
			httpRequest.setHeader(headerName, headers.get(headerName));
	}

	static function sendRequest(httpRequest:Http, method:String, body:String):Void
	{
		if (method == "POST")
		{
			if (body != null)
				httpRequest.setPostData(body);

			httpRequest.request(true);
			return;
		}

		httpRequest.request(false);
	}

	public static function getStatsSummary():String
	{
		var failureRate:Float = totalRequests > 0 ? (totalFailures / totalRequests) * 100 : 0;
		return 'Requests: $totalRequests | Failures: $totalFailures (${Math.round(failureRate)}%) | Received: ${Math.round(totalBytesReceived / 1024)}KB';
	}
}
