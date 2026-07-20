package shark.active.system;

import openfl.display.BitmapData;
import shark.audio.Audio;
import shark.backend.Language;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;
import shark.online.User;
import shark.online.manager.Internet;
import shark.ui.security.Guard;

#if cpp
import lime.manager.LimeManager;
import lime.manager.SutilLime;
#end

typedef CommandRequest = {
	args:String,
	onReply:String->Void,
	onError:String->Void,
	?onImage:BitmapData->Void,
	?onImageError:String->Void
}

typedef CommandHandler = CommandRequest->Void

class Head
{
	public static var isThinking(default, null):Bool = false;
	public static var onThinkingChanged:Bool->Void;
	public static var onFlaggedInput:String->Void;
	public static var onRateLimited:Void->Void;
	public static var onNavigate:String->Void;

	public static var queueWhenOffline:Bool = true;

	public static var totalMessages(default, null):Int = 0;
	public static var totalImages(default, null):Int = 0;
	public static var totalFlagged(default, null):Int = 0;

	static var commands:Map<String, CommandHandler> = new Map();
	static var commandsInitialized:Bool = false;

	static function ensureCommandsInitialized():Void
	{
		if (commandsInitialized)
			return;

		commandsInitialized = true;

		registerCommand("/image", handleImageCommand);
		registerCommand("!image", handleImageCommand);
		registerCommand("/reset", handleResetCommand);
		registerCommand("!reset", handleResetCommand);
		registerCommand("/clear", handleResetCommand);
		registerCommand("/help", handleHelpCommand);
		registerCommand("!help", handleHelpCommand);
		registerCommand("/about", handleAboutCommand);
		registerCommand("!about", handleAboutCommand);
		registerCommand("/status", handleStatusCommand);
		registerCommand("!status", handleStatusCommand);
		registerCommand("/stats", handleStatsCommand);
		registerCommand("!stats", handleStatsCommand);
		registerCommand("/mute", handleMuteCommand);
		registerCommand("!mute", handleMuteCommand);
		registerCommand("/unmute", handleUnmuteCommand);
		registerCommand("!unmute", handleUnmuteCommand);
		registerCommand("/play", handlePlayCommand);
		registerCommand("!play", handlePlayCommand);
		registerCommand("/language", handleLanguageCommand);
		registerCommand("!language", handleLanguageCommand);
	}

	public static function registerCommand(name:String, handler:CommandHandler):Void
	{
		ensureCommandsInitialized();
		commands.set(name.toLowerCase(), handler);
	}

	public static function getWelcomeMessage():String
	{
		var index:Int = 1 + Std.random(3);
		return Language.get('greeting.$index');
	}

	public static function think(input:String, onReply:String->Void, onError:String->Void, ?onImage:BitmapData->Void, ?onImageError:String->Void):Void
	{
		ensureCommandsInitialized();

		var sanitized:String = Guard.sanitizeInput(input);

		if (sanitized.length == 0)
			return;

		if (Guard.detectPromptInjection(sanitized))
		{
			totalFlagged++;

			if (onFlaggedInput != null)
				onFlaggedInput(sanitized);
		}

		var commandName:String = extractCommandName(sanitized);

		if (commandName != null && commands.exists(commandName))
		{
			var args:String = StringTools.trim(sanitized.substr(commandName.length));

			commands.get(commandName)({
				args: args,
				onReply: onReply,
				onError: onError,
				onImage: onImage,
				onImageError: onImageError
			});

			return;
		}

		if (!Guard.checkAndRegister())
		{
			if (onRateLimited != null)
				onRateLimited();

			onError(Language.get("chat.rateLimited"));
			return;
		}

		sendChatMessage(sanitized, onReply, onError, onImage, onImageError);
	}

	static function extractCommandName(input:String):String
	{
		if (input.length == 0)
			return null;

		var firstChar:String = input.charAt(0);

		if (firstChar != "/" && firstChar != "!")
			return null;

		var spaceIndex:Int = input.indexOf(" ");
		var name:String = spaceIndex == -1 ? input : input.substr(0, spaceIndex);

		return name.toLowerCase();
	}

