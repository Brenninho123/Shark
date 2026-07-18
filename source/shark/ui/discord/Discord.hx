package shark.ui.discord;

#if cpp
import hxdiscord_rpc.Discord as DiscordRpc;
import hxdiscord_rpc.Types;
#end

class Discord
{
	public static var isSupported(default, null):Bool;
	public static var isConnected(default, null):Bool = false;

	static var applicationId:String = "";
	static var currentState:String = "";
	static var currentDetails:String = "";
	static var startTimestamp:Float = 0;

	public static function initialize(clientId:String):Void
	{
		#if cpp
		isSupported = true;
		applicationId = clientId;

		var handlers = Types.DiscordEventHandlers.create();
		handlers.ready = onReady;
		handlers.disconnected = onDisconnected;
		handlers.errored = onErrored;

		DiscordRpc.Init(clientId, cpp.RawPointer.addressOf(handlers), true, null);

		startTimestamp = Date.now().getTime() / 1000;
		#else
		isSupported = false;
		#end
	}

	static function onReady(request:cpp.RawConstPointer<Types.DiscordUser>):Void
	{
		isConnected = true;
	}

	static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		isConnected = false;
	}

	static function onErrored(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		isConnected = false;
	}

	public static function update(state:String, details:String, ?largeImageKey:String, ?largeImageText:String, resetTimestamp:Bool = false):Void
	{
		#if cpp
		if (!isSupported)
			return;

		currentState = state;
		currentDetails = details;

		if (resetTimestamp)
			startTimestamp = Date.now().getTime() / 1000;

		var presence = Types.DiscordRichPresence.create();
		presence.state = state;
		presence.details = details;
		presence.startTimestamp = Std.int(startTimestamp);

		if (largeImageKey != null)
			presence.largeImageKey = largeImageKey;

		if (largeImageText != null)
			presence.largeImageText = largeImageText;

		DiscordRpc.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
		#end
	}

	public static function clear():Void
	{
		#if cpp
		if (!isSupported)
			return;

		DiscordRpc.ClearPresence();
		#end
	}

	public static function runCallbacks():Void
	{
		#if cpp
		if (!isSupported)
			return;

		DiscordRpc.RunCallbacks();
		#end
	}

	public static function shutdown():Void
	{
		#if cpp
		if (!isSupported)
			return;

		DiscordRpc.Shutdown();
		isConnected = false;
		#end
	}
}
