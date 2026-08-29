package shark.functions;

import haxe.Json;
import haxe.Timer;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.utils.ByteArray;
import shark.Content;
import shark.data.license.ImageLicense;
import shark.mobile.backend.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.online.Network;
import shark.online.NetworkResponse;
import shark.online.Online;
import shark.online.User;
import shark.ui.debug.CrasherLog;
import shark.ui.security.Guard;
import lime.manager.LimeManager;

typedef ImageRequest = {
	prompt:String,
	cacheKey:String,
	width:Int,
	height:Int,
	token:Int
}

typedef PendingCallback = {
	onComplete:BitmapData->Void,
	onError:String->Void
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
	public static var maxQueueLength:Int = 10;
	public static var minDimension:Int = 64;
	public static var maxDimension:Int = 2048;

	static var queue:Array<ImageRequest> = [];
	static var isBusy:Bool = false;
	static var lastRequestTime:Float = 0;
	static var currentToken:Int = 0;
	static var initialized:Bool = false;

	static var imageCache:Map<String, BitmapData> = new Map();
	static var cacheOrder:Array<String> = [];
	static var pendingCallbacks:Map<String, Array<PendingCallback>> = new Map();

	static var totalGenerated:Int = 0;
	static var totalFailed:Int = 0;
	static var totalCacheHits:Int = 0;
	static var totalDeduped:Int = 0;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		Content.initialize();

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
		generateChecked(prompt, onComplete, onError, function(reason:String):Void
		{
			onError('Confirmation required: $reason');
		}, width, height);
	}

	public static function generateChecked(prompt:String, onComplete:BitmapData->Void, onError:String->Void, onNeedsConsent:String->Void, width:Int = 512,
			height:Int = 512):Void
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

		var clampedWidth:Int = clampDimension(width);
		var clampedHeight:Int = clampDimension(height);

		ImageLicense.requestGeneration(trimmed, function():Void
		{
			enqueueGeneration(trimmed, onComplete, onError, clampedWidth, clampedHeight);
		}, onNeedsConsent, onError);
	}

	public static function confirmAndGenerate(prompt:String, onComplete:BitmapData->Void, onError:String->Void, width:Int = 512, height:Int = 512):Void
	{
		var trimmed:String = StringTools.trim(prompt);

		ImageLicense.recordConsent(trimmed);
		enqueueGeneration(trimmed, onComplete, onError, clampDimension(width), clampDimension(height));
	}

	static function clampDimension(value:Int):Int
	{
		if (value < minDimension)
			return minDimension;

		if (value > maxDimension)
			return maxDimension;

		return value;
	}

	public static function cancelPending():Void
	{
		queue = [];
		currentToken++;
		isBusy = false;
		pendingCallbacks = new Map();
	}

	public static function getQueueLength():Int
	{
		return queue.length;
	}

	public static function isGenerating():Bool
	{
		return isBusy;
	}

	static function buildCacheKey(prompt:String, width:Int, height:Int):String
	{
		return '$prompt|${width}x$height';
	}

	static function enqueueGeneration(trimmed:String, onComplete:BitmapData->Void, onError:String->Void, width:Int, height:Int):Void
	{
		var cacheKey:String = buildCacheKey(trimmed, width, height);

		if (cacheEnabled && imageCache.exists(cacheKey))
		{
			totalCacheHits++;
			touchCacheAccess(cacheKey);
			onComplete(imageCache.get(cacheKey));
			return;
		}

		if (pendingCallbacks.exists(cacheKey))
		{
			totalDeduped++;
			pendingCallbacks.get(cacheKey).push({onComplete: onComplete, onError: onError});
			return;
		}

		if (queue.length >= maxQueueLength)
		{
			onError('Too many pending image requests (max $maxQueueLength) - please wait for one to finish.');
			return;
		}

		pendingCallbacks.set(cacheKey, [{onComplete: onComplete, onError: onError}]);

		CrasherLog.addBreadcrumb("Image generation requested", "image");

		queue.push({
			prompt: trimmed,
			cacheKey: cacheKey,
			width: width,
			height: height,
			token: currentToken
		});

		processQueue();
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
				return;

			if (!response.success)
			{
				failRequest(request, response.error);
				return;
			}

			try
			{
				var parsed = Json.parse(response.data);
				var base64Image:String = parsed.image;

				decodeBase64Image(base64Image, function(bitmap:BitmapData):Void
				{
					if (request.token != currentToken)
						return;

					if (cacheEnabled)
						cacheImage(request.cacheKey, bitmap);

					if (autoSaveToStorage)
						Content.saveImage(bitmap, generateFilename(request.prompt), request.prompt);

					totalGenerated++;
					Vibration.trigger(HapticStyle.SUCCESS);
					CrasherLog.addBreadcrumb("Image generation completed", "image");

					resolveSuccess(request.cacheKey, bitmap);
					finishRequest();
				}, function(error:String):Void
				{
					failRequest(request, error);
				});
			}
			catch (e:Dynamic)
			{
				failRequest(request, Std.string(e));
			}
		}, null, maxRetries);
	}

	static function failRequest(request:ImageRequest, error:String):Void
	{
		totalFailed++;
		Vibration.trigger(HapticStyle.WARNING);
		CrasherLog.logWarning('Image generation failed: $error', "image");

		resolveError(request.cacheKey, error);
		finishRequest();
	}

	static function resolveSuccess(cacheKey:String, bitmap:BitmapData):Void
	{
		var callbacks:Array<PendingCallback> = pendingCallbacks.get(cacheKey);
		pendingCallbacks.remove(cacheKey);

		if (callbacks == null)
			return;

		for (callback in callbacks)
			callback.onComplete(bitmap);
	}

	static function resolveError(cacheKey:String, error:String):Void
	{
		var callbacks:Array<PendingCallback> = pendingCallbacks.get(cacheKey);
		pendingCallbacks.remove(cacheKey);

		if (callbacks == null)
			return;

		for (callback in callbacks)
			callback.onError(error);
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

		if (!Guard.isValidImagePayload(bytes))
		{
			onError("Image data failed integrity check");
			return;
		}

		var byteArray:ByteArray = ByteArray.fromBytes(bytes);
		var loader = new Loader();
		var finished:Bool = false;
		var timeoutTimer:Timer = null;

		function onLoadComplete(e:Event):Void
		{
			if (finished)
				return;

			finished = true;

			if (timeoutTimer != null)
				timeoutTimer.stop();

			detachLoaderListeners(loader, onLoadComplete, onLoadError);

			var bitmapData:BitmapData = cast(loader.content, openfl.display.Bitmap).bitmapData;
			onComplete(bitmapData);
		}

		function onLoadError(e:IOErrorEvent):Void
		{
			if (finished)
				return;

			finished = true;

			if (timeoutTimer != null)
				timeoutTimer.stop();

			detachLoaderListeners(loader, onLoadComplete, onLoadError);
			onError(e.text);
		}

		timeoutTimer = Timer.delay(function():Void
		{
			if (finished)
				return;

			finished = true;
			detachLoaderListeners(loader, onLoadComplete, onLoadError);
			onError("Image decoding timed out");
		}, decodeTimeoutMs);

		loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
		loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		loader.loadBytes(byteArray);
	}

	static function detachLoaderListeners(loader:Loader, onLoadComplete:Event->Void, onLoadError:IOErrorEvent->Void):Void
	{
		try
		{
			loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadComplete);
			loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		}
		catch (e:Dynamic) {}
	}

	static function touchCacheAccess(key:String):Void
	{
		cacheOrder.remove(key);
		cacheOrder.push(key);
	}

	static function cacheImage(key:String, bitmap:BitmapData):Void
	{
		if (!imageCache.exists(key))
			cacheOrder.push(key);
		else
			touchCacheAccess(key);

		imageCache.set(key, bitmap);
		evictIfNeeded();
	}

	static function evictIfNeeded():Void
	{
		while (cacheOrder.length > maxCacheEntries)
		{
			var oldestKey:String = cacheOrder.shift();

			if (!imageCache.exists(oldestKey))
				continue;

			var bitmap:BitmapData = imageCache.get(oldestKey);

			if (bitmap != null)
				bitmap.dispose();

			imageCache.remove(oldestKey);
		}
	}

	public static function clearCache():Void
	{
		for (key in cacheOrder)
		{
			if (!imageCache.exists(key))
				continue;

			var bitmap:BitmapData = imageCache.get(key);

			if (bitmap != null)
				bitmap.dispose();
		}

		imageCache = new Map();
		cacheOrder = [];
	}

	public static function getStatusSummary():String
	{
		return 'ImageCreator: queued=${queue.length}, busy=$isBusy, cached=${cacheOrder.length}/$maxCacheEntries, generated=$totalGenerated, failed=$totalFailed, cache hits=$totalCacheHits, deduped=$totalDeduped';
	}
}
