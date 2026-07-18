package shark.backend;

import flixel.FlxG;

class ClientPrefs
{
	static inline var SAVE_NAME:String = "shark_save";

	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		if (!FlxG.save.isBound)
			FlxG.save.bind(SAVE_NAME);
	}

	public static function getBool(key:String, defaultValue:Bool = false):Bool
	{
		var value:Dynamic = Reflect.field(FlxG.save.data, key);
		return value != null ? value : defaultValue;
	}

	public static function setBool(key:String, value:Bool):Void
	{
		Reflect.setField(FlxG.save.data, key, value);
		FlxG.save.flush();
	}

	public static function getFloat(key:String, defaultValue:Float = 0):Float
	{
		var value:Dynamic = Reflect.field(FlxG.save.data, key);
		return value != null ? value : defaultValue;
	}

	public static function setFloat(key:String, value:Float):Void
	{
		Reflect.setField(FlxG.save.data, key, value);
		FlxG.save.flush();
	}

	public static function getString(key:String, defaultValue:String = ""):String
	{
		var value:Dynamic = Reflect.field(FlxG.save.data, key);
		return value != null ? value : defaultValue;
	}

	public static function setString(key:String, value:String):Void
	{
		Reflect.setField(FlxG.save.data, key, value);
		FlxG.save.flush();
	}

	public static function has(key:String):Bool
	{
		return Reflect.field(FlxG.save.data, key) != null;
	}

	public static function remove(key:String):Void
	{
		if (has(key))
		{
			Reflect.deleteField(FlxG.save.data, key);
			FlxG.save.flush();
		}
	}

	public static function toggleBool(key:String, defaultValue:Bool = false):Bool
	{
		var newValue:Bool = !getBool(key, defaultValue);
		setBool(key, newValue);
		return newValue;
	}

	public static var showFPS(get, set):Bool;

	static function get_showFPS():Bool
	{
		return getBool("showFPS", false);
	}

	static function set_showFPS(value:Bool):Bool
	{
		setBool("showFPS", value);
		return value;
	}

	public static var muted(get, set):Bool;

	static function get_muted():Bool
	{
		return getBool("muted", false);
	}

	static function set_muted(value:Bool):Bool
	{
		setBool("muted", value);
		return value;
	}

	public static var musicVolume(get, set):Float;

	static function get_musicVolume():Float
	{
		return getFloat("musicVolume", 0.5);
	}

	static function set_musicVolume(value:Float):Float
	{
		setFloat("musicVolume", value);
		return value;
	}

	public static var soundVolume(get, set):Float;

	static function get_soundVolume():Float
	{
		return getFloat("soundVolume", 0.7);
	}

	static function set_soundVolume(value:Float):Float
	{
		setFloat("soundVolume", value);
		return value;
	}

	public static var language(get, set):String;

	static function get_language():String
	{
		return getString("language", "en");
	}

	static function set_language(value:String):String
	{
		setString("language", value);
		return value;
	}

	public static function resetToDefaults():Void
	{
		showFPS = false;
		muted = false;
		musicVolume = 0.5;
		soundVolume = 0.7;
		language = "en";
	}
}
