package;

import flixel.FlxG;
import flixel.FlxGame;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Http;
import haxe.Json;
import haxe.Timer;
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
import shark.backend.ClientPrefs;
import shark.backend.Language;
import shark.backend.Paths;
import shark.data.DataFile;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;
import shark.menus.MainMenuState;
import shark.mobile.backend.Vibration.HapticStyle;
import shark.mobile.backend.Vibration;
import shark.mobile.StorageUtil;
import shark.online.Online;
import shark.online.User;
import shark.online.manager.Internet;
import shark.ui.debug.CrasherLog.CrashEntry;
import shark.ui.debug.CrasherLog;
import shark.ui.debug.DebugDisplay;
import shark.ui.discord.Discord;
import shark.ui.input.Cursor;
import shark.ui.window.WindowTheme;
import shark.ui.security.Guard;
import shark.server.Servers;
import git.resolution.Resolution4K;
import shark.backend.Mods;
import shark.mobile.utils.TouchUtil;
import shark.modding.Module;
import shark.modding.ModuleHandler;
import shark.api.google.GoogleClient;
import shark.api.newgrounds.NewClient;
import shark.world.Country;
import shark.Native;

typedef SettingsData = {
	hasCompletedFirstRun:Bool,
	muted:Bool,
	musicVolume:Float,
	soundVolume:Float,
	showFpsCounter:Bool,
	vibrationEnabled:Bool,
	vibrationIntensity:Float,
	reducedMotion:Bool,
	devModeEnabled:Bool,
	languageOverride:String,
	activeServerProfileId:String,
	customServerLabel:String,
	customServerChatEndpoint:String,
	customServerImageEndpoint:String,
	customServerApiKey:String,
	hasRequestedExternalStoragePermission:Bool
}

class Main extends Sprite
{
	public static var lastError:String = "";
	public static var isActive(default, null):Bool = true;
	public static var isSafeMode(default, null):Bool = false;
	public static var isNetworkConfigTrusted(default, null):Bool = true;

	public static function setNetworkTrusted(value:Bool):Void
	{
		isNetworkConfigTrusted = value;
	}
	public static var systemLanguage(default, null):String = "en";

	public static var instance(default, null):Main;
	public static var settings(default, null):DataFile<SettingsData>;

	static inline var SAVE_NAME:String = "shark_save";
	static inline var CRASH_LOOP_LIMIT:Int = 5;
	static inline var CRASH_LOOP_WINDOW_SECONDS:Float = 30;
	static inline var MAX_LOGGED_MESSAGE_LENGTH:Int = 500;

	static var wasFirstLaunch:Bool = false;
	static var bootPhases:Array<{phase:String, ms:Float}> = [];
	static var bootStartTime:Float = -1;

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
		recordBootPhase("init_start");

		setupStage();
		setupErrorHandling();
		setupLifecycle();
		setupInput();
		setupLocale();
		setupCrashReporting();
		setupSettings();
		requestAndroidPermissionsIfNeeded();
		recordBootPhase("settings_ready");

		ClientPrefs.initialize();
		Language.initialize();
		Audio.initialize();
		Resolution4K.initialize();
		User.initialize();
		recordBootPhase("core_systems_ready");

		setupNetworkConfig();
		setupSecurity();
		Servers.setup();
		setupConnectivity();
		setupHeadSignals();
		recordBootPhase("network_config_ready");

		MainCpp.recordCheckpoint("pre_lime_shark");
		LimeShark.initialize();
		MainCpp.recordCheckpoint("lime_shark_ready");

		ImageCreator.initialize();

		#if sys
		try
		{
			extractBundledMods();
			ModuleHandler.initialize();
			Mods.initialize();
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Mod system failed to initialize, continuing without mods: ${Std.string(e)}');
		}
		#end

		recordBootPhase("mods_ready");

		setupGame();
		setupStateTracking();
		MainCpp.recordCheckpoint("flixel_game_ready");

		setupTouch();

		#if sys
		try
		{
			setupMods();
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Mod update loop failed to start: ${Std.string(e)}');
		}
		#end

		setupDiscord();
		setupPlatforms();
		setupDebugOverlay();

		#if debug
		addChild(new FPS(10, 10, 0xFFFFFF));
		#end

