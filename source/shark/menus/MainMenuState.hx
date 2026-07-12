package shark.menus;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxInputText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.display.BitmapData;
import shark.active.GameState;
import shark.active.system.Head;
import shark.online.Online;

class MainMenuState extends FlxState
{
	static inline var COLOR_ABYSS:FlxColor = 0xFF00111F;
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_WAVE:FlxColor = 0xFF2C7DA0;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;
	static inline var COLOR_KELP:FlxColor = 0xFF14746F;
	static inline var COLOR_ONLINE:FlxColor = 0xFF4ADE80;
	static inline var COLOR_OFFLINE:FlxColor = 0xFFF87171;

	var inputField:FlxInputText;
	var historyText:FlxText;
	var titleText:FlxText;
	var sendButton:FlxButton;
	var statusDot:FlxSprite;
	var statusText:FlxText;
	var thinkingText:FlxText;

	var waveLayers:Array<FlxSprite> = [];
	var bubbles:Array<FlxSprite> = [];
	var lightRays:Array<FlxSprite> = [];
	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];

	var conversation:Array<String> = [];
	var isMobile:Bool;
	var thinkingElapsed:Float = 0;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		createDepthGradient();
		createLightRays();
		createWaveBackground();
		createKelp();
		createBubbles();

		titleText = new FlxText(0, isMobile ? 30 : 20, FlxG.width, "SHARK");
		titleText.setFormat(null, isMobile ? 40 : 32, COLOR_FOAM, CENTER);
		titleText.setBorderStyle(SHADOW, COLOR_ACCENT, 2);
		add(titleText);

		createStatusIndicator();

		thinkingText = new FlxText(0, titleText.y + titleText.height + 4, FlxG.width, "");
		thinkingText.setFormat(null, isMobile ? 16 : 14, COLOR_ACCENT, CENTER);
		add(thinkingText);

		var historyPad:Int = isMobile ? 30 : 20;
		var historyHeight:Int = FlxG.height - (isMobile ? 220 : 160);

		var historyBackdrop = new FlxSprite(historyPad - 10, 100).makeGraphic(FlxG.width - (historyPad - 10) * 2, historyHeight, COLOR_MID);
		historyBackdrop.alpha = 0.3;
		add(historyBackdrop);

		var historyBorder = new FlxSprite(historyPad - 10, 100).makeGraphic(FlxG.width - (historyPad - 10) * 2, 2, COLOR_ACCENT);
		historyBorder.alpha = 0.6;
		add(historyBorder);

		historyText = new FlxText(historyPad, 110, FlxG.width - historyPad * 2, "");
		historyText.setFormat(null, isMobile ? 20 : 16, COLOR_FOAM, LEFT);
		add(historyText);

		var inputHeight:Int = isMobile ? 60 : 40;
		var inputWidth:Int = isMobile ? FlxG.width - 160 : FlxG.width - 140;

		inputField = new FlxInputText(historyPad, FlxG.height - inputHeight - 20, inputWidth, "", isMobile ? 20 : 16, COLOR_FOAM);
		inputField.backgroundColor = COLOR_MID;
		inputField.borderColor = COLOR_ACCENT;
		inputField.borderStyle = OUTLINE;
		inputField.borderSize = 2;
		add(inputField);

		sendButton = new FlxButton(historyPad + inputWidth + 10, FlxG.height - inputHeight - 20, "Send", onSendPressed);
		sendButton.setSize(isMobile ? 110 : 90, inputHeight);
		sendButton.color = COLOR_WAVE;
		sendButton.label.color = COLOR_FOAM;
		add(sendButton);

		Online.onStatusChanged = onOnlineStatusChanged;
		Online.start();

		Head.onThinkingChanged = onThinkingChanged;
	}

	function createDepthGradient():Void
	{
		var bands:Array<FlxColor> = [COLOR_ABYSS, COLOR_DEEP, COLOR_MID];
		var bandHeight:Int = Std.int(FlxG.height / bands.length) + 2;

		for (i in 0...bands.length)
		{
			var band = new FlxSprite(0, i * bandHeight);
			band.makeGraphic(FlxG.width, bandHeight, bands[i]);
			band.scrollFactor.set(0, 0);
			add(band);
		}
	}

	function createLightRays():Void
	{
		var rayCount:Int = isMobile ? 3 : 5;

		for (i in 0...rayCount)
		{
			var ray = new FlxSprite(Std.random(FlxG.width), -100);
			ray.makeGraphic(30 + Std.random(20), FlxG.height + 200, COLOR_FOAM);
			ray.angle = -15;
			ray.alpha = 0.03 + Std.random(4) / 100;
			ray.scrollFactor.set(0, 0);
			add(ray);
			lightRays.push(ray);

			FlxTween.tween(ray, {x: ray.x + 60}, 8 + Std.random(4), {
				ease: FlxEase.sineInOut,
				type: PINGPONG
			});
		}
	}

	function createWaveBackground():Void
	{
		var colors:Array<FlxColor> = [COLOR_MID, COLOR_WAVE, COLOR_ACCENT];

		for (i in 0...colors.length)
		{
			var wave = new FlxSprite(0, FlxG.height - 40 - (i * 30));
			wave.makeGraphic(FlxG.width, 60, colors[i]);
			wave.alpha = 0.22;
			wave.scrollFactor.set(0, 0);
			add(wave);
			waveLayers.push(wave);

			FlxTween.tween(wave, {x: -40}, 3 + i, {
				ease: FlxEase.sineInOut,
				type: PINGPONG
			});
		}
	}

	function createKelp():Void
	{
		var bladeCount:Int = isMobile ? 5 : 8;

		for (i in 0...bladeCount)
		{
			var height:Int = 40 + Std.random(60);
			var blade = new FlxSprite((i / bladeCount) * FlxG.width + Std.random(20), FlxG.height - height);
			blade.makeGraphic(8, height, COLOR_KELP);
			blade.alpha = 0.5;
			blade.origin.set(4, height);
			add(blade);

			kelpBlades.push({sprite: blade, offset: Std.random(6283) / 1000, speed: 1 + Std.random(50) / 100});
		}
	}

	function createBubbles():Void
	{
		var bubbleCount:Int = isMobile ? 8 : 14;

		for (i in 0...bubbleCount)
		{
			var size:Int = 4 + Std.random(10);
			var bubble = new FlxSprite(Std.random(FlxG.width), FlxG.height + Std.random(200));
			bubble.makeGraphic(size, size, COLOR_ACCENT);
			bubble.alpha = 0.3 + Std.random(40) / 100;
			add(bubble);
			bubbles.push(bubble);
		}
	}

	function createStatusIndicator():Void
	{
		statusDot = new FlxSprite(FlxG.width - 26, 14);
		statusDot.makeGraphic(12, 12, COLOR_OFFLINE);
		add(statusDot);

		statusText = new FlxText(0, 14, FlxG.width - 44, "offline");
		statusText.setFormat(null, 14, COLOR_OFFLINE, RIGHT);
		add(statusText);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (bubble in bubbles)
		{
			bubble.y -= elapsed * (20 + bubble.width * 4);

			if (bubble.y < -bubble.height)
			{
				bubble.y = FlxG.height + Std.random(100);
				bubble.x = Std.random(FlxG.width);
			}
		}

		for (blade in kelpBlades)
		{
			blade.offset += elapsed * blade.speed;
			blade.sprite.angle = Math.sin(blade.offset) * 6;
		}

		if (Head.isThinking)
		{
			thinkingElapsed += elapsed;
			var dots:Int = Std.int(thinkingElapsed * 2) % 4;
			thinkingText.text = "Shark is thinking" + StringTools.rpad("", ".", dots);
		}

		if (!isMobile && FlxG.keys.justPressed.ENTER && inputField.text.length > 0)
			sendMessage(inputField.text);
	}

	function onSendPressed():Void
	{
		if (inputField.text.length > 0)
			sendMessage(inputField.text);
	}

	function sendMessage(message:String):Void
	{
		var trimmed:String = StringTools.trim(message);

		if (trimmed.toLowerCase() == "!play")
		{
			appendToHistory("You: " + message);
			inputField.text = "";
			goToGameState();
			return;
		}

		appendToHistory("You: " + message);
		inputField.text = "";

		Head.think(message, onReply, onError, onImageGenerated, onImageError);
	}

	function goToGameState():Void
	{
		FlxG.switchState(new GameState());
	}

	function onReply(reply:String):Void
	{
		appendToHistory("Shark: " + reply);
	}

	function onError(error:String):Void
	{
		appendToHistory("Error: " + error);
	}

	function onImageGenerated(bitmap:BitmapData):Void
	{
		var sprite = new FlxSprite(FlxG.width - bitmap.width - 20, 110);
		sprite.pixels = bitmap;
		add(sprite);

		appendToHistory("Shark: [image generated]");
	}

	function onImageError(error:String):Void
	{
		appendToHistory("Error generating image: " + error);
	}

	function onOnlineStatusChanged(online:Bool):Void
	{
		statusDot.color = online ? COLOR_ONLINE : COLOR_OFFLINE;
		statusText.color = online ? COLOR_ONLINE : COLOR_OFFLINE;
		statusText.text = online ? "online" : "offline";
		sendButton.alive = online;
	}

	function onThinkingChanged(thinking:Bool):Void
	{
		thinkingElapsed = 0;

		if (!thinking)
			thinkingText.text = "";
	}

	function appendToHistory(line:String):Void
	{
		conversation.push(line);
		historyText.text = conversation.join("\n");
	}
}
