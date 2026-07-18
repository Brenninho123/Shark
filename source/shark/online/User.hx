package shark.online;

import flixel.FlxG;
import shark.ui.security.Guard;

class User
{
	public static var userId(default, null):String;
	public static var sessionId(default, null):String;
	public static var firstLaunchTime(default, null):Float;
	public static var sessionStartTime(default, null):Float;
	public static var launchCount(default, null):Int = 0;

	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		loadOrCreateUserId();
		createSessionId();
		trackLaunch();
	}

	static function loadOrCreateUserId():Void
	{
		if (FlxG.save.data.userId != null)
		{
			userId = FlxG.save.data.userId;
			firstLaunchTime = FlxG.save.data.firstLaunchTime != null ? FlxG.save.data.firstLaunchTime : nowSeconds();
			return;
		}

		userId = Guard.generateToken(24);
		firstLaunchTime = nowSeconds();

		FlxG.save.data.userId = userId;
		FlxG.save.data.firstLaunchTime = firstLaunchTime;
		FlxG.save.flush();
	}

	static function createSessionId():Void
	{
		sessionId = Guard.generateToken(16);
		sessionStartTime = nowSeconds();
	}

	static function trackLaunch():Void
	{
		var previousCount:Int = FlxG.save.data.launchCount != null ? FlxG.save.data.launchCount : 0;
		launchCount = previousCount + 1;

		FlxG.save.data.launchCount = launchCount;
		FlxG.save.flush();
	}

	static function nowSeconds():Float
	{
		return Date.now().getTime() / 1000;
	}

	public static function getSessionDurationSeconds():Float
	{
		if (sessionStartTime <= 0)
			return 0;

		return nowSeconds() - sessionStartTime;
	}

	public static function getAccountAgeDays():Float
	{
		if (firstLaunchTime == null || firstLaunchTime <= 0)
			return 0;

		return (nowSeconds() - firstLaunchTime) / 86400;
	}

	public static function isReturningUser():Bool
	{
		return launchCount > 1;
	}

	public static function resetIdentity():Void
	{
		userId = Guard.generateToken(24);
		firstLaunchTime = nowSeconds();
		launchCount = 1;

		FlxG.save.data.userId = userId;
		FlxG.save.data.firstLaunchTime = firstLaunchTime;
		FlxG.save.data.launchCount = launchCount;
		FlxG.save.flush();
	}

	public static function getShortId():String
	{
		return userId != null && userId.length >= 8 ? userId.substr(0, 8) : userId;
	}

	public static function getSummary():String
	{
		return 'User: ${getShortId()} | Launch #$launchCount | ${isReturningUser() ? "returning" : "new"} | Session: ${Math.round(getSessionDurationSeconds())}s';
	}
}
