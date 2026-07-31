package shark.online.manager;

import haxe.Timer;
import shark.online.Online;
import shark.ui.debug.CrasherLog;

typedef PendingAction = {
	action:Void->Void,
	queuedAt:Float,
	?onExpired:Void->Void
}

class Internet
{
	public static var isConnected(get, never):Bool;
	public static var latencyMs(get, never):Float;
	public static var maxPendingActionAgeSeconds:Float = 300;
	public static var maxPendingActions:Int = 100;
	public static var pendingActionStaggerMs:Int = 150;

	static var listeners:Array<Bool->Void> = [];
	static var pendingActions:Array<PendingAction> = [];
	static var initialized:Bool = false;

	static var previousLatency:Float = -1;

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

	static function get_latencyMs():Float
	{
		return Online.averageLatencyMs;
	}

	public static function getUptimePercentage():Float
	{
		return Online.getUptimePercentage();
	}

	public static function getPendingActionsCount():Int
	{
		return pendingActions.length;
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
		{
			try
			{
				listener(online);
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Internet listener threw an error: ${Std.string(e)}');
			}
		}

		if (online)
			runPendingActions();
	}

	public static function runWhenOnline(action:Void->Void, ?onExpired:Void->Void):Void
	{
		if (isConnected)
		{
			safeRun(action);
			return;
		}

		if (pendingActions.length >= maxPendingActions)
		{
			var dropped:PendingAction = pendingActions.shift();

			if (dropped.onExpired != null)
				safeRun(dropped.onExpired);

			CrasherLog.logWarning('Pending action queue full (>$maxPendingActions), dropping oldest entry');
		}

		pendingActions.push({
			action: action,
			queuedAt: Timer.stamp(),
			onExpired: onExpired
		});
	}

	public static function clearPendingActions():Void
	{
		pendingActions = [];
	}

	static function runPendingActions():Void
	{
		var actions:Array<PendingAction> = pendingActions;
		pendingActions = [];

		var now:Float = Timer.stamp();
		var delayMs:Int = 0;

		for (pending in actions)
		{
			var age:Float = now - pending.queuedAt;

			if (age > maxPendingActionAgeSeconds)
			{
				if (pending.onExpired != null)
					safeRun(pending.onExpired);

				continue;
			}

			var actionRef:Void->Void = pending.action;

			if (delayMs <= 0)
			{
				safeRun(actionRef);
			}
			else
			{
				Timer.delay(function():Void
				{
					safeRun(actionRef);
				}, delayMs);
			}

			delayMs += pendingActionStaggerMs;
		}
	}

	static function safeRun(fn:Void->Void):Void
	{
		try
		{
			fn();
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Queued action failed: ${Std.string(e)}');
		}
	}

	public static function measureLatency(onResult:Float->Void):Void
	{
		Online.checkNow(function(online:Bool):Void
		{
			onResult(online ? Online.averageLatencyMs : -1);
		});
	}

	public static function forceCheck(?onResult:Bool->Void):Void
	{
		Online.checkNow(onResult);
	}

	public static function getQualityTrend():String
	{
		var current:Float = Online.averageLatencyMs;

		if (previousLatency < 0 || current < 0)
		{
			previousLatency = current;
			return "stable";
		}

		var trend:String;

		if (current < previousLatency * 0.85)
			trend = "improving";
		else if (current > previousLatency * 1.15)
			trend = "degrading";
		else
			trend = "stable";

		previousLatency = current;

		return trend;
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

	public static function getDetailedStatus():String
	{
		if (!isConnected)
			return 'Offline (uptime ${Math.round(getUptimePercentage())}%)';

		return '${getStatusLabel()} - ${Math.round(latencyMs)}ms, ${getQualityTrend()}, uptime ${Math.round(getUptimePercentage())}%';
	}
}
