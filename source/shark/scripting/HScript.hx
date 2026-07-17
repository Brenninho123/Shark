package shark.scripting;

import hscript.SharkScript;
import shark.active.system.Body;
import shark.active.system.BodyState;
import shark.active.system.Head;
import shark.audio.Audio;

typedef HScriptResult = {
	success:Bool,
	value:Dynamic,
	?error:String
}

class HScript
{
	static var engine:SharkScript;
	static var body:Body;

	public static function initialize(?bodyRef:Body):Void
	{
		engine = new SharkScript();
		body = bodyRef;

		bindAudioApi();
		bindBodyApi();
		bindStatsApi();
	}

	public static function attachBody(bodyRef:Body):Void
	{
		body = bodyRef;
	}

	static function bindAudioApi():Void
	{
		engine.setVariable("playSound", function(key:String):Void
		{
			Audio.play(key);
		});

		engine.setVariable("muteAudio", function():Void
		{
			Audio.setMuted(true);
		});

		engine.setVariable("unmuteAudio", function():Void
		{
			Audio.setMuted(false);
		});
	}

	static function bindBodyApi():Void
	{
		engine.setVariable("bodyIdle", function():Void
		{
			if (body != null)
				body.setState(IDLE);
		});

		engine.setVariable("bodyThink", function():Void
		{
			if (body != null)
				body.setState(THINKING);
		});

		engine.setVariable("bodyTalk", function():Void
		{
			if (body != null)
				body.setState(TALKING);
		});

		engine.setVariable("bodyReact", function():Void
		{
			if (body != null)
				body.setState(REACTING);
		});

		engine.setVariable("bodyBlink", function():Void
		{
			if (body != null)
				body.blink();
		});
	}

	static function bindStatsApi():Void
	{
		engine.setVariable("getMessageCount", function():Int
		{
			return Head.totalMessages;
		});

		engine.setVariable("getImageCount", function():Int
		{
			return Head.totalImages;
		});
	}

	public static function bind(name:String, value:Dynamic):Void
	{
		engine.setVariable(name, value);
	}

	public static function run(code:String):HScriptResult
	{
		if (engine == null)
			initialize();

		var result = engine.run(code);

		return {
			success: result.success,
			value: result.value,
			error: result.error
		};
	}

	public static function getOutput():Array<String>
	{
		return engine != null ? engine.getOutput() : [];
	}

	public static function reset():Void
	{
		if (engine != null)
			engine.reset();

		bindAudioApi();
		bindBodyApi();
		bindStatsApi();
	}
}
