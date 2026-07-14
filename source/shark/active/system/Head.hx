package shark.active.system;

import openfl.display.BitmapData;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;
import shark.online.manager.Internet;
import shark.ui.security.Guard;

typedef CommandHandler = {
	args:String,
	onReply:String->Void,
	onError:String->Void,
	?onImage:BitmapData->Void,
	?onImageError:String->Void
}->Void

class Head
{
	public static var isThinking(default, null):Bool = false;
	public static var onThinkingChanged:Bool->Void;
	public static var onFlaggedInput:String->Void;
	public static var onRateLimited:Void->Void;

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
		registerCommand("/help", handleHelpCommand);
		registerCommand("!help", handleHelpCommand);
	}

	public static function registerCommand(name:String, handler:CommandHandler):Void
	{
		ensureCommandsInitialized();
		commands.set(name.toLowerCase(), handler);
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

	static function handleImageCommand(request:{args:String, onReply:String->Void, onError:String->Void, ?onImage:BitmapData->Void, ?onImageError:String->Void}):Void
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

	static function handleResetCommand(request:{args:String, onReply:String->Void, onError:String->Void, ?onImage:BitmapData->Void, ?onImageError:String->Void}):Void
	{
		reset();
		request.onReply("Conversation reset");
	}

	static function handleHelpCommand(request:{args:String, onReply:String->Void, onError:String->Void, ?onImage:BitmapData->Void, ?onImageError:String->Void}):Void
	{
		var lines:Array<String> = ["Available commands:"];

		for (name in commands.keys())
			lines.push(name);

		request.onReply(lines.join("\n"));
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
