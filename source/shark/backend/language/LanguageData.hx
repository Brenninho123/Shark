package shark.backend.language;

class LanguageData
{
	public static function get(code:String):Map<String, String>
	{
		return switch (code)
		{
			case "en": English.strings;
			case "pt": Portuguese.strings;
			case "es": Spanish.strings;
			default: English.strings;
		}
	}
}
