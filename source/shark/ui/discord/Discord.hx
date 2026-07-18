package shark.ui.discord;

#if cpp
import discord_rpc.DiscordRpc;
#end

class Discord
{
	public static var isSupported(default, null):Bool;
	public static var isConnected(default, null):Bool = false;

	static var applicationId:String = "";
	static var startTimestamp:Float = 0;

	public static function initialize(clientId:String):Void
	{
		#if cpp
		isSupported = true;
		applicationId = clientId;
		startTimestamp = Date.now().getTime() / 1000;

		DiscordRpc.start({
			clientID: clientId,
			onReady: onReady,
			onDisconnected: onDisconnected,
			onError: onError
		});
		#else
		isSupported = false;
		#end
	}

	static function onReady():Void
	{
		isConnected = true;
	}

	static function onDisconnected(errorCode:Int, message:String):Void
	{
		isConnected = false;
	}

	static function onError(errorCode:Int, message:String):Void
	{
		isConnected = false;
	}

	public static function update(state:String, details:String, ?largeImageKey:String, ?largeImageText:String, resetTimestamp:Bool = false):Void
	{
		#if cpp
		if (!isSupported)
			return;

		if (resetTimestamp)
			startTimestamp = Date.now().getTime() / 1000;

		DiscordRpc.presence({
			state: state,
			details: details,
			startTimestamp: Std.int(startTimestamp),
			largeImageKey: largeImageKey,
			largeImageText: largeImageText
		});
		#end
	}

	public static function runCallbacks():Void
	{
		#if cpp
		if (!isSupported)
			return;

		DiscordRpc.process();
		#end
	}

	public static function shutdown():Void
	{
		#if cpp
		if (!isSupported)
			return;

		DiscordRpc.shutdown();
		isConnected = false;
		#end
	}
}
