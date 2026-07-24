package shark.modding;

import shark.active.system.Head;
import shark.backend.Mods;

class ModuleHandler
{
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		hookIntoHead();
	}

	static function hookIntoHead():Void
	{
		var previousThinking:Bool->Void = Head.onThinkingChanged;

		Head.onThinkingChanged = function(thinking:Bool):Void
		{
			if (previousThinking != null)
				previousThinking(thinking);

			Mods.callHookOnAll(thinking ? "onThinkingStart" : "onThinkingEnd");
		};

		var previousFlagged:String->Void = Head.onFlaggedInput;

		Head.onFlaggedInput = function(input:String):Void
		{
			if (previousFlagged != null)
				previousFlagged(input);

			Mods.callHookOnAll("onFlaggedInput");
		};

		var previousRateLimited:Void->Void = Head.onRateLimited;

		Head.onRateLimited = function():Void
		{
			if (previousRateLimited != null)
				previousRateLimited();

			Mods.callHookOnAll("onRateLimited");
		};

		var previousNavigate:String->Void = Head.onNavigate;

		Head.onNavigate = function(destination:String):Void
		{
			if (previousNavigate != null)
				previousNavigate(destination);

			Mods.callHookOnAll("onNavigate", [destination]);
		};
	}

	public static function notifyMessageSent(message:String):Void
	{
		Mods.callHookOnAll("onMessageSent", [message]);
	}

	public static function notifyReplyReceived(reply:String):Void
	{
		Mods.callHookOnAll("onReplyReceived", [reply]);
	}

	public static function notifyImageGenerated():Void
	{
		Mods.callHookOnAll("onImageGenerated");
	}

	public static function notifyError(error:String):Void
	{
		Mods.callHookOnAll("onError", [error]);
	}

	public static function notifyStateChanged(stateName:String):Void
	{
		Mods.callHookOnAll("onStateChanged", [stateName]);
	}

	public static function notifyLanguageChanged(languageCode:String):Void
	{
		Mods.callHookOnAll("onLanguageChanged", [languageCode]);
	}
}
