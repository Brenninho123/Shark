package flixel;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import shark.audio.Audio;
import shark.backend.SharkCamera;

class FlixelShark
{
	public static function makeSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, alpha:Float = 1):FlxSprite
	{
		var sprite = new FlxSprite(x, y).makeGraphic(width, height, color);
		sprite.alpha = alpha;
		return sprite;
	}

	public static function makeStaticSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, alpha:Float = 1):FlxSprite
	{
		var sprite = makeSprite(x, y, width, height, color, alpha);
		sprite.scrollFactor.set(0, 0);
		return sprite;
	}

	public static function makeText(x:Float, y:Float, width:Float, text:String, size:Int = 16, color:FlxColor = FlxColor.WHITE,
			alignment:FlxTextAlign = LEFT):FlxText
	{
		var label = new FlxText(x, y, width, text);
		label.setFormat(null, size, color, alignment);
		return label;
	}

	public static function makeShadowText(x:Float, y:Float, width:Float, text:String, size:Int = 16, color:FlxColor = FlxColor.WHITE,
			shadowColor:FlxColor = FlxColor.BLACK, alignment:FlxTextAlign = LEFT):FlxText
	{
		var label = makeText(x, y, width, text, size, color, alignment);
		label.setBorderStyle(SHADOW, shadowColor, 2);
		return label;
	}

	public static function makeButton(x:Float, y:Float, label:String, onClick:Void->Void, ?width:Int, ?height:Int, bgColor:FlxColor = FlxColor.GRAY,
			textColor:FlxColor = FlxColor.WHITE):FlxButton
	{
		var button = new FlxButton(x, y, label, onClick);

		if (width != null && height != null)
			button.setSize(width, height);

		button.color = bgColor;
		button.label.color = textColor;

		return button;
	}

	public static function createDepthGradient(state:FlxState, colors:Array<FlxColor>):Void
	{
		if (colors.length == 0)
			return;

		var bandHeight:Int = Std.int(FlxG.height / colors.length) + 2;

		for (i in 0...colors.length)
		{
			var band = makeStaticSprite(0, i * bandHeight, FlxG.width, bandHeight, colors[i]);
			state.add(band);
		}
	}

	public static function createBubbleField(state:FlxState, count:Int, color:FlxColor, minSize:Int = 4, maxSize:Int = 14):Array<FlxSprite>
	{
		var bubbles:Array<FlxSprite> = [];

		for (i in 0...count)
		{
			var size:Int = minSize + Std.random(maxSize - minSize);
			var bubble = makeSprite(Std.random(FlxG.width), FlxG.height + Std.random(200), size, size, color, 0.25 + Std.random(40) / 100);

			state.add(bubble);
			bubbles.push(bubble);
		}

		return bubbles;
	}

	public static function updateBubbleField(bubbles:Array<FlxSprite>, elapsed:Float):Void
	{
		for (bubble in bubbles)
		{
			bubble.y -= elapsed * (18 + bubble.width * 4);

			if (bubble.y < -bubble.height)
			{
				bubble.y = FlxG.height + Std.random(100);
				bubble.x = Std.random(FlxG.width);
			}
		}
	}

	public static function switchState(newState:FlxState, useTransition:Bool = true, transitionDuration:Float = 0.4, transitionColor:FlxColor = FlxColor.BLACK):Void
	{
		if (useTransition)
			SharkCamera.transitionToState(newState, transitionDuration, transitionColor);
		else
			FlxG.switchState(newState);
	}

	public static function playSfx(key:String, volumeScale:Float = 1):Void
	{
		Audio.play(key, volumeScale);
	}

	public static function pulse(sprite:FlxSprite, amount:Float = 0.08, duration:Float = 0.15):Void
	{
		sprite.scale.set(1 + amount, 1 + amount);
		flixel.tweens.FlxTween.tween(sprite.scale, {x: 1, y: 1}, duration, {ease: flixel.tweens.FlxEase.quadOut});
	}
}
