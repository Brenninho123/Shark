package hscript;

import hscript.Parser;
import hscript.Interp;
import hscript.Expr;
import shark.ui.security.Guard;

typedef ScriptResult = {
	success:Bool,
	value:Dynamic,
	?error:String
}

class SharkScript
{
	public static var maxScriptLength:Int = 5000;

	var parser:Parser;
	var interp:Interp;
	var exposedVariables:Map<String, Dynamic> = new Map();
	var astCache:Map<String, Expr> = new Map();
	var output:Array<String> = [];

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

	public function unexpose(name:String):Void
	{
		exposedVariables.remove(name);
		interp.variables.remove(name);
	}

	public function run(code:String):ScriptResult
	{
		var sanitized:String = Guard.sanitizeInput(code);

		if (sanitized.length == 0)
			return {success: false, value: null, error: "Empty script"};

		if (sanitized.length > maxScriptLength)
			return {success: false, value: null, error: 'Script exceeds $maxScriptLength characters'};

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

			return {success: true, value: value};
		}
		catch (e:hscript.Expr.Error)
		{
			return {success: false, value: null, error: 'Parse error: ${Std.string(e)}'};
		}
		catch (e:Dynamic)
		{
			return {success: false, value: null, error: Std.string(e)};
		}
	}

	public function getOutput():Array<String>
	{
		return output.copy();
	}

	function hashScript(code:String):String
	{
		#if cpp
		return Std.string(hxcpp.CPP.fnv1aHash(code));
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
}
