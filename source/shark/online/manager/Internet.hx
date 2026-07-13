package shark.online.manager;

import haxe.Timer;
import shark.online.Online;

class Internet
{
	public static var isConnected(get, never):Bool;
	public static var latencyMs(default, null):Float = -1;

	static var listeners:Array<Bool->Void> = [];
	static var pendingActions:Array<Void->Void> = [];
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		Online.onStatusChanged = onStatusChanged;
		Online.start();
	}

	static function get_isConnected():Bool
	{
		return Online.isOnline;
	}

	public static function addListener(callback:Bool->Void):Void
	{
		if (listeners.indexOf(callback) == -1)
			listeners.push(callback);
	}

	public static function removeListener(callback:Bool->Void):Void
	{
		listeners.remove(callback);
	}

	static function onStatusChanged(online:Bool):Void
	{
		for (listener in listeners)
			listener(online);

		if (online)
			runPendingActions();
	}

	public static function runWhenOnline(action:Void->Void):Void
	{
		if (isConnected)
		{
			action();
			return;
		}

		pendingActions.push(action);
	}

	public static function clearPendingActions():Void
	{
		pendingActions = [];
	}

	static function runPendingActions():Void
	{
		var actions:Array<Void->Void> = pendingActions;
		pendingActions = [];

		for (action in actions)
			action();
	}

	public static function measureLatency(onResult:Float->Void):Void
	{
		var start:Float = Timer.stamp();

		Online.checkNow(function(online:Bool):Void
		{
			latencyMs = online ? (Timer.stamp() - start) * 1000 : -1;
			onResult(latencyMs);
		});
	}

	public static function forceCheck(?onResult:Bool->Void):Void
	{
		Online.checkNow(onResult);
	}

	public static function getStatusLabel():String
	{
		if (!isConnected)
			return "Offline";

		if (latencyMs < 0)
			return "Online";

		if (latencyMs < 150)
			return "Online (fast)";

		if (latencyMs < 500)
			return "Online (slow)";

		return "Online (unstable)";
	}
}
