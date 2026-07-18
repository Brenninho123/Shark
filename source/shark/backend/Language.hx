package shark.backend;

import flixel.FlxG;
import shark.backend.JsonObject;
import shark.backend.Paths;

import Main;

class Language
{
	public static var current(default, null):String = "en";
	public static var supportedLanguages:Array<String> = ["en", "pt", "es"];

	static var cache:Map<String, JsonObject> = new Map();
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		if (FlxG.save.data.language != null && isSupported(FlxG.save.data.language))
			current = FlxG.save.data.language;
		else
			current = detectSystemLanguage();
	}

	static function detectSystemLanguage():String
	{
		var detected:String = Main.systemLanguage;
		return isSupported(detected) ? detected : "en";
	}

	public static function isSupported(code:String):Bool
	{
		return supportedLanguages.indexOf(code) != -1;
	}

	public static function setLanguage(code:String):Bool
	{
		if (!isSupported(code))
			return false;

		current = code;

		FlxG.save.data.language = code;
		FlxG.save.flush();

		return true;
	}

	public static function get(key:String, ?params:Map<String, String>):String
	{
		var raw:String = getBundle(current).getPath(key, null);

		if (raw == null && current != "en")
			raw = getBundle("en").getPath(key, null);

		if (raw == null)
			raw = key;

		if (params != null)
			for (paramKey in params.keys())
				raw = StringTools.replace(raw, '{$paramKey}', params.get(paramKey));

		return raw;
	}

	public static function has(key:String):Bool
	{
		return getBundle(current).getPath(key, null) != null;
	}

	static function getBundle(lang:String):JsonObject
	{
		if (cache.exists(lang))
			return cache.get(lang);

		var bundle:JsonObject = Paths.getLocalizedJsonObject("strings", lang);
		cache.set(lang, bundle);

		return bundle;
	}

	public static function clearCache():Void
	{
		cache = new Map();
	}

	public static function getLanguageName(code:String):String
	{
		return switch (code)
		{
			case "en": "English";
			case "pt": "Português";
			case "es": "Español";
			case "fr": "Français";
			case "de": "Deutsch";
			case "ja": "日本語";
			default: code;
		}
	}

	public static function getSupportedLanguageNames():Array<{code:String, name:String}>
	{
		return [for (lang in supportedLanguages) {code: lang, name: getLanguageName(lang)}];
	}
}
