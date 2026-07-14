package shark.ui.input;

import flixel.FlxG;
import shark.backend.Paths;

class Cursor
{
	public static var isCustom(default, null):Bool = false;
	public static var scale:Float = 1;
	public static var offsetX:Int = 0;
	public static var offsetY:Int = 0;

	static inline var CURSOR_KEY:String = "cursor/mouse";

	public static function initialize():Void
	{
		if (FlxG.onMobile)
		{
			FlxG.mouse.visible = false;
			return;
		}

		load();
	}

	public static function load():Void
	{
		var path:String = Paths.image(CURSOR_KEY);

		if (!Paths.exists(path))
		{
			fallbackToSystemCursor();
			return;
		}

		var graphic = Paths.getGraphic(CURSOR_KEY, true);

		if (graphic == null)
		{
			fallbackToSystemCursor();
			return;
		}

		FlxG.mouse.load(graphic, scale, offsetX, offsetY);
		FlxG.mouse.useSystemCursor = false;
		FlxG.mouse.visible = true;

		isCustom = true;
	}

	static function fallbackToSystemCursor():Void
	{
		isCustom = false;
		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = true;
	}

	public static function reload():Void
	{
		FlxG.mouse.unload();
		load();
	}

	public static function show():Void
	{
		FlxG.mouse.visible = true;
	}

	public static function hide():Void
	{
		FlxG.mouse.visible = false;
	}

	public static function useSystemCursor():Void
	{
		FlxG.mouse.unload();
		fallbackToSystemCursor();
	}

	public static function setTransform(newScale:Float, newOffsetX:Int, newOffsetY:Int):Void
	{
		scale = newScale;
		offsetX = newOffsetX;
		offsetY = newOffsetY;

		if (isCustom)
			reload();
	}
}
