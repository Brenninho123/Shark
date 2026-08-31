package macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class SharkMacro
{
	#if macro
	static function resolveDefine(name:String, fallback:String):String
	{
		var value:String = Context.definedValue(name);
		return value != null ? value : fallback;
	}

	static function resolveIntPart(parts:Array<String>, index:Int):Int
	{
		if (index >= parts.length)
			return 0;

		var parsed:Null<Int> = Std.parseInt(parts[index]);
		return parsed != null ? parsed : 0;
	}
	#end

	public static macro function getDefine(name:String, defaultValue:String = ""):Expr
	{
		return macro $v{resolveDefine(name, defaultValue)};
	}

	public static macro function getVersion():Expr
	{
		return macro $v{resolveDefine("SHARK_VERSION", "0.0.0")};
	}

	public static macro function getVersionMajor():Expr
	{
		var parts:Array<String> = resolveDefine("SHARK_VERSION", "0.0.0").split(".");
		return macro $v{resolveIntPart(parts, 0)};
	}

	public static macro function getVersionMinor():Expr
	{
		var parts:Array<String> = resolveDefine("SHARK_VERSION", "0.0.0").split(".");
		return macro $v{resolveIntPart(parts, 1)};
	}

	public static macro function getVersionPatch():Expr
	{
		var parts:Array<String> = resolveDefine("SHARK_VERSION", "0.0.0").split(".");
		return macro $v{resolveIntPart(parts, 2)};
	}

	public static macro function getBuildNumber():Expr
	{
		return macro $v{resolveDefine("SHARK_BUILD_NUMBER", "0")};
	}

	public static macro function getCommit():Expr
	{
		return macro $v{resolveDefine("SHARK_COMMIT", "unknown")};
	}

	public static macro function getPlatform():Expr
	{
		return macro $v{resolveDefine("SHARK_PLATFORM", "unknown")};
	}

	public static macro function getEnvironment():Expr
	{
		return macro $v{resolveDefine("SHARK_ENVIRONMENT", "dev")};
	}

	public static macro function isCiBuild():Expr
	{
		var value:Bool = Context.defined("SHARK_CI_BUILD");
		return macro $v{value};
	}

	public static macro function isDevMode():Expr
	{
		var value:Bool = Context.defined("SHARK_DEV_MODE");
		return macro $v{value};
	}

	public static macro function isDebugBuild():Expr
	{
		var value:Bool = Context.defined("debug");
		return macro $v{value};
	}

	public static macro function isProductionBuild():Expr
	{
		var value:Bool = resolveDefine("SHARK_ENVIRONMENT", "dev") == "production";
		return macro $v{value};
	}

	public static macro function getBuildTimestamp():Expr
	{
		var raw:String = Context.definedValue("SHARK_BUILD_TIMESTAMP");
		var seconds:Null<Int> = raw != null ? Std.parseInt(raw) : null;
		var timestamp:Float = seconds != null ? seconds * 1000.0 : Date.now().getTime();

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
		var version:String = resolveDefine("SHARK_VERSION", "0.0.0");
		var commit:String = resolveDefine("SHARK_COMMIT", "unknown");
		var platform:String = resolveDefine("SHARK_PLATFORM", "unknown");
		var environment:String = resolveDefine("SHARK_ENVIRONMENT", "dev");

		var summary:String = 'Shark $version ($platform, $environment, commit $commit)';

		return macro $v{summary};
	}

	public static macro function getBuildInfoObject():Expr
	{
		var version:String = resolveDefine("SHARK_VERSION", "0.0.0");
		var buildNumber:String = resolveDefine("SHARK_BUILD_NUMBER", "0");
		var commit:String = resolveDefine("SHARK_COMMIT", "unknown");
		var platform:String = resolveDefine("SHARK_PLATFORM", "unknown");
		var environment:String = resolveDefine("SHARK_ENVIRONMENT", "dev");
		var isDev:Bool = Context.defined("SHARK_DEV_MODE");
		var isCi:Bool = Context.defined("SHARK_CI_BUILD");
		var isDebug:Bool = Context.defined("debug");

		return macro {
			version: $v{version},
			buildNumber: $v{buildNumber},
			commit: $v{commit},
			platform: $v{platform},
			environment: $v{environment},
			isDevMode: $v{isDev},
			isCiBuild: $v{isCi},
			isDebugBuild: $v{isDebug}
		};
	}

	public static macro function requireDefine(name:String):Expr
	{
		if (!Context.defined(name))
			Context.error('Required compiler define "$name" is not set - check Project.hxp.', Context.currentPos());

		return macro {};
	}
}
