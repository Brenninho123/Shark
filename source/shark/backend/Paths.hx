package shark.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.text.Font;
import shark.backend.JsonObject;

class Paths
{
	static inline var ASSET_ROOT:String = "assets";

	static var graphicCache:Map<String, FlxGraphic> = new Map();
	static var atlasCache:Map<String, FlxAtlasFrames> = new Map();
	static var soundCache:Map<String, Sound> = new Map();
	static var fontCache:Map<String, String> = new Map();
	static var textCache:Map<String, String> = new Map();
	static var existsCache:Map<String, Bool> = new Map();

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

		if (!exists(path))
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

		if (!exists(xmlPath))
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

		if (!exists(path))
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

		if (!exists(path))
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

		if (!exists(path))
			return null;

		var content:String = Assets.getText(path);
		textCache.set(cacheKey, content);

		return content;
	}

	public static function getJson(key:String):Dynamic
	{
		var raw:String = getText(key, "json");

		if (raw == null)
			return null;

		try
		{
			return haxe.Json.parse(raw);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function getJsonObject(key:String):JsonObject
	{
		var raw:String = getText(key, "json");
		return JsonObject.parse(raw);
	}

	public static function dataExists(key:String):Bool
	{
		return exists(data(key));
	}

	public static function invalidateText(key:String, extension:String = "json"):Void
	{
		textCache.remove('$key.$extension');
	}

	public static function exists(path:String):Bool
	{
		if (existsCache.exists(path))
			return existsCache.get(path);

		var result:Bool = Assets.exists(path);
		existsCache.set(path, result);

		return result;
	}

	public static function imageExists(key:String):Bool
	{
		return exists(image(key));
	}

	public static function soundExists(key:String):Bool
	{
		return exists(sound(key));
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

	public static function preloadWithProgress(keys:Array<String>, kind:String, ?onProgress:Float->Void, ?onComplete:Void->Void, persist:Bool = true):Void
	{
		for (i in 0...keys.length)
		{
			if (kind == "sound")
				getSound(keys[i], persist);
			else
				getGraphic(keys[i], persist);

			if (onProgress != null)
				onProgress((i + 1) / keys.length);
		}

		if (onComplete != null)
			onComplete();
	}

	public static function randomSoundVariant(baseKey:String, count:Int):String
	{
		var index:Int = 1 + Std.random(count);
		return '${baseKey}${index}';
	}

	public static function getRandomSound(baseKey:String, count:Int, persist:Bool = false):Sound
	{
		return getSound(randomSoundVariant(baseKey, count), persist);
	}

	public static function getRandomGraphic(baseKey:String, count:Int, persist:Bool = false):FlxGraphic
	{
		var index:Int = 1 + Std.random(count);
		return getGraphic('${baseKey}${index}', persist);
	}

	public static function getCacheStats():String
	{
		var graphics:Int = 0;

		for (key in graphicCache.keys())
			graphics++;

		var sounds:Int = 0;

		for (key in soundCache.keys())
			sounds++;

		var texts:Int = 0;

		for (key in textCache.keys())
			texts++;

		return 'graphics: $graphics, sounds: $sounds, texts: $texts';
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
		existsCache = new Map();

		if (includePersistent)
			persistentKeys = new Map();
	}
}
