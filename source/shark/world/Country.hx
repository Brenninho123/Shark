package shark.world;

import shark.backend.ClientPrefs;
import shark.online.Network;
import shark.online.NetworkResponse;
import shark.ui.debug.CrasherLog;

class Country
{
	public static var countryCode(default, null):String;
	public static var countryName(default, null):String;
	public static var isDetected(default, null):Bool = false;
	public static var isDetecting(default, null):Bool = false;

	static inline var API_URL:String = "https://ipapi.co/json/";
	static inline var PREF_CODE:String = "detectedCountryCode";
	static inline var PREF_NAME:String = "detectedCountryName";

	public static function initialize():Void
	{
		var cachedCode:String = ClientPrefs.getString(PREF_CODE, "");

		if (cachedCode.length > 0)
		{
			countryCode = cachedCode;
			countryName = ClientPrefs.getString(PREF_NAME, "");
			isDetected = true;
		}
	}

	public static function detect(?onComplete:String->Void, ?onError:String->Void, forceRefresh:Bool = false):Void
	{
		if (isDetecting)
			return;

		if (isDetected && !forceRefresh)
		{
			if (onComplete != null)
				onComplete(countryCode);

			return;
		}

		isDetecting = true;

		Network.get(API_URL, null, function(response:NetworkResponse):Void
		{
			isDetecting = false;

			if (!response.success)
			{
				CrasherLog.logWarning('Country detection failed: ${response.error}', "world");

				if (onError != null)
					onError(response.error);

				return;
			}

			try
			{
				var parsed:Dynamic = haxe.Json.parse(response.data);
				var code:String = parsed.country_code;
				var name:String = parsed.country_name;

				if (code == null || code.length == 0)
				{
					if (onError != null)
						onError("No country data in response");

					return;
				}

				countryCode = code;
				countryName = name;
				isDetected = true;

				ClientPrefs.setString(PREF_CODE, countryCode);
				ClientPrefs.setString(PREF_NAME, countryName != null ? countryName : "");

				if (onComplete != null)
					onComplete(countryCode);
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Country detection parse error: ${Std.string(e)}', "world");

				if (onError != null)
					onError("Failed to parse country data");
			}
		});
	}

	public static function clearCache():Void
	{
		countryCode = null;
		countryName = null;
		isDetected = false;

		ClientPrefs.remove(PREF_CODE);
		ClientPrefs.remove(PREF_NAME);
	}

	public static function getSummary():String
	{
		if (!isDetected)
			return "Country: not detected";

		return 'Country: $countryName ($countryCode)';
	}
}
