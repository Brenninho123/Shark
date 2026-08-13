package haxe.ui.backend;

import hscript.SharkScript;
import haxe.ui.core.Component;
import shark.active.system.Body;
import shark.active.system.BodyState;
import shark.active.system.Head;
import shark.audio.Audio;
import shark.ui.debug.CrasherLog;

typedef BoundEvent = {
	eventType:String,
	handler:Dynamic->Void
}

class HScriptManager
{
	static var componentScripts:Map<Component, SharkScript> = new Map();
	static var componentErrors:Map<Component, String> = new Map();
	static var componentEvents:Map<Component, Array<BoundEvent>> = new Map();
	static var initialized:Bool = false;
	static var boundBody:Body;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;
	}

	public static function attachBody(bodyRef:Body):Void
	{
		boundBody = bodyRef;
	}

	static function getOrCreateScript(component:Component):SharkScript
	{
		if (componentScripts.exists(component))
			return componentScripts.get(component);

		var script:SharkScript = new SharkScript();
		script.expose("component", component);
		bindDefaultApi(script);

		componentScripts.set(component, script);

		return script;
	}

	static function bindDefaultApi(script:SharkScript):Void
	{
		script.expose("playSound", function(key:String):Void
		{
			Audio.play(key);
		});

		script.expose("bodyReact", function():Void
		{
			if (boundBody != null)
				boundBody.setState(REACTING);
		});

		script.expose("bodyIdle", function():Void
		{
			if (boundBody != null)
				boundBody.setState(IDLE);
		});

		script.expose("getMessageCount", function():Int
		{
			return Head.totalMessages;
		});
	}

	public static function bindScript(component:Component, code:String):SharkScript
	{
		var script:SharkScript = getOrCreateScript(component);
		var result = script.run(code);

		if (!result.success)
		{
			componentErrors.set(component, result.error);
			CrasherLog.logWarning('HScriptManager: script bind failed - ${result.error}', "haxeui");
		}
		else
		{
			componentErrors.remove(component);
		}

		return script;
	}

	public static function bindEvent(component:Component, eventType:String, code:String):Void
	{
		var script:SharkScript = getOrCreateScript(component);

		var handler = function(event:Dynamic):Void
		{
			script.expose("event", event);

			var result = script.run(code);

			if (!result.success)
			{
				componentErrors.set(component, result.error);
				CrasherLog.logWarning('HScriptManager: event "$eventType" script failed - ${result.error}', "haxeui");
			}
		};

		try
		{
			component.registerEvent(eventType, handler);

			if (!componentEvents.exists(component))
				componentEvents.set(component, []);

			componentEvents.get(component).push({eventType: eventType, handler: handler});
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('HScriptManager: failed to register event "$eventType" - ${Std.string(e)}', "haxeui");
		}
	}

	public static function callHook(component:Component, hookName:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!componentScripts.exists(component))
			return null;

		return componentScripts.get(component).callFunction(hookName, args);
	}

	public static function hasHook(component:Component, hookName:String):Bool
	{
		return componentScripts.exists(component) && componentScripts.get(component).hasFunction(hookName);
	}

	public static function hasScript(component:Component):Bool
	{
		return componentScripts.exists(component);
	}

	public static function getLastError(component:Component):String
	{
		return componentErrors.exists(component) ? componentErrors.get(component) : null;
	}

	public static function unbind(component:Component):Void
	{
		if (componentEvents.exists(component))
		{
			try
			{
				for (bound in componentEvents.get(component))
					component.unregisterEvent(bound.eventType, bound.handler);
			}
			catch (e:Dynamic) {}

			componentEvents.remove(component);
		}

		componentScripts.remove(component);
		componentErrors.remove(component);
	}

	public static function clearAll():Void
	{
		for (component in componentEvents.keys())
			unbind(component);

		componentScripts = new Map();
		componentErrors = new Map();
		componentEvents = new Map();
	}

	public static function getBoundComponentCount():Int
	{
		var count:Int = 0;

		for (component in componentScripts.keys())
			count++;

		return count;
	}
}
