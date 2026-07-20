package shark.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import shark.backend.ClientPrefs;
import shark.backend.Paths;

class Audio
{
	public static var musicVolume(default, set):Float = 0.5;
	public static var soundVolume(default, set):Float = 0.7;
	public static var isMuted(default, null):Bool = false;

	static var currentMusic:FlxSound;
	static var currentMusicKey:String;
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if (initialized)
			return;

		initialized = true;

		musicVolume = ClientPrefs.musicVolume;
		soundVolume = ClientPrefs.soundVolume;
		isMuted = ClientPrefs.muted;

		if (FlxG.sound != null)
			FlxG.sound.muted = isMuted;
	}

	public static function playMusic(key:String, loop:Bool = true, fadeInDuration:Float = 1):Void
	{
		if (key == currentMusicKey && currentMusic != null && currentMusic.playing)
			return;

		var path:String = Paths.music(key);

		if (!Paths.exists(path))
			return;

		if (currentMusic != null && currentMusic.playing)
			stopMusic(0);

		FlxG.sound.playMusic(path, isMuted ? 0 : musicVolume, loop);
		currentMusic = FlxG.sound.music;
		currentMusicKey = key;

		if (currentMusic != null && fadeInDuration > 0)
		{
			currentMusic.volume = 0;
			currentMusic.fadeIn(fadeInDuration, 0, isMuted ? 0 : musicVolume);
		}
	}

	public static function crossfadeMusic(key:String, duration:Float = 1.5, loop:Bool = true):Void
	{
		if (key == currentMusicKey && currentMusic != null && currentMusic.playing)
			return;

		var outgoing:FlxSound = currentMusic;

		if (outgoing != null)
		{
			outgoing.fadeOut(duration, 0, function(_):Void
			{
				outgoing.stop();
			});
		}

		currentMusic = null;
		currentMusicKey = null;

		playMusic(key, loop, duration);
	}

	public static function stopMusic(fadeOutDuration:Float = 1):Void
	{
		if (currentMusic == null)
			return;

		var musicRef:FlxSound = currentMusic;

		if (fadeOutDuration > 0)
		{
			musicRef.fadeOut(fadeOutDuration, 0, function(_):Void
			{
				musicRef.stop();
			});
		}
		else
		{
			musicRef.stop();
		}

		currentMusic = null;
		currentMusicKey = null;
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

		var sound = Paths.getSound(key, true);

		if (sound == null)
			return;

		FlxG.sound.play(cast sound, soundVolume * volumeScale);
	}

	public static function playRandom(baseKey:String, count:Int, volumeScale:Float = 1):Void
	{
		if (isMuted || count <= 0)
			return;

		var sound = Paths.getRandomSound(baseKey, count, true);

		if (sound == null)
			return;

		FlxG.sound.play(cast sound, soundVolume * volumeScale);
	}

	public static function setMuted(value:Bool):Void
	{
		isMuted = value;

		if (currentMusic != null)
			currentMusic.volume = isMuted ? 0 : musicVolume;

		if (FlxG.sound != null)
			FlxG.sound.muted = isMuted;

		ClientPrefs.muted = isMuted;
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

		if (initialized)
			ClientPrefs.musicVolume = musicVolume;

		return musicVolume;
	}

	static function set_soundVolume(value:Float):Float
	{
		soundVolume = clampVolume(value);

		if (initialized)
			ClientPrefs.soundVolume = soundVolume;

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
