package hscript;

import hscript.Parser;
import hscript.Interp;
import hscript.Expr;
import shark.ui.security.Guard;
import shark.ui.debug.CrasherLog;

#if cpp
import hxcpp.CPP;
#end

typedef ScriptResult = {
	success:Bool,
	value:Dynamic,
	?error:String,
	?executionTimeMs:Float
}

typedef ScriptHistoryEntry = {
	codeSnippet:String,
	success:Bool,
	executionTimeMs:Float,
	timestamp:Float
}

class SharkScript
{
	public static var maxScriptLength:Int = 5000;
	public static var slowScriptThresholdMs:Float = 50;
	public static var rateLimitBucket:String = "hscript";
	public static var enforceRateLimit:Bool = true;
	public static inline var MAX_HISTORY:Int = 20;

	var parser:Parser;
	var interp:Interp;
	var exposedVariables:Map<String, Dynamic> = new Map();
	var astCache:Map<String, Expr> = new Map();
	var output:Array<String> = [];
	var history:Array<ScriptHistoryEntry> = [];

	public function new()
	{
		parser = new Parser();
		interp = new Interp();

		exposeDefaults();
	}

	function exposeDefaults():Void
	{
		expose("Math", Math);
		expose("Std", Std);
		expose("StringTools", StringTools);

		expose("print", function(value:Dynamic):Void
		{
			output.push(Std.string(value));
		});
	}

	public function expose(name:String, value:Dynamic):Void
	{
		exposedVariables.set(name, value);
		interp.variables.set(name, value);
	}

	public function exposeMultiple(values:Map<String, Dynamic>):Void
	{
		for (name => value in values)
			expose(name, value);
	}

	public function unexpose(name:String):Void
	{
		exposedVariables.remove(name);
		interp.variables.remove(name);
	}

	public function run(code:String):ScriptResult
	{
		if (enforceRateLimit && !Guard.checkAndRegister(rateLimitBucket))
			return {success: false, value: null, error: "Too many scripts running, please slow down", executionTimeMs: 0};

		var sanitized:String = Guard.sanitizeInput(code);

		if (sanitized.length == 0)
			return {success: false, value: null, error: "Empty script", executionTimeMs: 0};

		if (sanitized.length > maxScriptLength)
			return {success: false, value: null, error: 'Script exceeds $maxScriptLength characters', executionTimeMs: 0};

		var startTime:Float = nowMs();

		try
		{
			output = [];

			var cacheKey:String = hashScript(sanitized);
			var expr:Expr;

			if (astCache.exists(cacheKey))
			{
				expr = astCache.get(cacheKey);
			}
			else
			{
				expr = parser.parseString(sanitized);
				astCache.set(cacheKey, expr);
			}

			var value:Dynamic = interp.execute(expr);
			var elapsed:Float = nowMs() - startTime;

			recordHistory(sanitized, true, elapsed);
			warnIfSlow(elapsed);

			return {success: true, value: value, executionTimeMs: elapsed};
		}
		catch (e:hscript.Expr.Error)
		{
			var elapsed:Float = nowMs() - startTime;
			recordHistory(sanitized, false, elapsed);

			return {success: false, value: null, error: 'Parse error: ${Std.string(e)}', executionTimeMs: elapsed};
		}
		catch (e:Dynamic)
		{
			var elapsed:Float = nowMs() - startTime;
			recordHistory(sanitized, false, elapsed);

			return {success: false, value: null, error: Std.string(e), executionTimeMs: elapsed};
		}
	}

	static function nowMs():Float
	{
		#if cpp
		return CPP.getHighResTimeMs();
		#else
		return Sys.time() * 1000;
		#end
	}

	function warnIfSlow(elapsedMs:Float):Void
	{
		if (elapsedMs > slowScriptThresholdMs)
			CrasherLog.logWarning('Slow hscript execution: ${Math.round(elapsedMs)}ms');
	}

	function recordHistory(code:String, success:Bool, elapsedMs:Float):Void
	{
		var snippet:String = code.length > 60 ? code.substr(0, 60) + "..." : code;

		history.push({
			codeSnippet: snippet,
			success: success,
			executionTimeMs: elapsedMs,
			timestamp: Date.now().getTime() / 1000
		});

		if (history.length > MAX_HISTORY)
			history.shift();
	}

	public function getHistory():Array<ScriptHistoryEntry>
	{
		return history.copy();
	}

	public function callFunction(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!interp.variables.exists(name))
			return null;

		var fn:Dynamic = interp.variables.get(name);

		if (!Reflect.isFunction(fn))
			return null;

		try
		{
			return Reflect.callMethod(null, fn, args != null ? args : []);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public function hasFunction(name:String):Bool
	{
		return interp.variables.exists(name) && Reflect.isFunction(interp.variables.get(name));
	}

	public function getOutput():Array<String>
	{
		return output.copy();
	}

	function hashScript(code:String):String
	{
		#if cpp
		return Std.string(CPP.fnv1aHash(code));
		#else
		return code;
		#end
	}

	public function reset():Void
	{
		interp = new Interp();

		for (name => value in exposedVariables)
			interp.variables.set(name, value);
	}

	public function clearCache():Void
	{
		astCache = new Map();
	}

	public function clearHistory():Void
	{
		history = [];
	}
}
