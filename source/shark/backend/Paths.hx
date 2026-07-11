package shark.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;

class Paths
{
	static inline var ASSET_ROOT:String = "assets";

	static var graphicCache:Map<String, FlxGraphic> = new Map();
	static var soundCache:Map<String, Sound> = new Map();

	public static function image(key:String):String
	{
		return '$ASSET_ROOT/images/$key.png';
	}

	public static function sound(key:String):String
	{
		return '$ASSET_ROOT/sounds/$key.ogg';
	}

	public static function music(key:String):String
	{
		return '$ASSET_ROOT/music/$key.ogg';
	}

	public static function font(key:String):String
	{
		return '$ASSET_ROOT/fonts/$key';
	}

	public static function data(key:String):String
	{
		return '$ASSET_ROOT/data/$key.json';
	}

	public static function file(key:String, extension:String = "txt"):String
	{
		return '$ASSET_ROOT/data/$key.$extension';
	}

	public static function getGraphic(key:String):FlxGraphic
	{
		if (graphicCache.exists(key))
			return graphicCache.get(key);

		var path:String = image(key);

		if (!Assets.exists(path))
			return null;

		var bitmapData:BitmapData = Assets.getBitmapData(path);
		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmapData, false, path);
		graphic.persist = true;

		graphicCache.set(key, graphic);

		return graphic;
	}

	public static function getSound(key:String):Sound
	{
		if (soundCache.exists(key))
			return soundCache.get(key);

		var path:String = sound(key);

		if (!Assets.exists(path))
			return null;

		var loadedSound:Sound = Assets.getSound(path);
		soundCache.set(key, loadedSound);

		return loadedSound;
	}

	public static function getText(key:String, extension:String = "json"):String
	{
		var path:String = extension == "json" ? data(key) : file(key, extension);

		if (!Assets.exists(path))
			return null;

		return Assets.getText(path);
	}

	public static function exists(path:String):Bool
	{
		return Assets.exists(path);
	}

	public static function clearCache():Void
	{
		for (graphic in graphicCache)
			if (graphic != null)
				graphic.destroy();

		graphicCache = new Map();
		soundCache = new Map();
	}
}
