package shark;

import shark.backend.Paths;
import shark.modding.Module;
import lime.manager.LimeManager;

class Assets
{
	public static var isInitialized(default, null):Bool = false;
	public static var modOverridesEnabled:Bool = true;

	static var overrideCache:Map<String, Bool> = new Map();

	public static function initialize():Void
	{
		if (isInitialized)
			return;

		isInitialized = true;

		var previousCallback:Bool->Void = LimeManager.onLowMemoryModeChanged;

		LimeManager.onLowMemoryModeChanged = function(isLow:Bool):Void
		{
			if (previousCallback != null)
				previousCallback(isLow);

			if (isLow)
				Paths.clearVolatileCache();
		};
	}

	public static function resolveImagePath(key:String):String
	{
		var overridePath:String = getModAssetPath("images", key, "png");

		if (overridePath != null)
			return overridePath;

		return Paths.image(key);
	}

	public static function resolveSoundKeyIsOverridden(key:String):Bool
	{
		return getModAssetPath("sounds", key, "ogg") != null || getModAssetPath("sounds", key, "mp3") != null;
	}

	static function getModAssetPath(category:String, key:String, extension:String):String
	{
		#if sys
		if (!modOverridesEnabled)
			return null;

		var cacheKey:String = '$category/$key.$extension';

		if (overrideCache.exists(cacheKey))
		{
			var cached:Bool = overrideCache.get(cacheKey);
			return cached ? buildModAssetPath(category, key, extension) : null;
		}

		var path:String = buildModAssetPath(category, key, extension);
		var exists:Bool = sys.FileSystem.exists(path);

		overrideCache.set(cacheKey, exists);

		return exists ? path : null;
		#else
		return null;
		#end
	}

	static function buildModAssetPath(category:String, key:String, extension:String):String
	{
		return '${Module.getModsDirectory()}/assets/$category/$key.$extension';
	}

	public static function clearOverrideCache():Void
	{
		overrideCache = new Map();
	}

	public static function preloadCritical(keys:Array<String>, ?onProgress:Float->Void, ?onComplete:Void->Void):Void
	{
		Paths.preloadWithProgress(keys, "image", onProgress, onComplete);
	}

	public static function getCacheReport():String
	{
		return 'Assets cached: ${Paths.getCacheEntryCount()} | Low memory: ${LimeManager.isLowMemoryMode}';
	}

	public static function forceClearAll(includePersistent:Bool = false):Void
	{
		Paths.clearCache(includePersistent);
		clearOverrideCache();
	}
}
