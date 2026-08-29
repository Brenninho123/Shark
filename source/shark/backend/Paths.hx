package shark.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.net.URLRequest;
import openfl.text.Font;
import shark.backend.JsonObject;
import shark.modding.Module;
import shark.ui.debug.CrasherLog;

import Main;

class Paths
{
	static inline var ASSET_ROOT:String = "assets";
	static inline var MAX_GRAPHIC_CACHE_SIZE:Int = 120;

	public static var modOverridesEnabled:Bool = true;

	static var graphicCache:Map<String, FlxGraphic> = new Map();
	static var atlasCache:Map<String, FlxAtlasFrames> = new Map();
	static var soundCache:Map<String, Sound> = new Map();
	static var fontCache:Map<String, String> = new Map();
	static var textCache:Map<String, String> = new Map();
	static var existsCache:Map<String, Bool> = new Map();
	static var modOverrideCache:Map<String, Bool> = new Map();

	static var persistentKeys:Map<String, Bool> = new Map();
	static var graphicAccessOrder:Array<String> = [];

	static var modSourcedGraphicKeys:Map<String, Bool> = new Map();
	static var modSourcedTextKeys:Map<String, Bool> = new Map();
	static var modSourcedSoundKeys:Map<String, Bool> = new Map();

	static var cacheHits:Int = 0;
	static var cacheMisses:Int = 0;

	public static function image(key:String):String
	{
		return '$ASSET_ROOT/images/$key.png';
	}

	public static function astcVariantPath(key:String):String
	{
		return '$ASSET_ROOT/images/astc/$key.astc';
	}

	public static var preferCompressedTextures(get, never):Bool;

	static function get_preferCompressedTextures():Bool
	{
		return FlxG.onMobile;
	}

	public static function hasAstcVariant(key:String):Bool
	{
		return exists(astcVariantPath(key));
	}

	public static function shouldUseAstc(key:String):Bool
	{
		return preferCompressedTextures && hasAstcVariant(key);
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

	public static function getModOverridePath(category:String, key:String, extension:String):String
	{
		#if sys
		if (!modOverridesEnabled)
			return null;

		var cacheKeyPath:String = '$category/$key.$extension';

		if (modOverrideCache.exists(cacheKeyPath))
			return modOverrideCache.get(cacheKeyPath) ? buildModOverridePath(category, key, extension) : null;

		var path:String = buildModOverridePath(category, key, extension);
		var found:Bool = sys.FileSystem.exists(path);

		modOverrideCache.set(cacheKeyPath, found);

		return found ? path : null;
		#else
		return null;
		#end
	}

	static function buildModOverridePath(category:String, key:String, extension:String):String
	{
		return '${Module.getModsDirectory()}/assets/$category/$key.$extension';
	}

	public static function hasModOverride(category:String, key:String, extension:String):Bool
	{
		return getModOverridePath(category, key, extension) != null;
	}

	public static function describeAsset(category:String, key:String, extension:String):String
	{
		var overridePath:String = getModOverridePath(category, key, extension);
		return overridePath != null ? 'mod override: $overridePath' : "base game asset";
	}

	public static function clearModOverrideCache():Void
	{
		modOverrideCache = new Map();
	}

	public static function onModsReloaded():Void
	{
		clearModOverrideCache();

		for (key in modSourcedGraphicKeys.keys())
		{
			if (graphicCache.exists(key))
			{
				var graphic:FlxGraphic = graphicCache.get(key);

				if (graphic != null)
					graphic.destroy();

				graphicCache.remove(key);
			}

			graphicAccessOrder.remove(key);
		}

		for (key in modSourcedTextKeys.keys())
			textCache.remove(key);

		for (key in modSourcedSoundKeys.keys())
			soundCache.remove(key);

		modSourcedGraphicKeys = new Map();
		modSourcedTextKeys = new Map();
		modSourcedSoundKeys = new Map();
		existsCache = new Map();

		CrasherLog.addBreadcrumb("Paths caches invalidated after mod reload", "assets");
	}

	static function touchGraphicAccess(key:String):Void
	{
		graphicAccessOrder.remove(key);
		graphicAccessOrder.push(key);
		evictOldestGraphicIfNeeded();
	}

	static function evictOldestGraphicIfNeeded():Void
	{
		if (graphicAccessOrder.length <= MAX_GRAPHIC_CACHE_SIZE)
			return;

		for (i in 0...graphicAccessOrder.length)
		{
			var candidate:String = graphicAccessOrder[i];

			if (persistentKeys.exists(candidate))
				continue;

			graphicAccessOrder.splice(i, 1);

			if (graphicCache.exists(candidate))
			{
				var graphic:FlxGraphic = graphicCache.get(candidate);

				if (graphic != null)
					graphic.destroy();

				graphicCache.remove(candidate);
			}

			return;
		}
	}

	public static function getGraphic(key:String, persist:Bool = false, checkCompressed:Bool = false):FlxGraphic
	{
		if (graphicCache.exists(key))
		{
			cacheHits++;
			touchGraphicAccess(key);
			return graphicCache.get(key);
		}

		cacheMisses++;

		if (hasModOverride("images", key, "png"))
			CrasherLog.logWarning('Mod override found for image "$key" - use getGraphicAsync() or preloadModOverrides() first, since synchronous getGraphic() cannot load external mod files', "assets");

		if (checkCompressed && shouldUseAstc(key))
			CrasherLog.logWarning('ASTC variant found for "$key" but GPU texture upload is not implemented yet; using PNG fallback', "assets");

		var path:String = image(key);

		if (!exists(path))
			return null;

		var bitmapData:BitmapData = Assets.getBitmapData(path);
		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmapData, false, path);
		graphic.persist = persist;

		graphicCache.set(key, graphic);
		touchGraphicAccess(key);

		if (persist)
			persistentKeys.set(key, true);

		return graphic;
	}

