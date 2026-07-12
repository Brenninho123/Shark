package shark.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.text.Font;

class Paths
{
	static inline var ASSET_ROOT:String = "assets";

	static var graphicCache:Map<String, FlxGraphic> = new Map();
	static var atlasCache:Map<String, FlxAtlasFrames> = new Map();
	static var soundCache:Map<String, Sound> = new Map();
	static var fontCache:Map<String, String> = new Map();
	static var textCache:Map<String, String> = new Map();

	static var persistentKeys:Map<String, Bool> = new Map();

	public static function image(key:String):String
	{
		return '$ASSET_ROOT/images/$key.png';
	}

	public static function sound(key:String):String
	{
		return '$ASSET_ROOT/sounds/$key.$soundExtension';
	}

	public static function music(key:String):String
	{
		return '$ASSET_ROOT/music/$key.$soundExtension';
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

	public static var soundExtension(get, never):String;

	static function get_soundExtension():String
	{
		#if web
		return "mp3";
		#else
		return "ogg";
		#end
	}

	public static function getGraphic(key:String, persist:Bool = false):FlxGraphic
	{
		if (graphicCache.exists(key))
			return graphicCache.get(key);

		var path:String = image(key);

		if (!Assets.exists(path))
			return null;

		var bitmapData:BitmapData = Assets.getBitmapData(path);
		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmapData, false, path);
		graphic.persist = persist;

		graphicCache.set(key, graphic);

		if (persist)
			persistentKeys.set(key, true);

		return graphic;
	}

	public static function getSparrowAtlas(key:String, persist:Bool = false):FlxAtlasFrames
	{
		if (atlasCache.exists(key))
			return atlasCache.get(key);

		var graphic:FlxGraphic = getGraphic(key, persist);

		if (graphic == null)
			return null;

		var xmlPath:String = '$ASSET_ROOT/images/$key.xml';

		if (!Assets.exists(xmlPath))
			return null;

		var frames:FlxAtlasFrames = FlxAtlasFrames.fromSparrow(graphic, Assets.getText(xmlPath));
		atlasCache.set(key, frames);

		if (persist)
			persistentKeys.set(key, true);

		return frames;
	}

	public static function getSound(key:String, persist:Bool = false):Sound
	{
		if (soundCache.exists(key))
			return soundCache.get(key);

		var path:String = sound(key);

		if (!Assets.exists(path))
			return null;

		var loadedSound:Sound = Assets.getSound(path);
		soundCache.set(key, loadedSound);

		if (persist)
			persistentKeys.set(key, true);

		return loadedSound;
	}

	public static function getFont(key:String):String
	{
		if (fontCache.exists(key))
			return fontCache.get(key);

		var path:String = font(key);

		if (!Assets.exists(path))
			return null;

		var loadedFont:Font = Assets.getFont(path);
		var fontName:String = loadedFont != null ? loadedFont.fontName : null;

		if (fontName != null)
			fontCache.set(key, fontName);

		return fontName;
	}

	public static function getText(key:String, extension:String = "json"):String
	{
		var cacheKey:String = '$key.$extension';

		if (textCache.exists(cacheKey))
			return textCache.get(cacheKey);

		var path:String = extension == "json" ? data(key) : file(key, extension);

		if (!Assets.exists(path))
			return null;

		var content:String = Assets.getText(path);
		textCache.set(cacheKey, content);

		return content;
	}

	public static function exists(path:String):Bool
	{
		return Assets.exists(path);
	}

	public static function imageExists(key:String):Bool
	{
		return Assets.exists(image(key));
	}

	public static function soundExists(key:String):Bool
	{
		return Assets.exists(sound(key));
	}

	public static function preloadImages(keys:Array<String>, persist:Bool = true):Void
	{
		for (key in keys)
			getGraphic(key, persist);
	}

	public static function preloadSounds(keys:Array<String>, persist:Bool = true):Void
	{
		for (key in keys)
			getSound(key, persist);
	}

	public static function clearCache(includePersistent:Bool = false):Void
	{
		for (key => graphic in graphicCache)
		{
			if (!includePersistent && persistentKeys.exists(key))
				continue;

			if (graphic != null)
				graphic.destroy();

			graphicCache.remove(key);
		}

		for (key in soundCache.keys())
			if (includePersistent || !persistentKeys.exists(key))
				soundCache.remove(key);

		for (key in atlasCache.keys())
			if (includePersistent || !persistentKeys.exists(key))
				atlasCache.remove(key);

		textCache = new Map();

		if (includePersistent)
			persistentKeys = new Map();
	}
}
