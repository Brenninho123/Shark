package shark.server;

import haxe.Http;
import haxe.Timer;
import shark.backend.Paths;
import shark.functions.ChatEngine;
import shark.functions.ImageCreator;
import shark.online.Online;
import shark.ui.debug.CrasherLog;
import shark.ui.security.Guard;

import Main;

typedef ServerProfile = {
	id:String,
	label:String,
	chatEndpoint:String,
	imageEndpoint:String,
	diagnosticsEndpoint:String,
	requiresApiKey:Bool,
	isOfficial:Bool
}

class Servers
{
	static inline var TEST_TIMEOUT_MS:Int = 8000;

	static var profiles:Array<ServerProfile> = [];
	static var isSetup:Bool = false;

	public static function setup():Void
	{
		buildProfileList();

		var active:ServerProfile = getActiveProfile();

		if (active != null)
			applyProfile(active);

		isSetup = true;
	}

	static function buildProfileList():Void
	{
		profiles = [];

		var config:Dynamic = Paths.getJson("config");
		var network:Dynamic = config != null ? Reflect.field(config, "network") : null;
		var officialDiagnostics:String = network != null ? safeField(network, "diagnosticsEndpoint", "") : "";

		profiles.push({
			id: "official",
			label: "Official",
			chatEndpoint: ChatEngine.endpoint,
			imageEndpoint: ImageCreator.endpoint,
			diagnosticsEndpoint: officialDiagnostics,
			requiresApiKey: true,
			isOfficial: true
		});

		if (config != null && Reflect.hasField(config, "servers"))
		{
			try
			{
				var list:Array<Dynamic> = Reflect.field(config, "servers");

				for (entry in list)
				{
					var id:String = safeField(entry, "id", "");

					if (id.length == 0)
						continue;

					profiles.push({
						id: id,
						label: safeField(entry, "label", id),
						chatEndpoint: safeField(entry, "chatEndpoint", ""),
						imageEndpoint: safeField(entry, "imageEndpoint", ""),
						diagnosticsEndpoint: safeField(entry, "diagnosticsEndpoint", ""),
						requiresApiKey: Reflect.hasField(entry, "requiresApiKey") ? Reflect.field(entry, "requiresApiKey") == true : true,
						isOfficial: false
					});
				}
			}
			catch (e:Dynamic)
			{
				CrasherLog.logWarning("config.json \"servers\" section could not be parsed - ignoring extra server profiles.", "server");
			}
		}

		profiles.push(buildCustomProfile());
	}

	static function buildCustomProfile():ServerProfile
	{
		var label:String = Main.settings.data.customServerLabel;

		return {
			id: "custom",
			label: label != null && label.length > 0 ? label : "My Own Server",
			chatEndpoint: Main.settings.data.customServerChatEndpoint,
			imageEndpoint: Main.settings.data.customServerImageEndpoint,
			diagnosticsEndpoint: "",
			requiresApiKey: Main.settings.data.customServerApiKey != null && Main.settings.data.customServerApiKey.length > 0,
			isOfficial: false
		};
	}

	static function rebuildCustomProfileInPlace():Void
	{
		for (i in 0...profiles.length)
			if (profiles[i].id == "custom")
				profiles[i] = buildCustomProfile();
	}

	static function safeField(source:Dynamic, field:String, fallback:String):String
	{
		if (source == null)
			return fallback;

		var value:Dynamic = Reflect.field(source, field);
		return value != null ? Std.string(value) : fallback;
	}

	public static function getProfiles():Array<ServerProfile>
	{
		return profiles.copy();
	}

	public static function getActiveProfile():ServerProfile
	{
		for (profile in profiles)
			if (profile.id == Main.settings.data.activeServerProfileId)
				return profile;

		return profiles.length > 0 ? profiles[0] : null;
	}

	public static function setActiveProfile(id:String):Bool
	{
		var profile:ServerProfile = null;

		for (candidate in profiles)
			if (candidate.id == id)
				profile = candidate;

		if (profile == null)
			return false;

		if (StringTools.trim(profile.chatEndpoint).length > 0 && !Guard.isValidUrl(profile.chatEndpoint))
		{
			CrasherLog.logSecurity('Rejected server profile "${profile.id}" - invalid chat endpoint');
			return false;
		}

		if (StringTools.trim(profile.imageEndpoint).length > 0 && !Guard.isValidUrl(profile.imageEndpoint))
		{
			CrasherLog.logSecurity('Rejected server profile "${profile.id}" - invalid image endpoint');
			return false;
		}

		Main.settings.update(function(d) d.activeServerProfileId = profile.id);
		applyProfile(profile);

		return true;
	}

