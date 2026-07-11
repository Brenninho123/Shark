package shark.online;

import haxe.Http;
import haxe.Timer;

class Online
{
	public static var isOnline(default, null):Bool = false;
	public static var onStatusChanged:Bool->Void;

	public static var checkUrl:String = "https://www.google.com";
	public static var checkInterval:Float = 15;

	static var timer:Timer;
	static var isChecking:Bool = false;

	public static function start():Void
	{
		checkNow();

		if (timer != null)
			timer.stop();

		timer = new Timer(Std.int(checkInterval * 1000));
		timer.run = checkNow;
	}

	public static function stop():Void
	{
		if (timer != null)
		{
			timer.stop();
			timer = null;
		}
	}

	public static function checkNow(?onResult:Bool->Void):Void
	{
		if (isChecking)
			return;

		isChecking = true;

		var http = new Http(checkUrl);

		http.onData = function(data:String):Void
		{
			isChecking = false;
			setStatus(true);

			if (onResult != null)
				onResult(true);
		};

		http.onError = function(msg:String):Void
		{
			isChecking = false;
			setStatus(false);

			if (onResult != null)
				onResult(false);
		};

		http.request(false);
	}

	static function setStatus(value:Bool):Void
	{
		if (isOnline == value)
			return;

		isOnline = value;

		if (onStatusChanged != null)
			onStatusChanged(value);
	}
}
