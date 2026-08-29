package shark.modding;

#if sys
import polymod.Polymod;
import sys.FileSystem;
#end

import shark.data.DataFile;
import shark.ui.debug.CrasherLog;

typedef ModPreferencesData = {
	hasCustomSelection:Bool,
	enabledModIds:Array<String>,
	modOrder:Array<String>
}

class PolyMod
{
	public static var isSupported(default, null):Bool;
	public static var isInitialized(default, null):Bool = false;
	public static var loadedModIds(default, null):Array<String> = [];
	public static var loadedModMetadata(default, null):Array<Dynamic> = [];
	public static var maxModsLoaded:Int = 40;

	static var preferences:DataFile<ModPreferencesData>;
	static var lastSuccessfulModIds:Array<String> = [];
	static var errorTally:Map<String, Int> = new Map();

	public static function initialize(?modIds:Array<String>):Void
	{
		#if sys
		isSupported = true;
		ensurePreferencesLoaded();

		try
		{
			var root:String = Module.getModsDirectory();

			if (!FileSystem.exists(root))
				FileSystem.createDirectory(root);

			var available:Array<String> = listAvailableModDirs(root);
			var dirsToLoad:Array<String> = resolveModDirsToLoad(modIds, available);

			if (dirsToLoad.length > maxModsLoaded)
			{
				CrasherLog.logWarning('Requested ${dirsToLoad.length} mods, capping at $maxModsLoaded', "polymod");
				dirsToLoad = dirsToLoad.slice(0, maxModsLoaded);
			}

			resetErrorTally();

			var metadata:Array<Dynamic> = cast Polymod.init({
				modRoot: root,
				dirs: dirsToLoad,
				framework: FLIXEL,
				errorCallback: onPolymodMessage
			});

			loadedModMetadata = metadata != null ? metadata : [];
			loadedModIds = extractModIds(loadedModMetadata);
			isInitialized = true;

			if (loadedModIds.length > 0)
				lastSuccessfulModIds = loadedModIds.copy();
		}
		catch (e:Dynamic)
		{
			isSupported = false;
			isInitialized = false;
			CrasherLog.logWarning('Polymod.init failed: ${Std.string(e)}', "polymod");
		}
		#else
		isSupported = false;
		#end
	}

	#if sys
	static function resolveModDirsToLoad(explicitModIds:Array<String>, available:Array<String>):Array<String>
	{
		if (explicitModIds != null)
			return explicitModIds;

		if (!preferences.data.hasCustomSelection)
			return available;

		var ordered:Array<String> = [];

		for (id in preferences.data.modOrder)
			if (available.indexOf(id) != -1 && preferences.data.enabledModIds.indexOf(id) != -1 && ordered.indexOf(id) == -1)
				ordered.push(id);

		for (id in preferences.data.enabledModIds)
			if (available.indexOf(id) != -1 && ordered.indexOf(id) == -1)
				ordered.push(id);

		return ordered;
	}

	static function extractModIds(metadata:Array<Dynamic>):Array<String>
	{
		if (metadata == null || metadata.length == 0)
			return [];

		var ids:Array<String> = [];

		for (entry in metadata)
			ids.push(safeStringField(entry, "id", "unknown"));

		return ids;
	}

	static function safeStringField(value:Dynamic, field:String, fallback:String):String
	{
		try
		{
			var result:Dynamic = Reflect.field(value, field);
			return result != null ? Std.string(result) : fallback;
		}
		catch (e:Dynamic)
		{
			return fallback;
		}
	}

	static function resetErrorTally():Void
	{
		errorTally = new Map();
	}