	static function applyProfile(profile:ServerProfile):Void
	{
		ChatEngine.endpoint = profile.chatEndpoint;
		ImageCreator.endpoint = profile.imageEndpoint;

		if (profile.id == "custom")
		{
			ChatEngine.apiKey = Main.settings.data.customServerApiKey;
			ImageCreator.apiKey = Main.settings.data.customServerApiKey;
		}

		Main.setNetworkTrusted(true);

		if (ChatEngine.endpoint != null && ChatEngine.endpoint.length > 0)
			Online.configureApi(ChatEngine.endpoint);

		CrasherLog.addBreadcrumb('Switched to server profile "${profile.id}"', "server");
	}

	public static function setCustomServer(label:String, chatEndpoint:String, imageEndpoint:String, apiKey:String):Bool
	{
		var trimmedChat:String = StringTools.trim(chatEndpoint);
		var trimmedImage:String = StringTools.trim(imageEndpoint);

		if (trimmedChat.length > 0 && !Guard.isValidUrl(trimmedChat))
		{
			CrasherLog.logSecurity("Rejected custom server - invalid chat endpoint");
			return false;
		}

		if (trimmedImage.length > 0 && !Guard.isValidUrl(trimmedImage))
		{
			CrasherLog.logSecurity("Rejected custom server - invalid image endpoint");
			return false;
		}

		Main.settings.update(function(d):Void
		{
			d.customServerLabel = label;
			d.customServerChatEndpoint = trimmedChat;
			d.customServerImageEndpoint = trimmedImage;
			d.customServerApiKey = apiKey;
		});

		rebuildCustomProfileInPlace();

		CrasherLog.addBreadcrumb("Custom server profile updated", "server");

		if (Main.settings.data.activeServerProfileId == "custom")
			return setActiveProfile("custom");

		return true;
	}

	public static function getDiagnosticsEndpoint():String
	{
		var active:ServerProfile = getActiveProfile();
		return active != null ? active.diagnosticsEndpoint : "";
	}

	public static function isReachable():Bool
	{
		return Online.apiOnline;
	}

	public static function getLatencyMs():Float
	{
		return Online.apiLatencyMs;
	}

	public static function testEndpoint(chatEndpoint:String, onResult:Bool->Float->Void):Void
	{
		testProfile({
			id: "test",
			label: "Test",
			chatEndpoint: chatEndpoint,
			imageEndpoint: "",
			diagnosticsEndpoint: "",
			requiresApiKey: false,
			isOfficial: false
		}, onResult);
	}

	public static function testProfile(profile:ServerProfile, onResult:Bool->Float->Void):Void
	{
		if (profile == null || StringTools.trim(profile.chatEndpoint).length == 0)
		{
			onResult(false, -1);
			return;
		}

		if (!Guard.isValidUrl(profile.chatEndpoint))
		{
			onResult(false, -1);
			return;
		}

		var startTime:Float = Timer.stamp();
		var http:Http = new Http(profile.chatEndpoint);
		var finished:Bool = false;

		var timeoutTimer = Timer.delay(function():Void
		{
			if (finished)
				return;

			finished = true;
			onResult(false, -1);
		}, TEST_TIMEOUT_MS);

		http.onData = function(data:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			onResult(true, (Timer.stamp() - startTime) * 1000);
		};

		http.onError = function(msg:String):Void
		{
			if (finished)
				return;

			finished = true;
			timeoutTimer.stop();
			onResult(false, -1);
		};

		http.request(false);
	}

	public static function getStatusSummary():String
	{
		var active:ServerProfile = getActiveProfile();
		var label:String = active != null ? active.label : "none";
		var latencyLabel:String = Online.apiLatencyMs < 0 ? "n/a" : '${Std.int(Online.apiLatencyMs)}ms';

		return 'Servers: active=$label, profiles=${profiles.length}, reachable=${isReachable()}, latency=$latencyLabel';
	}
}
