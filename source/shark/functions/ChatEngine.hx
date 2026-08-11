package shark.functions;

import haxe.Json;
import haxe.Timer;
import openfl.display.BitmapData;
import shark.FileSys;
import shark.functions.ImageCreator;
import shark.online.Network;
import shark.online.NetworkResponse;
import shark.online.Online;
import shark.online.User;
import shark.ui.debug.CrasherLog;
import shark.world.Country;

#if sys
import lime.system.System;
#end

typedef ChatMessage = {role:String, content:String};

typedef ChatRequest = {
	message:String,
	onComplete:String->Void,
	onError:String->Void,
	?onImage:BitmapData->Void,
	?onImageError:String->Void,
	token:Int
}

class ChatEngine
{
	public static var endpoint:String = "";
	public static var apiKey:String = "";
	public static var systemPrompt:String = "";
	public static var model:String = "";
	public static var temperature:Float = 0.8;
	public static var maxTokens:Int = 1024;
	public static var maxRetries:Int = 2;
	public static var maxHistory:Int = 40;
	public static var maxHistoryCharacters:Int = 24000;
	public static var minRequestInterval:Float = 0.6;
	public static var maxMessageLength:Int = 4000;
	public static var requireOnline:Bool = true;
	public static var includeCountryContext:Bool = false;

	static var history:Array<ChatMessage> = [];
	static var queue:Array<ChatRequest> = [];
	static var isBusy:Bool = false;
	static var lastRequestTime:Float = 0;
	static var currentToken:Int = 0;

	static inline var IMAGE_TAG_START:String = "[[image:";
	static inline var IMAGE_TAG_END:String = "]]";
	static inline var HISTORY_FILENAME:String = "chat_history.json";
	static inline var LOG_CATEGORY:String = "chat";

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

	static function buildTrimmedHistory():Array<ChatMessage>
	{
		var trimmed:Array<ChatMessage> = history.length > maxHistory ? history.slice(history.length - maxHistory) : history.copy();
		var totalCharacters:Int = 0;

		for (entry in trimmed)
			totalCharacters += entry.content.length;

		while (totalCharacters > maxHistoryCharacters && trimmed.length > 2)
		{
			totalCharacters -= trimmed[0].content.length;
			trimmed.shift();
		}

		return trimmed;
	}

	static function executeRequest(request:ChatRequest):Void
	{
		lastRequestTime = Timer.stamp();

		var trimmedHistory:Array<ChatMessage> = buildTrimmedHistory();
		var messages:Array<ChatMessage> = trimmedHistory.concat([{role: "user", content: request.message}]);

		var payload:Dynamic = {
			system: systemPrompt,
			messages: messages,
			temperature: temperature,
			max_tokens: maxTokens
		};

		if (model != "")
			Reflect.setField(payload, "model", model);

		if (User.userId != null)
			Reflect.setField(payload, "user", User.userId);

		if (includeCountryContext && Country.isDetected)
			Reflect.setField(payload, "country", Country.countryCode);

		var headers:Map<String, String> = new Map();

		if (apiKey != "")
			headers.set("Authorization", 'Bearer $apiKey');

		Network.postJson(endpoint, payload, headers, function(response:NetworkResponse):Void
		{
			if (request.token != currentToken)
				return;

			if (!response.success)
			{
				var friendlyError:String = response.status == 429
					? "The AI service is rate-limiting requests right now, please wait a moment and try again"
					: response.error;

				CrasherLog.logWarning('Chat request failed (status ${response.status}): ${response.error}', LOG_CATEGORY);
				request.onError(friendlyError);
				finishRequest(request);
				return;
			}

			try
			{
				var parsed = Json.parse(response.data);
				var reply:String = parsed.reply;

				history.push({role: "user", content: request.message});
				history.push({role: "assistant", content: reply});

				saveHistory();

				var cleanReply:String = extractAndTriggerImage(reply, request.onImage, request.onImageError);

				request.onComplete(cleanReply);
				finishRequest(request);
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Chat response parse error: ${Std.string(e)}', LOG_CATEGORY);
				request.onError(Std.string(e));
				finishRequest(request);
			}
		}, null, maxRetries);
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
				CrasherLog.logWarning('Inline image generation failed: $error', LOG_CATEGORY);

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

	public static function deleteMessageAt(index:Int):Bool
	{
		if (index < 0 || index >= history.length)
			return false;

		history.splice(index, 1);
		saveHistory();

		return true;
	}

	public static function editMessageAt(index:Int, newContent:String):Bool
	{
		if (index < 0 || index >= history.length)
			return false;

		var trimmed:String = StringTools.trim(newContent);

		if (trimmed.length == 0 || trimmed.length > maxMessageLength)
			return false;

		history[index] = {role: history[index].role, content: trimmed};
		saveHistory();

		return true;
	}

	public static function getHistorySummary():String
	{
		var userCount:Int = 0;
		var assistantCount:Int = 0;
		var totalCharacters:Int = 0;

		for (entry in history)
		{
			totalCharacters += entry.content.length;

			if (entry.role == "user")
				userCount++;
			else
				assistantCount++;
		}

		return '$userCount user, $assistantCount assistant messages, ${Math.round(totalCharacters / 1024 * 10) / 10}KB total';
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
		if (!FileSys.writeText(getHistoryPath(), Json.stringify(history)))
			CrasherLog.logWarning("Failed to save chat history", LOG_CATEGORY);
	}

	public static function loadHistory():Void
	{
		var content:String = FileSys.readText(getHistoryPath());

		if (content == null)
		{
			history = [];
			return;
		}

		try
		{
			history = Json.parse(content);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to parse chat history: ${Std.string(e)}', LOG_CATEGORY);
			history = [];
		}
	}
}
