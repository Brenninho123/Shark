package shark.mobile.utils;

import flixel.FlxG;

#if FLX_TOUCH
import flixel.input.touch.FlxTouch;
#end

typedef TouchState = {
	id:Int,
	startX:Float,
	startY:Float,
	startTime:Float,
	lastX:Float,
	lastY:Float,
	isDragging:Bool,
	longPressTriggered:Bool
}

class TouchUtil
{
	public static var deadZonePixels:Float = 12;
	public static var tapMaxDurationSeconds:Float = 0.25;
	public static var longPressDurationSeconds:Float = 0.6;
	public static var doubleTapWindowSeconds:Float = 0.35;
	public static var swipeMinDistance:Float = 40;
	public static var swipeMaxDurationSeconds:Float = 0.5;
	public static var touchTargetPadding:Float = 12;

	public static var onTap:Float->Float->Void;
	public static var onDoubleTap:Float->Float->Void;
	public static var onLongPress:Float->Float->Void;
	public static var onSwipe:String->Float->Float->Void;
	public static var onDragStart:Float->Float->Void;
	public static var onDragMove:Float->Float->Float->Float->Void;
	public static var onDragEnd:Float->Float->Void;

	static var activeTouches:Map<Int, TouchState> = new Map();
	static var lastTapTime:Float = -1;
	static var lastTapX:Float = 0;
	static var lastTapY:Float = 0;

	public static function update(elapsed:Float):Void
	{
		#if FLX_TOUCH
		var seenIds:Map<Int, Bool> = new Map();

		for (touch in FlxG.touches.list)
		{
			seenIds.set(touch.touchPointID, true);
			processTouch(touch);
		}

		for (id in activeTouches.keys())
			if (!seenIds.exists(id))
				activeTouches.remove(id);
		#end
	}

	#if FLX_TOUCH
	static function processTouch(touch:FlxTouch):Void
	{
		var id:Int = touch.touchPointID;
		var pos = touch.getWorldPosition();

		if (touch.justPressed)
		{
			activeTouches.set(id, {
				id: id,
				startX: pos.x,
				startY: pos.y,
				startTime: haxe.Timer.stamp(),
				lastX: pos.x,
				lastY: pos.y,
				isDragging: false,
				longPressTriggered: false
			});
		}
		else if (activeTouches.exists(id))
		{
			var state:TouchState = activeTouches.get(id);
			var dx:Float = pos.x - state.startX;
			var dy:Float = pos.y - state.startY;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);

			if (!state.isDragging && dist > deadZonePixels)
			{
				state.isDragging = true;

				if (onDragStart != null)
					onDragStart(state.startX, state.startY);
			}

			if (state.isDragging)
			{
				var moveDx:Float = pos.x - state.lastX;
				var moveDy:Float = pos.y - state.lastY;

				if (onDragMove != null)
					onDragMove(pos.x, pos.y, moveDx, moveDy);
			}

			state.lastX = pos.x;
			state.lastY = pos.y;

			var elapsedTouch:Float = haxe.Timer.stamp() - state.startTime;

			if (!state.isDragging && !state.longPressTriggered && elapsedTouch >= longPressDurationSeconds)
			{
				state.longPressTriggered = true;

				if (onLongPress != null)
					onLongPress(pos.x, pos.y);
			}
		}

		if (touch.justReleased && activeTouches.exists(id))
		{
			var state:TouchState = activeTouches.get(id);
			var dx:Float = pos.x - state.startX;
			var dy:Float = pos.y - state.startY;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);
			var duration:Float = haxe.Timer.stamp() - state.startTime;

			if (state.isDragging)
			{
				if (onDragEnd != null)
					onDragEnd(pos.x, pos.y);

				if (dist >= swipeMinDistance && duration <= swipeMaxDurationSeconds)
				{
					var direction:String = getSwipeDirection(dx, dy);
					var velocity:Float = dist / Math.max(duration, 0.001);

					if (onSwipe != null)
						onSwipe(direction, dist, velocity);
				}
			}
			else if (!state.longPressTriggered && duration <= tapMaxDurationSeconds)
			{
				handleTap(pos.x, pos.y);
			}

			activeTouches.remove(id);
		}

		pos.put();
	}

	static function getSwipeDirection(dx:Float, dy:Float):String
	{
		if (Math.abs(dx) > Math.abs(dy))
			return dx > 0 ? "right" : "left";

		return dy > 0 ? "down" : "up";
	}

	static function handleTap(x:Float, y:Float):Void
	{
		var now:Float = haxe.Timer.stamp();

		if (lastTapTime >= 0 && (now - lastTapTime) <= doubleTapWindowSeconds)
		{
			var dx:Float = x - lastTapX;
			var dy:Float = y - lastTapY;

			if (Math.sqrt(dx * dx + dy * dy) <= deadZonePixels * 2)
			{
				if (onDoubleTap != null)
					onDoubleTap(x, y);

				lastTapTime = -1;
				return;
			}
		}

		lastTapTime = now;
		lastTapX = x;
		lastTapY = y;

		if (onTap != null)
			onTap(x, y);
	}
	#end

	public static function isPointNearTarget(x:Float, y:Float, targetX:Float, targetY:Float, targetWidth:Float, targetHeight:Float):Bool
	{
		var pad:Float = touchTargetPadding;

		return x >= targetX - pad && x <= targetX + targetWidth + pad && y >= targetY - pad && y <= targetY + targetHeight + pad;
	}

	public static function getActiveTouchCount():Int
	{
		var count:Int = 0;

		#if FLX_TOUCH
		for (id in activeTouches.keys())
			count++;
		#end

		return count;
	}

	public static function reset():Void
	{
		activeTouches = new Map();
		lastTapTime = -1;
	}
}
