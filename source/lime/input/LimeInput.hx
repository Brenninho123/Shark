package lime.input;

import lime.app.Application;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.Window;
import lime.ui.Gamepad;

class LimeInput
{
	public static var onRawKeyDown:KeyCode->KeyModifier->Void;
	public static var onRawKeyUp:KeyCode->KeyModifier->Void;
	public static var onRawTextInput:String->Void;

	static var resizeListeners:Array<Int->Int->Void> = [];
	static var initialized:Bool = false;

	public static var window(get, never):Window;

	static function get_window():Window
	{
		return Application.current != null ? Application.current.window : null;
	}

	public static function initialize():Void
	{
		if (initialized || window == null)
			return;

		initialized = true;

		window.onKeyDown.add(handleKeyDown);
		window.onKeyUp.add(handleKeyUp);
		window.onTextInput.add(handleTextInput);
		window.onResize.add(handleResize);
	}

	static function handleKeyDown(keyCode:KeyCode, modifier:KeyModifier):Void
	{
		if (onRawKeyDown != null)
			onRawKeyDown(keyCode, modifier);
	}

	static function handleKeyUp(keyCode:KeyCode, modifier:KeyModifier):Void
	{
		if (onRawKeyUp != null)
			onRawKeyUp(keyCode, modifier);
	}

	static function handleTextInput(text:String):Void
	{
		if (onRawTextInput != null)
			onRawTextInput(text);
	}

	static function handleResize(width:Int, height:Int):Void
	{
		for (listener in resizeListeners)
		{
			try
			{
				listener(width, height);
			}
			catch (e:Dynamic) {}
		}
	}

	public static function addResizeListener(callback:Int->Int->Void):Void
	{
		if (resizeListeners.indexOf(callback) == -1)
			resizeListeners.push(callback);
	}

	public static function removeResizeListener(callback:Int->Int->Void):Void
	{
		resizeListeners.remove(callback);
	}

	public static function showSoftKeyboard():Void
	{
		if (window != null)
			window.textInputEnabled = true;
	}

	public static function hideSoftKeyboard():Void
	{
		if (window != null)
			window.textInputEnabled = false;
	}

	public static function isSoftKeyboardEnabled():Bool
	{
		return window != null && window.textInputEnabled;
	}

	public static function getWindowSize():{width:Int, height:Int}
	{
		if (window == null)
			return {width: 0, height: 0};

		return {width: window.width, height: window.height};
	}

	public static function getDisplayScale():Float
	{
		return window != null ? window.scale : 1;
	}

	public static function requestFocus():Void
	{
		if (window != null)
			window.focus();
	}

	public static function setFullscreen(value:Bool):Void
	{
		if (window != null)
			window.fullscreen = value;
	}

	public static function isFullscreen():Bool
	{
		return window != null && window.fullscreen;
	}

	public static function getConnectedGamepadCount():Int
	{
		var count:Int = 0;

		for (id in Gamepad.devices.keys())
			count++;

		return count;
	}

	public static function hasConnectedGamepad():Bool
	{
		return getConnectedGamepadCount() > 0;
	}

	public static function getGamepadNames():Array<String>
	{
		var names:Array<String> = [];

		for (gamepad in Gamepad.devices)
			names.push(gamepad.name != null ? gamepad.name : "Unknown gamepad");

		return names;
	}
}
