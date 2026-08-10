package haxe.ui.backend;

import hscript.SharkScript;
import haxe.ui.core.Component;

class HScriptManager
{
	static var componentScripts:Map<Component, SharkScript> = new Map();
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;
	}

	public static function bindScript(component:Component, code:String):SharkScript
	{
		var script:SharkScript = componentScripts.exists(component) ? componentScripts.get(component) : new SharkScript();

		script.expose("component", component);

		var result = script.run(code);

		if (!result.success)
			script.expose("lastError", result.error);

		componentScripts.set(component, script);

		return script;
	}

	public static function bindEvent(component:Component, eventType:String, code:String):Void
	{
		var script:SharkScript = componentScripts.exists(component) ? componentScripts.get(component) : new SharkScript();
		script.expose("component", component);

		componentScripts.set(component, script);

		component.registerEvent(eventType, function(event:Dynamic):Void
		{
			script.expose("event", event);
			script.run(code);
		});
	}

	public static function callHook(component:Component, hookName:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!componentScripts.exists(component))
			return null;

		return componentScripts.get(component).callFunction(hookName, args);
	}

	public static function hasScript(component:Component):Bool
	{
		return componentScripts.exists(component);
	}

	public static function unbind(component:Component):Void
	{
		componentScripts.remove(component);
	}

	public static function clearAll():Void
	{
		componentScripts = new Map();
	}

	public static function getBoundComponentCount():Int
	{
		var count:Int = 0;

		for (component in componentScripts.keys())
			count++;

		return count;
	}
}
