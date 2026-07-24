package shark.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import shark.backend.ClientPrefs;
import shark.backend.Paths;

class SoundGroup
{
	static var registry:Map<String, SoundGroup> = new Map();

	public static function get(name:String, defaultVolume:Float = 1):SoundGroup
	{
		if (!registry.exists(name))
			registry.set(name, new SoundGroup(name, defaultVolume));

		return registry.get(name);
	}

	public static function getAllGroupNames():Array<String>
	{
		var names:Array<String> = [];

		for (name in registry.keys())
			names.push(name);

		return names;
	}

	public static function stopAllGroups():Void
	{
		for (group in registry)
			group.stopAll();
	}

	public var name(default, null):String;
	public var volume(default, set):Float;
	public var isMuted(default, set):Bool;

	var activeSounds:Array<FlxSound> = [];

	function new(name:String, defaultVolume:Float)
	{
		this.name = name;
		volume = ClientPrefs.getFloat(prefKey("volume"), defaultVolume);
		isMuted = ClientPrefs.getBool(prefKey("muted"), false);
	}

	function prefKey(suffix:String):String
	{
		return 'soundGroup_${name}_$suffix';
	}

	public function play(key:String, volumeScale:Float = 1):FlxSound
	{
		if (isMuted || Audio.isMuted)
			return null;

		var sound = Paths.getSound(key, true);

		if (sound == null)
			return null;

		var effectiveVolume:Float = volume * volumeScale * Audio.soundVolume;
		var flxSound:FlxSound = FlxG.sound.play(cast sound, effectiveVolume);

		if (flxSound != null)
		{
			activeSounds.push(flxSound);
			cleanupFinished();
		}

		return flxSound;
	}

	public function playRandom(baseKey:String, count:Int, volumeScale:Float = 1):FlxSound
	{
		if (isMuted || Audio.isMuted || count <= 0)
			return null;

		var sound = Paths.getRandomSound(baseKey, count, true);

		if (sound == null)
			return null;

		var effectiveVolume:Float = volume * volumeScale * Audio.soundVolume;
		var flxSound:FlxSound = FlxG.sound.play(cast sound, effectiveVolume);

		if (flxSound != null)
		{
			activeSounds.push(flxSound);
			cleanupFinished();
		}

		return flxSound;
	}

	public function stopAll():Void
	{
		for (sound in activeSounds)
			if (sound != null)
				sound.stop();

		activeSounds = [];
	}

	public function pauseAll():Void
	{
		for (sound in activeSounds)
			if (sound != null)
				sound.pause();
	}

	public function resumeAll():Void
	{
		for (sound in activeSounds)
			if (sound != null)
				sound.resume();
	}

	function cleanupFinished():Void
	{
		activeSounds = activeSounds.filter(function(sound:FlxSound):Bool
		{
			return sound != null && sound.playing;
		});
	}

	public function getActiveCount():Int
	{
		cleanupFinished();
		return activeSounds.length;
	}

	function set_volume(value:Float):Float
	{
		var clamped:Float = clampVolume(value);
		volume = clamped;

		ClientPrefs.setFloat(prefKey("volume"), clamped);
		applyToActive();

		return clamped;
	}

	function set_isMuted(value:Bool):Bool
	{
		isMuted = value;

		ClientPrefs.setBool(prefKey("muted"), value);
		applyToActive();

		return value;
	}

	function applyToActive():Void
	{
		var effectiveVolume:Float = isMuted ? 0 : volume;

		for (sound in activeSounds)
			if (sound != null)
				sound.volume = effectiveVolume * Audio.soundVolume;
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
