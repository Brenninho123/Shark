package shark.functions;

import haxe.Http;
import haxe.Json;
import haxe.Timer;
import openfl.display.BitmapData;
import shark.functions.ImageCreator;
import shark.online.Online;

#if sys
import sys.FileSystem;
import sys.io.File;
import lime.system.System;
#end

typedef ChatMessage = {role:String, content:String};

typedef ChatRequest = {
	message:String,
	onComplete:String->Void,
	onError:String->Void,
	?onImage:BitmapData->Void,
	?onImageError:String->Void,
	attempts:Int,
	token:Int
}

class ChatEngine
{
	public static var endpoint:String = "";
	public static var apiKey:String = "";
	public static var systemPrompt:String = "";
	public static var maxRetries:Int = 2;
	public static var maxHistory:Int = 40;
	public static var minRequestInterval:Float = 0.6;
	public static var maxMessageLength:Int = 4000;
	public static var requireOnline:Bool = true;

	static var history:Array<ChatMessage> = [];
	static var queue:Array<ChatRequest> = [];
	static var isBusy:Bool = false;
	static var lastRequestTime:Float = 0;
	static var currentToken:Int = 0;

	static inline var IMAGE_TAG_START:String = "[[image:";
	static inline var IMAGE_TAG_END:String = "]]";
	static inline var HISTORY_FILENAME:String = "chat_history.json";

	public static function send(message:String, onComplete:String->Void, onError:String->Void, ?onImage:BitmapData->Void, ?onImageError:String->Void):Void
	{
		var trimmed:String = StringTools.trim(message);

		if (trimmed.length == 0)
		{
			onError("Message is empty");
			return;
		}

		if (trimmed.length > maxMessageLength)
		{
			onError('Message exceeds $maxMessageLength characters');
			return;
		}

		if (requireOnline && !Online.isOnline)
		{
			onError("No internet connection");
			return;
		}

		queue.push({
			message: trimmed,
			onComplete: onComplete,
			onError: onError,
			onImage: onImage,
			onImageError: onImageError,
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

	static function executeRequest(request:ChatRequest):Void
	{
		lastRequestTime = Timer.stamp();

		var trimmedHistory:Array<ChatMessage> = history.length > maxHistory ? history.slice(history.length - maxHistory) : history;

		var http = new Http(endpoint);
		http.setHeader("Content-Type", "application/json");

		if (apiKey != "")
			http.setHeader("Authorization", 'Bearer $apiKey');

		var messages:Array<ChatMessage> = trimmedHistory.concat([{role: "user", content: request.message}]);

		var payload = {
			system: systemPrompt,
			messages: messages
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
				var reply:String = response.reply;

				history.push({role: "user", content: request.message});
				history.push({role: "assistant", content: reply});

				saveHistory();

				var cleanReply:String = extractAndTriggerImage(reply, request.onImage, request.onImageError);

				request.onComplete(cleanReply);
				finishRequest(request);
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

	static function handleFailure(request:ChatRequest, message:String, statusCode:Int):Void
	{
		request.attempts++;

		var isRetryable:Bool = statusCode != 401 && statusCode != 403 && statusCode != 400;

		if (isRetryable && request.attempts <= maxRetries)
		{
			var backoff:Int = Std.int(Math.pow(2, request.attempts) * 500);

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

	static function finishRequest(request:ChatRequest):Void
	{
		if (queue.length > 0)
			queue.shift();

		isBusy = false;
		processQueue();
	}

	static function extractAndTriggerImage(reply:String, onImage:BitmapData->Void, onImageError:String->Void):String
	{
		var startIndex:Int = reply.indexOf(IMAGE_TAG_START);

		if (startIndex == -1)
			return reply;

		var endIndex:Int = reply.indexOf(IMAGE_TAG_END, startIndex);

		if (endIndex == -1)
			return reply;

		var prompt:String = reply.substring(startIndex + IMAGE_TAG_START.length, endIndex);
		var cleanReply:String = reply.substring(0, startIndex) + reply.substring(endIndex + IMAGE_TAG_END.length);

		if (onImage != null)
		{
			ImageCreator.generate(prompt, onImage, function(error:String):Void
			{
				if (onImageError != null)
					onImageError(error);
			});
		}

		return StringTools.trim(cleanReply);
	}

	public static function getHistory():Array<ChatMessage>
	{
		return history.copy();
	}

	public static function reset():Void
	{
		history = [];
		queue = [];
		isBusy = false;
		currentToken++;

		saveHistory();
	}

	static function getHistoryPath():String
	{
		#if sys
		var base:String = System.applicationStorageDirectory;

		if (!StringTools.endsWith(base, "/") && !StringTools.endsWith(base, "\\"))
			base += "/";

		return base + HISTORY_FILENAME;
		#else
		return "";
		#end
	}

	static function saveHistory():Void
	{
		#if sys
		try
		{
			File.saveContent(getHistoryPath(), Json.stringify(history));
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function loadHistory():Void
	{
		#if sys
		try
		{
			var path:String = getHistoryPath();

			if (FileSystem.exists(path))
				history = Json.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			history = [];
		}
		#end
	}
}
