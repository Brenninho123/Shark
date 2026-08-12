package shark.api.newgrounds;

#if html5
import io.newgrounds.NG;
#end

import shark.ui.debug.CrasherLog;

class NewClient
{
	public static var isSupported(default, null):Bool;
	public static var isConnected(default, null):Bool = false;
	public static var appId(default, null):String = "";

	public static function initialize(newAppId:String, ?sessionId:String):Void
	{
		#if html5
		isSupported = true;

		if (newAppId == null || newAppId.length == 0)
		{
			isSupported = false;
			return;
		}

		appId = newAppId;

		try
		{
			NG.create(appId, sessionId);

			NG.onCoreReady.add(onLoginSuccess);

			NG.core.requestLogin(function(outcome:io.newgrounds.LoginOutcome):Void {});
		}
		catch (e:Dynamic)
		{
			isSupported = false;
			CrasherLog.logWarning('Newgrounds NG.create failed: ${Std.string(e)}');
		}
		#else
		isSupported = false;
		#end
	}

	#if html5
	static function onLoginSuccess():Void
	{
		isConnected = true;
	}
	#end

	public static function unlockMedal(medalId:Int):Void
	{
		if (!isSupported || !isConnected)
			return;

		#if html5
		try
		{
			NG.core.calls.medal.unlock(medalId).addErrorHandler(function(error:Dynamic):Void
			{
				CrasherLog.logWarning('Failed to unlock medal $medalId: ${Std.string(error)}');
			}).send();
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Newgrounds medal unlock threw: ${Std.string(e)}');
		}
		#end
	}

	public static function postScore(boardId:Int, score:Int):Void
	{
		if (!isSupported || !isConnected)
			return;

		#if html5
		try
		{
			NG.core.calls.scoreBoard.postScore(boardId, score).addErrorHandler(function(error:Dynamic):Void
			{
				CrasherLog.logWarning('Failed to post score to board $boardId: ${Std.string(error)}');
			}).send();
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Newgrounds score post threw: ${Std.string(e)}');
		}
		#end
	}

	public static function checkSession():Void
	{
		if (!isSupported)
			return;

		#if html5
		try
		{
			NG.core.calls.app.checkSession().send();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function getStatusSummary():String
	{
		if (!isSupported)
			return "Newgrounds: not supported on this target";

		return 'Newgrounds: ${isConnected ? "connected" : "not connected"} (app: $appId)';
	}
}
