package shark.backend;

import shark.active.system.Body;
import shark.active.system.BodyState;
import shark.active.system.Head;
import shark.audio.Audio;
import shark.modding.Module;
import lime.manager.LimeManager;

typedef ModuleSummary = {
	name:String,
	loaded:Bool,
	enabled:Bool,
	?error:String
}

class Mods
{
	public static var loadedModules(default, null):Array<Module> = [];
	public static var isInitialized(default, null):Bool = false;

	static var boundBody:Body;

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
		bindDefaultApi(mod);
		mod.load();

		loadedModules.push(mod);

		return mod;
	}

	static function bindDefaultApi(mod:Module):Void
	{
		mod.bind("modName", mod.name);
		mod.bind("buildVersion", LimeManager.buildVersion);

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

		if (boundBody != null)
		{
			mod.bind("bodyIdle", function():Void
			{
				boundBody.setState(IDLE);
			});

			mod.bind("bodyThink", function():Void
			{
				boundBody.setState(THINKING);
			});

			mod.bind("bodyTalk", function():Void
			{
				boundBody.setState(TALKING);
			});

			mod.bind("bodyReact", function():Void
			{
				boundBody.setState(REACTING);
			});
		}
	}

	public static function updateAll(elapsed:Float):Void
	{
		for (mod in loadedModules)
			if (mod.isEnabled)
				mod.update(elapsed);
	}

	public static function unloadAll():Void
	{
		for (mod in loadedModules)
			mod.destroy();

		loadedModules = [];
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
		return mod != null ? mod.reload() : false;
	}

	public static function reloadAll():Void
	{
		loadAll();
	}

	public static function setModuleEnabled(name:String, enabled:Bool):Void
	{
		var mod:Module = getModule(name);

		if (mod != null)
			mod.isEnabled = enabled;
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
			summaries.push({
				name: mod.name,
				loaded: mod.isLoaded,
				enabled: mod.isEnabled,
				error: mod.lastError
			});

		return summaries;
	}

	public static function callHookOnAll(hookName:String, ?args:Array<Dynamic>):Void
	{
		for (mod in loadedModules)
			if (mod.isEnabled && mod.hasHook(hookName))
				mod.callHook(hookName, args);
	}
}
