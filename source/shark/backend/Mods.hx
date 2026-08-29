package shark.backend;

import shark.active.system.Body;
import shark.active.system.BodyState;
import shark.active.system.Head;
import shark.audio.Audio;
import shark.data.DataFile;
import shark.mobile.backend.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.modding.Module;
import shark.modding.api.ModVersion;
import shark.online.Online;
import shark.ui.debug.CrasherLog;
import lime.manager.LimeManager;
import Main;

typedef ModuleSummary = {
	name:String,
	loaded:Bool,
	enabled:Bool,
	?error:String,
	?apiVersion:String,
	?compatible:Bool
}

class Mods
{
	static inline var MAX_CONSECUTIVE_FAILURES:Int = 5;

	public static var loadedModules(default, null):Array<Module> = [];
	public static var isInitialized(default, null):Bool = false;

	static var boundBody:Body;
	static var updateFailureCounts:Map<String, Int> = new Map();
	static var modStorageFiles:Map<String, DataFile<Dynamic>> = new Map();

	public static function initialize(?bodyRef:Body):Void
	{
		if (isInitialized)
			return;

		isInitialized = true;
		boundBody = bodyRef;

		Module.ensureModsDirectory();
		loadAll();
	}

	public static function attachBody(bodyRef:Body):Void
	{
		boundBody = bodyRef;
	}

	public static function loadAll():Void
	{
		unloadAll();

		for (name in Module.listAvailableModules())
			loadModule(name);
	}

	public static function loadModule(name:String):Module
	{
		var existing:Module = getModule(name);

		if (existing != null)
			return existing;

		var mod = new Module(name);

		try
		{
			bindDefaultApi(mod);
			mod.load();
			loadedModules.push(mod);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to load mod "$name": ${Std.string(e)}', "mods");

			try
			{
				mod.destroy();
			}
			catch (destroyError:Dynamic) {}

			return null;
		}

		return mod;
	}

	static function bindDefaultApi(mod:Module):Void
	{
		mod.bind("modName", mod.name);
		mod.bind("buildVersion", LimeManager.buildVersion);
		mod.bind("apiVersion", ModVersion.CURRENT);
		mod.bind("isSafeMode", function():Bool return Main.isSafeMode);

		mod.bind("playSound", function(key:String):Void
		{
			Audio.play(key);
		});

		mod.bind("muteAudio", function():Void
		{
			Audio.setMuted(true);
		});

		mod.bind("unmuteAudio", function():Void
		{
			Audio.setMuted(false);
		});

		mod.bind("getMessageCount", function():Int
		{
			return Head.totalMessages;
		});

		mod.bind("getImageCount", function():Int
		{
			return Head.totalImages;
		});

		mod.bind("bodyIdle", function():Void
		{
			if (boundBody != null)
				boundBody.setState(IDLE);
		});

		mod.bind("bodyThink", function():Void
		{
			if (boundBody != null)
				boundBody.setState(THINKING);
		});

		mod.bind("bodyTalk", function():Void
		{
			if (boundBody != null)
				boundBody.setState(TALKING);
		});

		mod.bind("bodyReact", function():Void
		{
			if (boundBody != null)
				boundBody.setState(REACTING);
		});

		mod.bind("isOnline", function():Bool
		{
			return Online.isOnline;
		});

		mod.bind("isApiOnline", function():Bool
		{
			return Online.apiOnline;
		});

		mod.bind("vibrate", function(?style:String):Void
		{
			if (!ModVersion.isFeatureSupported(VIBRATION_ACCESS))
				return;

			Vibration.trigger(resolveHapticStyle(style));
		});

		mod.bind("logInfo", function(message:String):Void
		{
			CrasherLog.addBreadcrumb(message, 'mod:${mod.name}');
		});

		mod.bind("logWarning", function(message:String):Void
		{
			CrasherLog.logWarning(message, 'mod:${mod.name}');
		});

		mod.bind("getStorage", function(key:String):Dynamic
		{
			return Reflect.field(getModStorageFile(mod.name).data, key);
		});

		mod.bind("setStorage", function(key:String, value:Dynamic):Void
		{
			var file:DataFile<Dynamic> = getModStorageFile(mod.name);

			file.update(function(d:Dynamic):Void
			{
				Reflect.setField(d, key, value);
			});
		});
	}

	static function getModStorageFile(modName:String):DataFile<Dynamic>
	{
		if (!modStorageFiles.exists(modName))
		{
			var file = new DataFile<Dynamic>('mod_storage_$modName', {});
			file.load();
			modStorageFiles.set(modName, file);
		}

		return modStorageFiles.get(modName);
	}

