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
import shark.audio.Audio;
import shark.backend.Paths;
import shark.functions.ChatEngine;
import shark.online.manager.Internet;
import lime.manager.LimeManager;

import Main;

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
	var muteButton:FlxButton;
	var newChatButton:FlxButton;
	var statusDot:FlxSprite;
	var statusText:FlxText;
	var thinkingText:FlxText;

	var waveLayers:Array<FlxSprite> = [];
	var bubbles:Array<FlxSprite> = [];
	var lightRays:Array<FlxSprite> = [];
	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];
	var imageSprites:Array<FlxSprite> = [];

	var conversation:Array<String> = [];
	var isMobile:Bool;
	var thinkingElapsed:Float = 0;
	var latencyRefreshTimer:Float = 0;

	static inline var LATENCY_REFRESH_INTERVAL:Float = 15;

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

		muteButton = new FlxButton(20, 12, Audio.isMuted ? "Unmute" : "Mute", onMutePressed);
		muteButton.setSize(isMobile ? 90 : 70, isMobile ? 40 : 26);
		muteButton.color = COLOR_MID;
		muteButton.label.color = COLOR_FOAM;
		add(muteButton);

		newChatButton = new FlxButton(muteButton.x + muteButton.width + 10, 12, "New Chat", onNewChatPressed);
		newChatButton.setSize(isMobile ? 120 : 90, isMobile ? 40 : 26);
		newChatButton.color = COLOR_MID;
		newChatButton.label.color = COLOR_FOAM;
		add(newChatButton);

		Internet.addListener(onOnlineStatusChanged);
		onOnlineStatusChanged(Internet.isConnected);

		Head.onThinkingChanged = onThinkingChanged;
		Head.onNavigate = onNavigateRequest;

		restoreHistory();

		if (conversation.length == 0)
			appendToHistory("Shark: " + Head.getWelcomeMessage());

		if (Paths.exists(Paths.music("ocean_ambient")))
			Audio.playMusic("ocean_ambient");

		createVersionTag();
		animateTitle();
	}

	function onNavigateRequest(destination:String):Void
	{
		if (destination == "games")
			goToGameState();
	}

	function createVersionTag():Void
	{
		var versionText = new FlxText(0, FlxG.height - (isMobile ? 18 : 14), FlxG.width - 10, 'v${LimeManager.buildVersion}');
		versionText.setFormat(null, 10, COLOR_ACCENT, RIGHT);
		versionText.alpha = 0.5;
		add(versionText);
	}

	function animateTitle():Void
	{
		FlxTween.tween(titleText, {alpha: 0.75}, 1.6, {
			ease: FlxEase.sineInOut,
			type: PINGPONG
		});
	}

	function restoreHistory():Void
	{
		ChatEngine.loadHistory();

		for (entry in ChatEngine.getHistory())
		{
			var speaker:String = entry.role == "user" ? "You" : "Shark";
			conversation.push('$speaker: ${entry.content}');
		}

		historyText.text = conversation.join("\n");
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

		if (Internet.isConnected)
		{
			latencyRefreshTimer += elapsed;

			if (latencyRefreshTimer >= LATENCY_REFRESH_INTERVAL)
			{
				latencyRefreshTimer = 0;
				Internet.measureLatency(function(_):Void
				{
					statusText.text = Internet.getStatusLabel();
				});
			}
		}
	}

	function onSendPressed():Void
	{
		if (inputField.text.length > 0)
		{
			sendMessage(inputField.text);
			pulseButton(sendButton);
		}
	}

	function pulseButton(button:FlxButton):Void
	{
		button.scale.set(1.08, 1.08);
		FlxTween.tween(button.scale, {x: 1, y: 1}, 0.15, {ease: FlxEase.quadOut});
	}

	function sendMessage(message:String):Void
	{
		appendToHistory("You: " + message);
		inputField.text = "";

		if (!isChatConfigured() && !isLocalCommand(message))
		{
			var reason:String = Main.isNetworkConfigTrusted
				? "I'm not connected to an AI backend yet. Set ChatEngine.endpoint (and apiKey, if needed) before I can reply."
				: "My backend endpoint was blocked for security reasons (invalid URL). Check assets/data/config.json.";

			appendToHistory("Shark: " + reason);
			return;
		}

		Audio.play("message_send");

		sendButton.alive = false;

		Head.think(message, onReply, onError, onImageGenerated, onImageError);
	}

	function isLocalCommand(message:String):Bool
	{
		var trimmed:String = StringTools.trim(message).toLowerCase();
		var firstChar:String = trimmed.length > 0 ? trimmed.charAt(0) : "";

		return firstChar == "/" || firstChar == "!";
	}

	function isChatConfigured():Bool
	{
		return StringTools.trim(ChatEngine.endpoint).length > 0;
	}

	function goToGameState():Void
	{
		FlxG.switchState(new GameState());
	}

	function onReply(reply:String):Void
	{
		appendToHistory("Shark: " + reply);
		Audio.play("message_receive");
		sendButton.alive = Internet.isConnected;
	}

	function onError(error:String):Void
	{
		appendToHistory("Error: " + error);
		sendButton.alive = Internet.isConnected;
	}

	function onImageGenerated(bitmap:BitmapData):Void
	{
		var sprite = new FlxSprite(FlxG.width - bitmap.width - 20, 110);
		sprite.pixels = bitmap;
		add(sprite);
		imageSprites.push(sprite);

		appendToHistory("Shark: [image generated]");
		Audio.play("message_receive");
	}

	function onImageError(error:String):Void
	{
		appendToHistory("Error generating image: " + error);
	}

	function onMutePressed():Void
	{
		var muted:Bool = Audio.toggleMute();
		muteButton.text = muted ? "Unmute" : "Mute";
		pulseButton(muteButton);
	}

	function onNewChatPressed():Void
	{
		Head.reset();

		conversation = [];
		historyText.text = "";

		for (sprite in imageSprites)
			remove(sprite, true);

		imageSprites = [];

		appendToHistory("Shark: " + Head.getWelcomeMessage());
		pulseButton(newChatButton);
	}

	function onOnlineStatusChanged(online:Bool):Void
	{
		statusDot.color = online ? COLOR_ONLINE : COLOR_OFFLINE;
		statusText.color = online ? COLOR_ONLINE : COLOR_OFFLINE;
		statusText.text = Internet.getStatusLabel();
		sendButton.alive = online && !Head.isThinking;

		if (online)
		{
			latencyRefreshTimer = 0;
			Internet.measureLatency(function(_):Void
			{
				statusText.text = Internet.getStatusLabel();
			});
		}
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
