package shark.online;

import haxe.Http;
import haxe.Json;
import haxe.Timer;
import shark.online.manager.Internet;
import shark.online.NetworkResponse;

class Network
{
	public static var defaultTimeoutMs:Int = 15000;
	public static var defaultRetries:Int = 2;
	public static var slowLatencyThresholdMs:Float = 500;

	static var activeRequests:Map<Int, Bool> = new Map();
	static var nextRequestId:Int = 0;

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

		activeRequests.set(requestId, true);

		var resolvedTimeout:Int = timeoutMs != null ? timeoutMs : resolveAdaptiveTimeout();
		var resolvedRetries:Int = retries != null ? retries : defaultRetries;

		runAttempt(requestId, url, method, headers, body, onComplete, resolvedTimeout, resolvedRetries, 0);

		return requestId;
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

	static function runAttempt(requestId:Int, url:String, method:String, headers:Map<String, String>, body:String, onComplete:NetworkResponse->Void,
			timeoutMs:Int, retries:Int, attemptNumber:Int):Void
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
			finishAttempt(state, requestId, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, "Request timed out");
		}, timeoutMs);

		httpRequest.onData = function(responseData:String):Void
		{
			if (state.finished)
				return;

			state.finished = true;
			timeoutHandle.stop();
			activeRequests.remove(requestId);

			if (onComplete != null)
				onComplete({success: true, status: state.statusCode, data: responseData});
		};

		httpRequest.onError = function(errorMessage:String):Void
		{
			finishAttempt(state, requestId, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, errorMessage, timeoutHandle);
		};

		sendRequest(httpRequest, method, body);
	}

	static function finishAttempt(state:{statusCode:Int, finished:Bool}, requestId:Int, url:String, method:String, headers:Map<String, String>,
			body:String, onComplete:NetworkResponse->Void, timeoutMs:Int, retries:Int, attemptNumber:Int, errorMessage:String, ?timeoutHandle:Timer):Void
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
				runAttempt(requestId, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber + 1);
			}, backoffMs);

			return;
		}

		activeRequests.remove(requestId);

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
}