		recordBootPhase("init_complete");
		fireReady();
	}

	static function buildDefaultSettings():SettingsData
	{
		return {
			hasCompletedFirstRun: false,
			muted: false,
			musicVolume: 0.5,
			soundVolume: 0.7,
			showFpsCounter: false,
			vibrationEnabled: true,
			vibrationIntensity: 1,
			reducedMotion: false,
			devModeEnabled: false,
			languageOverride: "",
			activeServerProfileId: "official",
			customServerLabel: "",
			customServerChatEndpoint: "",
			customServerImageEndpoint: "",
			customServerApiKey: "",
			hasRequestedExternalStoragePermission: false
		};
	}

	function setupSettings():Void
	{
		settings = new DataFile<SettingsData>("settings", buildDefaultSettings());
		settings.validator = validateSettingsData;

		settings.onCorruptionRecovered = function(reason:String):Void
		{
			CrasherLog.logWarning('Settings file recovered: $reason', "settings");
		};

		settings.load();
		wasFirstLaunch = !settings.data.hasCompletedFirstRun;

		Audio.setMuted(settings.data.muted);
		Audio.musicVolume = settings.data.musicVolume;
		Audio.soundVolume = settings.data.soundVolume;

		Vibration.setEnabled(settings.data.vibrationEnabled);
		Vibration.setGlobalIntensity(settings.data.vibrationIntensity);
		Vibration.setReducedMotionProvider(isReducedMotionEnabled);

		debugOverlayVisible = settings.data.showFpsCounter;
	}

	public static var onExternalStoragePermissionChanged:Bool->Void;
	static var lastKnownExternalStoragePermission:Bool = false;

	static function notifyExternalStoragePermission(granted:Bool):Void
	{
		if (lastKnownExternalStoragePermission == granted)
			return;

		lastKnownExternalStoragePermission = granted;

		if (onExternalStoragePermissionChanged != null)
			onExternalStoragePermissionChanged(granted);
	}

	function requestAndroidPermissionsIfNeeded():Void
	{
		#if android
		if (settings.data.hasRequestedExternalStoragePermission)
			return;

		StorageUtil.requestExternalStoragePermission(function(granted:Bool):Void
		{
			settings.update(function(d:SettingsData):Void d.hasRequestedExternalStoragePermission = true);

			CrasherLog.addBreadcrumb(granted ? "External storage permission granted" : "External storage permission denied", "storage");

			notifyExternalStoragePermission(granted);
		});
		#end
	}

	public static function hasExternalStoragePermission():Bool
	{
		#if android
		return StorageUtil.hasExternalStoragePermission();
		#else
		return false;
		#end
	}

	public static function requestExternalStoragePermission():Void
	{
		#if android
		StorageUtil.requestExternalStoragePermission(function(granted:Bool):Void
		{
			if (settings != null)
				settings.update(function(d:SettingsData):Void d.hasRequestedExternalStoragePermission = true);

			CrasherLog.addBreadcrumb(granted ? "External storage permission granted" : "External storage permission denied", "storage");

			notifyExternalStoragePermission(granted);
		});
		#end
	}

	static function isReducedMotionEnabled():Bool
	{
		return settings != null && settings.data.reducedMotion;
	}

	static function validateSettingsData(data:SettingsData):Bool
	{
		return data.musicVolume >= 0 && data.musicVolume <= 1
			&& data.soundVolume >= 0 && data.soundVolume <= 1
			&& data.vibrationIntensity >= 0 && data.vibrationIntensity <= 1;
	}

	function setupCrashReporting():Void
	{
		CrasherLog.repeatedCrashWindowSeconds = CRASH_LOOP_WINDOW_SECONDS;
		CrasherLog.repeatedCrashThreshold = CRASH_LOOP_LIMIT;
		CrasherLog.minLogSeverity = isDevModeActive() ? "trace" : "warning";
		CrasherLog.setContext("language", systemLanguage);

		CrasherLog.onRepeatedCrash = function(category:String, count:Int):Void
		{
			if (!isSafeMode)
				enterSafeMode();
		};

		CrasherLog.remoteReporter = reportCrashRemotely;
	}

	public static function isDevModeEnabled():Bool
	{
		return settings != null && settings.data.devModeEnabled;
	}

	public static function isDevModeActive():Bool
	{
		#if SHARK_DEV_MODE
		return true;
		#else
		return isDevModeEnabled();
		#end
	}

	public static function toggleDevMode():Bool
	{
		var newValue:Bool = !isDevModeEnabled();

		settings.update(function(d:SettingsData):Void d.devModeEnabled = newValue);
		CrasherLog.minLogSeverity = isDevModeActive() ? "trace" : "warning";

		return newValue;
	}

	function reportCrashRemotely(entry:CrashEntry):Void
	{
		var endpoint:String = Servers.getDiagnosticsEndpoint();

		if (endpoint == null || endpoint.length == 0)
			return;

		Online.enqueueRetry('crash-report-${entry.timestamp}', function():Void
		{
			try
			{
				var http:Http = new Http(endpoint);
				http.setHeader("Content-Type", "application/json");
				http.setPostData(Json.stringify(entry));
				http.request(true);
			}
			catch (e:Dynamic) {}
		});
	}

	function recordBootPhase(phase:String):Void
	{
		var now:Float = Timer.stamp();

		if (bootStartTime < 0)
			bootStartTime = now;

		bootPhases.push({phase: phase, ms: (now - bootStartTime) * 1000});
	}

	function extractBundledMods():Void
	{
		#if (sys && SHARK_HAS_BUNDLED_MODS)
		try
		{
			if (!Module.ensureModsDirectory())
				return;

			var prefix:String = "assets/mods/";
			var suffix:String = "." + Module.SCRIPT_EXTENSION;

			for (path in openfl.utils.Assets.list())
			{
				if (!StringTools.startsWith(path, prefix) || !StringTools.endsWith(path, suffix))
					continue;

				var filename:String = path.substr(prefix.length);
				var destPath:String = Module.getModsDirectory() + "/" + filename;

				if (sys.FileSystem.exists(destPath))
					continue;

				try
				{
					var content:String = openfl.utils.Assets.getText(path);
					sys.io.File.saveContent(destPath, content);
				}
				catch (e:Dynamic)
				{
					CrasherLog.logWarning('Failed to extract bundled mod: $filename');
				}
			}
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Mod extraction failed entirely: ${Std.string(e)}');
		}
		#end
	}

	function setupMods():Void
	{
		FlxG.signals.postUpdate.add(function():Void
		{
			Mods.updateAll(FlxG.elapsed);
		});
	}

	function setupTouch():Void
	{
		#if FLX_TOUCH
		FlxG.signals.postUpdate.add(function():Void
		{
			TouchUtil.update(FlxG.elapsed);
		});
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
		applyDiscordSection(parsed.discord);
		applyPlatformsSection(parsed.platforms);
		validateConfigSchema(parsed);

		if (wasFirstLaunch)
			settings.update(function(d:SettingsData):Void d.hasCompletedFirstRun = true);

		isNetworkConfigLoaded = true;
	}

	static var knownConfigSections:Array<String> = [
		"network", "chat", "api", "image", "audio", "security", "connectivity", "app", "discord", "platforms", "servers"
	];

	function validateConfigSchema(parsed:Dynamic):Void
	{
		var unknownSections:Array<String> = [];

		for (field in Reflect.fields(parsed))
			if (knownConfigSections.indexOf(field) == -1)
				unknownSections.push(field);

		if (unknownSections.length > 0)
			CrasherLog.logWarning('config.json has unrecognized section(s): ${unknownSections.join(", ")} - check for typos', "config");

		if (parsed.network == null)
			CrasherLog.logWarning("config.json is missing the \"network\" section entirely - chat/image won't work", "config");
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
		if (section == null || !wasFirstLaunch)
			return;

		settings.update(function(d:SettingsData):Void
		{
			if (section.musicVolume != null)
				d.musicVolume = section.musicVolume;

			if (section.soundVolume != null)
				d.soundVolume = section.soundVolume;

			if (section.startMuted != null)
				d.muted = section.startMuted;
		});

		Audio.setMuted(settings.data.muted);
		Audio.musicVolume = settings.data.musicVolume;
		Audio.soundVolume = settings.data.soundVolume;
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

	var discordEnabled:Bool = false;
	var discordClientId:String = "";

	function applyDiscordSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.enabled != null)
			discordEnabled = section.enabled;

		if (section.clientId != null)
			discordClientId = section.clientId;
	}

	function setupDiscord():Void
	{
		#if cpp
		if (!discordEnabled || StringTools.trim(discordClientId).length == 0)
			return;

		try
		{
			Discord.initialize(discordClientId);
			Discord.update("In the main menu", "Just started up");
			FlxG.signals.postUpdate.add(Discord.runCallbacks);
		}
		catch (e:Dynamic)
		{
			CrasherLog.logWarning('Discord RPC failed to initialize: ${Std.string(e)}');
		}
		#end
	}

	var newgroundsEnabled:Bool = false;
	var newgroundsAppId:String = "";
	var googlePlayGamesEnabled:Bool = false;
	var countryDetectionEnabled:Bool = false;

	function applyPlatformsSection(section:Dynamic):Void
	{
		if (section == null)
			return;

		if (section.newgrounds != null)
		{
			if (section.newgrounds.enabled != null)
				newgroundsEnabled = section.newgrounds.enabled;

			if (section.newgrounds.appId != null)
				newgroundsAppId = section.newgrounds.appId;
		}

		if (section.googlePlayGames != null && section.googlePlayGames.enabled != null)
			googlePlayGamesEnabled = section.googlePlayGames.enabled;

		if (section.countryDetection != null && section.countryDetection.enabled != null)
			countryDetectionEnabled = section.countryDetection.enabled;
	}

	function setupPlatforms():Void
	{
		if (newgroundsEnabled && StringTools.trim(newgroundsAppId).length > 0)
		{
			try
			{
				NewClient.initialize(newgroundsAppId);
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Newgrounds failed to initialize: ${Std.string(e)}', "platforms");
			}
		}

		#if android
		if (googlePlayGamesEnabled)
		{
			try
			{
				GoogleClient.initialize(false);
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('Google Play Games failed to initialize: ${Std.string(e)}', "platforms");
			}
		}
		#end

		if (countryDetectionEnabled)
			Country.detect();
	}

	function setupStateTracking():Void
	{
		FlxG.signals.postStateSwitch.add(onStateSwitched);
	}

	function onStateSwitched():Void
	{
		if (FlxG.state == null)
			return;

		var stateName:String = Type.getClassName(Type.getClass(FlxG.state));
		CrasherLog.addBreadcrumb('Switched to $stateName', "navigation");

		#if cpp
		if (discordEnabled)
			Discord.update(stateLabelFor(stateName), "");
		#end
	}

	function stateLabelFor(stateName:String):String
	{
		return switch (stateName)
		{
			case "shark.menus.MainMenuState": "Chatting with Shark";
			case "shark.active.GameState": "Choosing a mini-game";
			case "shark.active.games.BubblePopState": "Playing Bubble Pop";
			case "shark.active.games.ReefRunnerState": "Playing Reef Runner";
			case "shark.active.games.DeepDiveState": "Playing Deep Dive";
			case "shark.menus.options.OptionsState": "Adjusting settings";
			default: "Exploring the app";
		}
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
		Online.start();

		if (ChatEngine.endpoint != null && ChatEngine.endpoint.length > 0)
			Online.configureApi(ChatEngine.endpoint);

		Online.addStatusListener(onConnectivityChanged);
		Online.addApiStatusListener(onApiStatusChanged);
	}

	function onConnectivityChanged(isOnline:Bool):Void
	{
		CrasherLog.addBreadcrumb(isOnline ? "Back online" : "Went offline", "connectivity");
	}

	function onApiStatusChanged(isOnline:Bool):Void
	{
		CrasherLog.addBreadcrumb(isOnline ? "Shark API reachable" : "Shark API unreachable", "connectivity");
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
		WindowTheme.initialize();

		#if mobile
		FlxG.scaleMode = new flixel.system.scaleModes.RatioScaleMode();
		#end
	}

	function setupDebugOverlay():Void
	{
		debugOverlay = new DebugDisplay(10, 30);
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

		settings.update(function(d:SettingsData):Void d.showFpsCounter = debugOverlayVisible);
		Vibration.trigger(HapticStyle.SELECTION);

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

	public static var onReady:Array<Void->Void> = [];
	public static var onPause:Array<Void->Void> = [];
	public static var onResume:Array<Void->Void> = [];

	static var readyFired:Bool = false;

	public static function addReadyListener(callback:Void->Void):Void
	{
		if (readyFired)
		{
			callback();
			return;
		}

		onReady.push(callback);
	}

	public static function addPauseListener(callback:Void->Void):Void
	{
		onPause.push(callback);
	}

	public static function addResumeListener(callback:Void->Void):Void
	{
		onResume.push(callback);
	}

	static function fireReady():Void
	{
		if (readyFired)
			return;

		readyFired = true;

		for (callback in onReady)
		{
			try
			{
				callback();
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning('onReady listener failed: ${Std.string(e)}', "lifecycle");
			}
		}
	}

	static function firePause():Void
	{
		for (callback in onPause)
		{
			try
			{
				callback();
			}
			catch (e:Dynamic) {}
		}
	}

	static function fireResume():Void
	{
		for (callback in onResume)
		{
			try
			{
				callback();
			}
			catch (e:Dynamic) {}
		}
	}

	public static function getDiagnostics():String
	{
		return Native.getFullReport();
	}

	public static function getFullDiagnostics():String
	{
		var sections:Array<String> = [
			"-- App --",
			getAppSummary(),
			"-- Boot --",
			getBootReport(),
			"-- Connectivity --",
			Online.getSummary(),
			"-- Servers --",
			Servers.getStatusSummary(),
			"-- Vibration --",
			Vibration.getStatusSummary(),
			"-- Crash log --",
			CrasherLog.getStatusSummary(),
			"-- Settings --",
			settings != null ? settings.getStatusSummary() : "not loaded",
			"-- Storage --",
			StorageUtil.getStatusSummary(),
			"-- Native --",
			Native.getFullReport()
		];

		return sections.join("\n\n");
	}

	public static function getBootReport():String
	{
		var lines:Array<String> = [];

		for (entry in bootPhases)
			lines.push('${entry.phase}: ${Std.int(entry.ms)}ms');

		return lines.join("\n");
	}

	public static function getBuildInfo():Dynamic
	{
		try
		{
			return Paths.getJson("build_info");
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public static function getAppSummary():String
	{
		var lines:Array<String> = [
			'Language: $systemLanguage',
			'Network trusted: $isNetworkConfigTrusted',
			'Safe mode: $isSafeMode',
			ChatEngine.getHistorySummary(),
			CrasherLog.getCategorySummary()
		];

		var buildInfo:Dynamic = getBuildInfo();

		if (buildInfo != null)
			lines.push('Build: ${Reflect.field(buildInfo, "version")} (${Reflect.field(buildInfo, "commit")}) [${Reflect.field(buildInfo, "environment")}]');

		var activeServer = Servers.getActiveProfile();

		if (activeServer != null)
			lines.push('Server: ${activeServer.label} (${Servers.isReachable() ? "reachable" : "unreachable"})');

		return lines.join(" | ");
	}

	public static function isFirstLaunch():Bool
	{
		return wasFirstLaunch;
	}

	public static function getSettings():DataFile<SettingsData>
	{
		return settings;
	}

	public static function isReady():Bool
	{
		return readyFired;
	}

	public static function restartChat():Void
	{
		Head.reset();
	}

	public static function forceGarbageCollect():Void
	{
		Native.collectGarbage(true);
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

		#if android
		if (settings != null && settings.data.hasRequestedExternalStoragePermission)
			notifyExternalStoragePermission(StorageUtil.hasExternalStoragePermission());
		#end

		fireResume();
	}

	function onDeactivate(e:Event):Void
	{
		isActive = false;
		Audio.pauseMusic();

		if (FlxG.sound != null)
			FlxG.sound.pause();

		Vibration.cancel();
		flushSave();
		firePause();
	}

	#if sys
	function onExiting(e:Event):Void
	{
		flushSave();

		#if cpp
		if (discordEnabled)
			Discord.shutdown();
		#end
	}
	#end

	function flushSave():Void
	{
		settings.update(function(d:SettingsData):Void
		{
			d.muted = Audio.isMuted;
			d.musicVolume = Audio.musicVolume;
			d.soundVolume = Audio.soundVolume;
		});

		settings.forceSave();
		CrasherLog.flush();
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

		Vibration.menuSelect();
		CrasherLog.addBreadcrumb("Back button pressed", "input");
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
	}

	function enterSafeMode():Void
	{
		isSafeMode = true;

		Online.stop();
		LimeManager.disableRuntimeOptimization();
		Audio.stopMusic(0);
		Vibration.cancel();
		Vibration.setEnabled(false);

		CrasherLog.setContext("safeMode", "true");
		CrasherLog.logSecurity("Entered safe mode after repeated crashes");

		if (FlxG.state != null && !Std.isOfType(FlxG.state, MainMenuState))
			FlxG.switchState(new MainMenuState());
	}

	function logSecurityEvent(message:String):Void
	{
		CrasherLog.logSecurity(message);
	}
}