	static function resolveHapticStyle(name:String):HapticStyle
	{
		if (name == null)
			return MEDIUM;

		return switch (name.toLowerCase())
		{
			case "light": LIGHT;
			case "heavy": HEAVY;
			case "selection": SELECTION;
			case "success": SUCCESS;
			case "warning": WARNING;
			case "error": ERROR;
			case "notification": NOTIFICATION;
			default: MEDIUM;
		}
	}

	public static function updateAll(elapsed:Float):Void
	{
		for (mod in loadedModules)
		{
			if (!mod.isEnabled)
				continue;

			try
			{
				mod.update(elapsed);
				updateFailureCounts.set(mod.name, 0);
			}
			catch (e:Dynamic)
			{
				handleModuleFailure(mod, 'update() threw: ${Std.string(e)}');
			}
		}
	}

	static function handleModuleFailure(mod:Module, message:String):Void
	{
		var count:Int = (updateFailureCounts.exists(mod.name) ? updateFailureCounts.get(mod.name) : 0) + 1;
		updateFailureCounts.set(mod.name, count);

		CrasherLog.logWarning('Mod "${mod.name}": $message', "mods");

		if (count >= MAX_CONSECUTIVE_FAILURES && mod.isEnabled)
		{
			mod.isEnabled = false;
			CrasherLog.logError('Mod "${mod.name}" disabled after $count consecutive failures', "mods");
		}
	}

	public static function unloadAll():Void
	{
		for (mod in loadedModules)
		{
			try
			{
				mod.destroy();
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Mod "${mod.name}" threw during destroy(): ${Std.string(e)}', "mods");
			}
		}

		loadedModules = [];
		updateFailureCounts = new Map();
	}

	public static function getModule(name:String):Module
	{
		for (mod in loadedModules)
			if (mod.name == name)
				return mod;

		return null;
	}

	public static function reloadModule(name:String):Bool
	{
		var mod:Module = getModule(name);

		if (mod == null)
			return false;

		updateFailureCounts.remove(name);

		try
		{
			return mod.reload();
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Mod "$name" failed to reload: ${Std.string(e)}', "mods");
			return false;
		}
	}

	public static function reloadAll():Void
	{
		updateFailureCounts = new Map();
		loadAll();
	}

	public static function setModuleEnabled(name:String, enabled:Bool):Void
	{
		var mod:Module = getModule(name);

		if (mod == null)
			return;

		mod.isEnabled = enabled;

		if (enabled)
			updateFailureCounts.set(name, 0);
	}

	public static function getLoadedCount():Int
	{
		var count:Int = 0;

		for (mod in loadedModules)
			if (mod.isLoaded)
				count++;

		return count;
	}

	public static function getModuleSummaries():Array<ModuleSummary>
	{
		var summaries:Array<ModuleSummary> = [];

		for (mod in loadedModules)
		{
			var declaredVersion:String = safeStringField(mod, "apiVersion", ModVersion.CURRENT);

			summaries.push({
				name: mod.name,
				loaded: mod.isLoaded,
				enabled: mod.isEnabled,
				error: mod.lastError,
				apiVersion: declaredVersion,
				compatible: ModVersion.isModSupported(declaredVersion)
			});
		}

		return summaries;
	}

	static function safeStringField(target:Dynamic, field:String, fallback:String):String
	{
		try
		{
			var value:Dynamic = Reflect.field(target, field);
			return value != null ? Std.string(value) : fallback;
		}
		catch (e:Dynamic)
		{
			return fallback;
		}
	}

	public static function callHookOnAll(hookName:String, ?args:Array<Dynamic>):Void
	{
		for (mod in loadedModules)
		{
			if (!mod.isEnabled || !mod.hasHook(hookName))
				continue;

			try
			{
				mod.callHook(hookName, args);
			}
			catch (e:Dynamic)
			{
				handleModuleFailure(mod, 'hook "$hookName" threw: ${Std.string(e)}');
			}
		}
	}

	public static function getStatusSummary():String
	{
		var enabledCount:Int = 0;
		var failedCount:Int = 0;

		for (mod in loadedModules)
		{
			if (mod.isEnabled)
				enabledCount++;

			if (updateFailureCounts.exists(mod.name) && updateFailureCounts.get(mod.name) > 0)
				failedCount++;
		}

		return 'Mods: ${loadedModules.length} loaded, $enabledCount enabled, $failedCount with recent errors (API ${ModVersion.CURRENT})';
	}
}
