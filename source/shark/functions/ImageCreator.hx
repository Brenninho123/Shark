package shark.functions;

import haxe.Http;
import haxe.Json;
import haxe.Timer;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.utils.ByteArray;
import shark.mobile.StorageUtil;
import shark.online.Online;

typedef ImageRequest = {
	prompt:String,
	onComplete:BitmapData->Void,
	onError:String->Void,
	width:Int,
	height:Int,
	attempts:Int,
	token:Int
}

class ImageCreator
{
	public static var endpoint:String = "";
	public static var apiKey:String = "";
	public static var maxRetries:Int = 2;
	public static var minRequestInterval:Float = 1.0;
	public static var maxPromptLength:Int = 1000;
	public static var requireOnline:Bool = true;
	public static var autoSaveToStorage:Bool = true;
	public static var cacheEnabled:Bool = true;
	public static var decodeTimeoutMs:Int = 15000;

	static var queue:Array<ImageRequest> = [];
	static var isBusy:Bool = false;
	static var lastRequestTime:Float = 0;
	static var currentToken:Int = 0;

	static var imageCache:Map<String, BitmapData> = new Map();

	public static function generate(prompt:String, onComplete:BitmapData->Void, onError:String->Void, width:Int = 512, height:Int = 512):Void
	{
		var trimmed:String = StringTools.trim(prompt);

		if (trimmed.length == 0)
		{
			onError("Image description is empty");
			return;
		}

		if (trimmed.length > maxPromptLength)
		{
			onError('Description exceeds $maxPromptLength characters');
			return;
		}

		if (requireOnline && !Online.isOnline)
		{
			onError("No internet connection");
			return;
		}

		var cacheKey:String = buildCacheKey(trimmed, width, height);

		if (cacheEnabled && imageCache.exists(cacheKey))
		{
			onComplete(imageCache.get(cacheKey));
			return;
		}

		queue.push({
			prompt: trimmed,
			onComplete: onComplete,
			onError: onError,
			width: width,
			height: height,
			attempts: 0,
			token: currentToken
		});

		processQueue();
	}

	public static function cancelPending():Void
	{
		queue = [];
		currentToken++;
		isBusy = false;
	}

	static function buildCacheKey(prompt:String, width:Int, height:Int):String
	{
		return '$prompt|${width}x$height';
	}

	static function processQueue():Void
	{
		if (isBusy || queue.length == 0)
			return;

		var request = queue[0];
		isBusy = true;

		var now:Float = Timer.stamp();
		var elapsed:Float = now - lastRequestTime;
		var delay:Float = elapsed < minRequestInterval ? (minRequestInterval - elapsed) : 0;

		Timer.delay(function():Void
		{
			executeRequest(request);
		}, Std.int(delay * 1000));
	}

	static function executeRequest(request:ImageRequest):Void
	{
		lastRequestTime = Timer.stamp();

		var http = new Http(endpoint);
		http.setHeader("Content-Type", "application/json");

		if (apiKey != "")
			http.setHeader("Authorization", 'Bearer $apiKey');

		var payload = {
			prompt: request.prompt,
			width: request.width,
			height: request.height
		};

		http.setPostData(Json.stringify(payload));

		var statusCode:Int = 0;

		http.onStatus = function(status:Int):Void
		{
			statusCode = status;
		};

		http.onData = function(data:String):Void
		{
			if (request.token != currentToken)
				return;

			try
			{
				var response = Json.parse(data);
				var base64Image:String = response.image;

				decodeBase64Image(base64Image, function(bitmap:BitmapData):Void
				{
					if (request.token != currentToken)
						return;

					if (cacheEnabled)
						imageCache.set(buildCacheKey(request.prompt, request.width, request.height), bitmap);

					if (autoSaveToStorage)
						StorageUtil.saveImage(bitmap, generateFilename(request.prompt), function(_):Void {}, function(_):Void {});

					request.onComplete(bitmap);
					finishRequest(request);
				}, function(error:String):Void
				{
					handleFailure(request, error, statusCode);
				});
			}
			catch (e:Dynamic)
			{
				handleFailure(request, Std.string(e), statusCode);
			}
		};

		http.onError = function(msg:String):Void
		{
			if (request.token != currentToken)
				return;

			handleFailure(request, msg, statusCode);
		};

		http.request(true);
	}

	static function handleFailure(request:ImageRequest, message:String, statusCode:Int):Void
	{
		request.attempts++;

		var isRetryable:Bool = statusCode != 401 && statusCode != 403 && statusCode != 400;

		if (isRetryable && request.attempts <= maxRetries)
		{
			var backoff:Int = Std.int(Math.pow(2, request.attempts) * 700);

			Timer.delay(function():Void
			{
				executeRequest(request);
			}, backoff);
		}
		else
		{
			request.onError(message);
			finishRequest(request);
		}
	}

	static function finishRequest(request:ImageRequest):Void
	{
		if (queue.length > 0)
			queue.shift();

		isBusy = false;
		processQueue();
	}

	static function generateFilename(prompt:String):String
	{
		var slug:String = prompt.length > 40 ? prompt.substr(0, 40) : prompt;
		return 'shark_${Std.int(Timer.stamp())}_$slug';
	}

	static function decodeBase64Image(base64Data:String, onComplete:BitmapData->Void, onError:String->Void):Void
	{
		var bytes:Bytes;

		try
		{
			bytes = Base64.decode(base64Data);
		}
		catch (e:Dynamic)
		{
			onError("Invalid image data received");
			return;
		}

		var byteArray:ByteArray = ByteArray.fromBytes(bytes);
		var loader = new Loader();
		var finished:Bool = false;

		var timeoutTimer = Timer.delay(function():Void
		{
			if (finished)
				return;

			finished = true;
			onError("Image decoding timed out");
		}, decodeTimeoutMs);

		loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();

			var bitmapData:BitmapData = cast(loader.content, openfl.display.Bitmap).bitmapData;
			onComplete(bitmapData);
		});

		loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			onError(e.text);
		});

		loader.loadBytes(byteArray);
	}

	public static function clearCache():Void
	{
		imageCache = new Map();
	}
}
