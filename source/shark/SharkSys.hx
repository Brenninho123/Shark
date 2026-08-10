package shark;

#if sys
import Sys as HaxeSys;
#end

class SharkSys
{
	public static var isSupported(default, null):Bool;

	public static function initialize():Void
	{
		#if sys
		isSupported = true;
		#else
		isSupported = false;
		#end
	}

	public static function getEnv(name:String, fallback:String = ""):String
	{
		#if sys
		var value:String = HaxeSys.getEnv(name);
		return value != null && value.length > 0 ? value : fallback;
		#else
		return fallback;
		#end
	}

	public static function getArgs():Array<String>
	{
		#if sys
		return HaxeSys.args();
		#else
		return [];
		#end
	}

	public static function hasArg(flag:String):Bool
	{
		return getArgs().indexOf(flag) != -1;
	}

	public static function getArgValue(flag:String, fallback:String = ""):String
	{
		var args:Array<String> = getArgs();
		var index:Int = args.indexOf(flag);

		if (index == -1 || index + 1 >= args.length)
			return fallback;

		return args[index + 1];
	}

	public static function getCwd():String
	{
		#if sys
		return HaxeSys.getCwd();
		#else
		return "";
		#end
	}

	public static function sleep(seconds:Float):Void
	{
		#if sys
		HaxeSys.sleep(seconds);
		#end
	}

	public static function exit(code:Int, ?reason:String):Void
	{
		#if sys
		if (reason != null)
			shark.ui.debug.CrasherLog.logWarning('SharkSys.exit($code): $reason', "system");

		HaxeSys.exit(code);
		#end
	}

	public static function getSystemName():String
	{
		#if sys
		return HaxeSys.systemName();
		#else
		return "unknown";
		#end
	}

	public static function print(message:String):Void
	{
		#if sys
		HaxeSys.println(message);
		#end
	}
}
