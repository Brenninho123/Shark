package shark.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;
import haxe.Timer;

class SharkSound
{
	public static var defaultGroup:FlxSoundGroup = new FlxSoundGroup();
	static var soundCooldowns:Map<String, Float> = new Map();

	public static function play(path:String, volume:Float = 1.0, pitchRange:Float = 0.0, cooldownMs:Float = 0):FlxSound
	{
		if (path == null || path.length == 0)
			return null;

		var now:Float = Timer.stamp() * 1000;
		if (cooldownMs > 0 && soundCooldowns.exists(path))
		{
			if (now - soundCooldowns.get(path) < cooldownMs)
				return null;
		}

		soundCooldowns.set(path, now);

		var sound:FlxSound = FlxG.sound.play(path, volume);
		if (sound != null)
		{
			sound.group = defaultGroup;

			if (pitchRange > 0)
			{
				var randomPitch:Float = 1.0 + (Math.random() * pitchRange * 2 - pitchRange);
				sound.pitch = randomPitch;
			}
		}

		return sound;
	}

	public static function playWithVariation(path:String, minVolume:Float = 0.8, maxVolume:Float = 1.0, minPitch:Float = 0.9, maxPitch:Float = 1.1):FlxSound
	{
		if (path == null || path.length == 0)
			return null;

		var randomVolume:Float = minVolume + Math.random() * (maxVolume - minVolume);
		var randomPitch:Float = minPitch + Math.random() * (maxPitch - minPitch);

		var sound:FlxSound = FlxG.sound.play(path, randomVolume);
		if (sound != null)
		{
			sound.group = defaultGroup;
			sound.pitch = randomPitch;
		}

		return sound;
	}

	public static function playRandom(paths:Array<String>, volume:Float = 1.0, pitchRange:Float = 0.0):FlxSound
	{
		if (paths == null || paths.length == 0)
			return null;

		var selectedPath:String = paths[Std.int(Math.random() * paths.length)];
		return play(selectedPath, volume, pitchRange);
	}

	public static function play3D(path:String, sourceX:Float, sourceY:Float, listenerX:Float, listenerY:Float, maxDistance:Float = 1000, baseVolume:Float = 1.0):FlxSound
	{
		var dx:Float = sourceX - listenerX;
		var dy:Float = sourceY - listenerY;
		var distance:Float = Math.sqrt(dx * dx + dy * dy);

		if (distance >= maxDistance)
			return null;

		var attenuation:Float = 1.0 - (distance / maxDistance);
		var finalVolume:Float = baseVolume * attenuation;

		var sound:FlxSound = play(path, finalVolume);
		if (sound != null)
		{
			var pan:Float = dx / maxDistance;
			if (pan < -1.0) pan = -1.0;
			if (pan > 1.0) pan = 1.0;
			sound.pan = pan;
		}

		return sound;
	}

	public static function stopAll():Void
	{
		FlxG.sound.destroy(false);
	}

	public static function clearCooldowns():Void
	{
		soundCooldowns = new Map();
	}
}
