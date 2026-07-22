package shark.backend.input;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepad;
import flixel.addons.ui.FlxVirtualPad;
import flixel.addons.ui.FlxVirtualPad.FlxVirtualPadDPadMode;
import flixel.addons.ui.FlxVirtualPad.FlxVirtualPadButtonMode;
import shark.mobile.utils.TouchUtil;

enum InputMethod
{
	KEYBOARD;
	GAMEPAD;
	TOUCH;
	NONE;
}

class Controls
{
	public static var isMobile(default, null):Bool;
	public static var virtualPad(default, null):FlxVirtualPad;
	public static var lastInputMethod(default, null):InputMethod = NONE;

	public static var onGamepadConnected:FlxGamepad->Void;
	public static var onGamepadDisconnected:FlxGamepad->Void;

	public static var swipeAsDirection:Bool = true;
	public static var swipeHoldSeconds:Float = 0.2;

	static var initialized:Bool = false;
	static var swipeDirection:String;
	static var swipeExpireTime:Float = -1;
	static var tapJustHappened:Bool = false;

	public static var gamepad(get, never):FlxGamepad;

	static function get_gamepad():FlxGamepad
	{
		return FlxG.gamepads.firstActive;
	}

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;
		isMobile = FlxG.onMobile;

		FlxG.gamepads.deviceConnected.add(handleGamepadConnected);
		FlxG.gamepads.deviceDisconnected.add(handleGamepadDisconnected);

		#if FLX_TOUCH
		var previousTap:Float->Float->Void = TouchUtil.onTap;
		var previousSwipe:String->Float->Float->Void = TouchUtil.onSwipe;

		TouchUtil.onTap = function(x:Float, y:Float):Void
		{
			if (previousTap != null)
				previousTap(x, y);

			tapJustHappened = true;
			lastInputMethod = TOUCH;
		};

