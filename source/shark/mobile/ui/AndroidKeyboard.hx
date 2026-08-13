package shark.mobile.ui;

import flixel.FlxG;
import lime.input.LimeInput;

#if android
import openfl.events.Event;
import openfl.Lib;
#end

class AndroidKeyboard
{
	public static var isSoftKeyboardVisible(default, null):Bool = false;
	public static var onKeyboardVisibilityChanged:Bool->Void;

	static inline var VISIBILITY_HEIGHT_RATIO:Float = 0.75;

	static var fullHeight:Float = 0;
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		#if android
		if (Lib.current != null && Lib.current.stage != null)
		{
			fullHeight = Lib.current.stage.stageHeight;
			Lib.current.stage.addEventListener(Event.RESIZE, onStageResize);
		}
		#end
	}

	#if android
	static function onStageResize(e:Event):Void
	{
		if (Lib.current == null || Lib.current.stage == null || fullHeight <= 0)
			return;

		var currentHeight:Float = Lib.current.stage.stageHeight;
		var wasVisible:Bool = isSoftKeyboardVisible;

		isSoftKeyboardVisible = currentHeight < fullHeight * VISIBILITY_HEIGHT_RATIO;

		if (wasVisible != isSoftKeyboardVisible && onKeyboardVisibilityChanged != null)
			onKeyboardVisibilityChanged(isSoftKeyboardVisible);
	}
	#end

	public static function show():Void
	{
		LimeInput.showSoftKeyboard();
	}

	public static function hide():Void
	{
		LimeInput.hideSoftKeyboard();
	}

	public static function isGamepadConnected():Bool
	{
		return FlxG.gamepads.firstActive != null;
	}

	public static function shouldShowVirtualControls():Bool
	{
		return !isGamepadConnected();
	}

	public static function shouldShowVirtualKeyboardHint():Bool
	{
		return !isGamepadConnected() && !isSoftKeyboardVisible;
	}

	public static function getInputModeSummary():String
	{
		if (isGamepadConnected())
			return "gamepad";

		if (isSoftKeyboardVisible)
			return "soft keyboard";

		return "touch";
	}
}
