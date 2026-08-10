package shark.api.admob;

#if (android || ios)
import extension.admob.Admob;
import extension.admob.AdmobEvent;
import extension.admob.AdmobConsent;
#end

import shark.ui.debug.CrasherLog;

class AdMobClient
{
	public static var isSupported(default, null):Bool;
	public static var isInitialized(default, null):Bool = false;

	public static var onInitComplete:Void->Void;
	public static var onInterstitialClosed:Void->Void;
	public static var onRewardedEarned:Void->Void;

	static var pendingInterstitialUnit:String;
	static var pendingRewardedUnit:String;

	public static function initialize():Void
	{
		#if (android || ios)
		isSupported = true;

		try
		{
			Admob.setCallback(onAdmobEvent);
			Admob.init();
		}
		catch (e:Dynamic)
		{
			isSupported = false;
			CrasherLog.logWarning('Admob.init failed: ${Std.string(e)}', "admob");
		}
		#else
		isSupported = false;
		#end
	}

	#if (android || ios)
	static function onAdmobEvent(event:String, message:String):Void
	{
		switch (event)
		{
			case AdmobEvent.INIT_OK:
				isInitialized = true;

				if (onInitComplete != null)
					onInitComplete();

			case AdmobEvent.INTERSTITIAL_LOADED:
				try
				{
					Admob.showInterstitial();
				}
				catch (e:Dynamic) {}

			case AdmobEvent.REWARDED_LOADED:
				try
				{
					Admob.showRewarded();
				}
				catch (e:Dynamic) {}

			default:
		}
	}
	#end

	public static function isPrivacyOptionsRequired():Bool
	{
		#if (android || ios)
		try
		{
			return Admob.isPrivacyOptionsRequired();
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function showPrivacyOptions():Void
	{
		#if (android || ios)
		try
		{
			Admob.showPrivacyOptionsForm();
		}
		catch (e:Dynamic) {}
		#end
	}

	public static function hasFullConsent():Bool
	{
		#if (android || ios)
		try
		{
			return Admob.getConsent() == AdmobConsent.FULL;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function showBanner(adUnitId:String):Void
	{
		if (!isSupported || !isInitialized)
			return;

		#if (android || ios)
		try
		{
			Admob.showBanner(adUnitId);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Admob.showBanner failed: ${Std.string(e)}', "admob");
		}
		#end
	}

	public static function loadInterstitial(adUnitId:String):Void
	{
		if (!isSupported || !isInitialized)
			return;

		#if (android || ios)
		try
		{
			Admob.loadInterstitial(adUnitId);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Admob.loadInterstitial failed: ${Std.string(e)}', "admob");
		}
		#end
	}

	public static function loadRewarded(adUnitId:String):Void
	{
		if (!isSupported || !isInitialized)
			return;

		#if (android || ios)
		try
		{
			Admob.loadRewarded(adUnitId);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Admob.loadRewarded failed: ${Std.string(e)}', "admob");
		}
		#end
	}

	public static function getStatusSummary():String
	{
		if (!isSupported)
			return "AdMob: not supported on this target";

		return 'AdMob: ${isInitialized ? "initialized" : "not initialized"} | consent: ${hasFullConsent() ? "full" : "limited/none"}';
	}
}
