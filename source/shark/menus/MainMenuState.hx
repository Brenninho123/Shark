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
import shark.functions.ChatEngine;

class MainMenuState extends FlxState
{
	static inline var COLOR_DEEP:FlxColor = 0xFF012A4A;
	static inline var COLOR_MID:FlxColor = 0xFF01497C;
	static inline var COLOR_WAVE:FlxColor = 0xFF2C7DA0;
	static inline var COLOR_ACCENT:FlxColor = 0xFF61A5C2;
	static inline var COLOR_FOAM:FlxColor = 0xFFE0FBFC;

	var inputField:FlxInputText;
	var historyText:FlxText;
	var titleText:FlxText;
	var sendButton:FlxButton;

	var waveLayers:Array<FlxSprite> = [];
	var bubbles:Array<FlxSprite> = [];

	var conversation:Array<String> = [];
	var isMobile:Bool;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_DEEP;

		createWaveBackground();
		createBubbles();

		titleText = new FlxText(0, isMobile ? 30 : 20, FlxG.width, "SHARK");
		titleText.setFormat(null, isMobile ? 40 : 32, COLOR_FOAM, CENTER);
		titleText.setBorderStyle(SHADOW, COLOR_ACCENT, 2);
		add(titleText);

		var historyPad:Int = isMobile ? 30 : 20;
		var historyHeight:Int = FlxG.height - (isMobile ? 220 : 160);

		var historyBackdrop = new FlxSprite(historyPad - 10, 80).makeGraphic(FlxG.width - (historyPad - 10) * 2, historyHeight, COLOR_MID);
		historyBackdrop.alpha = 0.35;
		add(historyBackdrop);

		historyText = new FlxText(historyPad, 90, FlxG.width - historyPad * 2, "");
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
		sendButton.resize(isMobile ? 110 : 90, inputHeight);
		sendButton.color = COLOR_WAVE;
		sendButton.label.color = COLOR_FOAM;
		add(sendButton);
	}

	function createWaveBackground():Void
	{
		var colors:Array<FlxColor> = [COLOR_MID, COLOR_WAVE, COLOR_ACCENT];

		for (i in 0...colors.length)
		{
			var wave = new FlxSprite(0, FlxG.height - 40 - (i * 30));
			wave.makeGraphic(FlxG.width, 60, colors[i]);
			wave.alpha = 0.25;
			wave.scrollFactor.set(0, 0);
			add(wave);
			waveLayers.push(wave);

			FlxTween.tween(wave, {x: -40}, 3 + i, {
				ease: FlxEase.sineInOut,
				type: PINGPONG
			});
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
		appendToHistory("You: " + message);
		inputField.text = "";

		ChatEngine.send(message, onReply, onError);
	}

	function onReply(reply:String):Void
	{
		appendToHistory("Shark: " + reply);
	}

	function onError(error:String):Void
	{
		appendToHistory("Error: " + error);
	}

	function appendToHistory(line:String):Void
	{
		conversation.push(line);
		historyText.text = conversation.join("\n");
	}
}