		TouchUtil.onSwipe = function(direction:String, distance:Float, velocity:Float):Void
		{
			if (previousSwipe != null)
				previousSwipe(direction, distance, velocity);

			if (swipeAsDirection)
			{
				swipeDirection = direction;
				swipeExpireTime = haxe.Timer.stamp() + swipeHoldSeconds;
				lastInputMethod = TOUCH;
			}
		};
		#end
	}

	static function handleGamepadConnected(gamepadDevice:FlxGamepad):Void
	{
		if (onGamepadConnected != null)
			onGamepadConnected(gamepadDevice);
	}

	static function handleGamepadDisconnected(gamepadDevice:FlxGamepad):Void
	{
		if (onGamepadDisconnected != null)
			onGamepadDisconnected(gamepadDevice);
	}

	public static function isGamepadConnected():Bool
	{
		return gamepad != null;
	}

	public static function getGamepadName():String
	{
		return gamepad != null ? gamepad.name : "none";
	}

	public static function createVirtualPad(dpadMode:FlxVirtualPadDPadMode = FULL, buttonMode:FlxVirtualPadButtonMode = A):FlxVirtualPad
	{
		if (!isMobile)
			return null;

		virtualPad = new FlxVirtualPad(dpadMode, buttonMode);
		return virtualPad;
	}

	public static function destroyVirtualPad():Void
	{
		if (virtualPad == null)
			return;

		virtualPad.destroy();
		virtualPad = null;
	}

	static function isSwipeActive(direction:String):Bool
	{
		if (!swipeAsDirection || swipeExpireTime < 0)
			return false;

		if (haxe.Timer.stamp() > swipeExpireTime)
		{
			swipeExpireTime = -1;
			return false;
		}

		return swipeDirection == direction;
	}

	public static function isLeftPressed():Bool
	{
		if (FlxG.keys.anyPressed([LEFT, A]))
		{
			lastInputMethod = KEYBOARD;
			return true;
		}

		if (gamepad != null && (gamepad.pressed.DPAD_LEFT || gamepad.getXAxis(LEFT_ANALOG_STICK) < -0.4))
		{
			lastInputMethod = GAMEPAD;
			return true;
		}

		if (virtualPad != null && virtualPad.buttonLeft.pressed)
		{
			lastInputMethod = TOUCH;
			return true;
		}

		return isSwipeActive("left");
	}

	public static function isRightPressed():Bool
	{
		if (FlxG.keys.anyPressed([RIGHT, D]))
		{
			lastInputMethod = KEYBOARD;
			return true;
		}

		if (gamepad != null && (gamepad.pressed.DPAD_RIGHT || gamepad.getXAxis(LEFT_ANALOG_STICK) > 0.4))
		{
			lastInputMethod = GAMEPAD;
			return true;
		}

		if (virtualPad != null && virtualPad.buttonRight.pressed)
		{
			lastInputMethod = TOUCH;
			return true;
		}

		return isSwipeActive("right");
	}

	public static function isUpPressed():Bool
	{
		if (FlxG.keys.anyPressed([UP, W]))
		{
			lastInputMethod = KEYBOARD;
			return true;
		}

		if (gamepad != null && (gamepad.pressed.DPAD_UP || gamepad.getYAxis(LEFT_ANALOG_STICK) < -0.4))
		{
			lastInputMethod = GAMEPAD;
			return true;
		}

		if (virtualPad != null && virtualPad.buttonUp.pressed)
		{
			lastInputMethod = TOUCH;
			return true;
		}

		return isSwipeActive("up");
	}

	public static function isDownPressed():Bool
	{
		if (FlxG.keys.anyPressed([DOWN, S]))
		{
			lastInputMethod = KEYBOARD;
			return true;
		}

		if (gamepad != null && (gamepad.pressed.DPAD_DOWN || gamepad.getYAxis(LEFT_ANALOG_STICK) > 0.4))
		{
			lastInputMethod = GAMEPAD;
			return true;
		}

		if (virtualPad != null && virtualPad.buttonDown.pressed)
		{
			lastInputMethod = TOUCH;
			return true;
		}

		return isSwipeActive("down");
	}

	public static function isActionJustPressed():Bool
	{
		if (FlxG.keys.anyJustPressed([SPACE, ENTER]))
		{
			lastInputMethod = KEYBOARD;
			return true;
		}

		if (gamepad != null && (gamepad.justPressed.A || gamepad.justPressed.X))
		{
			lastInputMethod = GAMEPAD;
			return true;
		}

		if (virtualPad != null && virtualPad.buttonA.justPressed)
		{
			lastInputMethod = TOUCH;
			return true;
		}

		#if FLX_TOUCH
		if (tapJustHappened && virtualPad == null)
		{
			tapJustHappened = false;
			return true;
		}
		#end

		return false;
	}

	public static function isActionPressed():Bool
	{
		if (FlxG.keys.anyPressed([SPACE, ENTER]))
		{
			lastInputMethod = KEYBOARD;
			return true;
		}

		if (gamepad != null && (gamepad.pressed.A || gamepad.pressed.X))
		{
			lastInputMethod = GAMEPAD;
			return true;
		}

		if (virtualPad != null && virtualPad.buttonA.pressed)
		{
			lastInputMethod = TOUCH;
			return true;
		}

		return false;
	}

	public static function isBackJustPressed():Bool
	{
		if (FlxG.keys.anyJustPressed([ESCAPE, BACKSPACE]))
		{
			lastInputMethod = KEYBOARD;
			return true;
		}

		if (gamepad != null && gamepad.justPressed.BACK)
		{
			lastInputMethod = GAMEPAD;
			return true;
		}

		return false;
	}

	public static function getHorizontalAxis():Float
	{
		if (isLeftPressed() && !isRightPressed())
			return -1;

		if (isRightPressed() && !isLeftPressed())
			return 1;

		if (gamepad != null)
		{
			var axis:Float = gamepad.getXAxis(LEFT_ANALOG_STICK);

			if (Math.abs(axis) > 0.15)
				return axis;
		}

		return 0;
	}

	public static function getVerticalAxis():Float
	{
		if (isUpPressed() && !isDownPressed())
			return -1;

		if (isDownPressed() && !isUpPressed())
			return 1;

		if (gamepad != null)
		{
			var axis:Float = gamepad.getYAxis(LEFT_ANALOG_STICK);

			if (Math.abs(axis) > 0.15)
				return axis;
		}

		return 0;
	}
}
