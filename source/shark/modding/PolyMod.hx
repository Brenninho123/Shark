package shark.modding;

#if sys
import polymod.Polymod;
import sys.FileSystem;
#end

import shark.ui.debug.CrasherLog;

class PolyMod
{
	public static var isSupported(default, null):Bool;
	public static var isInitialized(default, null):Bool = false;
	public static var loadedModIds(default, null):Array<String> = [];

	public static function initialize(?modIds:Array<String>):Void
	{
		#if sys
		isSupported = true;

		try
		{
			var root:String = Module.getModsDirectory();

			if (!FileSystem.exists(root))
				FileSystem.createDirectory(root);

			var dirsToLoad:Array<String> = modIds != null ? modIds : listAvailableModDirs(root);

			Polymod.init({
				modRoot: root,
				dirs: dirsToLoad,
				framework: FLIXEL,
				errorCallback: onPolymodMessage
			});

			loadedModIds = dirsToLoad;
			isInitialized = true;
		}
		catch (e:Dynamic)
		{
			isSupported = false;
			CrasherLog.logWarning('Polymod.init failed: ${Std.string(e)}', "polymod");
		}
		#else
		isSupported = false;
		#end
	}

	#if sys
	static function onPolymodMessage(error:Dynamic):Void
	{
		CrasherLog.logWarning('Polymod: ${Std.string(error)}', "polymod");
	}

	static function listAvailableModDirs(root:String):Array<String>
	{
		if (!FileSystem.exists(root))
			return [];

		var dirs:Array<String> = [];

		for (entry in FileSystem.readDirectory(root))
		{
			var fullPath:String = root + "/" + entry;

			try
			{
				if (FileSystem.isDirectory(fullPath))
					dirs.push(entry);
			}
			catch (e:Dynamic) {}
		}

		return dirs;
	}
	#end

	public static function reload(?modIds:Array<String>):Void
	{
		clearCache();
		initialize(modIds);
	}

	public static function clearCache():Void
	{
		#if sys
		if (!isInitialized)
			return;

		try
		{
			Polymod.clearCache();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function getStatusSummary():String
	{
		if (!isSupported)
			return "Polymod: not supported on this target";

		var modList:String = loadedModIds.length > 0 ? loadedModIds.join(", ") : "none";

		return 'Polymod: ${isInitialized ? "initialized" : "not initialized"} (${loadedModIds.length} mod folder(s): $modList)';
	}
}
