package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.LimeShark;
import lime.manager.LimeManager;
import lime.ui.KeyCode;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.errors.Error;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.UncaughtErrorEvent;
import openfl.system.Capabilities;
import shark.active.system.Head;
import shark.audio.Audio;
import shark.backend.Paths;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;
import shark.menus.MainMenuState;
import shark.online.Online;
import shark.online.manager.Internet;
import shark.ui.debug.CrasherLog;
import shark.ui.debug.DebugDisplay;
import shark.ui.input.Cursor;
import shark.ui.security.Guard;

class Main extends Sprite
{
	public static var lastError:String = "";
	public static var isActive(default, null):Bool = true;
	public static var isSafeMode(default, null):Bool = false;
	public static var isNetworkConfigTrusted(default, null):Bool = true;
	public static var systemLanguage(default, null):String = "en";

	public static var instance(default, null):Main;

	static inline var SAVE_NAME:String = "shark_save";
	static inline var CRASH_LOOP_LIMIT:Int = 5;
	static inline var CRASH_LOOP_WINDOW_SECONDS:Float = 30;
	static inline var MAX_LOGGED_MESSAGE_LENGTH:Int = 500;

	var debugOverlay:DebugDisplay;
	var debugOverlayVisible:Bool = false;

	public function new()
	{
		super();

		MainCpp.nativeInit();

		instance = this;

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
	}

	function onAddedToStage(e:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		init();
	}

	function init():Void
	{
		setupStage();
		setupErrorHandling();
		setupLifecycle();
		setupInput();
		setupLocale();
		setupSave();
		setupNetworkConfig();
		setupSecurity();
		setupConnectivity();
		setupHeadSignals();

		MainCpp.recordCheckpoint("pre_lime_shark");
		LimeShark.initialize();
		MainCpp.recordCheckpoint("lime_shark_ready");

		setupGame();
		MainCpp.recordCheckpoint("flixel_game_ready");

		setupDebugOverlay();

		#if debug
		addChild(new FPS(10, 10, 0xFFFFFF));
		#end
	}

	function setupStage():Void
	{
		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;

		#if mobile
		stage.addEventListener(Event.RESIZE, onStageResize);
		#end
	}

