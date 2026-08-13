package shark.api.google;

class GoogleClient
{
	public static var isSupported(default, null):Bool = false;
	public static var isSignedIn(default, null):Bool = false;

	public static function initialize(enableCloudSave:Bool = false):Void {}

	public static function signIn():Void {}

	public static function unlockAchievement(achievementId:String):Void {}

	public static function incrementAchievement(achievementId:String, steps:Int):Void {}

	public static function submitScore(leaderboardId:String, score:Int):Void {}

	public static function showAchievements():Void {}

	public static function showLeaderboard(leaderboardId:String):Void {}

	public static function getStatusSummary():String
	{
		return "Google Play Games: not supported on this target";
	}
}
