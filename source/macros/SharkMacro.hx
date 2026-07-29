package macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class SharkMacro
{
	public static macro function getDefine(name:String, defaultValue:String = ""):Expr
	{
		var value:String = Context.definedValue(name);

		if (value == null)
			value = defaultValue;

		return macro $v{value};
	}

	public static macro function getVersion():Expr
	{
		var value:String = Context.definedValue("SHARK_VERSION");

		if (value == null)
			value = "0.0.0";

		return macro $v{value};
	}

	public static macro function getCommit():Expr
	{
		var value:String = Context.definedValue("SHARK_COMMIT");

		if (value == null)
			value = "unknown";

		return macro $v{value};
	}

	public static macro function getPlatform():Expr
	{
		var value:String = Context.definedValue("SHARK_PLATFORM");

		if (value == null)
			value = "unknown";

		return macro $v{value};
	}

	public static macro function isCiBuild():Expr
	{
		var value:Bool = Context.defined("SHARK_CI_BUILD");
		return macro $v{value};
	}

	public static macro function getBuildTimestamp():Expr
	{
		var timestamp:Float = Date.now().getTime();
		return macro $v{timestamp};
	}

	public static macro function getHaxeVersion():Expr
	{
		var value:String = haxe.macro.Compiler.getDefine("haxe_ver");

		if (value == null)
			value = "unknown";

		return macro $v{value};
	}

	public static macro function getFullBuildInfo():Expr
	{
		var version:String = Context.definedValue("SHARK_VERSION");
		var commit:String = Context.definedValue("SHARK_COMMIT");
		var platform:String = Context.definedValue("SHARK_PLATFORM");

		if (version == null)
			version = "0.0.0";

		if (commit == null)
			commit = "unknown";

		if (platform == null)
			platform = "unknown";

		var summary:String = 'Shark $version ($platform, commit $commit)';

		return macro $v{summary};
	}
}
