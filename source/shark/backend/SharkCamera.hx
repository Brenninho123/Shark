package shark.backend;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;

enum ShakeIntensity
{
	LIGHT;
	MEDIUM;
	HEAVY;
}

enum FlashKind
{
	SUCCESS;
	DAMAGE;
	NEUTRAL;
}

class SharkCamera
{
	public static var defaultZoom(default, null):Float = 1;
	public static var isTransitioning(default, null):Bool = false;

	public static function initialize():Void
	{
		if (FlxG.camera != null)
			defaultZoom = FlxG.camera.zoom;
	}

	public static function shake(intensity:ShakeIntensity = MEDIUM, duration:Float = 0.3):Void
	{
		if (FlxG.camera == null)
			return;

		var amount:Float = switch (intensity)
		{
			case LIGHT: 0.01;
			case MEDIUM: 0.025;
			case HEAVY: 0.05;
		}

		FlxG.camera.shake(amount, duration);
	}

	public static function flash(kind:FlashKind = NEUTRAL, duration:Float = 0.25):Void
	{
		if (FlxG.camera == null)
			return;

		var color:FlxColor = switch (kind)
		{
			case SUCCESS: 0xFF61D8A0;
			case DAMAGE: 0xFFF87171;
			case NEUTRAL: 0xFFFFFFFF;
		}

		FlxG.camera.flash(color, duration);
	}

	public static function fadeOut(duration:Float = 0.4, color:FlxColor = FlxColor.BLACK, ?onComplete:Void->Void):Void
	{
		if (FlxG.camera == null)
		{
			if (onComplete != null)
				onComplete();

			return;
		}

		FlxG.camera.fade(color, duration, false, onComplete, true);
	}

	public static function fadeIn(duration:Float = 0.4, color:FlxColor = FlxColor.BLACK, ?onComplete:Void->Void):Void
	{
		if (FlxG.camera == null)
		{
			if (onComplete != null)
				onComplete();

			return;
		}

		FlxG.camera.fade(color, duration, true, onComplete, true);
	}

	public static function transitionToState(newState:FlxState, duration:Float = 0.4, color:FlxColor = FlxColor.BLACK):Void
	{
		if (isTransitioning)
			return;

		isTransitioning = true;

		fadeOut(duration, color, function():Void
		{
			FlxG.switchState(newState);
			fadeIn(duration, color, function():Void
			{
				isTransitioning = false;
			});
		});
	}

	public static function zoomTo(zoom:Float, duration:Float = 0.3):Void
	{
		if (FlxG.camera == null)
			return;

		FlxTween.tween(FlxG.camera, {zoom: zoom}, duration, {ease: FlxEase.quadOut});
	}

	public static function zoomPulse(amount:Float = 0.08, duration:Float = 0.15):Void
	{
		if (FlxG.camera == null)
			return;

		var baseZoom:Float = FlxG.camera.zoom;

		FlxTween.tween(FlxG.camera, {zoom: baseZoom + amount}, duration / 2, {
			ease: FlxEase.quadOut,
			onComplete: function(_):Void
			{
				FlxTween.tween(FlxG.camera, {zoom: baseZoom}, duration / 2, {ease: FlxEase.quadIn});
			}
		});
	}

	public static function resetZoom(duration:Float = 0.3):Void
	{
		zoomTo(defaultZoom, duration);
	}

	public static function tint(color:FlxColor, duration:Float = 0.5):Void
	{
		if (FlxG.camera == null)
			return;

		FlxG.camera.color = FlxColor.WHITE;
		FlxTween.color(FlxG.camera, duration, FlxG.camera.color, color);
	}

	public static function clearTint(duration:Float = 0.5):Void
	{
		if (FlxG.camera == null)
			return;

		FlxTween.color(FlxG.camera, duration, FlxG.camera.color, FlxColor.WHITE);
	}

	public static function follow(target:FlxSprite, lerpAmount:Float = 1, ?offsetX:Float, ?offsetY:Float):Void
	{
		if (FlxG.camera == null || target == null)
			return;

		FlxG.camera.follow(target, LOCKON, lerpAmount);

		if (offsetX != null || offsetY != null)
			FlxG.camera.followOffset.set(offsetX != null ? offsetX : 0, offsetY != null ? offsetY : 0);
	}

	public static function stopFollowing():Void
	{
		if (FlxG.camera != null)
			FlxG.camera.target = null;
	}
}
