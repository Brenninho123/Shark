package shark.active.system;

import openfl.display.BitmapData;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;

class Head
{
	public static var isThinking(default, null):Bool = false;
	public static var onThinkingChanged:Bool->Void;

	static inline var IMAGE_COMMAND:String = "/image";

	public static function think(input:String, onReply:String->Void, onError:String->Void, ?onImage:BitmapData->Void, ?onImageError:String->Void):Void
	{
		var trimmedInput:String = StringTools.trim(input);

		if (trimmedInput.length == 0)
			return;

		if (isImageCommand(trimmedInput))
		{
			handleImageRequest(trimmedInput, onImage, onImageError);
			return;
		}

		setThinking(true);

		ChatEngine.send(trimmedInput, function(reply:String):Void
		{
			setThinking(false);
			onReply(reply);
		}, function(error:String):Void
		{
			setThinking(false);
			onError(error);
		}, onImage, onImageError);
	}

	static function isImageCommand(input:String):Bool
	{
		return input.length >= IMAGE_COMMAND.length && input.substr(0, IMAGE_COMMAND.length).toLowerCase() == IMAGE_COMMAND;
	}

	static function handleImageRequest(input:String, ?onImage:BitmapData->Void, ?onImageError:String->Void):Void
	{
		var prompt:String = StringTools.trim(input.substr(IMAGE_COMMAND.length));

		if (prompt.length == 0)
		{
			if (onImageError != null)
				onImageError("No image description provided");
			return;
		}

		setThinking(true);

		ImageCreator.generate(prompt, function(bitmap:BitmapData):Void
		{
			setThinking(false);

			if (onImage != null)
				onImage(bitmap);
		}, function(error:String):Void
		{
			setThinking(false);

			if (onImageError != null)
				onImageError(error);
		});
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
