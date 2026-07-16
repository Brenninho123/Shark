package shark.backend.input;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepad;
import flixel.addons.ui.FlxVirtualPad;
import flixel.addons.ui.FlxVirtualPad.FlxVirtualPadDPadMode;
import flixel.addons.ui.FlxVirtualPad.FlxVirtualPadButtonMode;

class Controls
{
	public static var isMobile(default, null):Bool;
	public static var virtualPad(default, null):FlxVirtualPad;

	public static var onGamepadConnected:FlxGamepad->Void;
	public static var onGamepadDisconnected:FlxGamepad->Void;

	static var initialized:Bool = false;

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

	public static function isLeftPressed():Bool
	{
		if (FlxG.keys.anyPressed([LEFT, A]))
			return true;

		if (gamepad != null && (gamepad.pressed.DPAD_LEFT || gamepad.getXAxis(LEFT_ANALOG_STICK) < -0.4))
			return true;

		if (virtualPad != null && virtualPad.buttonLeft.pressed)
			return true;

		return false;
	}

	public static function isRightPressed():Bool
	{
		if (FlxG.keys.anyPressed([RIGHT, D]))
			return true;

		if (gamepad != null && (gamepad.pressed.DPAD_RIGHT || gamepad.getXAxis(LEFT_ANALOG_STICK) > 0.4))
			return true;

		if (virtualPad != null && virtualPad.buttonRight.pressed)
			return true;

		return false;
	}

	public static function isUpPressed():Bool
	{
		if (FlxG.keys.anyPressed([UP, W]))
			return true;

		if (gamepad != null && (gamepad.pressed.DPAD_UP || gamepad.getYAxis(LEFT_ANALOG_STICK) < -0.4))
			return true;

		if (virtualPad != null && virtualPad.buttonUp.pressed)
			return true;

		return false;
	}

	public static function isDownPressed():Bool
	{
		if (FlxG.keys.anyPressed([DOWN, S]))
			return true;

		if (gamepad != null && (gamepad.pressed.DPAD_DOWN || gamepad.getYAxis(LEFT_ANALOG_STICK) > 0.4))
			return true;

		if (virtualPad != null && virtualPad.buttonDown.pressed)
			return true;

		return false;
	}

	public static function isActionJustPressed():Bool
	{
		if (FlxG.keys.anyJustPressed([SPACE, ENTER]))
			return true;

		if (gamepad != null && (gamepad.justPressed.A || gamepad.justPressed.X))
			return true;

		if (virtualPad != null && virtualPad.buttonA.justPressed)
			return true;

		#if FLX_TOUCH
		var touch = FlxG.touches.getFirst();

		if (touch != null && touch.justPressed && virtualPad == null)
			return true;
		#end

		return false;
	}

	public static function isActionPressed():Bool
	{
		if (FlxG.keys.anyPressed([SPACE, ENTER]))
			return true;

		if (gamepad != null && (gamepad.pressed.A || gamepad.pressed.X))
			return true;

		if (virtualPad != null && virtualPad.buttonA.pressed)
			return true;

		return false;
	}

	public static function isBackJustPressed():Bool
	{
		if (FlxG.keys.anyJustPressed([ESCAPE, BACKSPACE]))
			return true;

		if (gamepad != null && gamepad.justPressed.BACK)
			return true;

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
