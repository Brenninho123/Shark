package shark.active.system;

import openfl.display.BitmapData;
import shark.audio.Audio;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;
import shark.online.manager.Internet;
import shark.ui.security.Guard;

#if cpp
import lime.manager.LimeManager;
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

	static var greetings:Array<String> = [
		"Hey, I'm Shark! Ask me anything, or type /help to see what I can do.",
		"Splash! Shark here, ready to chat. Type /help if you want a quick tour.",
		"Hi, I'm Shark. Type !play if you're in the mood for a mini-game, or just say hello."
	];

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
	}

	public static function registerCommand(name:String, handler:CommandHandler):Void
	{
		ensureCommandsInitialized();
		commands.set(name.toLowerCase(), handler);
	}

	public static function getWelcomeMessage():String
	{
		return greetings[Std.random(greetings.length)];
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

			onError("Too many messages, please slow down");
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
				request.onImageError("No image description provided");

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
		request.onReply("Conversation reset. Starting fresh!");
	}

	static function handleHelpCommand(request:CommandRequest):Void
	{
		var lines:Array<String> = [
			"Here's what I can do:",
			"/image <description> - generate an image",
			"/reset or /clear - start a new conversation",
			"/play - open the mini-games menu",
			"/mute or /unmute - toggle sound",
			"/status - check my connection",
			"/stats - see how much we've chatted",
			"/about - learn more about me"
		];

		request.onReply(lines.join("\n"));
	}

	static function handleAboutCommand(request:CommandRequest):Void
	{
		request.onReply("I'm Shark, an AI built with HaxeFlixel. I can chat, generate images, and I've got a few mini-games if you want a break.");
	}

	static function handleStatusCommand(request:CommandRequest):Void
	{
		var lines:Array<String> = [];

		lines.push('Connection: ${Internet.getStatusLabel()}');
		lines.push('Chat configured: ${ChatEngine.endpoint != "" ? "yes" : "no"}');

		#if cpp
		lines.push('Build: ${LimeManager.getBuildSummary()}');
		#end

		request.onReply(lines.join("\n"));
	}

	static function handleStatsCommand(request:CommandRequest):Void
	{
		var lines:Array<String> = [
			'Messages exchanged: $totalMessages',
			'Images generated: $totalImages',
			'Flagged inputs: $totalFlagged'
		];

		request.onReply(lines.join("\n"));
	}

	static function handleMuteCommand(request:CommandRequest):Void
	{
		Audio.setMuted(true);
		request.onReply("Muted.");
	}

	static function handleUnmuteCommand(request:CommandRequest):Void
	{
		Audio.setMuted(false);
		request.onReply("Unmuted.");
	}

	static function handlePlayCommand(request:CommandRequest):Void
	{
		if (onNavigate != null)
			onNavigate("games");
		else
			request.onReply("Mini-games aren't available right now.");
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
