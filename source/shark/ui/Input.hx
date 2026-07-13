package shark.ui;

import flixel.FlxG;
import flixel.math.FlxPoint;
import flixel.input.keyboard.FlxKey;

enum InputAction
{
	CONFIRM;
	CANCEL;
	LEFT;
	RIGHT;
	UP;
	DOWN;
	JUMP;
}

typedef SwipeResult = {
	direction:String,
	distance:Float
}

class Input
{
	public static var isMobile(default, null):Bool;

	static var bindings:Map<InputAction, Array<FlxKey>> = new Map();

	static var swipeStartX:Float = 0;
	static var swipeStartY:Float = 0;
	static var swipeStartTime:Float = 0;
	static var isTracking:Bool = false;

	static inline var SWIPE_MIN_DISTANCE:Float = 40;
	static inline var SWIPE_MAX_TIME:Float = 0.6;

	public static function initialize():Void
	{
		isMobile = FlxG.onMobile;

		bindings.set(CONFIRM, [ENTER, SPACE]);
		bindings.set(CANCEL, [ESCAPE, BACKSPACE]);
		bindings.set(LEFT, [LEFT, A]);
		bindings.set(RIGHT, [RIGHT, D]);
		bindings.set(UP, [UP, W]);
		bindings.set(DOWN, [DOWN, S]);
		bindings.set(JUMP, [SPACE, UP]);
	}

	public static function justPressed(action:InputAction):Bool
	{
		var keys:Array<FlxKey> = bindings.get(action);

		if (keys == null)
			return false;

		for (key in keys)
			if (FlxG.keys.checkStatus(key, JUST_PRESSED))
				return true;

		if (isPointerJustPressed() && (action == CONFIRM || action == JUMP))
			return true;

		return false;
	}

	public static function pressed(action:InputAction):Bool
	{
		var keys:Array<FlxKey> = bindings.get(action);

		if (keys == null)
			return false;

		for (key in keys)
			if (FlxG.keys.checkStatus(key, PRESSED))
				return true;

		return false;
	}

	public static function isPointerDown():Bool
	{
		if (FlxG.mouse.pressed)
			return true;

		#if FLX_TOUCH
		var touch = FlxG.touches.getFirst();

		if (touch != null)
			return true;
		#end

		return false;
	}

	public static function isPointerJustPressed():Bool
	{
		if (FlxG.mouse.justPressed)
			return true;

		#if FLX_TOUCH
		var touch = FlxG.touches.getFirst();

		if (touch != null && touch.justPressed)
			return true;
		#end

		return false;
	}

	public static function isPointerJustReleased():Bool
	{
		if (FlxG.mouse.justReleased)
			return true;

		#if FLX_TOUCH
		var touch = FlxG.touches.getFirst();

		if (touch != null && touch.justReleased)
			return true;
		#end

		return false;
	}

	public static function getPointerPosition():FlxPoint
	{
		#if FLX_TOUCH
		var touch = FlxG.touches.getFirst();

		if (touch != null)
			return touch.getWorldPosition();
		#end

		return FlxG.mouse.getWorldPosition();
	}

	public static function update():Void
	{
		trackSwipe();
	}

	static function trackSwipe():Void
	{
		if (isPointerJustPressed())
		{
			var pos:FlxPoint = getPointerPosition();
			swipeStartX = pos.x;
			swipeStartY = pos.y;
			swipeStartTime = haxe.Timer.stamp();
			isTracking = true;
			pos.put();
		}
	}

	public static function checkSwipeOnRelease():SwipeResult
	{
		if (!isTracking || !isPointerJustReleased())
			return null;

		isTracking = false;

		var elapsed:Float = haxe.Timer.stamp() - swipeStartTime;

		if (elapsed > SWIPE_MAX_TIME)
			return null;

		var pos:FlxPoint = getPointerPosition();
		var dx:Float = pos.x - swipeStartX;
		var dy:Float = pos.y - swipeStartY;
		pos.put();

		var distance:Float = Math.sqrt(dx * dx + dy * dy);

		if (distance < SWIPE_MIN_DISTANCE)
			return null;

		var direction:String;

		if (Math.abs(dx) > Math.abs(dy))
			direction = dx > 0 ? "right" : "left";
		else
			direction = dy > 0 ? "down" : "up";

		return {direction: direction, distance: distance};
	}

	public static function rebind(action:InputAction, keys:Array<FlxKey>):Void
	{
		bindings.set(action, keys);
	}
}
