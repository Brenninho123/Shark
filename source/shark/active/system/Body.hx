package shark.active.system;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

enum BodyState
{
	IDLE;
	THINKING;
	TALKING;
	REACTING;
}

class Body extends FlxSpriteGroup
{
	static inline var COLOR_CORE:FlxColor = 0xFF61A5C2;
	static inline var COLOR_THINKING:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_TALKING:FlxColor = 0xFF7FD8E8;
	static inline var COLOR_REACTING:FlxColor = 0xFFEF9F76;
	static inline var COLOR_EYE:FlxColor = 0xFF00111F;

	public var state(default, null):BodyState = IDLE;

	var core:FlxSprite;
	var ring:FlxSprite;
	var eyeLeft:FlxSprite;
	var eyeRight:FlxSprite;

	var size:Int;
	var idleTween:FlxTween;
	var ringTween:FlxTween;

	public function new(x:Float, y:Float, size:Int = 70)
	{
		super(x, y);

		this.size = size;

		ring = new FlxSprite(0, 0).makeGraphic(size, size, COLOR_CORE);
		ring.alpha = 0.2;
		add(ring);

		var coreSize:Int = Std.int(size * 0.68);
		var coreOffset:Float = (size - coreSize) / 2;

		core = new FlxSprite(coreOffset, coreOffset).makeGraphic(coreSize, coreSize, COLOR_CORE);
		add(core);

		var eyeSize:Int = Std.int(coreSize * 0.14);
		var eyeY:Float = core.y + coreSize * 0.4;

		eyeLeft = new FlxSprite(core.x + coreSize * 0.32, eyeY).makeGraphic(eyeSize, eyeSize, COLOR_EYE);
		add(eyeLeft);

		eyeRight = new FlxSprite(core.x + coreSize * 0.6, eyeY).makeGraphic(eyeSize, eyeSize, COLOR_EYE);
		add(eyeRight);

		setState(IDLE);
	}

	public function setState(newState:BodyState):Void
	{
		if (state == newState)
			return;

		state = newState;

		stopTweens();

		switch (state)
		{
			case IDLE:
				playIdle();
			case THINKING:
				playThinking();
			case TALKING:
				playTalking();
			case REACTING:
				playReacting();
		}
	}

	function stopTweens():Void
	{
		if (idleTween != null)
			idleTween.cancel();

		if (ringTween != null)
			ringTween.cancel();

		core.scale.set(1, 1);
		ring.scale.set(1, 1);
	}

	function playIdle():Void
	{
		core.color = COLOR_CORE;

		idleTween = FlxTween.tween(core.scale, {x: 1.05, y: 1.05}, 1.2, {
			ease: FlxEase.sineInOut,
			type: PINGPONG
		});

		ringTween = FlxTween.tween(ring, {alpha: 0.35}, 1.6, {
			ease: FlxEase.sineInOut,
			type: PINGPONG
		});
	}

	function playThinking():Void
	{
		core.color = COLOR_THINKING;

		idleTween = FlxTween.tween(core.scale, {x: 1.1, y: 0.95}, 0.3, {
			ease: FlxEase.sineInOut,
			type: PINGPONG
		});

		ringTween = FlxTween.tween(ring.scale, {x: 1.3, y: 1.3}, 0.6, {
			ease: FlxEase.sineInOut,
			type: PINGPONG
		});
	}

	function playTalking():Void
	{
		core.color = COLOR_TALKING;

		idleTween = FlxTween.tween(core.scale, {x: 0.95, y: 1.08}, 0.12, {
			ease: FlxEase.quadInOut,
			type: PINGPONG
		});
	}

	function playReacting():Void
	{
		core.color = COLOR_REACTING;
		core.scale.set(1.25, 1.25);

		idleTween = FlxTween.tween(core.scale, {x: 1, y: 1}, 0.35, {
			ease: FlxEase.elasticOut,
			onComplete: function(_):Void
			{
				setState(IDLE);
			}
		});
	}

	public function reactToMessageSent():Void
	{
		setState(TALKING);
	}

	public function reactToReplyReceived():Void
	{
		setState(REACTING);
	}

	public function reactToError():Void
	{
		var originalX:Float = x;

		FlxTween.tween(this, {x: originalX - 6}, 0.05, {
			type: PINGPONG,
			onComplete: function(_):Void
			{
				x = originalX;
				setState(IDLE);
			}
		});
	}

	public function blink():Void
	{
		eyeLeft.scale.y = 0.1;
		eyeRight.scale.y = 0.1;

		FlxTween.tween(eyeLeft.scale, {y: 1}, 0.1, {startDelay: 0.08});
		FlxTween.tween(eyeRight.scale, {y: 1}, 0.1, {startDelay: 0.08});
	}
}
