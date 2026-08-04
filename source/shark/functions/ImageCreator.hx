package shark.functions;

import haxe.Json;
import haxe.Timer;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import lime.manager.LimeManager;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.utils.ByteArray;
import shark.mobile.StorageUtil;
import shark.online.Network;
import shark.online.NetworkResponse;
import shark.online.Online;
import shark.online.User;
import shark.ui.security.Guard;

typedef ImageRequest = {
	prompt:String,
	onComplete:BitmapData->Void,
	onError:String->Void,
	width:Int,
	height:Int,
	token:Int
}

class ImageCreator
{
	public static var endpoint:String = "";
	public static var apiKey:String = "";
	public static var model:String = "";
	public static var quality:String = "standard";
	public static var maxRetries:Int = 2;
	public static var minRequestInterval:Float = 1.0;
	public static var maxPromptLength:Int = 1000;
	public static var requireOnline:Bool = true;
	public static var autoSaveToStorage:Bool = true;
	public static var cacheEnabled:Bool = true;
	public static var decodeTimeoutMs:Int = 15000;
	public static var maxCacheEntries:Int = 30;

	static var queue:Array<ImageRequest> = [];
	static var isBusy:Bool = false;
	static var lastRequestTime:Float = 0;
	static var currentToken:Int = 0;
	static var initialized:Bool = false;

	static var imageCache:Map<String, BitmapData> = new Map();
	static var cacheOrder:Array<String> = [];

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		var previousCallback:Bool->Void = LimeManager.onLowMemoryModeChanged;

		LimeManager.onLowMemoryModeChanged = function(isLow:Bool):Void
		{
			if (previousCallback != null)
				previousCallback(isLow);

			if (isLow)
				clearCache();
		};
	}

	public static function generate(prompt:String, onComplete:BitmapData->Void, onError:String->Void, width:Int = 512, height:Int = 512):Void
	{
		var trimmed:String = StringTools.trim(prompt);

		if (trimmed.length == 0)
		{
			if (onError != null)
				onError("Image description is empty");
			return;
		}

		if (trimmed.length > maxPromptLength)
		{
			if (onError != null)
				onError('Description exceeds $maxPromptLength characters');
			return;
		}

		if (requireOnline && !Online.isOnline)
		{
			if (onError != null)
				onError("No internet connection");
			return;
		}

		var cacheKey:String = buildCacheKey(trimmed, width, height);

		if (cacheEnabled && imageCache.exists(cacheKey))
		{
			if (onComplete != null)
				onComplete(imageCache.get(cacheKey));
			return;
		}

		queue.push({
			prompt: trimmed,
			onComplete: onComplete,
			onError: onError,
			width: width,
			height: height,
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

		var payload:Dynamic = {
			prompt: request.prompt,
			width: request.width,
			height: request.height,
			quality: quality
		};

		if (model != "")
			Reflect.setField(payload, "model", model);

		if (User.userId != null)
			Reflect.setField(payload, "user", User.userId);

		var headers:Map<String, String> = new Map();

		if (apiKey != "")
			headers.set("Authorization", 'Bearer $apiKey');

		Network.postJson(endpoint, payload, headers, function(response:NetworkResponse):Void
		{
			if (request.token != currentToken)
			{
				finishRequest();
				return;
			}

			if (!response.success)
			{
				if (request.onError != null)
					request.onError(response.error);
				finishRequest();
				return;
			}

			try
			{
				var parsed = Json.parse(response.data);
				var base64Image:String = parsed.image;

				decodeBase64Image(base64Image, function(bitmap:BitmapData):Void
				{
					if (request.token != currentToken)
					{
						finishRequest();
						return;
					}

					if (cacheEnabled)
						cacheImage(buildCacheKey(request.prompt, request.width, request.height), bitmap);

					if (autoSaveToStorage)
						StorageUtil.saveImage(bitmap, generateFilename(request.prompt), function(_):Void {}, function(_):Void {}, request.prompt);

					if (request.onComplete != null)
						request.onComplete(bitmap);

					finishRequest();
				}, function(error:String):Void
				{
					if (request.onError != null)
						request.onError(error);
					finishRequest();
				});
			}
			catch (e:Dynamic)
			{
				if (request.onError != null)
					request.onError(Std.string(e));
				finishRequest();
			}
		}, null, maxRetries);
	}

	static function finishRequest():Void
	{
		if (queue.length > 0)
			queue.shift();

		isBusy = false;
		processQueue();
	}

	static function generateFilename(prompt:String):String
	{
		var cleanPrompt:String = ~/[^a-zA-Z0-9_-]/g.replace(prompt, "_");
		var slug:String = cleanPrompt.length > 40 ? cleanPrompt.substr(0, 40) : cleanPrompt;
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
			if (onError != null)
				onError("Invalid image data received");
			return;
		}

		if (!Guard.isValidImagePayload(bytes))
		{
			if (onError != null)
				onError("Image data failed integrity check");
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
			if (onError != null)
				onError("Image decoding timed out");
		}, decodeTimeoutMs);

		loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();

			if (loader.content != null && Std.isOfType(loader.content, Bitmap))
			{
				var bitmapData:BitmapData = cast(loader.content, Bitmap).bitmapData;
				if (onComplete != null)
					onComplete(bitmapData);
			}
			else if (onError != null)
			{
				onError("Loaded content is not a valid Bitmap");
			}
		});

		loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			if (onError != null)
				onError(e.text);
		});

		loader.loadBytes(byteArray);
	}

	static function cacheImage(key:String, bitmap:BitmapData):Void
	{
		if (!imageCache.exists(key))
			cacheOrder.push(key);

		imageCache.set(key, bitmap);

		while (cacheOrder.length > maxCacheEntries)
		{
			var oldestKey:String = cacheOrder.shift();
			var oldBitmap:BitmapData = imageCache.get(oldestKey);
			if (oldBitmap != null)
			{
				oldBitmap.dispose();
				imageCache.remove(oldestKey);
			}
		}
	}

	public static function clearCache():Void
	{
		for (key in imageCache.keys())
		{
			var bmp:BitmapData = imageCache.get(key);
			if (bmp != null)
				bmp.dispose();
		}
		imageCache = new Map();
		cacheOrder = [];
	}
}
