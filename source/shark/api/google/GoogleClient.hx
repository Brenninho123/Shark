package shark.api.google;

#if android
import extension.gpg.GooglePlayGames;
#end

import shark.ui.debug.CrasherLog;

class GoogleClient
{
	public static var isSupported(default, null):Bool;
	public static var isSignedIn(default, null):Bool = false;

	public static function initialize(enableCloudSave:Bool = false):Void
	{
		#if android
		isSupported = true;

		try
		{
			GooglePlayGames.init(enableCloudSave);
		}
		catch (e:Dynamic)
		{
			isSupported = false;
			CrasherLog.logWarning('GooglePlayGames.init failed: ${Std.string(e)}', "google");
		}
		#else
		isSupported = false;
		#end
	}

	public static function signIn():Void
	{
		if (!isSupported)
			return;

		try
		{
			GooglePlayGames.login();
			isSignedIn = true;
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Google Play Games login failed: ${Std.string(e)}', "google");
		}
	}

	public static function unlockAchievement(achievementId:String):Void
	{
		if (!isSupported || !isSignedIn)
			return;

		try
		{
			GooglePlayGames.unlockAchievement(achievementId);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to unlock achievement $achievementId: ${Std.string(e)}', "google");
		}
	}

	public static function incrementAchievement(achievementId:String, steps:Int):Void
	{
		if (!isSupported || !isSignedIn)
			return;

		try
		{
			GooglePlayGames.incrementAchievement(achievementId, steps);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to increment achievement $achievementId: ${Std.string(e)}', "google");
		}
	}

	public static function submitScore(leaderboardId:String, score:Int):Void
	{
		if (!isSupported || !isSignedIn)
			return;

		try
		{
			GooglePlayGames.submitScore(leaderboardId, score);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to submit score to $leaderboardId: ${Std.string(e)}', "google");
		}
	}

	public static function showAchievements():Void
	{
		if (!isSupported || !isSignedIn)
			return;

		try
		{
			GooglePlayGames.showAchievements();
		}
		catch (e:Dynamic) {}
	}

	public static function showLeaderboard(leaderboardId:String):Void
	{
		if (!isSupported || !isSignedIn)
			return;

		try
		{
			GooglePlayGames.showLeaderboard(leaderboardId);
		}
		catch (e:Dynamic) {}
	}

	public static function getStatusSummary():String
	{
		if (!isSupported)
			return "Google Play Games: not supported on this target";

		return 'Google Play Games: ${isSignedIn ? "signed in" : "signed out"}';
	}
}
