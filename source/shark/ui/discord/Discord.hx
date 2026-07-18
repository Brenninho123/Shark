package shark.ui.discord;

class Discord
{
	public static var isSupported(default, null):Bool = false;
	public static var isConnected(default, null):Bool = false;

	public static function initialize(clientId:String):Void
	{
		isSupported = false;
	}

	public static function update(state:String, details:String, ?largeImageKey:String, ?largeImageText:String, resetTimestamp:Bool = false):Void {}

	public static function runCallbacks():Void {}

	public static function shutdown():Void {}
}