	function setupErrorHandling():Void
	{
		#if (openfl >= "8.0.0")
		if (stage.loaderInfo.uncaughtErrorEvents != null)
			stage.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtError);
		#end
	}

	function setupLifecycle():Void
	{
		stage.addEventListener(Event.ACTIVATE, onActivate);
		stage.addEventListener(Event.DEACTIVATE, onDeactivate);

		#if sys
		stage.addEventListener(Event.EXITING, onExiting);
		#end
	}

	function setupInput():Void
	{
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	}

	function setupLocale():Void
	{
		var raw:String = Capabilities.language;
		systemLanguage = raw != null && raw.length >= 2 ? raw.substr(0, 2).toLowerCase() : "en";
	}

	function setupSave():Void
	{
		FlxG.save.bind(SAVE_NAME);

		if (FlxG.save.data.muted != null)
			Audio.setMuted(FlxG.save.data.muted);

		if (FlxG.save.data.musicVolume != null)
			Audio.musicVolume = FlxG.save.data.musicVolume;
	}

	public static var isNetworkConfigLoaded(default, null):Bool = false;

	function setupNetworkConfig():Void
	{
		var parsed:Dynamic = Paths.getJson("config");

		if (parsed == null)
		{
			logSecurityEvent("No app config found or failed to parse (assets/data/config.json)");
			return;
		}

		applyNetworkSection(parsed.network);
		applyChatSection(parsed.chat);
		applyApiSection(parsed.api);
		applyImageSection(parsed.image);
		applyAudioSection(parsed.audio);
		applySecuritySection(parsed.security);
		applyConnectivitySection(parsed.connectivity);
		applyAppSection(parsed.app);

		isNetworkConfigLoaded = true;
	}

	function applyNetworkSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.chatEndpoint != null)
			ChatEngine.endpoint = section.chatEndpoint;

		if (section.chatApiKey != null)
			ChatEngine.apiKey = section.chatApiKey;

		if (section.imageEndpoint != null)
			ImageCreator.endpoint = section.imageEndpoint;

		if (section.imageApiKey != null)
			ImageCreator.apiKey = section.imageApiKey;

		if (section.requireOnline != null)
		{
			ChatEngine.requireOnline = section.requireOnline;
			ImageCreator.requireOnline = section.requireOnline;
		}
	}

	function applyChatSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.systemPrompt != null)
			ChatEngine.systemPrompt = section.systemPrompt;

		if (section.maxHistory != null)
			ChatEngine.maxHistory = section.maxHistory;

		if (section.maxMessageLength != null)
			ChatEngine.maxMessageLength = section.maxMessageLength;

		if (section.minRequestInterval != null)
			ChatEngine.minRequestInterval = section.minRequestInterval;

		if (section.maxRetries != null)
			ChatEngine.maxRetries = section.maxRetries;
	}

	function applyApiSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.chatModel != null)
			ChatEngine.model = section.chatModel;

		if (section.chatTemperature != null)
			ChatEngine.temperature = section.chatTemperature;

		if (section.chatMaxTokens != null)
			ChatEngine.maxTokens = section.chatMaxTokens;

		if (section.imageModel != null)
			ImageCreator.model = section.imageModel;

		if (section.imageQuality != null)
			ImageCreator.quality = section.imageQuality;
	}

	function applyImageSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.maxPromptLength != null)
			ImageCreator.maxPromptLength = section.maxPromptLength;

		if (section.minRequestInterval != null)
			ImageCreator.minRequestInterval = section.minRequestInterval;

		if (section.maxRetries != null)
			ImageCreator.maxRetries = section.maxRetries;

		if (section.cacheEnabled != null)
			ImageCreator.cacheEnabled = section.cacheEnabled;

		if (section.autoSaveToStorage != null)
			ImageCreator.autoSaveToStorage = section.autoSaveToStorage;
	}

	function applyAudioSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.musicVolume != null && FlxG.save.data.musicVolume == null)
			Audio.musicVolume = section.musicVolume;

		if (section.soundVolume != null)
			Audio.soundVolume = section.soundVolume;

		if (section.startMuted != null && FlxG.save.data.muted == null)
			Audio.setMuted(section.startMuted);
	}

	function applySecuritySection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.maxInputLength != null)
			Guard.maxInputLength = section.maxInputLength;

		if (section.maxRequestsPerWindow != null)
			Guard.maxRequestsPerWindow = section.maxRequestsPerWindow;

		if (section.rateLimitWindowSeconds != null)
			Guard.rateLimitWindowSeconds = section.rateLimitWindowSeconds;
	}

	function applyConnectivitySection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.onlineCheckInterval != null)
			Online.onlineCheckInterval = section.onlineCheckInterval;

		if (section.offlineCheckIntervalBase != null)
			Online.offlineCheckIntervalBase = section.offlineCheckIntervalBase;

		if (section.checkTimeoutMs != null)
			Online.checkTimeoutMs = section.checkTimeoutMs;
	}

	function applyAppSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.buildVersion != null)
			LimeManager.buildVersion = section.buildVersion;
	}

	function setupSecurity():Void
	{
		isNetworkConfigTrusted = true;

		if (ChatEngine.endpoint != "" && !Guard.isValidUrl(ChatEngine.endpoint))
		{
			isNetworkConfigTrusted = false;
			ChatEngine.endpoint = "";
			logSecurityEvent("Blocked untrusted ChatEngine endpoint");
		}

		if (ImageCreator.endpoint != "" && !Guard.isValidUrl(ImageCreator.endpoint))
		{
			isNetworkConfigTrusted = false;
			ImageCreator.endpoint = "";
			logSecurityEvent("Blocked untrusted ImageCreator endpoint");
		}
	}

	function setupConnectivity():Void
	{
		Internet.initialize();
	}

	function setupHeadSignals():Void
	{
		Head.onFlaggedInput = function(input:String):Void
		{
			logSecurityEvent("Flagged input (possible prompt injection)");
		};

		Head.onRateLimited = function():Void
		{
			logSecurityEvent("Rate limit triggered");
		};
	}

	function setupGame():Void
	{
		var game = new FlxGame(0, 0, MainMenuState, 60, 60, true);
		addChild(game);

		FlxG.autoPause = true;

		Cursor.initialize();

		#if mobile
		FlxG.scaleMode = new flixel.system.scaleModes.RatioScaleMode();
		#end
	}

	function setupDebugOverlay():Void
	{
		debugOverlay = new DebugDisplay(10, 30);
		debugOverlayVisible = FlxG.save.data.showFpsCounter == true;
		debugOverlay.visible = debugOverlayVisible;

		if (FlxG.stage != null)
			FlxG.signals.postUpdate.add(updateDebugOverlay);
	}

	var lastDebugState:flixel.FlxState;

	function updateDebugOverlay():Void
	{
		if (!debugOverlayVisible || FlxG.state == null)
			return;

		if (FlxG.state != lastDebugState)
		{
			debugOverlay = new DebugDisplay(10, 30);
			debugOverlay.visible = debugOverlayVisible;
			FlxG.state.add(debugOverlay);
			lastDebugState = FlxG.state;
		}

		debugOverlay.extraTag = isSafeMode ? "SAFE MODE" : "";
	}

	public function toggleDebugOverlay():Bool
	{
		debugOverlayVisible = !debugOverlayVisible;
		debugOverlay.visible = debugOverlayVisible;

		FlxG.save.data.showFpsCounter = debugOverlayVisible;
		FlxG.save.flush();

		return debugOverlayVisible;
	}

	public function isDebugOverlayVisible():Bool
	{
		return debugOverlayVisible;
	}

	public static function toggleFpsCounter():Bool
	{
		return instance != null ? instance.toggleDebugOverlay() : false;
	}

	public static function isFpsCounterVisible():Bool
	{
		return instance != null ? instance.isDebugOverlayVisible() : false;
	}

	function onStageResize(e:Event):Void
	{
		if (FlxG.game != null)
		{
			FlxG.game.x = 0;
			FlxG.game.y = 0;
		}
	}

	function onActivate(e:Event):Void
	{
		isActive = true;
		Audio.resumeMusic();

		if (FlxG.sound != null)
			FlxG.sound.resume();
	}

	function onDeactivate(e:Event):Void
	{
		isActive = false;
		Audio.pauseMusic();

		if (FlxG.sound != null)
			FlxG.sound.pause();

		flushSave();
	}

	#if sys
	function onExiting(e:Event):Void
	{
		flushSave();
	}
	#end

	function flushSave():Void
	{
		FlxG.save.data.muted = Audio.isMuted;
		FlxG.save.data.musicVolume = Audio.musicVolume;
		FlxG.save.flush();
	}

	function onKeyDown(e:KeyboardEvent):Void
	{
		#if android
		if (e.keyCode == KeyCode.APP_CONTROL_BACK)
		{
			e.preventDefault();
			handleBackButton();
			return;
		}
		#end

		#if debug
		if (e.keyCode == lime.ui.KeyCode.F3)
			toggleDebugOverlay();
		#end
	}

	function handleBackButton():Void
	{
		if (FlxG.state == null)
			return;

		if (Std.isOfType(FlxG.state, MainMenuState))
			return;

		FlxG.switchState(new MainMenuState());
	}

	function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		e.preventDefault();

		var rawMessage:String = "Unknown error";

		if (Std.isOfType(e.error, Error))
			rawMessage = cast(e.error, Error).message;
		else if (Std.isOfType(e.error, String))
			rawMessage = cast(e.error, String);

		lastError = Guard.sanitizeInput(rawMessage);

		if (lastError.length > MAX_LOGGED_MESSAGE_LENGTH)
			lastError = lastError.substr(0, MAX_LOGGED_MESSAGE_LENGTH);

		CrasherLog.logError(lastError);

		if (CrasherLog.isCrashingRepeatedly(CRASH_LOOP_WINDOW_SECONDS, CRASH_LOOP_LIMIT) && !isSafeMode)
			enterSafeMode();
	}

	function enterSafeMode():Void
	{
		isSafeMode = true;

		Online.stop();
		LimeManager.disableRuntimeOptimization();
		Audio.stopMusic(0);

		CrasherLog.logSecurity("Entered safe mode after repeated crashes");

		if (FlxG.state != null && !Std.isOfType(FlxG.state, MainMenuState))
			FlxG.switchState(new MainMenuState());
	}

	function logSecurityEvent(message:String):Void
	{
		CrasherLog.logSecurity(message);
	}
}
