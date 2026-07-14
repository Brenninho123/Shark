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

	public static function request(url:String, method:String, ?headers:Map<String, String>, ?body:String, onComplete:NetworkResponse->Void, ?timeoutMs:Int,
			?retries:Int):Int
	{
		var id:Int = nextRequestId++;
		activeRequests.set(id, true);

		var resolvedTimeout:Int = timeoutMs != null ? timeoutMs : adaptiveTimeout();
		var resolvedRetries:Int = retries != null ? retries : defaultRetries;

		attempt(id, url, method, headers, body, onComplete, resolvedTimeout, resolvedRetries, 0);

		return id;
	}

	public static function get(url:String, ?headers:Map<String, String>, onComplete:NetworkResponse->Void, ?timeoutMs:Int):Int
	{
		return request(url, "GET", headers, null, onComplete, timeoutMs, 0);
	}

	public static function postJson(url:String, payload:Dynamic, ?headers:Map<String, String>, onComplete:NetworkResponse->Void, ?timeoutMs:Int,
			?retries:Int):Int
	{
		var resolvedHeaders:Map<String, String> = headers != null ? headers : new Map();
		resolvedHeaders.set("Content-Type", "application/json");

		return request(url, "POST", resolvedHeaders, Json.stringify(payload), onComplete, timeoutMs, retries);
	}

	public static function cancel(id:Int):Void
	{
		activeRequests.remove(id);
	}

	public static function cancelAll():Void
	{
		activeRequests = new Map();
	}

	static function adaptiveTimeout():Int
	{
		if (Internet.latencyMs > slowLatencyThresholdMs)
			return defaultTimeoutMs * 2;

		return defaultTimeoutMs;
	}

	static function attempt(id:Int, url:String, method:String, ?headers:Map<String, String>, ?body:String, onComplete:NetworkResponse->Void, timeoutMs:Int,
			retries:Int, attemptNumber:Int):Void
	{
		if (!activeRequests.exists(id))
			return;

		var http = new Http(url);

		if (headers != null)
			for (key in headers.keys())
				http.setHeader(key, headers.get(key));

		var statusCode:Int = 0;
		var finished:Bool = false;

		http.onStatus = function(status:Int):Void
		{
			statusCode = status;
		};

		var timeoutTimer = Timer.delay(function():Void
		{
			if (finished)
				return;

			finished = true;
			retryOrFail(id, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, statusCode, "Request timed out");
		}, timeoutMs);

		http.onData = function(data:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			activeRequests.remove(id);

			onComplete({success: true, status: statusCode, data: data});
		};

		http.onError = function(msg:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			retryOrFail(id, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, statusCode, msg);
		};

		if (method == "POST")
		{
			if (body != null)
				http.setPostData(body);

			http.request(true);
		}
		else
		{
			http.request(false);
		}
	}

	static function retryOrFail(id:Int, url:String, method:String, ?headers:Map<String, String>, ?body:String, onComplete:NetworkResponse->Void,
			timeoutMs:Int, retries:Int, attemptNumber:Int, statusCode:Int, errorMessage:String):Void
	{
		if (!activeRequests.exists(id))
			return;

		var isRetryable:Bool = statusCode != 400 && statusCode != 401 && statusCode != 403;

		if (isRetryable && attemptNumber < retries)
		{
			var backoff:Int = Std.int(Math.pow(2, attemptNumber + 1) * 500);

			Timer.delay(function():Void
			{
				attempt(id, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber + 1);
			}, backoff);

			return;
		}

		activeRequests.remove(id);
		onComplete({success: false, status: statusCode, data: "", error: errorMessage});
	}
}

	public static function get(url:String, ?headers:Map<String, String>, onComplete:NetworkResponse->Void, ?timeoutMs:Int):Int
	{
		return request(url, "GET", headers, null, onComplete, timeoutMs, 0);
	}

	public static function postJson(url:String, payload:Dynamic, ?headers:Map<String, String>, onComplete:NetworkResponse->Void, ?timeoutMs:Int,
			?retries:Int):Int
	{
		var resolvedHeaders:Map<String, String> = headers != null ? headers : new Map();
		resolvedHeaders.set("Content-Type", "application/json");

		return request(url, "POST", resolvedHeaders, Json.stringify(payload), onComplete, timeoutMs, retries);
	}

	public static function cancel(id:Int):Void
	{
		activeRequests.remove(id);
	}

	public static function cancelAll():Void
	{
		activeRequests = new Map();
	}

	static function adaptiveTimeout():Int
	{
		if (Internet.latencyMs > slowLatencyThresholdMs)
			return defaultTimeoutMs * 2;

		return defaultTimeoutMs;
	}

	static function attempt(id:Int, url:String, method:String, ?headers:Map<String, String>, ?body:String, onComplete:NetworkResponse->Void, timeoutMs:Int,
			retries:Int, attemptNumber:Int):Void
	{
		if (!activeRequests.exists(id))
			return;

		var http = new Http(url);

		if (headers != null)
			for (key in headers.keys())
				http.setHeader(key, headers.get(key));

		var statusCode:Int = 0;
		var finished:Bool = false;

		http.onStatus = function(status:Int):Void
		{
			statusCode = status;
		};

		var timeoutTimer = Timer.delay(function():Void
		{
			if (finished)
				return;

			finished = true;
			retryOrFail(id, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, statusCode, "Request timed out");
		}, timeoutMs);

		http.onData = function(data:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			activeRequests.remove(id);

			onComplete({success: true, status: statusCode, data: data});
		};

		http.onError = function(msg:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			retryOrFail(id, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber, statusCode, msg);
		};

		if (method == "POST")
		{
			if (body != null)
				http.setPostData(body);

			http.request(true);
		}
		else
		{
			http.request(false);
		}
	}

	static function retryOrFail(id:Int, url:String, method:String, ?headers:Map<String, String>, ?body:String, onComplete:NetworkResponse->Void,
			timeoutMs:Int, retries:Int, attemptNumber:Int, statusCode:Int, errorMessage:String):Void
	{
		if (!activeRequests.exists(id))
			return;

		var isRetryable:Bool = statusCode != 400 && statusCode != 401 && statusCode != 403;

		if (isRetryable && attemptNumber < retries)
		{
			var backoff:Int = Std.int(Math.pow(2, attemptNumber + 1) * 500);

			Timer.delay(function():Void
			{
				attempt(id, url, method, headers, body, onComplete, timeoutMs, retries, attemptNumber + 1);
			}, backoff);

			return;
		}

		activeRequests.remove(id);
		onComplete({success: false, status: statusCode, data: "", error: errorMessage});
	}
}
