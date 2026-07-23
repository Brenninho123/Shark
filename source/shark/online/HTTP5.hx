package shark.online;

import shark.online.NetworkResponse;

#if html5
import js.html.XMLHttpRequest;
import js.html.ProgressEvent;
import js.lib.ArrayBuffer;
import js.lib.Uint8Array;
#end

class HTTP5
{
	public static var isSupported(default, null):Bool;
	public static var defaultTimeoutMs:Int = 15000;

	public static function initialize():Void
	{
		#if html5
		isSupported = true;
		#else
		isSupported = false;
		#end
	}

	public static function request(url:String, method:String = "GET", ?headers:Map<String, String>, ?body:String, ?onComplete:NetworkResponse->Void,
			?onProgress:Float->Void, ?timeoutMs:Int):Void->Void
	{
		#if html5
		var xhr = new XMLHttpRequest();
		xhr.open(method, url, true);
		xhr.timeout = timeoutMs != null ? timeoutMs : defaultTimeoutMs;

		if (headers != null)
			for (headerName in headers.keys())
				xhr.setRequestHeader(headerName, headers.get(headerName));

		var finished:Bool = false;

		xhr.onload = function(e:Dynamic):Void
		{
			if (finished)
				return;

			finished = true;

			var success:Bool = xhr.status >= 200 && xhr.status < 300;

			if (onComplete != null)
				onComplete({
					success: success,
					status: xhr.status,
					data: xhr.responseText,
					error: success ? null : 'HTTP ${xhr.status}'
				});
		};

		xhr.onerror = function(e:Dynamic):Void
		{
			if (finished)
				return;

			finished = true;

			if (onComplete != null)
				onComplete({
					success: false,
					status: xhr.status,
					data: "",
					error: "Network error (possibly CORS - check the server allows this origin)"
				});
		};

		xhr.ontimeout = function(e:Dynamic):Void
		{
			if (finished)
				return;

			finished = true;

			if (onComplete != null)
				onComplete({success: false, status: 0, data: "", error: "Request timed out"});
		};

		if (onProgress != null)
		{
			xhr.onprogress = function(e:ProgressEvent):Void
			{
				if (e.lengthComputable)
					onProgress(e.loaded / e.total);
			};
		}

		xhr.send(body);

		return function():Void
		{
			if (!finished)
			{
				finished = true;
				xhr.abort();
			}
		};
		#else
		if (onComplete != null)
			onComplete({success: false, status: 0, data: "", error: "HTTP5 is only available on the html5 target"});

		return function():Void {};
		#end
	}

	public static function requestBinary(url:String, ?headers:Map<String, String>, ?onComplete:(Bool, haxe.io.Bytes, String) -> Void,
			?onProgress:Float->Void, ?timeoutMs:Int):Void->Void
	{
		#if html5
		var xhr = new XMLHttpRequest();
		xhr.open("GET", url, true);
		xhr.responseType = ARRAYBUFFER;
		xhr.timeout = timeoutMs != null ? timeoutMs : defaultTimeoutMs;

		if (headers != null)
			for (headerName in headers.keys())
				xhr.setRequestHeader(headerName, headers.get(headerName));

		var finished:Bool = false;

		xhr.onload = function(e:Dynamic):Void
		{
			if (finished)
				return;

			finished = true;

			var success:Bool = xhr.status >= 200 && xhr.status < 300;

			if (!success)
			{
				if (onComplete != null)
					onComplete(false, null, 'HTTP ${xhr.status}');

				return;
			}

			var buffer:ArrayBuffer = cast xhr.response;
			var bytes:haxe.io.Bytes = haxe.io.Bytes.ofData(cast new Uint8Array(buffer));

			if (onComplete != null)
				onComplete(true, bytes, null);
		};

		xhr.onerror = function(e:Dynamic):Void
		{
			if (finished)
				return;

			finished = true;

			if (onComplete != null)
				onComplete(false, null, "Network error (possibly CORS)");
		};

		xhr.ontimeout = function(e:Dynamic):Void
		{
			if (finished)
				return;

			finished = true;

			if (onComplete != null)
				onComplete(false, null, "Request timed out");
		};

		if (onProgress != null)
		{
			xhr.onprogress = function(e:ProgressEvent):Void
			{
				if (e.lengthComputable)
					onProgress(e.loaded / e.total);
			};
		}

		xhr.send();

		return function():Void
		{
			if (!finished)
			{
				finished = true;
				xhr.abort();
			}
		};
		#else
		if (onComplete != null)
			onComplete(false, null, "HTTP5 is only available on the html5 target");

		return function():Void {};
		#end
	}
}
