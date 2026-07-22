package git.resolution;

import flixel.FlxG;
import openfl.system.Capabilities;

class Resolution4K
{
	public static inline var UHD_WIDTH:Int = 3840;
	public static inline var UHD_HEIGHT:Int = 2160;

	public static inline var BASE_DESIGN_WIDTH:Int = 1280;
	public static inline var BASE_DESIGN_HEIGHT:Int = 720;

	public static var isUHD(default, null):Bool = false;
	public static var uiScale(default, null):Float = 1;
	public static var screenWidth(default, null):Int = 0;
	public static var screenHeight(default, null):Int = 0;

	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		screenWidth = Std.int(Capabilities.screenResolutionX);
		screenHeight = Std.int(Capabilities.screenResolutionY);

		isUHD = screenWidth >= UHD_WIDTH || screenHeight >= UHD_HEIGHT;
		uiScale = calculateUiScale();
	}

	static function calculateUiScale():Float
	{
		if (screenWidth <= 0)
			return 1;

		var widthScale:Float = screenWidth / BASE_DESIGN_WIDTH;
		var heightScale:Float = screenHeight / BASE_DESIGN_HEIGHT;
		var scale:Float = Math.min(widthScale, heightScale);

		return clampScale(scale);
	}

	static function clampScale(scale:Float):Float
	{
		if (scale < 1)
			return 1;

		if (scale > 3)
			return 3;

		return scale;
	}

	public static function scaledInt(baseSize:Int):Int
	{
		return Std.int(baseSize * uiScale);
	}

	public static function scaledFloat(baseSize:Float):Float
	{
		return baseSize * uiScale;
	}

	public static function recommendedWindowSize():{width:Int, height:Int}
	{
		if (!isUHD)
			return {width: BASE_DESIGN_WIDTH, height: BASE_DESIGN_HEIGHT};

		return {width: UHD_WIDTH, height: UHD_HEIGHT};
	}

	public static function applyRecommendedZoom():Void
	{
		#if desktop
		if (FlxG.camera == null)
			return;

		FlxG.camera.zoom = uiScale;
		#end
	}

	public static function getResolutionLabel():String
	{
		var tag:String = isUHD ? " (UHD)" : "";
		return '${screenWidth}x${screenHeight}$tag';
	}

	public static function getScaleSummary():String
	{
		return 'Resolution: ${getResolutionLabel()} | UI scale: ${Math.round(uiScale * 100)}%';
	}
}
