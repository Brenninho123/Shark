package shark.menus.intro;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import openfl.events.Event;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.utils.Assets;
import flixel.FlixelShark;
import shark.backend.Language;
import shark.menus.MainMenuState;
import shark.mobile.backend.Vibration;
import shark.ui.debug.CrasherLog;
import Main;

class IntroState extends FlxState
{
	static inline var MUSIC_PATH:String = "assets/sounds/intro/intro.mp3";
	static inline var MAX_DURATION_SECONDS:Float = 8;
	static inline var SKIP_PROMPT_DELAY_SECONDS:Float = 2;

	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;

	var titleText:FlxText;
	var skipPromptText:FlxText;
	var soundChannel:SoundChannel;
	var elapsedSeconds:Float = 0;
	var hasAdvanced:Bool = false;
	var isMobile:Bool;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);

		titleText = FlixelShark.makeShadowText(0, FlxG.height / 2 - 40, FlxG.width, Language.get("app.name"), isMobile ? 42 : 34, COLOR_FOAM, COLOR_ACCENT,
			FlxTextAlign.CENTER);
		titleText.alpha = 0;
		add(titleText);

		skipPromptText = FlixelShark.makeText(0, FlxG.height - (isMobile ? 60 : 40), FlxG.width, Language.get("intro.tapToContinue"), isMobile ? 16 : 13,
			COLOR_ACCENT, FlxTextAlign.CENTER);
		skipPromptText.alpha = 0;
		add(skipPromptText);

		animateIn();
		playMusic();

		CrasherLog.addBreadcrumb("Intro screen shown", "navigation");
	}

	function animateIn():Void
	{
		var reducedMotion:Bool = Main.settings != null && Main.settings.data.reducedMotion;

		if (reducedMotion)
		{
			titleText.alpha = 1;
			skipPromptText.alpha = 0.8;
			return;
		}

		FlxTween.tween(titleText, {alpha: 1}, 1.2, {ease: FlxEase.quadOut});
		FlxTween.tween(skipPromptText, {alpha: 0.8}, 0.8, {ease: FlxEase.quadOut, startDelay: SKIP_PROMPT_DELAY_SECONDS});
	}

	function playMusic():Void
	{
		try
		{
			var sound:Sound = Assets.getSound(MUSIC_PATH);

			if (sound == null)
			{
				CrasherLog.logWarning('Intro music not found at "$MUSIC_PATH"', "audio");
				return;
			}

			var transform:SoundTransform = new SoundTransform(resolveVolume());
			soundChannel = sound.play(0, 0, transform);

			if (soundChannel != null)
				soundChannel.addEventListener(Event.SOUND_COMPLETE, onMusicComplete);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Failed to play intro music: ${Std.string(e)}', "audio");
		}
	}

	function resolveVolume():Float
	{
		if (Main.settings == null)
			return 0.7;

		return Main.settings.data.muted ? 0 : Main.settings.data.musicVolume;
	}

	function onMusicComplete(e:Event):Void
	{
		advance();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		elapsedSeconds += elapsed;

		if (!hasAdvanced && elapsedSeconds >= MAX_DURATION_SECONDS)
		{
			advance();
			return;
		}

		if (elapsedSeconds >= SKIP_PROMPT_DELAY_SECONDS && wasSkipPressed())
			advance();
	}

	function wasSkipPressed():Bool
	{
		if (FlxG.keys.justPressed.ANY)
			return true;

		if (FlxG.mouse.justPressed)
			return true;

		return false;
	}

	function advance():Void
	{
		if (hasAdvanced)
			return;

		hasAdvanced = true;

		Vibration.menuSelect();
		CrasherLog.addBreadcrumb("Intro screen finished", "navigation");

		stopMusic();

		FlixelShark.switchState(new MainMenuState(), true, 0.5, COLOR_ABYSS);
	}

	function stopMusic():Void
	{
		if (soundChannel == null)
			return;

		try
		{
			soundChannel.removeEventListener(Event.SOUND_COMPLETE, onMusicComplete);
			soundChannel.stop();
		}
		catch (e:Dynamic) {}

		soundChannel = null;
	}

	override public function destroy():Void
	{
		stopMusic();
		super.destroy();
	}
}
