package shark.menus;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxInputText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.display.BitmapData;
import flixel.FlixelShark;
import git.graphic.GraphicGit;
import git.resolution.Resolution4K;
import shark.active.GameState;
import shark.active.system.Body;
import shark.active.system.BodyState;
import shark.active.system.Head;
import shark.audio.Audio;
import shark.backend.Language;
import shark.backend.Paths;
import shark.functions.ChatEngine;
import shark.menus.options.OptionsState;
import shark.online.Online;
import shark.online.manager.Internet;
import shark.shaders.WaterShader;
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
	static inline var COLOR_DANGER:FlxColor = 0xFFF87171;

	var inputField:FlxInputText;
	var historyText:FlxText;
	var titleText:FlxText;
	var sendButton:FlxButton;
	var muteButton:FlxButton;
	var newChatButton:FlxButton;
	var optionsButton:FlxButton;
	var muteIcon:FlxSpriteGroup;
	var statusDot:FlxSprite;
	var statusText:FlxText;
	var thinkingText:FlxText;
	var body:Body;
	var waterShader:WaterShader;

	var lightRays:Array<FlxSprite> = [];
	var kelpBlades:Array<{sprite:FlxSprite, offset:Float, speed:Float}> = [];
	var bubbles:Array<FlxSprite> = [];
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

		FlixelShark.createDepthGradient(this, [COLOR_ABYSS, COLOR_DEEP, COLOR_MID]);
		createLightRays();
		createWaveBackground();
		createKelp();
		bubbles = FlixelShark.createBubbleField(this, isMobile ? 8 : 14, COLOR_ACCENT);

		titleText = FlixelShark.makeShadowText(0, isMobile ? 30 : 20, FlxG.width, Language.get("menu.title"), isMobile ? 40 : 32, COLOR_FOAM, COLOR_ACCENT, CENTER);
		add(titleText);

		body = new Body(FlxG.width / 2 - 35, titleText.y + titleText.height + 8, 70);
		add(body);

		createStatusIndicator();

		thinkingText = FlixelShark.makeText(0, titleText.y + titleText.height + 4, FlxG.width, "", isMobile ? 16 : 14, COLOR_ACCENT, CENTER);
		add(thinkingText);

		var historyPad:Int = isMobile ? 30 : 20;
		var historyTop:Int = Std.int(body.y + 90);
		var historyHeight:Int = FlxG.height - historyTop - (isMobile ? 100 : 70);

		var historyBackdrop = GraphicGit.makeRoundedRectSprite(historyPad - 10, historyTop, FlxG.width - (historyPad - 10) * 2, historyHeight, COLOR_MID, 14,
			0.35);
		add(historyBackdrop);

		var historyBorder = new FlxSprite(historyPad - 10, historyTop);
		historyBorder.pixels = GraphicGit.createRoundedRectBorder(Std.int(FlxG.width - (historyPad - 10) * 2), historyHeight, COLOR_ACCENT, 14, 2, 0.6);
		add(historyBorder);

		historyText = FlixelShark.makeText(historyPad, historyTop + 10, FlxG.width - historyPad * 2, "", isMobile ? 20 : 16, COLOR_FOAM, LEFT);
		add(historyText);

		var inputHeight:Int = Resolution4K.scaledInt(isMobile ? 60 : 40);
		var inputWidth:Int = isMobile ? FlxG.width - Resolution4K.scaledInt(160) : FlxG.width - Resolution4K.scaledInt(140);

		inputField = new FlxInputText(historyPad, FlxG.height - inputHeight - 20, inputWidth, "", Resolution4K.scaledInt(isMobile ? 20 : 16), COLOR_FOAM);
		inputField.backgroundColor = COLOR_MID;
		inputField.borderColor = COLOR_ACCENT;
		inputField.borderStyle = OUTLINE;
		inputField.borderSize = 2;
		add(inputField);

		sendButton = createIconButton(historyPad + inputWidth + 10, FlxG.height - inputHeight - 20, inputHeight, inputHeight, COLOR_WAVE, onSendPressed);
		addSendIcon(sendButton);

		var topBarSize:Int = Resolution4K.scaledInt(isMobile ? 44 : 32);

		muteButton = createIconButton(20, 12, topBarSize, topBarSize, COLOR_MID, onMutePressed);
		muteIcon = addMuteIcon(muteButton, Audio.isMuted);

		newChatButton = createIconButton(muteButton.x + muteButton.width + 10, 12, topBarSize, topBarSize, COLOR_MID, onNewChatPressed);
		addPlusIcon(newChatButton);

		optionsButton = createIconButton(newChatButton.x + newChatButton.width + 10, 12, topBarSize, topBarSize, COLOR_MID, onOptionsPressed);
		addMenuIcon(optionsButton);

		Internet.addListener(onOnlineStatusChanged);
		onOnlineStatusChanged(Internet.isConnected);

		Head.onThinkingChanged = onThinkingChanged;
		Head.onNavigate = onNavigateRequest;

		restoreHistory();

		if (conversation.length == 0)
			appendToHistory(Language.get("app.name") + ": " + Head.getWelcomeMessage());

		if (Paths.exists(Paths.music("ocean_ambient")))
			Audio.playMusic("ocean_ambient");

		createVersionTag();
		animateTitle();
	}

	function createIconButton(x:Float, y:Float, width:Int, height:Int, color:FlxColor, onClick:Void->Void):FlxButton
	{
		var button = new FlxButton(x, y, "", onClick);
		button.setSize(width, height);
		button.color = color;
		button.label.text = "";
		add(button);
		return button;
	}

	function addSendIcon(button:FlxButton):Void
	{
		var cx:Float = button.x + button.width / 2;
		var cy:Float = button.y + button.height / 2;
		var barLength:Float = button.height * 0.32;

		var top = FlixelShark.makeSprite(0, 0, Std.int(barLength), 4, COLOR_FOAM);
		top.angle = -45;
		top.setPosition(cx - barLength * 0.55, cy - barLength * 0.5);
		add(top);

		var bottom = FlixelShark.makeSprite(0, 0, Std.int(barLength), 4, COLOR_FOAM);
		bottom.angle = 45;
		bottom.setPosition(cx - barLength * 0.55, cy + barLength * 0.15);
		add(bottom);
	}

	function addPlusIcon(button:FlxButton):Void
	{
		var cx:Float = button.x + button.width / 2;
		var cy:Float = button.y + button.height / 2;
		var length:Float = button.height * 0.5;

		var vertical = FlixelShark.makeSprite(cx - 2, cy - length / 2, 4, Std.int(length), COLOR_FOAM);
		add(vertical);

		var horizontal = FlixelShark.makeSprite(cx - length / 2, cy - 2, Std.int(length), 4, COLOR_FOAM);
		add(horizontal);
	}

	function addMenuIcon(button:FlxButton):Void
	{
		var cx:Float = button.x + button.width / 2;
		var cy:Float = button.y + button.height / 2;
		var barWidth:Float = button.width * 0.5;

		for (i in 0...3)
		{
			var bar = FlixelShark.makeSprite(cx - barWidth / 2, cy - 8 + i * 8, Std.int(barWidth), 3, COLOR_FOAM);
			add(bar);
		}
	}

	function addMuteIcon(button:FlxButton, muted:Bool):FlxSpriteGroup
	{
		var group = new FlxSpriteGroup(button.x, button.y);

		var cx:Float = button.width / 2;
		var cy:Float = button.height / 2;

		var speakerBody = FlixelShark.makeSprite(cx - 9, cy - 5, 6, 10, COLOR_FOAM);
		group.add(speakerBody);

		var cone = FlixelShark.makeSprite(cx - 4, cy - 8, 6, 16, COLOR_FOAM);
		cone.angle = 25;
		group.add(cone);

		if (muted)
		{
			var slash = FlixelShark.makeSprite(cx - 1, cy - 9, 3, 18, COLOR_DANGER);
			slash.angle = 45;
			group.add(slash);
		}
		else
		{
			for (i in 0...2)
			{
				var wave = FlixelShark.makeSprite(cx + 4 + i * 5, cy - 4 - i * 1, 2, Std.int(8 + i * 6), COLOR_ACCENT, 0.8);
				group.add(wave);
			}
		}

		add(group);
		return group;
	}

	function refreshMuteIcon(muted:Bool):Void
	{
		if (muteIcon != null)
			remove(muteIcon, true);

		muteIcon = addMuteIcon(muteButton, muted);
	}

	function onNavigateRequest(destination:String):Void
	{
		if (destination == "games")
			goToGameState();
	}

	function createVersionTag():Void
	{
		var versionText = FlixelShark.makeText(0, FlxG.height - (isMobile ? 18 : 14), FlxG.width - 10, 'v${LimeManager.buildVersion}', 10, COLOR_ACCENT, RIGHT);
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

	function createLightRays():Void
	{
		var rayCount:Int = isMobile ? 3 : 5;

		for (i in 0...rayCount)
		{
			var ray = FlixelShark.makeStaticSprite(Std.random(FlxG.width), -100, 30 + Std.random(20), FlxG.height + 200, COLOR_FOAM, 0.03 + Std.random(4) / 100);
			ray.angle = -15;
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

		waterShader = new WaterShader();

		for (i in 0...colors.length)
		{
			var wave = FlixelShark.makeStaticSprite(0, FlxG.height - 40 - (i * 30), FlxG.width, 60, colors[i], 0.22);
			wave.shader = waterShader;
			add(wave);

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
			var blade = FlixelShark.makeSprite((i / bladeCount) * FlxG.width + Std.random(20), FlxG.height - height, 8, height, COLOR_KELP, 0.5);
			blade.origin.set(4, height);
			add(blade);

			kelpBlades.push({sprite: blade, offset: Std.random(6283) / 1000, speed: 1 + Std.random(50) / 100});
		}
	}

	function createStatusIndicator():Void
	{
		statusDot = FlixelShark.makeSprite(FlxG.width - 26, 14, 12, 12, COLOR_OFFLINE);
		add(statusDot);

		statusText = FlixelShark.makeText(0, 14, FlxG.width - 44, "offline", 14, COLOR_OFFLINE, RIGHT);
		add(statusText);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		FlixelShark.updateBubbleField(bubbles, elapsed);

		if (waterShader != null)
			waterShader.update(elapsed);

		for (blade in kelpBlades)
		{
			blade.offset += elapsed * blade.speed;
			blade.sprite.angle = Math.sin(blade.offset) * 6;
		}

		if (Head.isThinking)
		{
			thinkingElapsed += elapsed;
			var dots:Int = Std.int(thinkingElapsed * 2) % 4;
			thinkingText.text = Language.get("menu.thinking") + StringTools.rpad("", ".", dots);
		}

		if (!isMobile && FlxG.keys.justPressed.ENTER && inputField.text.length > 0)
			sendMessage(inputField.text);

		if (Internet.isConnected)
		{
			latencyRefreshTimer += elapsed;

			if (latencyRefreshTimer >= LATENCY_REFRESH_INTERVAL)
			{
				latencyRefreshTimer = 0;
				refreshStatusText();
			}
		}
	}

	function refreshStatusText():Void
	{
		Internet.measureLatency(function(_):Void
		{
			statusText.text = '${Internet.getStatusLabel()} (${Online.getStabilityLabel()})';
		});
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
		FlixelShark.pulse(button, 0.08, 0.15);
	}

	function sendMessage(message:String):Void
	{
		appendToHistory(Language.get("chat.you") + ": " + message);
		inputField.text = "";
		body.reactToMessageSent();

		if (!isChatConfigured() && !isLocalCommand(message))
		{
			var reason:String = Main.isNetworkConfigTrusted
				? Language.get("chat.notConfigured")
				: Language.get("chat.blockedEndpoint");

			appendToHistory(Language.get("app.name") + ": " + reason);
			body.reactToError();
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
		FlixelShark.switchState(new GameState(), true, 0.4, COLOR_ABYSS);
	}

	function onReply(reply:String):Void
	{
		appendToHistory(Language.get("app.name") + ": " + reply);
		Audio.play("message_receive");
		sendButton.alive = Internet.isConnected;
		body.reactToReplyReceived();
	}

	function onError(error:String):Void
	{
		appendToHistory("Error: " + error);
		sendButton.alive = Internet.isConnected;
		body.reactToError();
	}

	function onImageGenerated(bitmap:BitmapData):Void
	{
		var sprite = new FlxSprite(FlxG.width - bitmap.width - 20, 110);
		sprite.pixels = bitmap;
		add(sprite);
		imageSprites.push(sprite);

		appendToHistory(Language.get("app.name") + ": " + Language.get("chat.imageGenerated"));
		Audio.play("message_receive");
		body.reactToReplyReceived();
	}

	function onImageError(error:String):Void
	{
		appendToHistory("Error generating image: " + error);
		body.reactToError();
	}

	function onMutePressed():Void
	{
		var muted:Bool = Audio.toggleMute();
		refreshMuteIcon(muted);
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

		appendToHistory(Language.get("app.name") + ": " + Head.getWelcomeMessage());
		pulseButton(newChatButton);
	}

	function onOptionsPressed():Void
	{
		FlixelShark.switchState(new OptionsState(), true, 0.4, COLOR_ABYSS);
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
			refreshStatusText();
		}
	}

	function onThinkingChanged(thinking:Bool):Void
	{
		thinkingElapsed = 0;
		body.setState(thinking ? THINKING : IDLE);

		if (!thinking)
			thinkingText.text = "";
	}

	function appendToHistory(line:String):Void
	{
		conversation.push(line);
		historyText.text = conversation.join("\n");
	}
}
