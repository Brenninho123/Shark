package shark.menus;

import flixel.FlxState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.display.BitmapData;
import haxe.ui.Toolkit;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.components.Button as UIButton;
import haxe.ui.components.TextField as UITextField;
import flixel.FlixelShark;
import git.graphic.GraphicGit;
import git.performance.Boost;
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
import shark.mobile.backend.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.online.Online;
import shark.online.manager.Internet;
import shark.mobile.ui.AndroidKeyboard;
import shark.shaders.WaterShader;
import shark.ui.debug.menu.DebugMenuState;
import lime.manager.LimeManager;

import Main;
import MainCpp;

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

	static var toolkitInitialized:Bool = false;

	var inputField:UITextField;
	var historyText:FlxText;
	var titleText:FlxText;
	var sendButton:UIButton;
	var muteButton:FlxButton;
	var newChatButton:FlxButton;
	var optionsButton:FlxButton;
	var boostButton:FlxButton;

	#if SHARK_DEV_MODE
	var debugButton:UIButton;
	#end

	var inputFieldBaseY:Float;
	var sendButtonBaseY:Float;
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
	var uiComponents:Array<Component> = [];

	var conversation:Array<String> = [];
	var isMobile:Bool;
	var thinkingElapsed:Float = 0;
	var latencyRefreshTimer:Float = 0;
	var historyPad:Int;

	static inline var LATENCY_REFRESH_INTERVAL:Float = 15;

	override public function create():Void
	{
		super.create();

		isMobile = FlxG.onMobile;
		bgColor = COLOR_ABYSS;

		ensureToolkit();

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

		historyPad = isMobile ? 30 : 20;
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

		createChatControls();

		var topBarSize:Int = Resolution4K.scaledInt(isMobile ? 44 : 32);

		muteButton = FlixelShark.createIconButton(this, 20, 12, topBarSize, topBarSize, COLOR_MID, onMutePressed);
		muteIcon = FlixelShark.addSpeakerIcon(this, muteButton, Audio.isMuted, COLOR_FOAM, COLOR_DANGER, COLOR_ACCENT);

		newChatButton = FlixelShark.createIconButton(this, muteButton.x + muteButton.width + 10, 12, topBarSize, topBarSize, COLOR_MID, onNewChatPressed);
		FlixelShark.addPlusIcon(this, newChatButton, COLOR_FOAM);

		optionsButton = FlixelShark.createIconButton(this, newChatButton.x + newChatButton.width + 10, 12, topBarSize, topBarSize, COLOR_MID,
			onOptionsPressed);
		FlixelShark.addMenuIcon(this, optionsButton, COLOR_FOAM);

		Boost.initialize();

		boostButton = FlixelShark.createIconButton(this, optionsButton.x + optionsButton.width + 10, 12, topBarSize, topBarSize,
			Boost.isBoostActive ? COLOR_ONLINE : COLOR_MID, onBoostPressed);
		FlixelShark.addBoltIcon(this, boostButton, COLOR_FOAM);

		#if SHARK_DEV_MODE
		createDebugButton(boostButton.x + boostButton.width + 10, 12, topBarSize);
		#end

		Internet.addListener(onOnlineStatusChanged);
		AndroidKeyboard.initialize();
		AndroidKeyboard.onKeyboardVisibilityChanged = onSoftKeyboardVisibilityChanged;
		onOnlineStatusChanged(Internet.isConnected);

		Head.onThinkingChanged = onThinkingChanged;
		Head.onNavigate = onNavigateRequest;

		restoreHistory();

		if (conversation.length == 0)
			appendToHistory(Language.get("app.name") + ": " + Head.getWelcomeMessage());

		if (Paths.exists(Paths.music("ocean_ambient")))
			Audio.playMusic("ocean_ambient");

		createVersionTag();
		createDevWatermark();
		animateTitle();
	}

	static function ensureToolkit():Void
	{
		if (toolkitInitialized)
			return;

		toolkitInitialized = true;
		Toolkit.init();
	}

	function addUI<T:Component>(component:T):T
	{
		Screen.instance.addComponent(component);
		uiComponents.push(component);
		return component;
	}

	function createChatControls():Void
	{
		var inputHeight:Int = Resolution4K.scaledInt(isMobile ? 60 : 40);
		var sendWidth:Int = Resolution4K.scaledInt(isMobile ? 90 : 70);
		var inputWidth:Int = FlxG.width - historyPad * 2 - sendWidth - 10;
		var rowTop:Float = FlxG.height - inputHeight - 20;

		inputField = addUI(new UITextField());
		inputField.left = historyPad;
		inputField.top = rowTop;
		inputField.width = inputWidth;
		inputField.height = inputHeight;
		inputField.text = "";

		sendButton = addUI(new UIButton());
		sendButton.text = Language.get("chat.send");
		sendButton.left = historyPad + inputWidth + 10;
		sendButton.top = rowTop;
		sendButton.width = sendWidth;
		sendButton.height = inputHeight;
		sendButton.onClick = function(e:Dynamic):Void
		{
			Vibration.trigger(HapticStyle.MEDIUM);
			onSendPressed();
		};

		inputFieldBaseY = inputField.top;
		sendButtonBaseY = sendButton.top;
	}

	#if SHARK_DEV_MODE
	function createDebugButton(x:Float, y:Float, size:Int):Void
	{
		debugButton = addUI(new UIButton());
		debugButton.text = "Debug";
		debugButton.left = x;
		debugButton.top = y;
		debugButton.width = Resolution4K.scaledInt(76);
		debugButton.height = size;
		debugButton.onClick = function(e:Dynamic):Void
		{
			Vibration.trigger(HapticStyle.SELECTION);
			FlixelShark.switchState(new DebugMenuState(), true, 0.4, COLOR_ABYSS);
		};
	}
	#end

	function refreshMuteIcon(muted:Bool):Void
	{
		if (muteIcon != null)
			remove(muteIcon, true);

		muteIcon = FlixelShark.addSpeakerIcon(this, muteButton, muted, COLOR_FOAM, COLOR_DANGER, COLOR_ACCENT);
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

	function createDevWatermark():Void
	{
		#if SHARK_DEV_MODE
		var label:String = 'Dev Build (Commit: ${MainCpp.BUILD_COMMIT})';

		var watermark = FlixelShark.makeShadowText(0, 8, FlxG.width - 10, label, isMobile ? 14 : 11, 0xFFF87171, COLOR_ABYSS, RIGHT);
		watermark.alpha = 0.8;
		add(watermark);

		FlxTween.tween(watermark, {alpha: 0.4}, 1.2, {
			ease: FlxEase.sineInOut,
			type: PINGPONG
		});
		#end
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
		lightRays = FlixelShark.createLightRays(this, rayCount, COLOR_FOAM);
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
		kelpBlades = FlixelShark.createKelpField(this, bladeCount, COLOR_KELP);
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
		FlixelShark.updateKelpField(kelpBlades, elapsed);

		if (waterShader != null)
			waterShader.update(elapsed);

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
			sendMessage(inputField.text);
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

		sendButton.disabled = true;

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
		sendButton.disabled = !Internet.isConnected;
		body.reactToReplyReceived();
	}

	function onError(error:String):Void
	{
		appendToHistory("Error: " + error);
		sendButton.disabled = !Internet.isConnected;
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

	function onBoostPressed():Void
	{
		var active:Bool = Boost.toggleBoost();

		boostButton.color = active ? COLOR_ONLINE : COLOR_MID;
		pulseButton(boostButton);
	}

	function onSoftKeyboardVisibilityChanged(visible:Bool):Void
	{
		if (!isMobile)
			return;

		var estimatedKeyboardHeight:Float = FlxG.height * 0.35;
		var targetInputTop:Float = visible ? inputFieldBaseY - estimatedKeyboardHeight : inputFieldBaseY;
		var targetSendTop:Float = visible ? sendButtonBaseY - estimatedKeyboardHeight : sendButtonBaseY;

		FlxTween.tween(inputField, {top: targetInputTop}, 0.2, {ease: FlxEase.quadOut});
		FlxTween.tween(sendButton, {top: targetSendTop}, 0.2, {ease: FlxEase.quadOut});
	}

	function onOnlineStatusChanged(online:Bool):Void
	{
		statusDot.color = online ? COLOR_ONLINE : COLOR_OFFLINE;
		statusText.color = online ? COLOR_ONLINE : COLOR_OFFLINE;
		statusText.text = Internet.getStatusLabel();
		sendButton.disabled = !(online && !Head.isThinking);

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

	override public function destroy():Void
	{
		for (component in uiComponents)
			Screen.instance.removeComponent(component);

		uiComponents = [];

		super.destroy();
	}
}