	static function sendChatMessage(message:String, onReply:String->Void, onError:String->Void, ?onImage:BitmapData->Void, ?onImageError:String->Void):Void
	{
		var action = function():Void
		{
			setThinking(true);

			ChatEngine.send(message, function(reply:String):Void
			{
				setThinking(false);
				totalMessages++;
				onReply(reply);
			}, function(error:String):Void
			{
				setThinking(false);
				onError(error);
			}, onImage, onImageError);
		};

		if (queueWhenOffline)
			Internet.runWhenOnline(action);
		else
			action();
	}

	static function handleImageCommand(request:CommandRequest):Void
	{
		if (request.args.length == 0)
		{
			if (request.onImageError != null)
				request.onImageError(Language.get("head.noImageDescription"));

			return;
		}

		setThinking(true);

		ImageCreator.generate(request.args, function(bitmap:BitmapData):Void
		{
			setThinking(false);
			totalImages++;

			if (request.onImage != null)
				request.onImage(bitmap);
		}, function(error:String):Void
		{
			setThinking(false);

			if (request.onImageError != null)
				request.onImageError(error);
		});
	}

	static function handleResetCommand(request:CommandRequest):Void
	{
		reset();
		request.onReply(Language.get("head.reset"));
	}

	static function handleHelpCommand(request:CommandRequest):Void
	{
		var lines:Array<String> = [
			Language.get("head.helpIntro"),
			Language.get("head.helpImage"),
			Language.get("head.helpReset"),
			Language.get("head.helpPlay"),
			Language.get("head.helpMute"),
			Language.get("head.helpStatus"),
			Language.get("head.helpStats"),
			Language.get("head.helpAbout"),
			Language.get("head.helpLanguage")
		];

		request.onReply(lines.join("\n"));
	}

	static function handleAboutCommand(request:CommandRequest):Void
	{
		request.onReply(Language.get("head.about"));
	}

	static function handleStatusCommand(request:CommandRequest):Void
	{
		var lines:Array<String> = [];

		var configured:String = ChatEngine.endpoint != "" ? Language.get("head.statusYes") : Language.get("head.statusNo");

		lines.push('${Language.get("head.statusConnection")}: ${Internet.getStatusLabel()}');
		lines.push('${Language.get("head.statusChatConfigured")}: $configured');

		#if cpp
		lines.push('${Language.get("head.statusBuild")}: ${LimeManager.getBuildSummary()}');
		#end

		request.onReply(lines.join("\n"));
	}

	static function handleStatsCommand(request:CommandRequest):Void
	{
		var lines:Array<String> = [
			'${Language.get("head.statsMessages")}: $totalMessages',
			'${Language.get("head.statsImages")}: $totalImages',
			'${Language.get("head.statsFlagged")}: $totalFlagged',
			'${Language.get("head.statsLaunches")}: ${User.launchCount}',
			'${Language.get("head.statsSession")}: ${Math.round(User.getSessionDurationSeconds())}s'
		];

		request.onReply(lines.join("\n"));
	}

	static function handleMuteCommand(request:CommandRequest):Void
	{
		Audio.setMuted(true);
		request.onReply(Language.get("head.muted"));
	}

	static function handleUnmuteCommand(request:CommandRequest):Void
	{
		Audio.setMuted(false);
		request.onReply(Language.get("head.unmuted"));
	}

	static function handlePlayCommand(request:CommandRequest):Void
	{
		if (onNavigate != null)
			onNavigate("games");
		else
			request.onReply(Language.get("head.miniGamesUnavailable"));
	}

	static function handleLanguageCommand(request:CommandRequest):Void
	{
		var supportedList:String = Language.supportedLanguages.join(", ");
		var code:String = StringTools.trim(request.args).toLowerCase();

		if (code.length == 0)
		{
			request.onReply(Language.get("head.languageMissing", ["list" => supportedList]));
			return;
		}

		if (!Language.setLanguage(code))
		{
			request.onReply(Language.get("head.languageInvalid", ["list" => supportedList]));
			return;
		}

		request.onReply(Language.get("head.languageChanged", ["language" => Language.getLanguageName(code)]));
	}

	public static function reset():Void
	{
		ChatEngine.reset();
		setThinking(false);
	}

	static function setThinking(value:Bool):Void
	{
		if (isThinking == value)
			return;

		isThinking = value;

		if (onThinkingChanged != null)
			onThinkingChanged(value);
	}
}
