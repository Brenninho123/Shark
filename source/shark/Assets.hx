package shark;

import shark.backend.Paths;
import lime.manager.LimeManager;

class Assets
{
	public static var isInitialized(default, null):Bool = false;

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
		var overridePath:String = Paths.getModOverridePath("images", key, "png");
		return overridePath != null ? overridePath : Paths.image(key);
	}

	public static function isImageOverridden(key:String):Bool
	{
		return Paths.hasModOverride("images", key, "png");
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
		Paths.clearModOverrideCache();
	}
}