	static function onPolymodMessage(error:Dynamic):Void
	{
		var severity:String = safeStringField(error, "severity", "WARNING");
		var code:String = safeStringField(error, "code", "UNKNOWN");
		var message:String = safeStringField(error, "message", Std.string(error));

		errorTally.set(code, (errorTally.exists(code) ? errorTally.get(code) : 0) + 1);

		var formatted:String = 'Polymod [$code]: $message';

		switch (severity.toUpperCase())
		{
			case "ERROR":
				CrasherLog.logError(formatted, "polymod");
			case "NOTICE":
				CrasherLog.logInfo(formatted, "polymod");
			default:
				CrasherLog.logWarning(formatted, "polymod");
		}
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

	static function ensurePreferencesLoaded():Void
	{
		if (preferences != null)
			return;

		preferences = new DataFile<ModPreferencesData>("mod_preferences", buildDefaultPreferences());
		preferences.load();
	}

	static function buildDefaultPreferences():ModPreferencesData
	{
		return {
			hasCustomSelection: false,
			enabledModIds: [],
			modOrder: []
		};
	}
	#end

	public static function reload(?modIds:Array<String>):Void
	{
		clearCache();
		initialize(modIds);

		#if sys
		if (loadedModIds.length == 0 && lastSuccessfulModIds.length > 0)
		{
			CrasherLog.logWarning("Reload resulted in zero mods loaded - rolling back automatically", "polymod");
			initialize(lastSuccessfulModIds);
		}
		#end

		shark.backend.Paths.onModsReloaded();
	}

	public static function hasLastGoodState():Bool
	{
		return lastSuccessfulModIds.length > 0;
	}

	public static function rollbackToLastGood():Void
	{
		if (!hasLastGoodState())
			return;

		CrasherLog.logWarning("Rolling back to last known-good mod set", "polymod");
		initialize(lastSuccessfulModIds.copy());
	}

	public static function getAvailableMods():Array<String>
	{
		#if sys
		return listAvailableModDirs(Module.getModsDirectory());
		#else
		return [];
		#end
	}

	public static function setModEnabled(id:String, enabled:Bool):Void
	{
		#if sys
		ensurePreferencesLoaded();

		preferences.update(function(d:ModPreferencesData):Void
		{
			d.hasCustomSelection = true;

			if (enabled)
			{
				if (d.enabledModIds.indexOf(id) == -1)
					d.enabledModIds.push(id);

				if (d.modOrder.indexOf(id) == -1)
					d.modOrder.push(id);
			}
			else
			{
				d.enabledModIds.remove(id);
			}
		});
		#end
	}

	public static function isModEnabled(id:String):Bool
	{
		#if sys
		ensurePreferencesLoaded();

		if (!preferences.data.hasCustomSelection)
			return true;

		return preferences.data.enabledModIds.indexOf(id) != -1;
		#else
		return false;
		#end
	}

	public static function setModOrder(orderedIds:Array<String>):Void
	{
		#if sys
		ensurePreferencesLoaded();

		preferences.update(function(d:ModPreferencesData):Void
		{
			d.hasCustomSelection = true;
			d.modOrder = orderedIds.copy();
		});
		#end
	}

	public static function disableMod(id:String):Void
	{
		setModEnabled(id, false);
		reload();
	}

	public static function enableMod(id:String):Void
	{
		setModEnabled(id, true);
		reload();
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

	public static function getModTitle(id:String):String
	{
		#if sys
		for (entry in loadedModMetadata)
		{
			var entryId:String = safeStringField(entry, "id", "");

			if (entryId == id)
				return safeStringField(entry, "title", id);
		}
		#end

		return id;
	}

	public static function getStatusSummary():String
	{
		if (!isSupported)
			return "Polymod: not supported on this target";

		var titles:Array<String> = [for (id in loadedModIds) getModTitle(id)];
		var modList:String = titles.length > 0 ? titles.join(", ") : "none";
		var errorSummary:String = formatErrorTally();

		return 'Polymod: ${isInitialized ? "initialized" : "not initialized"} (${loadedModIds.length} mod(s): $modList)$errorSummary';
	}

	static function formatErrorTally():String
	{
		var parts:Array<String> = [];

		for (code => count in errorTally)
			parts.push('$code: $count');

		return parts.length > 0 ? ' - issues: ${parts.join(", ")}' : "";
	}
}
