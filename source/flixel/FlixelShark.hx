package flixel;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import haxe.ds.WeakMap;
import lime.manager.LimeManager;
import shark.audio.Audio;
import shark.backend.Language;
import shark.backend.SharkCamera;
import shark.mobile.backend.Vibration.HapticStyle;
import shark.mobile.backend.Vibration;
import git.graphic.GraphicGit;
import git.resolution.Resolution4K;
import shark.shaders.WaterShader;

class FlixelShark
{
	public static inline var MAX_SPRITE_DIMENSION:Int = 4096;
	public static inline var MIN_SPRITE_DIMENSION:Int = 1;
	public static inline var MAX_TEXT_LENGTH:Int = 5000;
	public static var defaultButtonCooldownMs:Float = 350;

	public static function makeSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, alpha:Float = 1):FlxSprite
	{
		var sprite = new FlxSprite(x, y).makeGraphic(width, height, color);
		sprite.alpha = alpha;
		return sprite;
	}

	public static function makeSafeSprite(x:Float, y:Float, width:Int, height:Int, color:FlxColor, alpha:Float = 1):FlxSprite
	{
		return makeSprite(x, y, clampDimension(width), clampDimension(height), color, clampAlpha(alpha));
	}

	static function clampDimension(value:Int):Int
	{
		if (value < MIN_SPRITE_DIMENSION)
			return MIN_SPRITE_DIMENSION;

		if (value > MAX_SPRITE_DIMENSION)
			return MAX_SPRITE_DIMENSION;

		return value;
	}

	static function clampAlpha(value:Float):Float
	{
		if (Math.isNaN(value))
			return 1;

		if (value < 0)
			return 0;

		if (value > 1)
			return 1;

		return value;
	}

	public static function truncateText(text:String, maxLength:Int = MAX_TEXT_LENGTH):String
	{
		if (text == null)
			return "";

		if (text.length <= maxLength)
			return text;

		return text.substr(0, maxLength) + "...";
	}

	public static function makeSafeText(x:Float, y:Float, width:Float, text:String, size:Int = 16, color:FlxColor = FlxColor.WHITE,
			alignment:FlxTextAlign = LEFT):FlxText
	{
		return makeText(x, y, width, truncateText(text), size, color, alignment);
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

	static function wrapWithHaptics(onClick:Void->Void):Void->Void
	{
		return function():Void
		{
			Vibration.trigger(HapticStyle.SELECTION);

			if (onClick != null)
				onClick();
		};
	}

	public static function makeButton(x:Float, y:Float, label:String, onClick:Void->Void, ?width:Int, ?height:Int, bgColor:FlxColor = FlxColor.GRAY,
			textColor:FlxColor = FlxColor.WHITE):FlxButton
	{
		var button = new FlxButton(x, y, label, wrapWithHaptics(onClick));

		if (width != null && height != null)
			button.setSize(width, height);

		button.color = bgColor;
		button.label.color = textColor;

		return button;
	}

	public static function makeLocalizedText(x:Float, y:Float, width:Float, key:String, size:Int = 16, color:FlxColor = FlxColor.WHITE,
			alignment:FlxTextAlign = LEFT):FlxText
	{
		return makeText(x, y, width, Language.get(key), size, color, alignment);
	}

	public static function makeLocalizedShadowText(x:Float, y:Float, width:Float, key:String, size:Int = 16, color:FlxColor = FlxColor.WHITE,
			shadowColor:FlxColor = FlxColor.BLACK, alignment:FlxTextAlign = LEFT):FlxText
	{
		return makeShadowText(x, y, width, Language.get(key), size, color, shadowColor, alignment);
	}

	public static function makeLocalizedButton(x:Float, y:Float, key:String, onClick:Void->Void, ?width:Int, ?height:Int, bgColor:FlxColor = FlxColor.GRAY,
			textColor:FlxColor = FlxColor.WHITE):FlxButton
	{
		return makeButton(x, y, Language.get(key), onClick, width, height, bgColor, textColor);
	}

	public static function scaleCountForMemory(baseCount:Int):Int
	{
		if (LimeManager.isLowMemoryMode)
			return Std.int(baseCount * 0.4);

		if (LimeManager.currentQualityTier == 0)
			return Std.int(baseCount * 0.6);

		return baseCount;
	}

	public static function createCard(state:FlxState, x:Float, y:Float, width:Float, height:Float, bgColor:FlxColor, accentColor:FlxColor,
			shadowColor:FlxColor = FlxColor.BLACK):FlxSprite
	{
		var shadow = makeSprite(x + 4, y + 4, Std.int(width), Std.int(height), shadowColor, 0.4);
		state.add(shadow);

		var card = makeSprite(x, y, Std.int(width), Std.int(height), bgColor, 0.35);
		state.add(card);

		var accentBar = makeSprite(x, y, 6, Std.int(height), accentColor, 0.9);
		state.add(accentBar);

		return card;
	}

	public static function createRoundedCard(state:FlxState, x:Float, y:Float, width:Float, height:Float, bgColor:FlxColor, accentColor:FlxColor,
			radius:Float = 10, shadowColor:FlxColor = FlxColor.BLACK):FlxSprite
	{
		var shadow = GraphicGit.makeRoundedRectSprite(x + 4, y + 4, Std.int(width), Std.int(height), shadowColor, radius, 0.35);
		state.add(shadow);

		var card = GraphicGit.makeRoundedRectSprite(x, y, Std.int(width), Std.int(height), bgColor, radius, 0.35);
		state.add(card);

		var border = new FlxSprite(x, y);
		border.pixels = GraphicGit.createRoundedRectBorder(Std.int(width), Std.int(height), accentColor, radius, 2, 0.7);
		state.add(border);

		return card;
	}

	public static function createRoundedPanel(state:FlxState, x:Float, y:Float, width:Float, height:Float, color:FlxColor, radius:Float = 12,
			alpha:Float = 0.35):FlxSprite
	{
		var panel = GraphicGit.makeRoundedRectSprite(x, y, Std.int(width), Std.int(height), color, radius, alpha);
		state.add(panel);
		return panel;
	}

	public static function createChatBubbleCard(state:FlxState, x:Float, y:Float, width:Float, height:Float, color:FlxColor,
			tail:git.graphic.GraphicGit.BubbleTail = LEFT, radius:Float = 12, tailSize:Float = 10, alpha:Float = 0.9):FlxSprite
	{
		var bubble = GraphicGit.makeChatBubbleSprite(x, y, Std.int(width), Std.int(height), color, radius, tail, tailSize, alpha);
		state.add(bubble);
		return bubble;
	}

	public static function createProgressBar(state:FlxState, x:Float, y:Float, width:Float, height:Float, bgColor:FlxColor, fillColor:FlxColor,
			progress:Float = 1):{background:FlxSprite, fill:FlxSprite}
	{
		var background = GraphicGit.makePillSprite(x, y, Std.int(width), Std.int(height), bgColor, 1);
		state.add(background);

		var fill = GraphicGit.makePillSprite(x, y, Std.int(width), Std.int(height), fillColor, 1);
		state.add(fill);

		setProgressBarValue(fill, width, progress);

		return {background: background, fill: fill};
	}

	public static function setProgressBarValue(fillSprite:FlxSprite, fullWidth:Float, progress:Float):Void
	{
		var clamped:Float = clampAlpha(progress);
		fillSprite.clipRect = new FlxRect(0, 0, fullWidth * clamped, fillSprite.height);
	}

	public static function makeScaledText(x:Float, y:Float, width:Float, text:String, baseSize:Int = 16, color:FlxColor = FlxColor.WHITE,
			alignment:FlxTextAlign = LEFT):FlxText
	{
		return makeText(x, y, width, text, Resolution4K.scaledInt(baseSize), color, alignment);
	}

	public static function makeScaledButton(x:Float, y:Float, label:String, onClick:Void->Void, baseWidth:Int, baseHeight:Int,
			bgColor:FlxColor = FlxColor.GRAY, textColor:FlxColor = FlxColor.WHITE):FlxButton
	{
		return makeButton(x, y, label, onClick, Resolution4K.scaledInt(baseWidth), Resolution4K.scaledInt(baseHeight), bgColor, textColor);
	}

	static var activeWaterShaders:Array<{sprite:FlxSprite, shader:WaterShader}> = [];

	public static function applyWaterEffect(sprite:FlxSprite, amplitude:Float = 0.01, frequency:Float = 20, tintStrength:Float = 0.15):WaterShader
	{
		var shader = new WaterShader();
		shader.amplitude = amplitude;
		shader.frequency = frequency;
		shader.tintStrength = tintStrength;

		sprite.shader = shader;
		activeWaterShaders.push({sprite: sprite, shader: shader});

		return shader;
	}

	public static function removeWaterEffect(sprite:FlxSprite):Void
	{
		activeWaterShaders = activeWaterShaders.filter(function(pair) return pair.sprite != sprite);

		if (sprite != null && sprite.shader != null)
			sprite.shader = null;
	}

	public static function updateAllWaterShaders(elapsed:Float):Void
	{
		var stillActive:Array<{sprite:FlxSprite, shader:WaterShader}> = [];

		for (pair in activeWaterShaders)
		{
			if (pair.sprite == null || !pair.sprite.exists)
				continue;

			pair.shader.update(elapsed);
			stillActive.push(pair);
		}

		activeWaterShaders = stillActive;
	}

	public static function clearWaterShaders():Void
	{
		activeWaterShaders = [];
	}

	static var ambientTweens:Array<FlxTween> = [];

	public static function clearAmbientTweens():Void
	{
		for (tween in ambientTweens)
			if (tween != null)
				tween.cancel();

		ambientTweens = [];
	}

	public static function createIconButton(state:FlxState, x:Float, y:Float, width:Int, height:Int, color:FlxColor, onClick:Void->Void):FlxButton
	{
		var button = new FlxButton(x, y, "", wrapWithHaptics(onClick));
		button.setSize(width, height);
		button.color = color;
		state.add(button);
		return button;
	}

	public static function addArrowIcon(state:FlxState, button:FlxButton, color:FlxColor = FlxColor.WHITE):Void
	{
		var cx:Float = button.x + button.width / 2;
		var cy:Float = button.y + button.height / 2;
		var barLength:Float = button.height * 0.32;

		var top = makeSprite(0, 0, Std.int(barLength), 4, color);
		top.angle = -45;
		top.setPosition(cx - barLength * 0.55, cy - barLength * 0.5);
		state.add(top);

		var bottom = makeSprite(0, 0, Std.int(barLength), 4, color);
		bottom.angle = 45;
		bottom.setPosition(cx - barLength * 0.55, cy + barLength * 0.15);
		state.add(bottom);
	}

	public static function addPlusIcon(state:FlxState, button:FlxButton, color:FlxColor = FlxColor.WHITE):FlxSprite
	{
		var size:Int = Std.int(Math.min(button.width, button.height) * 0.5);
		var icon = new FlxSprite(button.x + (button.width - size) / 2, button.y + (button.height - size) / 2);
		icon.pixels = GraphicGit.createPlus(size, color, 3);
		state.add(icon);
		return icon;
	}

	public static function addMenuIcon(state:FlxState, button:FlxButton, color:FlxColor = FlxColor.WHITE):Void
	{
		var cx:Float = button.x + button.width / 2;
		var cy:Float = button.y + button.height / 2;
		var barWidth:Float = button.width * 0.5;

		for (i in 0...3)
			state.add(makeSprite(cx - barWidth / 2, cy - 8 + i * 8, Std.int(barWidth), 3, color));
	}

	public static function addSpeakerIcon(state:FlxState, button:FlxButton, muted:Bool, color:FlxColor = FlxColor.WHITE,
			mutedAccent:FlxColor = 0xFFF87171, waveAccent:FlxColor = 0xFF61A5C2):FlxSpriteGroup
	{
		var group = new FlxSpriteGroup(button.x, button.y);

		var cx:Float = button.width / 2;
		var cy:Float = button.height / 2;

		var speakerBody = makeSprite(cx - 9, cy - 5, 6, 10, color);
		group.add(speakerBody);

		var cone = makeSprite(cx - 4, cy - 8, 6, 16, color);
		cone.angle = 25;
		group.add(cone);

		if (muted)
		{
			var slash = makeSprite(cx - 1, cy - 9, 3, 18, mutedAccent);
			slash.angle = 45;
			group.add(slash);
		}
		else
		{
			for (i in 0...2)
				group.add(makeSprite(cx + 4 + i * 5, cy - 4 - i * 1, 2, Std.int(8 + i * 6), waveAccent, 0.8));
		}

		state.add(group);
		return group;
	}

	public static function addBoltIcon(state:FlxState, button:FlxButton, color:FlxColor = FlxColor.WHITE):FlxSpriteGroup
	{
		var group = new FlxSpriteGroup(button.x, button.y);

		var cx:Float = button.width / 2;
		var cy:Float = button.height / 2;

		var top = makeSprite(cx - 1, cy - 10, 3, 12, color);
		top.angle = 20;
		group.add(top);

		var bottom = makeSprite(cx - 2, cy - 2, 3, 12, color);
		bottom.angle = 20;
		group.add(bottom);

		state.add(group);
		return group;
	}

	public static function createLightRays(state:FlxState, count:Int, color:FlxColor = FlxColor.WHITE):Array<FlxSprite>
	{
		var rays:Array<FlxSprite> = [];
		var actualCount:Int = scaleCountForMemory(count);

		for (i in 0...actualCount)
		{
			var ray = makeStaticSprite(Std.random(FlxG.width), -100, 30 + Std.random(20), FlxG.height + 200, color, 0.03 + Std.random(4) / 100);
			ray.angle = -15;
			state.add(ray);
			rays.push(ray);

			var tween = FlxTween.tween(ray, {x: ray.x + 60}, 8 + Std.random(4), {
				ease: FlxEase.sineInOut,
				type: PINGPONG
			});

			ambientTweens.push(tween);
		}

		return rays;
	}

	public static function createKelpField(state:FlxState, count:Int, color:FlxColor):Array<{sprite:FlxSprite, offset:Float, speed:Float}>
	{
		var blades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];
		var actualCount:Int = scaleCountForMemory(count);

		for (i in 0...actualCount)
		{
			var height:Int = 40 + Std.random(60);
			var blade = makeSprite((i / actualCount) * FlxG.width + Std.random(20), FlxG.height - height, 8, height, color, 0.5);
			blade.origin.set(4, height);
			state.add(blade);

			blades.push({sprite: blade, offset: Std.random(6283) / 1000, speed: 1 + Std.random(50) / 100});
		}

		return blades;
	}

	public static function updateKelpField(blades:Array<{sprite:FlxSprite, offset:Float, speed:Float}>, elapsed:Float):Void
	{
		for (blade in blades)
		{
			blade.offset += elapsed * blade.speed;
			blade.sprite.angle = Math.sin(blade.offset) * 6;
		}
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
		var actualCount:Int = scaleCountForMemory(count);

		for (i in 0...actualCount)
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

	static var lastClickTimes:WeakMap<FlxButton, Float> = new WeakMap();

	public static function makeDebouncedButton(x:Float, y:Float, label:String, onClick:Void->Void, ?width:Int, ?height:Int, bgColor:FlxColor = FlxColor.GRAY,
			textColor:FlxColor = FlxColor.WHITE, cooldownMs:Float = -1):FlxButton
	{
		var effectiveCooldown:Float = cooldownMs > 0 ? cooldownMs : defaultButtonCooldownMs;
		var button:FlxButton = null;

		var wrappedClick = function():Void
		{
			var now:Float = haxe.Timer.stamp() * 1000;
			var lastClick:Float = lastClickTimes.exists(button) ? lastClickTimes.get(button) : -1;

			if (lastClick >= 0 && now - lastClick < effectiveCooldown)
				return;

			lastClickTimes.set(button, now);
			Vibration.trigger(HapticStyle.SELECTION);

			if (onClick != null)
				onClick();
		};

		button = new FlxButton(x, y, label, wrappedClick);

		if (width != null && height != null)
			button.setSize(width, height);

		button.color = bgColor;
		button.label.color = textColor;

		return button;
	}

	public static function wrapDebounced(button:FlxButton, onClick:Void->Void, cooldownMs:Float = -1):Void->Void
	{
		var effectiveCooldown:Float = cooldownMs > 0 ? cooldownMs : defaultButtonCooldownMs;

		return function():Void
		{
			var now:Float = haxe.Timer.stamp() * 1000;
			var lastClick:Float = lastClickTimes.exists(button) ? lastClickTimes.get(button) : -1;

			if (lastClick >= 0 && now - lastClick < effectiveCooldown)
				return;

			lastClickTimes.set(button, now);
			Vibration.trigger(HapticStyle.SELECTION);

			if (onClick != null)
				onClick();
		};
	}

	public static function safeSwitchState(newState:FlxState, useTransition:Bool = true, transitionDuration:Float = 0.4,
			transitionColor:FlxColor = FlxColor.BLACK):Bool
	{
		if (newState == null)
			return false;

		switchState(newState, useTransition, transitionDuration, transitionColor);
		return true;
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

	public static function getStatusSummary():String
	{
		return 'FlixelShark: ${activeWaterShaders.length} water shader(s), ${ambientTweens.length} ambient tween(s) tracked';
	}
}
