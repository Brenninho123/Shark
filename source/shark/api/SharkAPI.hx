package shark.api;

import flixel.FlxG;
import openfl.display.BitmapData;
import shark.active.system.Head;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;
import shark.online.MultiPlayer;
import shark.online.Online;
import shark.server.Servers;
import shark.ui.debug.CrasherLog;

typedef SharkMessage = {
	role:String,
	content:String
}

typedef SharkCapabilities = {
	chatAvailable:Bool,
	imageGenerationAvailable:Bool,
	multiplayerAvailable:Bool,
	isOnline:Bool,
	activeServerLabel:String
}

class SharkAPI
{
	public static inline var API_VERSION:String = "1.0.0";

	public static var onReply:String->Void;
	public static var onError:String->Void;
	public static var onImageGenerated:BitmapData->Void;
	public static var onImageError:String->Void;
	public static var onConsentRequired:String->Void;
	public static var onThinkingChanged:Bool->Void;

	static var initialized:Bool = false;
	static var lastKnownThinkingState:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;
		lastKnownThinkingState = Head.isThinking;

		FlxG.signals.postUpdate.add(pollThinkingState);
	}

	static function pollThinkingState():Void
	{
		if (Head.isThinking == lastKnownThinkingState)
			return;

		lastKnownThinkingState = Head.isThinking;

		if (onThinkingChanged != null)
			onThinkingChanged(lastKnownThinkingState);
	}

	public static function sendMessage(message:String):Void
	{
		var trimmed:String = StringTools.trim(message);

		if (trimmed.length == 0)
		{
			notifyError("Message is empty");
			return;
		}

		if (ChatEngine.requireOnline && !Online.isOnline)
		{
			notifyError("No internet connection");
			return;
		}

		CrasherLog.addBreadcrumb("SharkAPI.sendMessage called", "sharkapi");
		Head.think(trimmed, handleReply, handleError, handleImageGenerated, handleImageError);
	}

	public static function isThinking():Bool
	{
		return Head.isThinking;
	}

	public static function getWelcomeMessage():String
	{
		return Head.getWelcomeMessage();
	}

	public static function clearConversation():Void
	{
		Head.reset();
		CrasherLog.addBreadcrumb("SharkAPI.clearConversation called", "sharkapi");
	}

	public static function getConversationHistory():Array<SharkMessage>
	{
		var result:Array<SharkMessage> = [];

		for (entry in ChatEngine.getHistory())
			result.push({role: entry.role, content: entry.content});

		return result;
	}

	public static function exportConversation():String
	{
		return haxe.Json.stringify(getConversationHistory());
	}

	static function handleReply(reply:String):Void
	{
		if (onReply != null)
			onReply(reply);
	}

	static function handleError(error:String):Void
	{
		if (onError != null)
			onError(error);
	}

	static function handleImageGenerated(bitmap:BitmapData):Void
	{
		if (onImageGenerated != null)
			onImageGenerated(bitmap);
	}

	static function handleImageError(error:String):Void
	{
		if (onImageError != null)
			onImageError(error);
	}

	static function notifyError(message:String):Void
	{
		if (onError != null)
			onError(message);
	}

	public static function generateImage(prompt:String, width:Int = 512, height:Int = 512):Void
	{
		CrasherLog.addBreadcrumb("SharkAPI.generateImage called", "sharkapi");

		ImageCreator.generateChecked(prompt, handleImageGenerated, handleImageError, function(reason:String):Void
		{
			if (onConsentRequired != null)
				onConsentRequired(reason);
			else
				handleImageError('Confirmation required: $reason');
		}, width, height);
	}

	public static function confirmImageGeneration(prompt:String, width:Int = 512, height:Int = 512):Void
	{
		CrasherLog.addBreadcrumb("SharkAPI.confirmImageGeneration called", "sharkapi");
		ImageCreator.confirmAndGenerate(prompt, handleImageGenerated, handleImageError, width, height);
	}

	public static function isChatConfigured():Bool
	{
		return ChatEngine.endpoint != null && StringTools.trim(ChatEngine.endpoint).length > 0;
	}

	public static function isImageGenerationConfigured():Bool
	{
		return ImageCreator.endpoint != null && StringTools.trim(ImageCreator.endpoint).length > 0;
	}

	public static function isOnline():Bool
	{
		return Online.isOnline;
	}

	public static function getCapabilities():SharkCapabilities
	{
		var profile = Servers.getActiveProfile();

		return {
			chatAvailable: isChatConfigured(),
			imageGenerationAvailable: isImageGenerationConfigured(),
			multiplayerAvailable: MultiPlayer.isAvailable(),
			isOnline: isOnline(),
			activeServerLabel: profile != null ? profile.label : "none"
		};
	}

	public static function getApiVersion():String
	{
		return API_VERSION;
	}

	public static function getStatusSummary():String
	{
		var capabilities:SharkCapabilities = getCapabilities();

		return 'SharkAPI $API_VERSION: chat=${capabilities.chatAvailable}, images=${capabilities.imageGenerationAvailable}, multiplayer=${capabilities.multiplayerAvailable}, online=${capabilities.isOnline}, server=${capabilities.activeServerLabel}, thinking=${isThinking()}';
	}
}