	public static function getGraphicAsync(key:String, onComplete:FlxGraphic->Void, persist:Bool = false):Void
	{
		if (graphicCache.exists(key))
		{
			cacheHits++;
			touchGraphicAccess(key);
			onComplete(graphicCache.get(key));
			return;
		}

		cacheMisses++;

		var overridePath:String = getModOverridePath("images", key, "png");

		if (overridePath == null)
		{
			onComplete(getGraphic(key, persist));
			return;
		}

		#if sys
		BitmapData.loadFromFile(overridePath).onComplete(function(bitmapData:BitmapData):Void
		{
			if (bitmapData == null)
			{
				onComplete(getGraphic(key, persist));
				return;
			}

			var graphic:FlxGraphic = FlxGraphic.fromBitmapData(bitmapData, false, 'mod:$key');
			graphic.persist = persist;

			graphicCache.set(key, graphic);
			touchGraphicAccess(key);
			modSourcedGraphicKeys.set(key, true);

			if (persist)
				persistentKeys.set(key, true);

			onComplete(graphic);
		}).onError(function(_):Void
		{
			onComplete(getGraphic(key, persist));
		});
		#else
		onComplete(getGraphic(key, persist));
		#end
	}

	public static function preloadModOverrides(keys:Array<String>, ?onComplete:Void->Void):Void
	{
		var remaining:Int = keys.length;

		if (remaining == 0)
		{
			if (onComplete != null)
				onComplete();

			return;
		}

		for (key in keys)
		{
			getGraphicAsync(key, function(_):Void
			{
				remaining--;

				if (remaining <= 0 && onComplete != null)
					onComplete();
			});
		}
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
		{
			cacheHits++;
			return soundCache.get(key);
		}

		cacheMisses++;

		#if sys
		var overridePath:String = getModOverridePath("sounds", key, soundExtension);

		if (overridePath != null)
		{
			try
			{
				var moddedSound:Sound = new Sound(new URLRequest(overridePath));
				soundCache.set(key, moddedSound);
				modSourcedSoundKeys.set(key, true);

				if (persist)
					persistentKeys.set(key, true);

				return moddedSound;
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Failed to load mod sound override "$overridePath": ${Std.string(e)}', "assets");
			}
		}
		#end

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

		if (hasModOverride("fonts", key, "ttf"))
			CrasherLog.logWarning('Mod override found for font "$key" but external font loading is not supported yet - using bundled font', "assets");

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
		{
			cacheHits++;
			return textCache.get(cacheKey);
		}

		cacheMisses++;

		var overridePath:String = getModOverridePath("data", key, extension);

		#if sys
		if (overridePath != null)
		{
			try
			{
				var overrideContent:String = sys.io.File.getContent(overridePath);
				textCache.set(cacheKey, overrideContent);
				modSourcedTextKeys.set(cacheKey, true);
				return overrideContent;
			}
			catch (e:Dynamic) {}
		}
		#end

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
			return haxe.Json.parse(JsonObject.stripJsonComments(raw));
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

	public static function localizedPath(key:String, ?language:String):String
	{
		var lang:String = language != null ? language : Main.systemLanguage;
		return 'lang/$lang/$key';
	}

	public static function getLocalizedText(key:String, ?language:String):String
	{
		var lang:String = language != null ? language : Main.systemLanguage;
		var primary:String = getText(localizedPath(key, lang));

		if (primary != null)
			return primary;

		if (lang != "en")
		{
			var fallback:String = getText(localizedPath(key, "en"));

			if (fallback != null)
				return fallback;
		}

		return null;
	}

	public static function getLocalizedJsonObject(key:String, ?language:String):JsonObject
	{
		var raw:String = getLocalizedText(key, language);
		return JsonObject.parse(raw);
	}

	public static function hasLocalization(key:String, ?language:String):Bool
	{
		var lang:String = language != null ? language : Main.systemLanguage;
		return dataExists(localizedPath(key, lang));
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

	public static function preloadWithProgressAsync(keys:Array<String>, kind:String, batchSize:Int = 5, ?onProgress:Float->Void, ?onComplete:Void->Void,
			persist:Bool = true):Void
	{
		var index:Int = 0;

		function loadBatch():Void
		{
			var end:Int = Std.int(Math.min(index + batchSize, keys.length));

			while (index < end)
			{
				if (kind == "sound")
					getSound(keys[index], persist);
				else
					getGraphic(keys[index], persist);

				index++;
			}

			if (onProgress != null)
				onProgress(index / keys.length);

			if (index < keys.length)
				haxe.Timer.delay(loadBatch, 1);
			else if (onComplete != null)
				onComplete();
		}

		loadBatch();
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

	public static function getCacheEntryCount():Int
	{
		var count:Int = 0;

		for (key in graphicCache.keys())
			count++;

		for (key in soundCache.keys())
			count++;

		for (key in textCache.keys())
			count++;

		return count;
	}

	public static function getStatusSummary():String
	{
		var totalRequests:Int = cacheHits + cacheMisses;
		var hitRate:Float = totalRequests > 0 ? (cacheHits / totalRequests) * 100 : 0;

		return 'Paths: ${getCacheStats()} | hit rate ${formatDecimal(hitRate, 1)}% | mods ${modOverridesEnabled ? "enabled" : "disabled"}';
	}

	static function formatDecimal(value:Float, decimals:Int):String
	{
		var factor:Float = Math.pow(10, decimals);
		var rounded:Float = Math.round(value * factor) / factor;
		var text:String = Std.string(rounded);

		if (text.indexOf(".") == -1)
			text += ".0";

		return text;
	}

	public static function clearVolatileCache():Void
	{
		clearCache(false);
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
			graphicAccessOrder.remove(key);
		}

		for (key in soundCache.keys())
			if (includePersistent || !persistentKeys.exists(key))
				soundCache.remove(key);

		for (key in atlasCache.keys())
			if (includePersistent || !persistentKeys.exists(key))
				atlasCache.remove(key);

		textCache = new Map();
		existsCache = new Map();
		modOverrideCache = new Map();

		if (includePersistent)
		{
			persistentKeys = new Map();
			modSourcedGraphicKeys = new Map();
			modSourcedTextKeys = new Map();
			modSourcedSoundKeys = new Map();
		}
	}
}
