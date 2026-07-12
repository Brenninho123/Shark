package shark.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import shark.backend.Paths;

class Audio
{
	public static var musicVolume(default, set):Float = 0.5;
	public static var soundVolume(default, set):Float = 0.7;
	public static var isMuted(default, null):Bool = false;

	static var currentMusic:FlxSound;
	static var soundCache:Map<String, Bool> = new Map();

	public static function playMusic(key:String, loop:Bool = true, fadeInDuration:Float = 1):Void
	{
		var path:String = Paths.music(key);

		if (!Paths.exists(path))
			return;

		if (currentMusic != null && currentMusic.playing)
			stopMusic();

		FlxG.sound.playMusic(path, isMuted ? 0 : musicVolume, loop);
		currentMusic = FlxG.sound.music;

		if (currentMusic != null && fadeInDuration > 0)
		{
			currentMusic.volume = 0;
			currentMusic.fadeIn(fadeInDuration, 0, isMuted ? 0 : musicVolume);
		}
	}

	public static function stopMusic(fadeOutDuration:Float = 1):Void
	{
		if (currentMusic == null)
			return;

		if (fadeOutDuration > 0)
		{
			currentMusic.fadeOut(fadeOutDuration, 0, function(_):Void
			{
				if (currentMusic != null)
					currentMusic.stop();
			});
		}
		else
		{
			currentMusic.stop();
		}
	}

	public static function pauseMusic():Void
	{
		if (currentMusic != null)
			currentMusic.pause();
	}

	public static function resumeMusic():Void
	{
		if (currentMusic != null)
			currentMusic.resume();
	}

	public static function play(key:String, volumeScale:Float = 1):Void
	{
		if (isMuted)
			return;

		var path:String = Paths.sound(key);

		if (!Paths.exists(path))
			return;

		FlxG.sound.play(path, soundVolume * volumeScale);
	}

	public static function setMuted(value:Bool):Void
	{
		isMuted = value;

		if (currentMusic != null)
			currentMusic.volume = isMuted ? 0 : musicVolume;
	}

	public static function toggleMute():Bool
	{
		setMuted(!isMuted);
		return isMuted;
	}

	static function set_musicVolume(value:Float):Float
	{
		musicVolume = clampVolume(value);

		if (currentMusic != null && !isMuted)
			currentMusic.volume = musicVolume;

		return musicVolume;
	}

	static function set_soundVolume(value:Float):Float
	{
		soundVolume = clampVolume(value);
		return soundVolume;
	}

	static function clampVolume(value:Float):Float
	{
		if (value < 0)
			return 0;

		if (value > 1)
			return 1;

		return value;
	}
}
